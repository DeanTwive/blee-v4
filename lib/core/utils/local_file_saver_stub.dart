import 'dart:typed_data';

Future<String> saveImageBytesLocally({
  required Uint8List bytes,
  required String fileName,
}) async {
  throw UnsupportedError('Saving files locally is not supported on this platform.');
}
