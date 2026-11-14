const String kAppVersionName = String.fromEnvironment(
  'APP_VERSION_NAME',
  defaultValue: '1.2.0',
);

const int kAppBuildNumber = int.fromEnvironment(
  'APP_BUILD_NUMBER',
  defaultValue: 12,
);

String get kAppDisplayVersion => 'v$kAppVersionName ($kAppBuildNumber)';
