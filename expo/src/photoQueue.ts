import { and, asc, eq, inArray, lte, ne } from 'drizzle-orm';
import { useLiveQuery } from 'drizzle-orm/expo-sqlite';
import * as Network from 'expo-network';
import Storage from 'expo-sqlite/kv-store';
import { Platform } from 'react-native';
import { db } from './db/db';
import { photoQueue, photos, type QueueRow } from './db/schema';
import { supabase } from './supabase';

// Week 5, step 4: the photo queue. Photos leave the phone on Wi-Fi (or on mobile
// data, if the worker allows it), a few at a time, with backoff and jitter after a
// failure, and resume after a restart, on foreground and when the network returns.
// Foreground only: uploading with the phone locked is the OS's job (not built here).

const BUCKET = 'survey-photos';
const BATCH = 3; // photos at once
const BASE_MS = 2_000;
const CAP_MS = 300_000;
const MAX_ATTEMPTS = 6;
const MAX_BYTES = 6 * 1024 * 1024; // the bucket's limit (step 4's migration)

/** Full jitter: a random wait between 0 and min(cap, base × 2^attempt). */
export function retryDelay(attempt: number, random = Math.random): number {
  return random() * Math.min(CAP_MS, BASE_MS * 2 ** attempt);
}

// "Use mobile data for photos": a preference, not data (off by default: the worker's plan).
const CELLULAR = 'field.photosOnCellular';
export const cellularSetting = {
  get: () => Storage.getItemSync(CELLULAR) === '1',
  set: (on: boolean) => Storage.setItemSync(CELLULAR, on ? '1' : '0'),
};

/** The upload policy: a filter, not a promise (a captive portal says "Wi-Fi" too). */
export async function mayUpload(allowCellular: boolean): Promise<boolean> {
  // The browser hides the connection type (always UNKNOWN): on the web, online is enough.
  if (Platform.OS === 'web') return navigator.onLine;
  const s = await Network.getNetworkStateAsync();
  if (!s.isConnected || s.isInternetReachable === false) return false;
  if (s.type === Network.NetworkStateType.WIFI || s.type === Network.NetworkStateType.ETHERNET) return true;
  return allowCellular && s.type === Network.NetworkStateType.CELLULAR;
}

/**
 * The file's real type, from its first bytes: a PNG starts with 89 50 4E 47,
 * anything else goes as JPEG. Storage checks only the type the app declares,
 * so the app must declare the true one. (An unreadable file: 'jpg'; its
 * upload will fail and say why.)
 */
async function extensionOf(localUri: string): Promise<'png' | 'jpg'> {
  const head = new Uint8Array(await readBytes(localUri).catch(() => new ArrayBuffer(0))).slice(0, 4);
  const png = head.length === 4 && head[0] === 0x89 && head[1] === 0x50 && head[2] === 0x4e && head[3] === 0x47;
  return png ? 'png' : 'jpg';
}

const pathFor = async (uid: string, entranceId: string, photoId: string, localUri: string) =>
  `${uid}/${entranceId}/${photoId}.${await extensionOf(localUri)}`;

/** Queue a photo the moment it is saved: its remote path is fixed now, so a resend overwrites. */
export async function enqueue(photoId: string, entranceId: string, localUri: string, uid: string) {
  await db.insert(photoQueue).values({
    id: photoId,
    entranceId,
    localUri,
    remotePath: await pathFor(uid, entranceId, photoId, localUri),
    createdAt: Date.now(),
  });
}

/** Photos this phone still has to upload (waiting, on the wire, or failed). */
export async function waitingPhotos(): Promise<number> {
  return (await db.select({ id: photoQueue.id }).from(photoQueue).where(ne(photoQueue.state, 'synced'))).length;
}

/**
 * At start: a killed app leaves rows 'uploading' forever, so they go back to
 * 'pending'; and the photos of weeks 3–4, which waited on the phone with no
 * queue, join it.
 */
export async function resetUploading(uid: string) {
  await db.update(photoQueue).set({ state: 'pending' }).where(eq(photoQueue.state, 'uploading'));
  const waiting = await db.select().from(photos).where(ne(photos.uploadState, 'uploaded'));
  for (const p of waiting) {
    await db
      .insert(photoQueue)
      .values({
        id: p.id,
        entranceId: p.entranceId,
        localUri: p.localUri,
        remotePath: await pathFor(uid, p.entranceId, p.id, p.localUri),
        createdAt: Date.now(),
      })
      .onConflictDoNothing();
  }
}

const setState = (id: string, values: Partial<QueueRow>) =>
  db.update(photoQueue).set(values).where(eq(photoQueue.id, id));

/** The contract's uploadState follows the queue: pending/uploading → pending, synced → uploaded. */
const setUploadState = (id: string, uploadState: 'uploaded' | 'failed', lastError: string | null) =>
  db.update(photos).set({ uploadState, lastError }).where(eq(photos.id, id));

