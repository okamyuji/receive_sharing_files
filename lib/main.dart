import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:mime/mime.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

final logger = Logger();

// 保存したファイルの情報を管理するモデルクラス
class SavedFile {
  final String path;
  final String type;
  final String? thumbnail;
  final double? duration;
  final DateTime savedAt;

  SavedFile({
    required this.path,
    required this.type,
    this.thumbnail,
    this.duration,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'type': type,
        'thumbnail': thumbnail,
        'duration': duration,
        'savedAt': savedAt.toIso8601String(),
      };

  factory SavedFile.fromJson(Map<String, dynamic> json) => SavedFile(
        path: json['path'],
        type: json['type'],
        thumbnail: json['thumbnail'],
        duration: json['duration'],
        savedAt: DateTime.parse(json['savedAt']),
      );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  logger.d("Application started");
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  StreamSubscription? _intentSub;
  final _sharedFiles = <SharedMediaFile>[];
  bool _isProcessing = false;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  static const _savedFilesKey = 'saved_files';
  final _savedFiles = <SavedFile>[];

  @override
  void initState() {
    super.initState();
    _loadSavedFiles();
    _initializeSharing();
  }

  /// 共有ファイルを初期化する
  Future<void> _initializeSharing() async {
    try {
      // アプリが閉じていた時の共有を処理
      logger.d("Checking initial shared media");
      final initialMedia =
          await ReceiveSharingIntent.instance.getInitialMedia();
      if (initialMedia.isNotEmpty) {
        logger.d("Found initial shared media: ${initialMedia.length} files");
        _processSharedFiles(initialMedia);
      } else {
        logger.d("No initial shared media found");
      }

      // 継続的な共有を監視
      logger.d("Setting up media stream listener");
      _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (List<SharedMediaFile> value) {
          logger.d("Received shared media from stream: ${value.length} files");
          _processSharedFiles(value);
        },
        onError: (error) {
          logger.e("Stream error: $error");
        },
        onDone: () {
          logger.d("Stream completed");
        },
      );
    } catch (e, stackTrace) {
      logger.e("Error in _initializeSharing", error: e, stackTrace: stackTrace);
    }
  }

  /// 共有ファイルを処理する
  ///
  /// [files] 共有ファイルのリスト
  void _processSharedFiles(List<SharedMediaFile> files) {
    if (_isProcessing) {
      logger.d("Already processing files, skipping");
      return;
    }

    setState(() {
      _isProcessing = true;
      try {
        _sharedFiles.clear();
        for (final file in files) {
          logger.d("Processing file: ${file.path}");
          _sharedFiles.add(file);
        }
        logger.d("Processed ${_sharedFiles.length} files successfully");
      } catch (e, stackTrace) {
        logger.e("Error processing files", error: e, stackTrace: stackTrace);
      } finally {
        _isProcessing = false;
      }
    });
  }

  @override
  void dispose() {
    logger.d("Disposing MyAppState");
    _intentSub?.cancel();
    super.dispose();
  }

