import 'dart:async';
import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';

/// Google Drive backup service for Course Attendance Manager.
///
/// Local SQLite remains the source of truth. This service only creates and
/// updates backup files in the user's own Google Drive.
class GoogleDriveSyncService {
  GoogleDriveSyncService._();

  static final GoogleDriveSyncService instance = GoogleDriveSyncService._();

  static const String _webClientId =
      '472946327335-fpkl0k08oj8i70a9nhg4usfk2couffro.apps.googleusercontent.com';

  // The iOS OAuth client ID belongs to the app (not to an individual user).
  // It is supplied at build time so the same app can be used by many users,
  // each connecting their own Google account/Drive.
  static const String _iosClientId =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static const String driveScope = 'https://www.googleapis.com/auth/drive.file';
  static const String _driveApi = 'https://www.googleapis.com/drive/v3';
  static const String _uploadApi = 'https://www.googleapis.com/upload/drive/v3/files';

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _initialized = false;
  GoogleSignInAccount? _account;
  String? _accessToken;
  String? _rootFolderId;

  Timer? _autoSyncTimer;
  bool _autoSyncEnabled = true;
  bool _autoSyncRunning = false;

  bool get isConnected => _account != null && _accessToken != null;
  String? get accountEmail => _account?.email;
  bool get isAutoSyncEnabled => _autoSyncEnabled;

  static const Duration _autoSyncInterval = Duration(minutes: 2);

  Future<void> initialize() async {
    if (_initialized) return;

    await _googleSignIn.initialize(
      clientId: _iosClientId.isEmpty ? null : _iosClientId,
      serverClientId: _webClientId,
    );
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _autoSyncEnabled = prefs.getBool('drive_auto_sync_enabled') ?? true;

    // Restore a lightweight session if the plugin already has one.
    try {
      final account = await _googleSignIn.attemptLightweightAuthentication();
      if (account != null) {
        _account = account;
        await _refreshAccessToken(promptIfNecessary: false);
      }
    } catch (_) {
      // A previous session is optional. The explicit Connect button will
      // perform authentication when needed.
    }

    _startAutoSyncTimer();
  }

  Future<GoogleSignInAccount> connect() async {
    await initialize();

    final account = await _googleSignIn.authenticate();
    _account = account;

    await _authorizeDrive();
    _rootFolderId = await _getOrCreateFolder('Attendance');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('drive_account_email', account.email);
    await prefs.setString('drive_root_folder_id', _rootFolderId!);
    await prefs.setBool('drive_sync_enabled', true);

    return account;
  }

  Future<void> disconnect() async {
    _accessToken = null;
    _account = null;
    _rootFolderId = null;
    _stopAutoSyncTimer();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('drive_sync_enabled', false);
    await prefs.remove('drive_root_folder_id');
    await prefs.remove('drive_account_email');

    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
  }

  Future<void> _authorizeDrive() async {
    final authorization = await _googleSignIn.authorizationClient.authorizeScopes(
      [driveScope],
    );
    _accessToken = authorization.accessToken;
  }

  Future<void> _refreshAccessToken({bool promptIfNecessary = true}) async {
    if (_account == null) return;

    final headers = await _account!.authorizationClient.authorizationHeaders(
      [driveScope],
      promptIfNecessary: promptIfNecessary,
    );

    if (headers == null || headers['Authorization'] == null) {
      if (promptIfNecessary) {
        await _authorizeDrive();
      }
      return;
    }

    final authorization = headers['Authorization']!;
    if (authorization.startsWith('Bearer ')) {
      _accessToken = authorization.substring(7);
    }
  }

  Future<Map<String, String>> _headers({bool prompt = true}) async {
    if (!isConnected) {
      throw StateError('Google Drive is not connected.');
    }

    final headers = await _account!.authorizationClient.authorizationHeaders(
      [driveScope],
      promptIfNecessary: prompt,
    );

    if (headers == null || headers['Authorization'] == null) {
      await _authorizeDrive();
      return {'Authorization': 'Bearer $_accessToken'};
    }

    final auth = headers['Authorization'];
    if (auth != null && auth.startsWith('Bearer ')) {
      _accessToken = auth.substring(7);
    }

    return headers;
  }

  Future<Map<String, String>?> _silentHeaders() async {
    if (_account == null) return null;
    final headers = await _account!.authorizationClient.authorizationHeaders(
      [driveScope],
      promptIfNecessary: false,
    );
    if (headers == null || headers['Authorization'] == null) return null;
    final auth = headers['Authorization'];
    if (auth != null && auth.startsWith('Bearer ')) {
      _accessToken = auth.substring(7);
    }
    return headers;
  }

  Future<http.Response> _request(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    try {
      return await request(await _headers());
    } catch (e) {
      // Retry once after refreshing authorization.
      await _refreshAccessToken(promptIfNecessary: true);
      return await request(await _headers());
    }
  }

  Future<http.Response?> _silentRequest(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    final headers = await _silentHeaders();
    if (headers == null) return null;
    return request(headers);
  }

