import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

final logger = Logger();

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
  late StreamSubscription _intentSub;
  final _sharedFiles = <SharedMediaFile>[];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    logger.d("MyAppState.initState");
    _initializeSharing();
  }

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
    _intentSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Share Extension Demo'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Shared files:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                if (_sharedFiles.isEmpty)
                  const Text("No files shared yet")
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _sharedFiles.length,
                      itemBuilder: (context, index) {
                        final file = _sharedFiles[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(
                              file.path.split('/').last,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Type: ${file.type}'),
                                Text('Path: ${file.path}'),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
