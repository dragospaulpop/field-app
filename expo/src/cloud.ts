import type { PinsRepository, SurveysRepository } from './repositories';
import { supabasePins, supabaseSurveys } from './supabaseRepositories';

// The one place that chooses the implementation. Week 5 changed these two lines.
export const pins: PinsRepository = supabasePins;
export const surveys: SurveysRepository = supabaseSurveys;