  Future<String> _getOrCreateFolder(String name, {String? parentId}) async {
    final safeName = name.replaceAll("'", "\\'");
    var query = "name = '$safeName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    if (parentId != null) {
      query += " and '$parentId' in parents";
    }

    final uri = Uri.parse('$_driveApi/files').replace(
      queryParameters: {
        'q': query,
        'spaces': 'drive',
        'fields': 'files(id,name,mimeType,parents)',
        'pageSize': '100',
      },
    );

    final response = await _request(
      (headers) => http.get(uri, headers: headers),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final files = (jsonDecode(response.body)['files'] as List?) ?? [];
      if (files.isNotEmpty) {
        return files.first['id'].toString();
      }
    } else {
      throw Exception('Drive folder lookup failed: ${response.statusCode} ${response.body}');
    }

    final metadata = <String, dynamic>{
      'name': name,
      'mimeType': 'application/vnd.google-apps.folder',
    };
    if (parentId != null) metadata['parents'] = [parentId];

    final createUri = Uri.parse('$_driveApi/files').replace(
      queryParameters: {'fields': 'id,name,mimeType,parents'},
    );

    final createResponse = await _request(
      (headers) => http.post(
        createUri,
        headers: {
          ...headers,
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(metadata),
      ),
    );

    if (createResponse.statusCode >= 200 && createResponse.statusCode < 300) {
      return jsonDecode(createResponse.body)['id'].toString();
    }

    throw Exception(
      'Drive folder creation failed: ${createResponse.statusCode} ${createResponse.body}',
    );
  }

