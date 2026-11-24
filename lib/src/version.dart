const String kAppVersionName = String.fromEnvironment(
  'APP_VERSION_NAME',
  defaultValue: '1.8.1',
);

const int kAppBuildNumber = int.fromEnvironment(
  'APP_BUILD_NUMBER',
  defaultValue: 22,
);

String get kAppDisplayVersion => 'v$kAppVersionName ($kAppBuildNumber)';
