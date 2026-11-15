import { integer, real, sqliteTable, text } from 'drizzle-orm/sqlite-core';
import type { ReviewStatus, SurveyStatus, SyncState, UploadState } from '../contract/contract';

// One table per contract entity, one column per contract field, the same
// names. A column that may be null in the contract has no .notNull().

/** Every row: its id and the two timestamps the writer sets. */
const row = () => ({
  id: text().primaryKey(),
  createdAt: text().notNull(),
  updatedAt: text().notNull(),
});

/** The contract's local-only columns: kept on the phone, never sent. */
const local = () => ({
  syncState: text().$type<SyncState>().notNull().default('pending'),
  lastError: text(),
});

export const buildings = sqliteTable('buildings', {
  ...row(),
  label: text().notNull(),
  comment: text(),
  ...local(),
});

export const entrances = sqliteTable('entrances', {
  ...row(),
  buildingId: text()
    .notNull()
    .references(() => buildings.id),
  lat: real().notNull(),
  lng: real().notNull(),
  street: text().notNull(),
  number: text().notNull(),
  entranceName: text().notNull(),
  coordsConfirmed: integer({ mode: 'boolean' }).notNull(),
  correctedLat: real(),
  correctedLng: real(),
  addressConfirmed: integer({ mode: 'boolean' }).notNull(),
  stories: integer(),
  flats: integer(),
  elevators: integer(),
  yearBuilt: integer(),
  groundFloorCommercial: integer({ mode: 'boolean' }),
  comment: text(),
  surveyStatus: text().$type<SurveyStatus>().notNull(),
  surveyedBy: text(),
  surveyedAt: text(),
  ...local(),
  /** Exercise 1 — local-only: when this phone last opened the entrance. */
  openedAt: text(),
});

export const photos = sqliteTable('photos', {
  ...row(),
  entranceId: text()
    .notNull()
    .references(() => entrances.id),
  fileName: text().notNull(),
  remoteUrl: text(),
  takenAt: text().notNull(),
  lat: real(),
  lng: real(),
  heading: real(),
  uploadState: text().$type<UploadState>().notNull().default('pending'),
  reviewStatus: text().$type<ReviewStatus>().notNull().default('pending'),
  reviewNote: text(),
  reviewedBy: text(),
  replacesPhotoId: text(),
  ...local(),
  /** Where the file is on this phone (local-only, like syncState). */
  localUri: text().notNull(),
});

export type PhotoRow = typeof photos.$inferSelect;

/**
 * Week 5, step 4: the photo queue (local only, never sent). One row per photo
 * to upload, with the photo's id; snake_case columns, like the queue in the
 * explainer. state: pending → uploading → synced, or failed after MAX_ATTEMPTS.
 */
export const photoQueue = sqliteTable('photo_queue', {
  id: text().primaryKey(), // the photo's id (UUID v4, made on the phone)
  entranceId: text('entrance_id').notNull(),
  localUri: text('local_uri').notNull(), // the file in the app's own folder
  remotePath: text('remote_path').notNull(), // <user id>/<entrance id>/<photo id>.jpg, fixed at queue time
  state: text().$type<'pending' | 'uploading' | 'synced' | 'failed'>().notNull().default('pending'),
  attempts: integer().notNull().default(0),
  nextAttemptAt: integer('next_attempt_at').notNull().default(0), // ms since 1970: the backoff's memory
  lastError: text('last_error'),
  createdAt: integer('created_at').notNull(), // ms since 1970
});

export type QueueRow = typeof photoQueue.$inferSelect;
