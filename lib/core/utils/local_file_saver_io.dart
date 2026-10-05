import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

Future<String> saveImageBytesLocally({
  required Uint8List bytes,
  required String fileName,
}) async {
  Directory? dir;
  if (Platform.isAndroid) {
    dir = await getExternalStorageDirectory();
  } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  } else {
    // iOS
    dir = await getApplicationDocumentsDirectory();
  }
  dir ??= await getApplicationDocumentsDirectory();

  final filePath = p.join(dir.path, fileName);
  final file = File(filePath);
  await file.writeAsBytes(bytes);
  return filePath;
}
