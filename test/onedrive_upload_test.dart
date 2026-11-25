import 'dart:convert';
import 'dart:typed_data';

import 'package:armscan/services/onedrive_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('small files use a single PUT with the bearer token', () async {
    final calls = <http.Request>[];
    final client = MockClient((req) async {
      calls.add(req);
      return http.Response(jsonEncode({'webUrl': 'https://1drv.ms/x'}), 201);
    });
    final url = await GraphUploader(client, 'tok')
        .upload(Uint8List(1000), 'ArmScan', 'My scan.pdf');

    expect(url, 'https://1drv.ms/x');
    expect(calls, hasLength(1));
    expect(calls.single.method, 'PUT');
    expect(calls.single.url.path,
        '/v1.0/me/drive/root:/ArmScan/My%20scan.pdf:/content');
    expect(calls.single.headers['Authorization'], 'Bearer tok');
  });

  test('large files use an upload session in 320 KiB-aligned chunks', () async {
    final size = GraphUploader.chunkSize * 2 + 1234;
    final calls = <http.Request>[];
    final client = MockClient((req) async {
      calls.add(req);
      if (req.url.path.endsWith('createUploadSession')) {
        return http.Response(
            jsonEncode({'uploadUrl': 'https://upload.example/session'}), 200);
      }
      final last = req.headers['Content-Range']!.endsWith('${size - 1}/$size');
      return last
          ? http.Response(jsonEncode({'webUrl': 'https://1drv.ms/big'}), 201)
          : http.Response('{}', 202);
    });

    final url = await GraphUploader(client, 'tok')
        .upload(Uint8List(size), 'ArmScan', 'big.pdf');

    expect(url, 'https://1drv.ms/big');
    expect(GraphUploader.chunkSize % (320 * 1024), 0);
    expect(calls, hasLength(4)); // session + 3 chunks
    expect(calls[1].headers['Content-Range'],
        'bytes 0-${GraphUploader.chunkSize - 1}/$size');
    // The pre-authenticated upload URL must not receive the token.
    expect(calls[1].headers.containsKey('Authorization'), isFalse);
  });

  test('Graph errors surface a readable message', () async {
    final client = MockClient((_) async => http.Response(
        jsonEncode({'error': {'message': 'Insufficient quota'}}), 507));
    expect(
      () => GraphUploader(client, 'tok').upload(Uint8List(10), 'ArmScan', 'a.pdf'),
      throwsA(isA<OneDriveException>().having(
          (e) => e.message, 'message', contains('Insufficient quota'))),
    );
  });
}
