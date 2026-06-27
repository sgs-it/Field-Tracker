import 'storage_helper_stub.dart'
    if (dart.library.html) 'storage_helper_web.dart';

String? loadFromStorage(String key) {
  return getLocalStorage(key);
}

void saveToStorage(String key, String value) {
  setLocalStorage(key, value);
}
