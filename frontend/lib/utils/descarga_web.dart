// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

void guardarArchivo(Uint8List bytes, String nombre,
    {String mime = 'application/pdf'}) {
  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final enlace = html.AnchorElement(href: url)..download = nombre;
  enlace.click();
  html.Url.revokeObjectUrl(url);
}
