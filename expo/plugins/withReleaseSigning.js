// Week 6, step 8: sign the release build with YOUR upload key.
// android/ is generated (prebuild), so a hand edit of android/app/build.gradle
// is lost at the next `npx expo prebuild --clean`. This config plugin makes the
// same edit at every prebuild. The key's path and passwords are read from
// %USERPROFILE%\.gradle\gradle.properties: nothing secret is in the repository.
const { withAppBuildGradle } = require('expo/config-plugins');

const RELEASE_KEY = `    signingConfigs {
        release {
            if (project.hasProperty('FIELD_APP_UPLOAD_STORE_FILE')) {
                storeFile file(FIELD_APP_UPLOAD_STORE_FILE)
                storePassword FIELD_APP_UPLOAD_STORE_PASSWORD
                keyAlias FIELD_APP_UPLOAD_KEY_ALIAS
                keyPassword FIELD_APP_UPLOAD_KEY_PASSWORD
            }
        }
`;

// Without the four properties (a teammate with no key) release builds stay debug-signed.
const USE_IT = `signingConfig project.hasProperty('FIELD_APP_UPLOAD_STORE_FILE') ? signingConfigs.release : signingConfigs.debug`;

module.exports = function withReleaseSigning(config) {
  return withAppBuildGradle(config, (c) => {
    let gradle = c.modResults.contents;
    if (gradle.includes('FIELD_APP_UPLOAD_STORE_FILE')) return c; // already there
    const debugInRelease = /(release \{\s*\n(?:\s*\/\/[^\n]*\n)*\s*)signingConfig signingConfigs\.debug/;
    if (!gradle.includes('    signingConfigs {\n') || !debugInRelease.test(gradle)) {
      throw new Error('withReleaseSigning: android/app/build.gradle does not look like the Expo template any more');
    }
    gradle = gradle.replace('    signingConfigs {\n', RELEASE_KEY);
    gradle = gradle.replace(debugInRelease, `$1${USE_IT}`);
    c.modResults.contents = gradle;
    return c;
  });
};
