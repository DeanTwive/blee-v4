import 'dart:typed_data';
import 'local_file_saver_stub.dart'
    if (dart.library.html) 'local_file_saver_web.dart'
    if (dart.library.io) 'local_file_saver_io.dart' as saver;

/// Saves binary image bytes directly to local storage / downloads folder.
/// Returns a descriptive path or message on success.
Future<String> saveImageBytesLocally({
  required Uint8List bytes,
  required String fileName,
}) => saver.saveImageBytesLocally(bytes: bytes, fileName: fileName);
