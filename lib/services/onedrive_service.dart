import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:msal_auth/msal_auth.dart';

import '../config/onedrive_config.dart';

class OneDriveException implements Exception {
  OneDriveException(this.message);
  final String message;
  @override
  String toString() => message;
}

class OneDriveNotConfigured extends OneDriveException {
  OneDriveNotConfigured()
      : super('OneDrive is not set up in this build yet.');
}

/// Signs in with Microsoft (MSAL) and uploads PDFs to OneDrive through
/// Microsoft Graph.
class OneDriveService extends ChangeNotifier {
  OneDriveService({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  SingleAccountPca? _pca;
  String? _accountName;

  bool get isConfigured => OneDriveConfig.isConfigured;

  /// Display name or email of the signed-in account, null when signed out.
  String? get accountName => _accountName;
  bool get isSignedIn => _accountName != null;

  Future<SingleAccountPca> _client() async {
    if (!isConfigured) throw OneDriveNotConfigured();
    return _pca ??= await SingleAccountPca.create(
      clientId: OneDriveConfig.clientId,
      androidConfig: AndroidConfig(
        configFilePath: 'assets/msal_config.json',
        redirectUri: OneDriveConfig.androidRedirectUri,
      ),
      appleConfig: AppleConfig(
        authority: OneDriveConfig.authority,
        authorityType: AuthorityType.aad,
        broker: Broker.msAuthenticator,
      ),
    );
  }

  /// Restores a previous session without showing UI.
  Future<void> restore() async {
    if (!isConfigured) return;
    try {
      final account = await (await _client()).currentAccount;
      _accountName = account.username ?? account.name;
    } catch (_) {
      _accountName = null;
    }
    notifyListeners();
  }

  Future<void> signIn() async {
    final result = await (await _client()).acquireToken(
      scopes: OneDriveConfig.scopes,
      prompt: Prompt.selectAccount,
    );
    _accountName = result.account.username ?? result.account.name;
    notifyListeners();
  }

  Future<void> signOut() async {
    if (_pca != null) await _pca!.signOut();
    _accountName = null;
    notifyListeners();
  }

  Future<String> _token() async {
    final pca = await _client();
    try {
      return (await pca.acquireTokenSilent(scopes: OneDriveConfig.scopes))
          .accessToken;
    } on MsalUiRequiredException {
      final r = await pca.acquireToken(scopes: OneDriveConfig.scopes);
      _accountName = r.account.username ?? r.account.name;
      notifyListeners();
      return r.accessToken;
    } on MsalNoCurrentAccountException {
      final r = await pca.acquireToken(scopes: OneDriveConfig.scopes);
      _accountName = r.account.username ?? r.account.name;
      notifyListeners();
      return r.accessToken;
    }
  }

  /// Uploads [file] to `/ArmScan/{fileName}` and returns its web URL.
  Future<String> upload(File file, String fileName) async {
    final token = await _token();
    return GraphUploader(_http, token)
        .upload(await file.readAsBytes(), OneDriveConfig.folderName, fileName);
  }
}

/// Microsoft Graph upload logic, separate from MSAL so it can be unit-tested.
class GraphUploader {
  GraphUploader(this._http, this._token);

  final http.Client _http;
  final String _token;

  static const _graph = 'https://graph.microsoft.com/v1.0';

  /// Graph allows a simple PUT up to 4 MB; larger files need an upload session.
  static const simpleUploadLimit = 4 * 1024 * 1024;

  /// Chunks must be multiples of 320 KiB. 16 x 320 KiB = 5 MiB.
  static const chunkSize = 16 * 320 * 1024;

  Map<String, String> get _auth => {'Authorization': 'Bearer $_token'};

  String _itemPath(String folder, String name) =>
      '$_graph/me/drive/root:/${Uri.encodeComponent(folder)}/'
      '${Uri.encodeComponent(name)}';

  Future<String> upload(Uint8List bytes, String folder, String name) async {
    if (bytes.length <= simpleUploadLimit) {
      final res = await _http.put(
        Uri.parse(
            '${_itemPath(folder, name)}:/content?@microsoft.graph.conflictBehavior=rename'),
        headers: {..._auth, 'Content-Type': 'application/pdf'},
        body: bytes,
      );
      return _webUrl(res);
    }

    final session = await _http.post(
      Uri.parse('${_itemPath(folder, name)}:/createUploadSession'),
      headers: {..._auth, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'item': {'@microsoft.graph.conflictBehavior': 'rename'},
      }),
    );
    if (session.statusCode >= 300) _fail(session);
    final uploadUrl =
        (jsonDecode(session.body) as Map)['uploadUrl'] as String;

    http.Response? last;
    for (var start = 0; start < bytes.length; start += chunkSize) {
      final end = (start + chunkSize < bytes.length)
          ? start + chunkSize
          : bytes.length;
      // The pre-authenticated uploadUrl must NOT carry the bearer token.
      last = await _http.put(
        Uri.parse(uploadUrl),
        headers: {
          'Content-Length': '${end - start}',
          'Content-Range': 'bytes $start-${end - 1}/${bytes.length}',
        },
        body: bytes.sublist(start, end),
      );
      if (last.statusCode >= 300 && last.statusCode != 202) _fail(last);
    }
    return _webUrl(last!);
  }

  String _webUrl(http.Response res) {
    if (res.statusCode >= 300) _fail(res);
    final body = jsonDecode(res.body) as Map;
    return (body['webUrl'] as String?) ?? '';
  }

  Never _fail(http.Response res) {
    String detail = 'HTTP ${res.statusCode}';
    try {
      final err = (jsonDecode(res.body) as Map)['error'] as Map?;
      if (err?['message'] != null) detail = err!['message'] as String;
    } catch (_) {}
    throw OneDriveException('OneDrive upload failed: $detail');
  }
}
