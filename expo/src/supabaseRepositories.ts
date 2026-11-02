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

export const supabaseSurveys: SurveysRepository = {
  async push(s: SurveyDoc) {
    const { data, error } = await supabase
      .from('entrances')
      .update({
        // The survey's columns only, never the office's (lat, lng, assigned_to...).
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
        surveyed_by: s.surveyedBy,
        surveyed_at: s.surveyedAt,
        updated_at: s.updatedAt,
      })
      .eq('id', s.id)
      .select('id'); // ask for the changed rows back
    if (error) throw new Error(`${error.code}: ${error.message}`);
    // Zero rows and no error: RLS hid the row (it is not mine any more). That is a refusal.
    if (data.length === 0) throw new Error('refused: this entrance is no longer assigned to you');
  },
};
