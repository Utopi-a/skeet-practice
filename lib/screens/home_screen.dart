import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/red_lamp_widget.dart';
import '../widgets/orange_circle_widget.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isRedLampOn = false;
  bool _isOrangeCircleVisible = false;
  bool _isListening = false;
  bool _isProcessing = false; // 新しい状態変数を追加
  late NoiseMeter _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;

  // インターバルモード用
  bool _isIntervalMode = false;
  bool _isRunning = false;
  double _interval = 5.0; // デフォルトの間隔（秒）
  Timer? _intervalTimer;

  @override
  void initState() {
    super.initState();
    _noiseMeter = NoiseMeter();
    _requestMicrophonePermission();
  }

  /// マイクの使用権限をリクエストするメソッド
  ///
  /// このメソッドは、ユーザーにマイクの使用権限を要求します。
  /// 権限が許可された場合、音声検知を開始します。
  Future<void> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      print('マイクの使用権限が許可されました');
      if (!_isIntervalMode) {
        startListening();
      }
    } else if (status.isDenied) {
      print('マイクの使用権限が拒否されました');
      // ユーザーに権限の重要性を説明するダイアログを表示
      _showPermissionDeniedDialog();
    } else if (status.isPermanentlyDenied) {
      print('マイクの使用権限が永続的に拒否されました');
      // アプリ設定画面を開くようユーザーに促す
      _showOpenSettingsDialog();
    }
  }

  /// 権限拒否時のダイアログを表示するメソッド
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('マイクの使用権限が必要です'),
        content: Text('このアプリは音声検知機能を使用するため、マイクの使用権限が必要です。'),
        actions: <Widget>[
          TextButton(
            child: Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
              _requestMicrophonePermission();
            },
          ),
        ],
      ),
    );
  }

  /// 設定画面を開くダイアログを表示するメソッド
  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('設定が必要です'),
        content: Text('マイクの使用権限を有効にするには、アプリ設定画面から権限を許可してください。'),
        actions: <Widget>[
          TextButton(
            child: Text('設定を開く'),
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
          ),
          TextButton(
            child: Text('キャンセル'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// 音声検知を開始するメソッド
  void startListening() {
    if (_isListening) return;
    try {
      _noiseSubscription = _noiseMeter.noise.listen(
        onData,
        onError: onError,
        onDone: () {
          print('音声検知ストリームが終了しました');
          setState(() {
            _isListening = false;
          });
          // ストリームが終了した場合、再度開始を試みる
          Future.delayed(Duration(seconds: 1), () {
            if (!_isIntervalMode && !_isListening) {
              startListening();
            }
          });
        },
      );
      setState(() {
        _isListening = true;
      });
    } catch (err) {
      print('音声検知の開始中にエラーが発生しました: $err');
      setState(() {
        _isListening = false;
      });
    }
  }

  /// 音声データを処理するメソッド
  void onData(NoiseReading noiseReading) {
    // print('検出された音量: ${noiseReading.meanDecibel} dB'); // デバッグ出力
    if (!_isProcessing && noiseReading.meanDecibel > 70) {
      // しきい値を70デシベルに調整
      print('音声を検知しました: ${noiseReading.meanDecibel} dB');
      onVoiceDetected();
    }
  }

  /// 音声検知時の処理を行うメソッド
  void onVoiceDetected() {
    if (_isProcessing) return; // 既に処理中の場合は何もしない
    _isProcessing = true; // 処理開始

    setState(() {
      _isRedLampOn = true;
    });

    // 0〜3秒のランダムな遅延
    int delay = Random().nextInt(3000); // ミリ秒
    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted) return; // ウィジェットがまだマウントされているか確認
      setState(() {
        _isOrangeCircleVisible = true;
      });

      // オレンジの●を2秒間表示
      Future.delayed(Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() {
          _isOrangeCircleVisible = false;
          _isRedLampOn = false;
        });

        // 音声検知を一時停止し、2秒後に再開
        _noiseSubscription?.pause();
        Future.delayed(Duration(seconds: 2), () {
          if (!mounted) return;
          if (!_isIntervalMode) {
            _noiseSubscription?.resume();
          }
          _isProcessing = false; // 処理完了
        });
      });
    });
  }

  /// エラー処理を行うメソッド
  void onError(Object error) {
    print('音声検知中にエラーが発生しました: $error');
    setState(() {
      _isListening = false;
    });
    // エラーが発生した場合、再度リスニングを開始
    Future.delayed(Duration(seconds: 2), () {
      if (!_isIntervalMode && !_isListening) {
        startListening();
      }
    });
  }

  void startIntervalMode() {
    setState(() {
      _isRunning = true;
    });
    _intervalTimer =
        Timer.periodic(Duration(seconds: _interval.toInt()), (timer) {
      executeSequence();
    });
  }

  void stopIntervalMode() {
    setState(() {
      _isRunning = false;
      _isRedLampOn = false;
      _isOrangeCircleVisible = false;
    });
    if (_intervalTimer != null) {
      _intervalTimer!.cancel();
    }
  }

  void executeSequence() {
    setState(() {
      _isRedLampOn = true;
    });
    // 0〜3秒のランダムな遅延
    int delay = Random().nextInt(3000); // ミリ秒
    Future.delayed(Duration(milliseconds: delay), () {
      setState(() {
        _isOrangeCircleVisible = true;
      });
      // オレンジの●を2秒間表示
      Future.delayed(Duration(seconds: 2), () {
        setState(() {
          _isOrangeCircleVisible = false;
          _isRedLampOn = false;
        });
      });
    });
  }

  @override
  void dispose() {
    print('HomeScreenのdisposeメソッドが呼ばれました'); // デバッグ出力
    _noiseSubscription?.cancel();
    _intervalTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // UIの構築
    return Scaffold(
      appBar: AppBar(
        title: Text('スキート射撃練習'),
      ),
      body: Stack(
        children: [
          // メインコンテンツ
          Center(
            child: _isOrangeCircleVisible ? OrangeCircleWidget() : Container(),
          ),
          // 赤いランプ
          Positioned(
            top: 20,
            left: 20,
            child: _isRedLampOn ? RedLampWidget() : Container(),
          ),
          // コントロール
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('インターバルモード'),
                  value: _isIntervalMode,
                  onChanged: (value) {
                    setState(() {
                      _isIntervalMode = value;
                      if (_isIntervalMode) {
                        // 音声検知を停止
                        if (_isListening) {
                          _noiseSubscription?.cancel();
                          _isListening = false;
                        }
                      } else {
                        // 音声検知を開始
                        if (!_isListening) {
                          startListening();
                        }
                      }
                    });
                  },
                ),
                _isIntervalMode
                    ? Column(
                        children: [
                          Slider(
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: '間隔: ${_interval.toInt()} 秒',
                            value: _interval,
                            onChanged: (value) {
                              setState(() {
                                _interval = value;
                              });
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed:
                                    _isRunning ? null : startIntervalMode,
                                child: Text('開始'),
                              ),
                              SizedBox(width: 20),
                              ElevatedButton(
                                onPressed: _isRunning ? stopIntervalMode : null,
                                child: Text('停止'),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Container(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
