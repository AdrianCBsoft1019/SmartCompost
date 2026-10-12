import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

void guardarArchivo(
  Uint8List bytes,
  String nombre, {
  String mime = 'application/pdf',
}) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mime),
  );

  final url = web.URL.createObjectURL(blob);

  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = nombre;

  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();

  web.URL.revokeObjectURL(url);
}