  String _courseFolderName(Map<String, dynamic> course) {
    final code = (course['code'] ?? 'Course').toString().trim();
    final name = (course['name'] ?? '').toString().trim();
    final raw = name.isEmpty ? code : '${code}_$name';
    return raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  Future<Map<String, dynamic>?> _findFile(
    String name,
    String parentId,
  ) async {
    final safeName = name.replaceAll("'", "\\'");
    final query = "name = '$safeName' and '$parentId' in parents and trashed = false";

    final uri = Uri.parse('$_driveApi/files').replace(
      queryParameters: {
        'q': query,
        'spaces': 'drive',
        'fields': 'files(id,name,mimeType,modifiedTime,size)',
        'pageSize': '10',
      },
    );

    final response = await _request(
      (headers) => http.get(uri, headers: headers),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Drive file lookup failed: ${response.statusCode} ${response.body}');
    }

    final files = (jsonDecode(response.body)['files'] as List?) ?? [];
    if (files.isEmpty) return null;
    return Map<String, dynamic>.from(files.first as Map);
  }

  Future<String> _uploadJsonFile({
    required String fileName,
    required String parentId,
    required Map<String, dynamic> data,
  }) async {
    final existing = await _findFile(fileName, parentId);
    final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
    final boundary = 'cam_${DateTime.now().microsecondsSinceEpoch}';

    final body = <int>[];
    void add(String value) => body.addAll(utf8.encode(value));

    add('--$boundary\r\n');
    add('Content-Type: application/json; charset=UTF-8\r\n\r\n');
    add(jsonEncode({
      'name': fileName,
      'mimeType': 'application/json',
      'parents': existing == null ? [parentId] : null,
    }..removeWhere((key, value) => value == null)));
    add('\r\n--$boundary\r\n');
    add('Content-Type: application/json\r\n\r\n');
    body.addAll(bytes);
    add('\r\n--$boundary--\r\n');

    final uri = existing == null
        ? Uri.parse(_uploadApi).replace(queryParameters: {'uploadType': 'multipart', 'fields': 'id,name,mimeType,modifiedTime'})
        : Uri.parse('$_uploadApi/${existing['id']}').replace(queryParameters: {'uploadType': 'multipart', 'fields': 'id,name,mimeType,modifiedTime'});

    final response = await _request(
      (headers) => existing == null
          ? http.post(
              uri,
              headers: {
                ...headers,
                'Content-Type': 'multipart/related; boundary=$boundary',
                'Content-Length': body.length.toString(),
              },
              body: body,
            )
          : http.patch(
              uri,
              headers: {
                ...headers,
                'Content-Type': 'multipart/related; boundary=$boundary',
                'Content-Length': body.length.toString(),
              },
              body: body,
            ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Drive upload failed: ${response.statusCode} ${response.body}');
    }

    return jsonDecode(response.body)['id'].toString();
  }

  Future<Map<String, dynamic>> _downloadJsonFile(String fileId) async {
    final uri = Uri.parse('$_driveApi/files/$fileId').replace(
      queryParameters: {'alt': 'media'},
    );

    final response = await _request(
      (headers) => http.get(uri, headers: headers),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Drive download failed: ${response.statusCode} ${response.body}');
    }

    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<void> syncCourse({
    required Map<String, dynamic> course,
    required List<Map<String, dynamic>> students,
    required List<Map<String, dynamic>> attendance,
  }) async {
    if (!isConnected) return;
    _rootFolderId ??= await _getOrCreateFolder('Attendance');

    final courseFolder = await _getOrCreateFolder(
      _courseFolderName(course),
      parentId: _rootFolderId,
    );

    await _uploadJsonFile(
      fileName: 'course_backup.json',
      parentId: courseFolder,
      data: {
        'version': 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'course': course,
        'students': students,
        'attendance': attendance,
      },
    );
  }

  Future<void> syncProfile(Map<String, dynamic> profile) async {
    if (!isConnected) return;
    _rootFolderId ??= await _getOrCreateFolder('Attendance');
    await _uploadJsonFile(
      fileName: 'profile_backup.json',
      parentId: _rootFolderId!,
      data: profile,
    );
  }

  Future<Map<String, dynamic>?> downloadProfile() async {
    if (!isConnected) return null;
    _rootFolderId ??= await _getOrCreateFolder('Attendance');
    final file = await _findFile('profile_backup.json', _rootFolderId!);
    if (file == null) return null;
    return _downloadJsonFile(file['id'].toString());
  }

  Future<List<Map<String, dynamic>>> downloadCourseBackups() async {
    if (!isConnected) return [];
    _rootFolderId ??= await _getOrCreateFolder('Attendance');

    final uri = Uri.parse('$_driveApi/files').replace(
      queryParameters: {
        'q': "'$_rootFolderId' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
        'spaces': 'drive',
        'fields': 'files(id,name,mimeType)',
        'pageSize': '1000',
      },
    );

    final response = await _request(
      (headers) => http.get(uri, headers: headers),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Drive backup list failed: ${response.statusCode} ${response.body}');
    }

    final folders = (jsonDecode(response.body)['files'] as List?) ?? [];
    final result = <Map<String, dynamic>>[];

    for (final rawFolder in folders) {
      final folder = Map<String, dynamic>.from(rawFolder as Map);
      final file = await _findFile('course_backup.json', folder['id'].toString());
      if (file == null) continue;

      final data = await _downloadJsonFile(file['id'].toString());
      data['_drive_folder_name'] = folder['name'];
      result.add(data);
    }

    return result;
  }


  Future<String> ensureAttendanceFolder() async {
    await initialize();
    if (!isConnected) {
      throw StateError('Google Drive is not connected.');
    }
    _rootFolderId ??= await _getOrCreateFolder('Attendance');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('drive_root_folder_id', _rootFolderId!);
    return _rootFolderId!;
  }


  /// Enables or disables automatic Google Drive synchronization.
  ///
  /// Auto Sync runs while the app is open. It checks for local data changes
  /// every two minutes and uploads a full backup only when the data changed.
  /// Local data remains available even when Auto Sync is disabled or offline.
  Future<void> setAutoSyncEnabled(bool enabled) async {
    _autoSyncEnabled = enabled;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('drive_auto_sync_enabled', enabled);

    if (enabled) {
      _startAutoSyncTimer();
      // Run one immediate check after enabling.
      unawaited(autoSyncNow());
    } else {
      _stopAutoSyncTimer();
    }
  }

  void _startAutoSyncTimer() {
    _autoSyncTimer?.cancel();
    if (!_autoSyncEnabled) return;

    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (_) {
      unawaited(autoSyncNow());
    });
  }

  void _stopAutoSyncTimer() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// Checks whether local data changed since the last successful sync.
  Future<bool> autoSyncNow() async {
    if (!_autoSyncEnabled || !isConnected || _autoSyncRunning) return false;

    _autoSyncRunning = true;
    try {
      // Never trigger an interactive Google authorization dialog from the
      // automatic timer. Manual Sync/Connect may request authorization.
      final silentHeaders = await _silentHeaders();
      if (silentHeaders == null) return false;

      final data = await DatabaseHelper.instance.exportAllData();
      final payload = const JsonEncoder().convert(data);
      final signature = _simpleHash(payload);

      final prefs = await SharedPreferences.getInstance();
      final previousSignature =
          prefs.getString('drive_last_synced_signature');

      if (previousSignature == signature) {
        return false;
      }

      await syncFullBackup(data);

      await prefs.setString('drive_last_synced_signature', signature);
      return true;
    } catch (_) {
      // Auto Sync must never interrupt or block local attendance/marks work.
      return false;
    } finally {
      _autoSyncRunning = false;
    }
  }

  /// Stores a compact deterministic signature without adding another package.
  String _simpleHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<void> syncFullBackup(Map<String, dynamic> data) async {
    if (!isConnected) return;
    final folderId = await ensureAttendanceFolder();
    await _uploadJsonFile(
      fileName: 'CourseAttendance_Full_Backup.json',
      parentId: folderId,
      data: data,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'drive_last_backup_at',
      DateTime.now().toUtc().toIso8601String(),
    );

    // Manual backup is also considered the latest synchronized state.
    try {
      final signature = _simpleHash(const JsonEncoder().convert(data));
      await prefs.setString('drive_last_synced_signature', signature);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> downloadFullBackup() async {
    if (!isConnected) return null;
    final folderId = await ensureAttendanceFolder();
    final file = await _findFile('CourseAttendance_Full_Backup.json', folderId);
    if (file == null) return null;
    return _downloadJsonFile(file['id'].toString());
  }

  Future<void> setRootFolderId(String? id) async {
    _rootFolderId = id;
  }
}
