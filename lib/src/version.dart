const String kAppVersionName = String.fromEnvironment(
  'APP_VERSION_NAME',
  defaultValue: '1.1.0',
);

const int kAppBuildNumber = int.fromEnvironment(
  'APP_BUILD_NUMBER',
  defaultValue: 10,
);

String get kAppDisplayVersion => 'v$kAppVersionName ($kAppBuildNumber)';
