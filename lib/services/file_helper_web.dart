import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class PlatformFileHelper {
  static Future<bool> downloadJson(String fileName, String content) async {
    try {
      final bytes = utf8.encode(content);
      final jsArray = [bytes.toJS].toJS;
      final blob = web.Blob(
        jsArray,
        web.BlobPropertyBag(type: 'application/json'),
      );
      final url = web.URL.createObjectURL(blob);
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = url;
      anchor.download = fileName;
      anchor.click();
      web.URL.revokeObjectURL(url);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> pickJson() {
    final completer = Completer<String?>();
    try {
      final input = web.document.createElement('input') as web.HTMLInputElement;
      input.type = 'file';
      input.accept = '.json,application/json';

      input.onchange = (web.Event _) {
        final files = input.files;
        if (files == null || files.length == 0) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }
        final file = files.item(0);
        if (file == null) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }

        final reader = web.FileReader();
        reader.onload = (web.Event _) {
          final result = reader.result;
          if (result != null) {
            if (!completer.isCompleted) {
              completer.complete((result as JSString).toDart);
            }
          } else {
            if (!completer.isCompleted) completer.complete(null);
          }
        }.toJS;

        reader.onerror = (web.Event _) {
          if (!completer.isCompleted) completer.complete(null);
        }.toJS;

        reader.readAsText(file);
      }.toJS;

      input.click();
    } catch (_) {
      if (!completer.isCompleted) completer.complete(null);
    }
    return completer.future;
  }
}
