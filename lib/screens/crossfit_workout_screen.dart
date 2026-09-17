import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/pose_service.dart';
import '../services/multi_pose_tracker.dart';
import '../services/progression_service.dart';
import '../services/stats_service.dart';
import '../painters/pose_painter.dart';

enum WorkoutType { plank, pushups, rest }

class WorkoutPhase {
  final WorkoutType type;
  final int targetValue; // For plank/rest it's seconds. For pushups it's reps.

  WorkoutPhase({required this.type, required this.targetValue});
}

class CrossfitWorkoutScreen extends StatefulWidget {
  const CrossfitWorkoutScreen({super.key});

  @override
  State<CrossfitWorkoutScreen> createState() => _CrossfitWorkoutScreenState();
}

class _CrossfitWorkoutScreenState extends State<CrossfitWorkoutScreen> {
  // ── Camera & ML ──
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _camReady = false;
  bool _detecting = false;

  final PoseDetector _detector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );
  final MultiPoseTracker _tracker = MultiPoseTracker();
  List<PlayerTrack> _players = [];

  // ── Workout Data ──
  late final List<WorkoutPhase> _routine;
  int _currentPhaseIndex = 0;
  
  // Progress tracking
  double _currentValue = 0; // seconds or reps
  bool _isWorkoutComplete = false;
  bool _isHoldingPlank = false; // Is user currently in good plank form?

  int _totalPushupsDone = 0;
  int _totalPlankTimeDone = 0;
  bool _hasSavedData = false;

  // ── Timers ──
  Timer? _plankTimer;


  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _tracker.mode = TrackingMode.selfieCamera;
    _generateRandomRoutine();
    _setupCamera();
    _startPhaseLogic();
  }

  void _generateRandomRoutine() {
    final List<WorkoutPhase> phases = [];
    final random = math.Random();
    
    // Generate 5 random phases
    for (int i = 0; i < 5; i++) {
      // 50% chance for plank vs pushups, occasionally inject rest
      if (random.nextDouble() > 0.8) {
        phases.add(WorkoutPhase(type: WorkoutType.rest, targetValue: 10 + random.nextInt(10)));
      } else if (random.nextBool()) {
        phases.add(WorkoutPhase(type: WorkoutType.plank, targetValue: 10 + random.nextInt(20)));
      } else {
        phases.add(WorkoutPhase(type: WorkoutType.pushups, targetValue: 5 + random.nextInt(10)));
      }
    }
    _routine = phases;
  }

  void _saveData() {
    if (_hasSavedData) return;
    if (_totalPushupsDone > 0 || _totalPlankTimeDone > 0) {
      _hasSavedData = true;
      StatsService.addPlankTime(_totalPlankTimeDone);
      StatsService.addWorkoutCompleted();
      ProgressionService.instance.addWorkoutReps(
        athleteName: 'Athlete',
        reps: _totalPushupsDone,
        formScore: 100,
        plankSeconds: _totalPlankTimeDone,
      );
    }
  }

  @override
  void dispose() {
    _saveData();
    _plankTimer?.cancel();
    final c = _controller;
    _controller = null;
    c?.stopImageStream().catchError((_) {});
    c?.dispose();
    _detector.close();
    super.dispose();
  }

  Future<void> _setupCamera() async {
    if (!await Permission.camera.request().isGranted) return;
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    int idx = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
    if (idx == -1) idx = 0;

    _controller = CameraController(
      _cameras[idx],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await _controller!.initialize();
    await _controller!.startImageStream(_onFrame);

    if (mounted) {
      setState(() => _camReady = true);
    }
  }

  Future<void> _onFrame(CameraImage img) async {
    if (_detecting || _controller == null || _isWorkoutComplete) return;
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
      final isRotated = rot == InputImageRotation.rotation90deg || rot == InputImageRotation.rotation270deg;
      final sz = isRotated
          ? Size(img.height.toDouble(), img.width.toDouble())
          : Size(img.width.toDouble(), img.height.toDouble());

      final updated = _tracker.processFramePoses(poses, sz);

      if (poses.isEmpty || updated.isEmpty || updated.first.currentPose == null) {
        if (_isHoldingPlank) {
          _isHoldingPlank = false;
        }
      } else {
        final p1 = updated.first;
        final analysis = p1.lastAnalysis;
        if (analysis != null) {
          _processWorkoutLogic(analysis);
        }
      }

      if (mounted) {
        setState(() => _players = updated);
      }
    } catch (_) {}
    _detecting = false;
  }

  void _processWorkoutLogic(FrameAnalysis analysis) {
    if (_currentPhaseIndex >= _routine.length) return;
    final phase = _routine[_currentPhaseIndex];

    if (phase.type == WorkoutType.plank) {
      // Strictly enforce true biomechanical plank (straight spine + planted arms)
      bool goodPlank = analysis.isPlank;
      
      if (goodPlank != _isHoldingPlank) {
        _isHoldingPlank = goodPlank;
        HapticFeedback.lightImpact();
      }
    } else if (phase.type == WorkoutType.pushups) {
      if (analysis.repJustCompleted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _currentValue += 1;
          _totalPushupsDone += 1;
        });
        if (_currentValue >= phase.targetValue) {
          _advancePhase();
        }
      }
    }
  }

  void _startPhaseLogic() {
    _plankTimer?.cancel();
    _plankTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted || _isWorkoutComplete) {
        t.cancel();
        return;
      }

      final phase = _routine[_currentPhaseIndex];

      if (phase.type == WorkoutType.plank) {
        if (_isHoldingPlank) {
          setState(() {
            _currentValue += 0.1;
            // Since this runs every 100ms, increment total by integer seconds precisely
            if ((_currentValue * 10).toInt() % 10 == 0) {
              _totalPlankTimeDone += 1;
            }
          });
          if (_currentValue >= phase.targetValue) {
            _advancePhase();
          }
        }
      } else if (phase.type == WorkoutType.rest) {
        setState(() {
          _currentValue += 0.1;
        });
        if (_currentValue >= phase.targetValue) {
          _advancePhase();
        }
      }
    });
  }

  void _advancePhase() {
    HapticFeedback.heavyImpact();
    setState(() {
      _currentPhaseIndex++;
      _currentValue = 0;
      _isHoldingPlank = false;
      
      if (_currentPhaseIndex >= _routine.length) {
        _completeWorkout();
      }
    });
  }

  void _completeWorkout() {
    _isWorkoutComplete = true;
    _plankTimer?.cancel();
    _saveData();
  }

  // ── UI ──
  @override
  Widget build(BuildContext context) {
    final front = _cameras.isNotEmpty && _cameras.first.lensDirection == CameraLensDirection.front;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Background
          if (_camReady && _controller != null)
            FittedBox(
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
          
          // Dark Overlay
          Container(color: Colors.black.withValues(alpha: 0.6)),

          // Header
          Positioned(
            top: 50, left: 16, right: 16,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                const Text(
                  'CROSSFIT WOD',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
                const Spacer(),
                const SizedBox(width: 48), // Balance close button
              ],
            ),
          ),

          // Workout Logic UI
          if (_isWorkoutComplete)
            _buildCompletionScreen()
          else
            _buildActiveWorkoutScreen(),
        ],
      ),
    );
  }

  Widget _buildActiveWorkoutScreen() {
    final phase = _routine[_currentPhaseIndex];
    final remaining = phase.targetValue - _currentValue;

    String instruction = '';
    Color accentColor = const Color(0xFF00FF88);
    
    if (phase.type == WorkoutType.plank) {
      instruction = _isHoldingPlank ? 'HOLD PLANK' : 'GET INTO PLANK POSITION';
      accentColor = _isHoldingPlank ? const Color(0xFF00FF88) : const Color(0xFFFFCC00);
    } else if (phase.type == WorkoutType.pushups) {
      instruction = 'DO PUSHUPS';
      accentColor = const Color(0xFF00FF88);
    } else if (phase.type == WorkoutType.rest) {
      instruction = 'REST';
      accentColor = const Color(0xFF0A84FF);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Phase Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'PHASE ${_currentPhaseIndex + 1} OF ${_routine.length}',
            style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.0),
          ),
        ),
        const SizedBox(height: 30),

        // Value Display
        Text(
          phase.type == WorkoutType.pushups
              ? '${_currentValue.toInt()} / ${phase.targetValue}'
              : '${remaining.ceil()}s',
          style: TextStyle(
            color: accentColor,
            fontSize: 80,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 10),

        // Instruction Text
        Text(
          instruction,
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 1.0),
        ),
        
        // Progress Bar
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (_currentValue / phase.targetValue).clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(accentColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionScreen() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, color: Color(0xFF34C759), size: 64),
            const SizedBox(height: 16),
            const Text(
              'WORKOUT\nCOMPLETE',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1.1),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Return to Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
