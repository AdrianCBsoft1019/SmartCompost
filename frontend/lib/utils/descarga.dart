// Guarda un archivo en el dispositivo. En web dispara la descarga del
// navegador; en otras plataformas lanza un mensaje claro (aun no soportado).
export 'descarga_stub.dart' if (dart.library.html) 'descarga_web.dart';
