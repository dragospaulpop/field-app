import type { Entrance } from './contract/contract';
import type { PinsRepository, SurveyDoc, SurveysRepository } from './repositories';
import { supabase } from './supabase';

// Postgres speaks snake_case, the contract camelCase. This file is the ONLY place that knows.
type EntranceRow = {
  id: string;
  building_id: string;
  lat: number;
  lng: number;
  street: string;
  number: string;
  entrance_name: string;
  coords_confirmed: boolean;
  corrected_lat: number | null;
  corrected_lng: number | null;
  address_confirmed: boolean;
  stories: number | null;
  flats: number | null;
  elevators: number | null;
  year_built: number | null;
  ground_floor_commercial: boolean | null;
  comment: string | null;
  survey_status: Entrance['surveyStatus'];
  surveyed_by: string | null;
  surveyed_at: string | null;
  created_at: string;
  updated_at: string;
};

// PostgREST answers "2026-11-03T16:30:00+00:00"; the contract (and SQLite, and the
// pull's newer-than comparison) uses "2026-11-03T16:30:00.000Z". One form, made here.
const iso = (t: string) => new Date(t).toISOString();

export const toEntrance = (r: EntranceRow): Entrance => ({
  id: r.id,
  buildingId: r.building_id,
  lat: r.lat,
  lng: r.lng,
  street: r.street,
  number: r.number,
  entranceName: r.entrance_name,
  coordsConfirmed: r.coords_confirmed,
  correctedLat: r.corrected_lat,
  correctedLng: r.corrected_lng,
  addressConfirmed: r.address_confirmed,
  stories: r.stories,
  flats: r.flats,
  elevators: r.elevators,
  yearBuilt: r.year_built,
  groundFloorCommercial: r.ground_floor_commercial,
  comment: r.comment,
  surveyStatus: r.survey_status,
  surveyedBy: r.surveyed_by,
  surveyedAt: r.surveyed_at === null ? null : iso(r.surveyed_at),
  createdAt: iso(r.created_at),
  updatedAt: iso(r.updated_at),
});

let pullNow: (() => void) | null = null;

export const supabasePins: PinsRepository = {
  watchMine(uid, onPins, onError) {
    // Firestore pushed every change; Postgres answers when asked. So the app asks
    // now, and on refresh(): after every push (start, foreground, network back,
    // Sync now). Realtime, which pushes, is the stretch moon of this step.
    const pull = async () => {
      // RLS already limits this to my rows: the filter states the intent and uses the index.
      const { data, error } = await supabase.from('entrances').select('*').eq('assigned_to', uid);
      if (error) onError(new Error(error.message));
      else onPins((data as EntranceRow[]).map(toEntrance));
    };
    pull();
    pullNow = pull;
    return () => {
      pullNow = null; // signed out: no more pulls
    };
  },
  refresh: () => pullNow?.(),
};

// Errors that a retry cannot fix: a missing privilege (an office column), a check
// constraint, a NOT NULL, a value of the wrong type. Everything else is retried.
const PERMANENT = new Set(['42501', '23514', '23502', '22P02']);

/** The sentence the worker reads; the code is for the developer, in brackets. */
function sentence(code: string, message: string) {
  if (code === '42501')
    return `This app tried to change something only the office may change. Tell your teacher: it is a bug. (${code})`;
  if (code === '23514') return `One of the numbers is outside what the form allows. (${code}: ${message})`;
  return `The server refused this survey. (${code}: ${message})`;
}

export const supabaseSurveys: SurveysRepository = {
  async push(s: SurveyDoc) {
    // One call, one statement on the server: applied only if this version is newer
    // than the row's (row-level last-writer-wins, judged by Postgres, not the phone).
    const { data, error } = await supabase.rpc('upsert_survey', {
      p_entrance_id: s.id,
      p_fields: {
        street: s.street,
        number: s.number,
        entrance_name: s.entranceName,
        coords_confirmed: s.coordsConfirmed,
        corrected_lat: s.correctedLat,
        corrected_lng: s.correctedLng,
        address_confirmed: s.addressConfirmed,
        stories: s.stories,
        flats: s.flats,
        elevators: s.elevators,
        year_built: s.yearBuilt,
        ground_floor_commercial: s.groundFloorCommercial,
        comment: s.comment,
        survey_status: s.surveyStatus,
        surveyed_at: s.surveyedAt,
        // no surveyed_by: the server takes it from the token (auth.uid())
      },
      p_client_updated_at: s.updatedAt,
    });
    if (error) {
      // No network: supabase-js returns an error with an empty code (no database answered).
      return PERMANENT.has(error.code)
        ? { kind: 'refused', message: sentence(error.code, error.message) }
        : { kind: 'retry', message: error.message };
    }
    return data === true ? { kind: 'applied' } : { kind: 'lost' };
  },
};

/** Dev only (step 3's check): try to move a pin, which is the office's column. Expect 42501. */
export async function tryToMovePin(id: string, lat: number): Promise<string> {
  const { error } = await supabase.from('entrances').update({ lat }).eq('id', id);
  return error ? `${error.code}: ${error.message}` : 'moved: the office column is NOT protected';
}
