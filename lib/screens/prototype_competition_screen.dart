import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/pose_service.dart';
import '../services/multi_pose_tracker.dart';
import '../services/prototype_bot_engine.dart';
import '../services/stats_service.dart';
import '../services/progression_service.dart';
import '../painters/pose_painter.dart';
import 'crossfit_workout_screen.dart';
import 'plank_challenge_screen.dart';

enum _ScreenState {
  modeSelect,
  searching,
  live,
  botWaiting,
  results,
}

enum _GameMode { friends, bot, crossfit, plank }

class PrototypeCompetitionScreen extends StatefulWidget {
  const PrototypeCompetitionScreen({super.key});

  @override
  State<PrototypeCompetitionScreen> createState() =>
      _PrototypeCompetitionScreenState();
}

class _PrototypeCompetitionScreenState
    extends State<PrototypeCompetitionScreen> with TickerProviderStateMixin {
  // ── Camera ──
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _camIdx = 0;
  bool _camReady = false;
  bool _detecting = false;

  final PoseDetector _detector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );

  // ── Exact existing MultiPoseTracker from multi_pose_tracker.dart ──
  final MultiPoseTracker _multiTracker = MultiPoseTracker();
  List<PlayerTrack> _players = [];

  // ── Live Tracking Diagnostics ──
  double? _liveNoseRatio;
  String _liveStateText = 'Position face';
  bool _isFaceDetected = false;
  int _simulatedReps = 0; // for testing without physical pushups

  // ── Bot ──
  final PrototypeBotEngine _bot = PrototypeBotEngine();

  // ── State ──
  _ScreenState _state = _ScreenState.modeSelect;
  _GameMode _mode = _GameMode.friends;
  int _timerSec = 60;
  int _remaining = 60;
  Timer? _countdown;

  // ── Animations ──
  late AnimationController _pulseCtrl;
  late AnimationController _dotCtrl;

  static const _names = [
    'Alex', 'Jake', 'Sophia', 'Max', 'Dave', 'Mike',
    'Sarah', 'Chris', 'Nina', 'Zach', 'Lily', 'Omar',
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _multiTracker.mode = TrackingMode.selfieCamera;

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _bot.onUpdate = (a, b, c, d) {
      if (mounted) setState(() {});
    };
    _bot.onRepCompleted = (_) {
      if (mounted) HapticFeedback.lightImpact();
    };
    _bot.onBotSubmitted = () {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() => _state = _ScreenState.botWaiting);
      }
    };
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _dotCtrl.dispose();
    _countdown?.cancel();
    _bot.dispose();
    final c = _controller;
    _controller = null;
    c?.stopImageStream().catchError((_) {});
    c?.dispose();
    _detector.close();
    super.dispose();
  }

  // ── Camera helpers ──

  Future<void> _setupCamera() async {
    final perm = await Permission.camera.request();
    if (!perm.isGranted) return;
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    _camIdx = _cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    if (_camIdx == -1) _camIdx = 0;
    await _startCamera();
  }

  Future<void> _startCamera() async {
    final prev = _controller;
    if (prev != null) {
      await prev.stopImageStream().catchError((_) {});
      await prev.dispose();
    }
    _controller = CameraController(
      _cameras[_camIdx],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await _controller!.initialize();
    await _controller!.startImageStream(_onFrame);
    if (mounted) {
      setState(() {
        _camReady = true;
        _players = _multiTracker.allPlayers;
      });
    }
  }

  Future<void> _onFrame(CameraImage img) async {
    if (_detecting || _controller == null || !_controller!.value.isInitialized) {
      return;
    }
    _detecting = true;
    try {
      final cam = _controller!.description;
      final fmt = InputImageFormatValue.fromRawValue(img.format.raw);
      final rot = InputImageRotationValue.fromRawValue(cam.sensorOrientation);
      if (fmt == null || rot == null) {
        _detecting = false;
        return;
      }
      final input = InputImage.fromBytes(
        bytes: img.planes.first.bytes,
        metadata: InputImageMetadata(
          size: Size(img.width.toDouble(), img.height.toDouble()),
          rotation: rot,
          format: fmt,
          bytesPerRow: img.planes.first.bytesPerRow,
        ),
      );
      final poses = await _detector.processImage(input);
      final rotated = rot == InputImageRotation.rotation90deg ||
          rot == InputImageRotation.rotation270deg;
      final sz = rotated
          ? Size(img.height.toDouble(), img.width.toDouble())
          : Size(img.width.toDouble(), img.height.toDouble());

      // Use exact existing MultiPoseTracker from multi_pose_tracker.dart
      final updated = _multiTracker.processFramePoses(poses, sz);

      for (final p in updated) {
        if (p.lastAnalysis?.repJustCompleted == true) {
          HapticFeedback.mediumImpact();
        }
      }

      // Extract diagnostics from Player 1
      double? noseRatio;
      bool faceOk = false;
      String stateStr = 'Face visible';

      if (updated.isNotEmpty) {
        final p1 = updated.first;
        final nose = p1.currentPose?.landmarks[PoseLandmarkType.nose];
        if (nose != null && nose.likelihood > 0.30 && sz.height > 0) {
          faceOk = true;
          noseRatio = (nose.y / sz.height).clamp(0.0, 1.0);
        }
        final analysis = p1.lastAnalysis;
        if (analysis != null) {
          switch (analysis.repState) {
            case RepState.waitingForPlank:
              stateStr = 'Waiting for Lockout (<=35%)';
              break;
            case RepState.top:
              stateStr = 'Top Lockout ✓';
              break;
            case RepState.descending:
              stateStr = 'Descending...';
              break;
            case RepState.bottom:
              stateStr = 'Bottom Depth! (>=65%)';
              break;
            case RepState.ascending:
              stateStr = 'Pushing Up!';
              break;
          }
        }
      }

      if (mounted) {
        setState(() {
          _players = updated;
          _liveNoseRatio = noseRatio;
          _isFaceDetected = faceOk;
          _liveStateText = stateStr;
        });
      }
    } catch (_) {}
    _detecting = false;
  }

  // ── Testing Helper (Simulate Rep without doing real pushups) ──
  void _simulateTestRep() {
    HapticFeedback.mediumImpact();
    setState(() {
      _simulatedReps++;
    });
  }

  // ── Flow ──

  void _startFriendsMode() {
    _mode = _GameMode.friends;
    _simulatedReps = 0;
    _setupCamera();
    _remaining = _timerSec;
    _startTimer();
    setState(() => _state = _ScreenState.live);
  }

  void _startBotSearch() {
    _mode = _GameMode.bot;
    _simulatedReps = 0;
    setState(() => _state = _ScreenState.searching);
    final name = _names[DateTime.now().millisecondsSinceEpoch % _names.length];
    final delay = 2200 + (DateTime.now().millisecondsSinceEpoch % 1800);
    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _bot.name = name;
      _setupCamera();
      _bot.start();
      _remaining = _timerSec;
      _startTimer();
      setState(() => _state = _ScreenState.live);
    });
  }

  void _startTimer() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        _submit();
      }
    });
  }

  void _submit() {
    HapticFeedback.heavyImpact();
    _bot.stop();
    _countdown?.cancel();

    final ranked = List<PlayerTrack>.from(_multiTracker.allPlayers);
    ranked.sort((a, b) => b.repCount.compareTo(a.repCount));

    List<_Entry> entries = [];
    for (final p in ranked) {
      if (p.isPresent || p.repCount > 0 || (p.id == 1 && _simulatedReps > 0)) {
        final totalReps = p.id == 1 ? p.repCount + _simulatedReps : p.repCount;
        entries.add(_Entry(p.name, totalReps, p.formScore ?? 85, p.themeColor, false));
      }
    }
    if (entries.isEmpty && ranked.isNotEmpty) {
      final p = ranked.first;
      final totalReps = p.repCount + _simulatedReps;
      entries.add(_Entry(p.name, totalReps, p.formScore ?? 85, p.themeColor, false));
    }
    if (_mode == _GameMode.bot) {
      entries.add(_Entry(
        _bot.name,
        _bot.repCount,
        78 + (DateTime.now().millisecondsSinceEpoch % 17),
        const Color(0xFFCE93D8),
        true,
      ));
    }
    entries.sort((a, b) => b.reps.compareTo(a.reps));

    // Save total reps for all human players to global profile
    bool humanPlayed = false;
    for (final e in entries) {
      if (!e.isBot) {
        humanPlayed = true;
        ProgressionService.instance.addWorkoutReps(
          athleteName: e.name,
          reps: e.reps,
          formScore: e.form,
        );
      }
    }
    if (humanPlayed) {
      StatsService.addWorkoutCompleted();
    }

    setState(() => _state = _ScreenState.results);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ResultsSheet(
        entries: entries,
        onRematch: () {
          Navigator.pop(ctx);
          _multiTracker.resetAll();
          _bot.reset();
          _simulatedReps = 0;
          setState(() => _state = _ScreenState.modeSelect);
        },
        onExit: () {
          Navigator.pop(ctx);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _ScreenState.modeSelect:
        return _buildModeSelect();
      case _ScreenState.searching:
        return _buildSearching();
      case _ScreenState.live:
      case _ScreenState.botWaiting:
      case _ScreenState.results:
        return _buildLiveSession();
    }
  }

  // ────────────────────────────────────────
  //  MODE SELECT
  // ────────────────────────────────────────

  Widget _buildModeSelect() {
    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Push-up Arena',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text(
            'Choose mode',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Friends card
          _modeCard(
            selected: _mode == _GameMode.friends,
            onTap: () => setState(() => _mode = _GameMode.friends),
            icon: Icons.people_outline,
            title: 'Play with Friends (Up to 4)',
            desc: 'Tracks up to 4 people simultaneously facing the selfie camera. '
                'Reps are counted individually and never lost when someone steps away.',
          ),
          const SizedBox(height: 10),

          // Bot card
          _modeCard(
            selected: _mode == _GameMode.bot,
            onTap: () => setState(() => _mode = _GameMode.bot),
            icon: Icons.person_search_outlined,
            title: 'Challenge Bot Companion',
            desc: 'Compete against a Bot Companion who performs real push-ups, '
                'takes realistic breathers, and submits its score before you.',
          ),
          const SizedBox(height: 10),

          // CrossFit card
          _modeCard(
            selected: _mode == _GameMode.crossfit,
            onTap: () => setState(() => _mode = _GameMode.crossfit),
            icon: Icons.timer,
            title: 'CrossFit Split WOD',
            desc: 'Follow a timed split workout. Hold a plank, then transition '
                'directly to pushups based on on-screen timers.',
          ),
          const SizedBox(height: 10),

          // Plank card
          _modeCard(
            selected: _mode == _GameMode.plank,
            onTap: () => setState(() => _mode = _GameMode.plank),
            icon: Icons.shield,
            title: 'Endurance Plank',
            desc: 'Get into position and the timer starts automatically. '
                'It runs continuously while you maintain proper form!',
          ),

          // Timer
          const SizedBox(height: 28),
          const Text(
            'Round timer',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _timerChip(30, '0:30'),
              _timerChip(60, '1:00'),
              _timerChip(90, '1:30'),
              _timerChip(120, '2:00'),
              _timerChip(180, '3:00'),
            ],
          ),

          const SizedBox(height: 36),

          // Start button
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: () {
                if (_mode == _GameMode.friends) {
                  _startFriendsMode();
                } else if (_mode == _GameMode.bot) {
                  _startBotSearch();
                } else if (_mode == _GameMode.crossfit) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const CrossfitWorkoutScreen()),
                  );
                } else if (_mode == _GameMode.plank) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const PlankChallengeScreen()),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _mode == _GameMode.friends 
                    ? 'Start 4-Player Session' 
                    : _mode == _GameMode.bot
                        ? 'Find Opponent'
                        : _mode == _GameMode.crossfit
                            ? 'Start CrossFit WOD'
                            : 'Start Endless Plank',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeCard({
    required bool selected,
    required VoidCallback onTap,
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.white54 : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.white : Colors.white38, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white60,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }



  Widget _timerChip(int sec, String label) {
    final sel = _timerSec == sec;
    return GestureDetector(
      onTap: () => setState(() => _timerSec = sec),
      child: Chip(
        label: Text(label),
        labelStyle: TextStyle(
          color: sel ? Colors.black : Colors.white60,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        backgroundColor: sel ? Colors.white : Colors.white.withValues(alpha: 0.06),
        side: BorderSide(color: sel ? Colors.white : Colors.white12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
    );
  }

  // ────────────────────────────────────────
  //  SEARCHING
  // ────────────────────────────────────────

  Widget _buildSearching() {
    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, child) {
                        final v = _pulseCtrl.value;
                        return Container(
                          width: 100 + v * 20,
                          height: 100 + v * 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15 + v * 0.25),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.person_search_outlined,
                            color: Colors.white.withValues(alpha: 0.5 + v * 0.5),
                            size: 40,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    AnimatedBuilder(
                      animation: _dotCtrl,
                      builder: (_, child) {
                        final dots = '.' * ((_dotCtrl.value * 4).floor() % 4);
                        return Text(
                          'Looking for a player$dots',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bot Companion • ${_fmtTime(_timerSec)}',
                      style: const TextStyle(color: Colors.white30, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: TextButton(
                onPressed: () => setState(() => _state = _ScreenState.modeSelect),
                child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────
  //  LIVE SESSION
  // ────────────────────────────────────────

  Widget _buildLiveSession() {
    final front = _cameras.isNotEmpty &&
        _cameras[_camIdx].lensDirection == CameraLensDirection.front;

    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Camera View with Skeletons
            if (_camReady && _controller != null)
              Positioned.fill(
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.previewSize?.height ?? 1,
                        height: _controller!.value.previewSize?.width ?? 1,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(_controller!),
                            CustomPaint(
                              painter: PosePainter(
                                players: _players,
                                imageSize: Size(
                                  _controller!.value.previewSize?.height ?? 1,
                                  _controller!.value.previewSize?.width ?? 1,
                                ),
                                isFrontCamera: front,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white24,
                  strokeWidth: 2,
                ),
              ),

            // Gradient overlay
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      stops: const [0, 0.15, 0.55, 1],
                    ),
                  ),
                ),
              ),
            ),

            // 2. Top bar: Close, Timer, Flip camera
            Positioned(
              top: 4,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                    onPressed: () {
                      _bot.stop();
                      _countdown?.cancel();
                      Navigator.pop(context);
                    },
                  ),
                  const Spacer(),
                  // Timer badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _remaining <= 10 ? const Color(0xFFEF5350) : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: _remaining <= 10 ? const Color(0xFFEF5350) : Colors.white60,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _fmtTime(_remaining),
                          style: TextStyle(
                            color: _remaining <= 10 ? const Color(0xFFEF5350) : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.flip_camera_ios_outlined, color: Colors.white70, size: 22),
                    onPressed: () {
                      if (_cameras.length > 1) {
                        _camIdx = (_camIdx + 1) % _cameras.length;
                        _startCamera();
                      }
                    },
                  ),
                ],
              ),
            ),

            // 3. LIVE TRACKING DIAGNOSTIC GAUGE (Top Left)
            Positioned(
              top: 54,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Vertical slider bar
                    Container(
                      width: 10,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          Positioned(
                            top: 50 * 0.35,
                            left: 0,
                            right: 0,
                            child: Container(height: 2, color: const Color(0xFF4CAF50)),
                          ),
                          Positioned(
                            top: 50 * 0.65,
                            left: 0,
                            right: 0,
                            child: Container(height: 2, color: const Color(0xFFFF9800)),
                          ),
                          if (_liveNoseRatio != null)
                            Positioned(
                              top: (50 * _liveNoseRatio!).clamp(0.0, 44.0),
                              child: Container(
                                width: 8,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.face,
                              size: 13,
                              color: _isFaceDetected ? const Color(0xFF4CAF50) : Colors.white38,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isFaceDetected
                                  ? (_liveNoseRatio != null ? '${(_liveNoseRatio! * 100).toInt()}% Depth' : 'Face OK')
                                  : 'No Face',
                              style: TextStyle(
                                color: _isFaceDetected ? const Color(0xFF4CAF50) : Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _liveStateText,
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 4. "🧪 TEST REP" BUTTON (Top Right, lets user simulate reps immediately!)
            Positioned(
              top: 54,
              right: 14,
              child: ElevatedButton.icon(
                onPressed: _simulateTestRep,
                icon: const Icon(Icons.science, size: 15, color: Colors.black),
                label: const Text(
                  'TEST REP',
                  style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),

            // 5. Bot "waiting" banner
            if (_state == _ScreenState.botWaiting)
              Positioned(
                top: 118,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCE93D8), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Color(0xFF66BB6A), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: _bot.name,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                              TextSpan(
                                text: ' finished with ${_bot.repCount} reps. Waiting for you…',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 6. Bottom HUD: 4-Player Friends or Bot
            Positioned(
              bottom: 82,
              left: 12,
              right: 12,
              child: _mode == _GameMode.friends ? _friendsHUD() : _botHUD(),
            ),

            // 7. Single Submit Button
            Positioned(
              bottom: 16,
              left: 20,
              right: 20,
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Submit & See Results',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Friends HUD (Up to 4 Players) ──

  Widget _friendsHUD() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_multiTracker.detectedPeopleCount} of 4 athletes detected',
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.3,
          ),
          itemCount: _players.length,
          itemBuilder: (_, i) {
            final p = _players[i];
            final reps = p.id == 1 ? p.repCount + _simulatedReps : p.repCount;
            return _playerTile(p, reps);
          },
        ),
      ],
    );
  }

  Widget _playerTile(PlayerTrack p, int displayedReps) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: p.isPresent ? Colors.white30 : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 34,
            decoration: BoxDecoration(
              color: p.themeColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  p.isPresent
                      ? p.feedback
                      : (displayedReps > 0 ? 'Saved' : 'Waiting…'),
                  style: TextStyle(
                    color: p.isGoodForm ? Colors.white54 : const Color(0xFFEF5350),
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            '$displayedReps',
            style: TextStyle(
              color: p.themeColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bot HUD ──

  Widget _botHUD() {
    final human = _players.isNotEmpty ? _players.first : null;
    final userTotalReps = (human?.repCount ?? 0) + _simulatedReps;

    return Row(
      children: [
        // You
        Expanded(
          child: _scoreCard(
            label: 'You',
            reps: userTotalReps,
            subtitle: human?.feedback ?? 'Face the camera',
            color: Colors.white,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('vs', style: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        // Bot
        Expanded(
          child: _scoreCard(
            label: _bot.name,
            reps: _bot.repCount,
            subtitle: _bot.hasSubmitted ? 'Submitted ✓' : _bot.statusMessage,
            color: const Color(0xFFCE93D8),
            showProgress: !_bot.hasSubmitted,
            progress: _bot.phaseProgress,
          ),
        ),
      ],
    );
  }

  Widget _scoreCard({
    required String label,
    required int reps,
    required String subtitle,
    required Color color,
    bool showProgress = false,
    double progress = 0,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '$reps',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (showProgress) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.7)),
                minHeight: 3,
              ),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _fmtTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(1, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

// ── Data ──

class _Entry {
  final String name;
  final int reps;
  final int form;
  final Color color;
  final bool isBot;
  _Entry(this.name, this.reps, this.form, this.color, this.isBot);
}

// ── Results Sheet ──

class _ResultsSheet extends StatelessWidget {
  final List<_Entry> entries;
  final VoidCallback onRematch;
  final VoidCallback onExit;

  const _ResultsSheet({
    required this.entries,
    required this.onRematch,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final winner = entries.isNotEmpty ? entries.first : null;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Dialog(
        backgroundColor: const Color(0xFF1A1C22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 8),
              const Text(
                'Results',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (winner != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${winner.name} wins with ${winner.reps} reps!',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
              const SizedBox(height: 18),
              ...entries.asMap().entries.map((e) {
                final i = e.key;
                final item = e.value;
                final medals = ['🥇', '🥈', '🥉', '#4'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: i == 0
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: i == 0 ? const Color(0xFFFFD700).withValues(alpha: 0.4) : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          i < 3 ? medals[i] : medals[3],
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Form: ${item.form}%',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${item.reps}',
                          style: TextStyle(
                            color: item.color,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'reps',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onExit,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: const BorderSide(color: Colors.white12),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Exit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: onRematch,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Play Again',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
