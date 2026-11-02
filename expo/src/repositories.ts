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

/** What the cloud did with a survey (step 3). */
export type PushOutcome =
  | { kind: 'applied' } // the server took it
  | { kind: 'lost' } // not applied: a newer (or the same) version is there, or the pin is not mine
  | { kind: 'refused'; message: string } // an error a retry cannot fix
  | { kind: 'retry'; message: string }; // no answer, or an error that may pass

export interface SurveysRepository {
  /** Idempotent: sending the same survey twice changes nothing the second time. Never throws. */
  push(survey: SurveyDoc): Promise<PushOutcome>;
}
