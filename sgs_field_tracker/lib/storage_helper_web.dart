import 'dart:html' as html;

String? getLocalStorage(String key) {
  return html.window.localStorage[key];
}

void setLocalStorage(String key, String value) {
  html.window.localStorage[key] = value;
}
