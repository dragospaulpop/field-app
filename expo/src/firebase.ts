import { getApp, getApps, initializeApp } from 'firebase/app';
import { onAuthStateChanged, type User } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import { useEffect, useState } from 'react';
import { makeAuth } from './auth';

// The Web app's config from the Firebase console, read from expo/.env.
// EXPO_PUBLIC_ variables are copied into the app's JavaScript when Metro
// bundles it: they are not secrets (the security rules are the protection).
const config = {
  apiKey: process.env.EXPO_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.EXPO_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.EXPO_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.EXPO_PUBLIC_FIREBASE_APP_ID,
};

// Fast Refresh re-runs this file: reuse the app instead of creating a second one.
export const app = getApps().length ? getApp() : initializeApp(config);
export const auth = makeAuth(app);
export const firestore = getFirestore(app);

/** undefined while Firebase reads the saved session, then the user or null. */
export function useUser(): User | null | undefined {
  const [user, setUser] = useState<User | null | undefined>(undefined);
  useEffect(() => onAuthStateChanged(auth, setUser), []);
  return user;
}