function markRetry(row: QueueRow, message: string) {
  const attempts = row.attempts + 1;
  if (attempts >= MAX_ATTEMPTS) {
    return Promise.all([
      setState(row.id, { state: 'failed', attempts, lastError: message }),
      setUploadState(row.id, 'failed', message),
    ]);
  }
  return setState(row.id, {
    state: 'pending',
    attempts,
    lastError: message,
    nextAttemptAt: Date.now() + retryDelay(row.attempts),
  });
}

/** Read the file: a file:// path on the phone, a data: URI on the web; fetch reads both. */
async function readBytes(uri: string): Promise<ArrayBuffer> {
  return (await fetch(uri)).arrayBuffer();
}

/** One photo: the file first, then its row in survey_photos. Never throws: it writes the outcome. */
async function uploadOne(row: QueueRow) {
  await setState(row.id, { state: 'uploading' });
  try {
    const bytes = await readBytes(row.localUri);
    if (bytes.byteLength > MAX_BYTES) throw new Permanent('The photo is larger than 6 MiB: the bucket refuses it.');
    // upsert: a retry after "the file arrived but the answer was lost" overwrites the same object.
    const up = await supabase.storage
      .from(BUCKET)
      .upload(row.remotePath, bytes, { contentType: row.remotePath.endsWith('.png') ? 'image/png' : 'image/jpeg', upsert: true });
    if (up.error) throw new Error(`upload: ${up.error.message}`);
    // Then the row (no update grant on survey_photos: the row exists only for a finished upload).
    const [p] = await db.select().from(photos).where(eq(photos.id, row.id));
    const ins = await supabase.from('survey_photos').insert({
      id: p.id,
      entrance_id: p.entranceId,
      file_name: row.remotePath.split('/').pop() ?? p.fileName, // <photo id>.jpg or .png
      remote_path: row.remotePath,
      taken_at: p.takenAt,
      lat: p.lat,
      lng: p.lng,
      heading: p.heading,
      upload_state: 'uploaded',
    });
    // 23505: the row is already there (an earlier try inserted it, the answer was lost): done.
    if (ins.error && ins.error.code !== '23505') {
      if (ins.error.code === '42501') throw new Permanent(`This entrance is not yours any more (${ins.error.code}).`);
      throw new Error(`survey_photos: ${ins.error.code} ${ins.error.message}`);
    }
    await setState(row.id, { state: 'synced', lastError: null });
    await setUploadState(row.id, 'uploaded', null);
  } catch (e) {
    if (e instanceof Permanent) {
      await setState(row.id, { state: 'failed', attempts: row.attempts + 1, lastError: e.message });
      await setUploadState(row.id, 'failed', e.message);
    } else await markRetry(row, e instanceof Error ? e.message : String(e));
  }
}

/** A failure no retry can fix: straight to failed. */
class Permanent extends Error {}

let running = false;

/** The worker: single-flight, batches of 3, re-reads the table after every batch. */
export async function drainQueue() {
  if (running) return;
  running = true;
  try {
    while (await mayUpload(cellularSetting.get())) {
      const batch = await db
        .select()
        .from(photoQueue)
        .where(and(eq(photoQueue.state, 'pending'), lte(photoQueue.nextAttemptAt, Date.now())))
        .orderBy(asc(photoQueue.createdAt))
        .limit(BATCH);
      if (batch.length === 0) break;
      await Promise.all(batch.map(uploadOne)); // each writes its own row
    }
  } finally {
    running = false;
  }
  // Rows waiting out a backoff: look again when the earliest is due (foreground only).
  const [next] = await db
    .select({ at: photoQueue.nextAttemptAt })
    .from(photoQueue)
    .where(eq(photoQueue.state, 'pending'))
    .orderBy(asc(photoQueue.nextAttemptAt))
    .limit(1);
  // shortcut: a timer in the foreground only; a killed app waits for the next trigger instead.
  if (next && next.at > Date.now() && !timer) {
    timer = setTimeout(() => {
      timer = null;
      drainQueue();
    }, next.at - Date.now() + 100);
  }
}
let timer: ReturnType<typeof setTimeout> | null = null;

/** Retry, on a failed photo: back to pending, attempts from zero. */
export async function retryPhoto(id: string) {
  await setState(id, { state: 'pending', attempts: 0, nextAttemptAt: 0, lastError: null });
  await db.update(photos).set({ uploadState: 'pending', lastError: null }).where(eq(photos.id, id));
  await drainQueue();
}

/** The queue, for the screens: one entrance's rows, or the counts for the banner. */
export function useQueue(entranceId?: string): QueueRow[] {
  return useLiveQuery(
    entranceId
      ? db.select().from(photoQueue).where(eq(photoQueue.entranceId, entranceId))
      : db.select().from(photoQueue).where(inArray(photoQueue.state, ['pending', 'uploading', 'failed'])),
    [entranceId],
  ).data;
}
