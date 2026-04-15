import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:rtc_rnnoise/rtc_rnnoise.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  MediaStream? _localStream;
  RTCPeerConnection? _pc1;
  RTCPeerConnection? _pc2;
  bool _isTestRunning = false;
  bool _isDenoiseEnabled = true;
  bool _isSpeakerOn = false;
  double _mixLevel = 1.0;
  double _currentVad = 0.0;
  StreamSubscription? _vadSubscription;

  @override
  void initState() {
    super.initState();
    // 建立持久监听
    _startVadListening();
  }

  void _startVadListening() {
    _vadSubscription?.cancel();
    _vadSubscription = RtcRnnoise.vadStream.listen(
      (vad) {
        if (mounted) {
          setState(() => _currentVad = vad);
        }
      },
      onError: (err) => debugPrint('VAD Stream Error: $err'),
    );
    debugPrint('Dart: Started listening to VAD stream');
  }

  @override
  void dispose() {
    _vadSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startLoopbackTest() async {
    if (_isTestRunning) return;

    try {
      await RtcRnnoise.init();

      final Map<String, dynamic> constraints = {
        'audio': {
          'googNoiseSuppression': false, 
          'googEchoCancellation': true,
          'echoCancellation': true,
        },
        'video': false,
      };
      
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);

      _pc1 = await createPeerConnection({});
      _pc2 = await createPeerConnection({});

      _pc1!.onIceCandidate = (candidate) => _pc2?.addCandidate(candidate);
      _pc2!.onIceCandidate = (candidate) => _pc1?.addCandidate(candidate);

      _pc2!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'audio') {
          Helper.setSpeakerphoneOn(_isSpeakerOn);
        }
      };

      _localStream!.getTracks().forEach((track) {
        _pc1!.addTrack(track, _localStream!);
      });

      RTCSessionDescription offer = await _pc1!.createOffer();
      await _pc1!.setLocalDescription(offer);
      await _pc2!.setRemoteDescription(offer);

      RTCSessionDescription answer = await _pc2!.createAnswer();
      await _pc2!.setLocalDescription(answer);
      await _pc1!.setRemoteDescription(answer);

      setState(() => _isTestRunning = true);
    } catch (e) {
      debugPrint('Start Error: $e');
      _stopTest();
    }
  }

  Future<void> _stopTest() async {
    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    _localStream = null;

    await _pc1?.close();
    await _pc2?.close();
    _pc1 = null;
    _pc2 = null;

    await Helper.setSpeakerphoneOn(false);
    setState(() {
      _isTestRunning = false;
      _currentVad = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: Scaffold(
        appBar: AppBar(title: const Text('RNNoise 最终验证 (VAD)')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(_isTestRunning ? '🟢 正在实时回环测试' : '🔴 测试已停止', 
                           style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isTestRunning ? _stopTest : _startLoopbackTest,
                          icon: Icon(_isTestRunning ? Icons.stop : Icons.play_arrow),
                          label: Text(_isTestRunning ? '停止测试' : '开始测试'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isTestRunning ? Colors.red[100] : Colors.green[100]
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('AI 人声检测 (VAD)', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('${(_currentVad * 100).toInt()}%', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: _currentVad,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _currentVad > 0.8 ? Colors.green : Colors.blue
                        ),
                        minHeight: 15,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('扬声器模式'),
                subtitle: Text(_isSpeakerOn ? '当前：外放' : '当前：耳机/听筒'),
                secondary: Icon(_isSpeakerOn ? Icons.volume_up : Icons.headset),
                value: _isSpeakerOn,
                onChanged: (val) {
                  setState(() => _isSpeakerOn = val);
                  Helper.setSpeakerphoneOn(val);
                },
              ),
              SwitchListTile(
                title: const Text('AI 降噪开关'),
                subtitle: const Text('控制原生 C++ 核心是否处理数据'),
                secondary: const Icon(Icons.auto_fix_high),
                value: _isDenoiseEnabled,
                onChanged: (val) {
                  setState(() => _isDenoiseEnabled = val);
                  RtcRnnoise.setEnabled(val);
                },
              ),
              ListTile(
                title: const Text('降噪强度'),
                subtitle: Slider(
                  value: _mixLevel,
                  onChanged: (val) {
                    setState(() => _mixLevel = val);
                    RtcRnnoise.setSuppressionLevel(val);
                  },
                ),
                trailing: Text('${(_mixLevel * 100).toInt()}%'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
