import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preferences.
class AppSettings extends ChangeNotifier {
  static const _kAutoUpload = 'autoUploadOneDrive';

  SharedPreferences? _prefs;

  /// When on, every new scan is uploaded to OneDrive as a PDF once its text
  /// has been read. Off by default: local-first, cloud on request.
  bool get autoUploadToOneDrive => _prefs?.getBool(_kAutoUpload) ?? false;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    notifyListeners();
  }

  Future<void> setAutoUploadToOneDrive(bool value) async {
    await _prefs?.setBool(_kAutoUpload, value);
    notifyListeners();
  }
}