  /// ファイルを開く
  ///
  /// [path] ファイルパス
  Future<void> _openFile(String path) async {
    try {
      logger.d("Opening file: $path");

      final result = await OpenFile.open(
        path,
        type: lookupMimeType(path), // MIMEタイプを指定
      );

      if (result.type != ResultType.done) {
        throw Exception("Failed to open file: ${result.message}");
      }

      logger.d("File opened successfully");
    } catch (e, stackTrace) {
      logger.e("Error opening file: $path", error: e, stackTrace: stackTrace);

      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('ファイルを開けませんでした: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// ファイルのアイコンを取得する
  ///
  /// [path] ファイルパス
  IconData _getFileIcon(String path) {
    final mimeType = lookupMimeType(path) ?? '';

    if (mimeType.startsWith('video/')) {
      return Icons.video_library;
    } else if (mimeType.startsWith('audio/')) {
      return Icons.audio_file;
    } else if (mimeType.startsWith('image/')) {
      return Icons.image;
    } else if (mimeType.startsWith('text/')) {
      return Icons.text_snippet;
    } else {
      return Icons.insert_drive_file;
    }
  }

  /// ファイルを保存する
  ///
  /// [sourcePath] 元のファイルパス
  Future<String?> _saveFile(String sourcePath) async {
    try {
      logger.d("Saving file from: $sourcePath");

      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(sourcePath);
      final sourceFile = File(sourcePath);

      // 保存先のパスを生成（重複チェック込み）
      final targetPath = await _generateUniqueFilePath(appDir.path, fileName);

      // ファイルをコピー
      await sourceFile.copy(targetPath);
      logger.d("File saved to: $targetPath");

      // SavedFileオブジェクトを作成
      final savedFile = SavedFile(
        path: targetPath,
        type: lookupMimeType(targetPath) ?? 'application/octet-stream',
        savedAt: DateTime.now(),
      );

      setState(() {
        _savedFiles.add(savedFile);
      });

      // 保存済みファイルリストを更新
      await _saveSavedFilesList();

      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('ファイルを保存しました: ${path.basename(targetPath)}')),
        );
      }

      return targetPath;
    } catch (e, stackTrace) {
      logger.e("Error saving file", error: e, stackTrace: stackTrace);
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('ファイルの保存に失敗しました: ${e.toString()}')),
        );
      }
      return null;
    }
  }

  Future<String> _generateUniqueFilePath(
      String dirPath, String fileName) async {
    final extension = path.extension(fileName);
    final nameWithoutExt = path.basenameWithoutExtension(fileName);
    var finalPath = path.join(dirPath, fileName);
    var counter = 1;

    while (await File(finalPath).exists()) {
      finalPath = path.join(
        dirPath,
        '${nameWithoutExt}_${counter.toString().padLeft(3, '0')}$extension',
      );
      counter++;
    }

    return finalPath;
  }

  Future<void> _loadSavedFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFilesJson = prefs.getStringList(_savedFilesKey) ?? [];

      setState(() {
        _savedFiles.clear();
        for (final fileJson in savedFilesJson) {
          final fileMap = json.decode(fileJson);
          final file = SavedFile.fromJson(fileMap);
          if (File(file.path).existsSync()) {
            _savedFiles.add(file);
          }
        }
      });

      logger.d('Loaded ${_savedFiles.length} saved files');
    } catch (e, stackTrace) {
      logger.e('Error loading saved files', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _saveSavedFilesList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filesJson =
          _savedFiles.map((f) => json.encode(f.toJson())).toList();
      await prefs.setStringList(_savedFilesKey, filesJson);
      logger.d('Saved files list updated: ${_savedFiles.length} files');
    } catch (e, stackTrace) {
      logger.e('Error saving files list', error: e, stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey, // 修正箇所
      home: Scaffold(
        appBar: AppBar(
          title: const Text('共有ファイル受信'),
        ),
        body: _savedFiles.isEmpty && _sharedFiles.isEmpty
            ? const Center(child: Text('共有されたファイルはありません'))
            : ListView(
                children: [
                  ..._savedFiles.map((file) => _buildFileCard(file)),
                  ..._sharedFiles.map((file) => _buildSharedFileCard(file)),
                ],
              ),
      ),
    );
  }

  Widget _buildFileCard(SavedFile file) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        leading: Icon(_getFileIcon(file.path)),
        title: Text(path.basename(file.path)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${file.type}'),
            Text('保存日時: ${file.savedAt.toLocal()}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.open_in_new),
          onPressed: () => _openFile(file.path),
        ),
      ),
    );
  }

  Widget _buildSharedFileCard(SharedMediaFile file) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        leading: Icon(_getFileIcon(file.path)),
        title: Text(file.path.split('/').last),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${file.type}'),
            if (file.duration != null) Text('Duration: ${file.duration}ms'),
            if (file.thumbnail != null) Text('Thumbnail: ${file.thumbnail}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () => _saveFile(file.path),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => _openFile(file.path),
            ),
          ],
        ),
      ),
    );
  }
}
