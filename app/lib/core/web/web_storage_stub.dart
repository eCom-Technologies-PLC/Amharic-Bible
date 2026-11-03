String? webStorageRead(String key) => null;

void webStorageWrite(String key, String value) {}

/// Phones keep app data until the app is removed, so there is nothing to ask.
Future<void> requestPersistentStorage() async {}

/// Phones always have a system share sheet.
bool webCanShare() => true;

/// Apps are installed from the store.
bool installAvailable() => false;

Future<bool> promptInstall() async => false;

void onInstallChange(void Function() onChange) {}
