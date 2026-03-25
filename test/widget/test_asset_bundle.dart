import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _kTransparentImageBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=';

void setUpMockAssets() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final imageBytes = base64Decode(_kTransparentImageBase64);
  final imageData = ByteData.view(Uint8List.fromList(imageBytes).buffer);

  final manifestJson = utf8.encode('{}');
  final manifestJsonData = ByteData.view(Uint8List.fromList(manifestJson).buffer);

  final manifestBinData =
      const StandardMessageCodec().encodeMessage(<String, List<String>>{});

  ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'flutter/assets',
    (message) async {
      final key = const StringCodec().decodeMessage(message);
      if (key == 'AssetManifest.json') return manifestJsonData;
      if (key == 'AssetManifest.bin') return manifestBinData;
      return imageData;
    },
  );
}
