import type { Entrance, EntranceSurvey, SurveyStatus } from './contract/contract';

// What the app needs from "the cloud", and nothing about how. Screens and the
// sync code use these interfaces; only supabaseRepositories.ts knows Supabase
// (until week 5 it was firebaseRepositories.ts).

/** A survey as it travels: the surveyed fields, who, when, and which entrance. */
export type SurveyDoc = EntranceSurvey & {
  id: string; // the entrance's UUID: one survey per entrance, so a resend overwrites
  surveyStatus: SurveyStatus;
  surveyedBy: string;
  surveyedAt: string;
  updatedAt: string;
};

export interface PinsRepository {
  /** Calls onPins with all my pins now, and again after every change. Returns "stop". */
  watchMine(uid: string, onPins: (pins: Entrance[]) => void, onError: (e: Error) => void): () => void;
  /** Ask the cloud again now (Sync now, the app back in front). A live listener may ignore it. */
  refresh(): void;
}

export interface SurveysRepository {
  /** Idempotent: sending the same survey twice leaves one row as it was. Throws when refused. */
  push(survey: SurveyDoc): Promise<void>;
}
