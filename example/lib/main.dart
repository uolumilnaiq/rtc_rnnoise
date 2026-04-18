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
    _startVadListening();
  }

  void _startVadListening() {
    _vadSubscription?.cancel();
    _vadSubscription = RtcRnnoise.vadStream.listen(
      (vad) {
        if (mounted) setState(() => _currentVad = vad);
      },
      onError: (err) => debugPrint('VAD Stream Error: $err'),
    );
  }

  @override
  void dispose() {
    _vadSubscription?.cancel();
    _stopTest();
    super.dispose();
  }

  Future<void> _startLoopbackTest() async {
    if (_isTestRunning) return;

    try {
      // 1. 初始化插件
      await RtcRnnoise.init();

      // 2. 获取设备列表 (诊断用)
      final devices = await navigator.mediaDevices.enumerateDevices();
      for (var device in devices) {
        debugPrint('Device: ${device.kind}, Label: ${device.label}');
      }

      // 3. 配置音频约束 (禁用 WebRTC 原生降噪以测试 AI 效果)
      final Map<String, dynamic> constraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': false,
          'autoGainControl': true,
        },
        'video': false,
      };
      
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      await Helper.setSpeakerphoneOn(_isSpeakerOn);

      _pc1 = await createPeerConnection({});
      _pc2 = await createPeerConnection({});

      List<RTCIceCandidate> pc1Candidates = [];
      List<RTCIceCandidate> pc2Candidates = [];
      bool pc1RemoteSet = false;
      bool pc2RemoteSet = false;

      _pc1!.onIceCandidate = (candidate) async {
        if (pc2RemoteSet) {
          await _pc2!.addCandidate(candidate);
        } else {
          pc2Candidates.add(candidate);
        }
      };

      _pc2!.onIceCandidate = (candidate) async {
        if (pc1RemoteSet) {
          await _pc1!.addCandidate(candidate);
        } else {
          pc1Candidates.add(candidate);
        }
      };

      _pc2!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'audio') {
          debugPrint('✅ Remote audio track active');
        }
      };

      _localStream!.getTracks().forEach((track) {
        _pc1!.addTrack(track, _localStream!);
      });

      RTCSessionDescription offer = await _pc1!.createOffer();
      await _pc1!.setLocalDescription(offer);
      await _pc2!.setRemoteDescription(offer);
      pc2RemoteSet = true;
      for (var c in pc2Candidates) { await _pc2!.addCandidate(c); }

      RTCSessionDescription answer = await _pc2!.createAnswer();
      await _pc2!.setLocalDescription(answer);
      await _pc1!.setRemoteDescription(answer);
      pc1RemoteSet = true;
      for (var c in pc1Candidates) { await _pc1!.addCandidate(c); }

      // 4. 关键：注入降噪器
      try {
        bool attached = await RtcRnnoise.attach();
        if (attached) debugPrint('✅ RNNoise Attached Successfully');
      } catch (e) {
        debugPrint('⚠️ Attach failed (Expected on Simulators): $e');
      }

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
        appBar: AppBar(title: const Text('RNNoise v0.2 AI Denoise')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_isTestRunning ? '🟢 正在实时处理音频' : '🔴 已停止', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isTestRunning ? _stopTest : _startLoopbackTest,
                child: Text(_isTestRunning ? '停止测试' : '开始降噪测试'),
              ),
              const SizedBox(height: 40),
              const Text('人声检测概率 (VAD)'),
              const SizedBox(height: 10),
              Container(
                width: 300,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _currentVad,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _currentVad > 0.7 ? Colors.green : Colors.blue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text('${(_currentVad * 100).toInt()}%'),
              const SizedBox(height: 40),
              SizedBox(
                width: 300,
                child: SwitchListTile(
                  title: const Text('AI 降噪开关'),
                  value: _isDenoiseEnabled,
                  onChanged: (val) {
                    setState(() => _isDenoiseEnabled = val);
                    RtcRnnoise.setEnabled(val);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
