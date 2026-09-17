import 'dart:async';
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

class PlankChallengeScreen extends StatefulWidget {
  const PlankChallengeScreen({super.key});

  @override
  State<PlankChallengeScreen> createState() => _PlankChallengeScreenState();
}

class _PlankChallengeScreenState extends State<PlankChallengeScreen> {
  // â”€â”€ Camera & ML â”€â”€
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _camReady = false;
  bool _detecting = false;

  final PoseDetector _detector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );
  final MultiPoseTracker _tracker = MultiPoseTracker();
  List<PlayerTrack> _players = [];

  // Progress tracking
  double _plankSeconds = 0;
  bool _isHoldingPlank = false;
  bool _hasSavedData = false;
  bool _isFinished = false;

  // â”€â”€ Timers â”€â”€
  Timer? _plankTimer;

  // â”€â”€ Diagnostics â”€â”€
  String _liveStateText = 'Get into plank position';
  String? _detectedOrientation;
  int? _plankFormScore;
  int _currentCameraIdx = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _tracker.mode = TrackingMode.sideProfile; // MultiPoseTracker will use universal plank detection
    _setupCamera();
    _startPhaseLogic();
  }

  void _saveData() {
    if (_hasSavedData) return;
    if (_plankSeconds > 0) {
      _hasSavedData = true;
      StatsService.addPlankTime(_plankSeconds.toInt());
      StatsService.addWorkoutCompleted();
      ProgressionService.instance.addWorkoutReps(
        athleteName: 'Athlete',
        reps: 0,
        formScore: _plankFormScore ?? 100,
        plankSeconds: _plankSeconds.toInt(),
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

  Future<void> _setupCamera({int? cameraIndex}) async {
    if (!await Permission.camera.request().isGranted) return;
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    if (cameraIndex != null) {
      _currentCameraIdx = cameraIndex % _cameras.length;
    } else {
      _currentCameraIdx = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      if (_currentCameraIdx == -1) _currentCameraIdx = 0;
    }

    final old = _controller;
    _controller = null;
    await old?.stopImageStream().catchError((_) {});
    await old?.dispose();

    _controller = CameraController(
      _cameras[_currentCameraIdx],
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

  void _toggleCamera() {
    if (_cameras.length <= 1) return;
    HapticFeedback.selectionClick();
    _setupCamera(cameraIndex: _currentCameraIdx + 1);
  }

  Future<void> _onFrame(CameraImage img) async {
    if (_detecting || _controller == null || _isFinished) return;
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
          setState(() {
            _isHoldingPlank = false;
            _liveStateText = 'Position body in camera view';
          });
        }
      } else {
        final p1 = updated.first;
        final analysis = p1.lastAnalysis;
        if (analysis != null) {
          _liveStateText = analysis.plankFeedback ?? analysis.feedback;
          _detectedOrientation = analysis.plankOrientation;
          _plankFormScore = analysis.plankFormScore;
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
    if (_isFinished) return;
    
    // Strictly enforce true biomechanical plank (straight spine + planted arms)
    bool goodPlank = analysis.isPlank;
    
    if (goodPlank != _isHoldingPlank) {
      setState(() => _isHoldingPlank = goodPlank);
    }
  }

  void _startPhaseLogic() {
    _plankTimer?.cancel();
    _plankTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted || _isFinished) {
        t.cancel();
        return;
      }

      if (_isHoldingPlank) {
        setState(() {
          _plankSeconds += 0.1;
        });
      }
    });
  }

  void _completeWorkout() {
    setState(() {
      _isFinished = true;
    });
    _plankTimer?.cancel();
    _saveData();
  }

  // â”€â”€ UI â”€â”€
  @override
  Widget build(BuildContext context) {
    final front = _cameras.isNotEmpty && _cameras[_currentCameraIdx].lensDirection == CameraLensDirection.front;

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
                  'ENDURANCE PLANK',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
                const Spacer(),
                if (_cameras.length > 1)
                  IconButton(
                    icon: const Icon(Icons.flip_camera_ios_outlined, color: Colors.white, size: 24),
                    onPressed: _toggleCamera,
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),

          // Workout Logic UI
          if (_isFinished)
            _buildCompletionScreen()
          else
            _buildActiveWorkoutScreen(),
        ],
      ),
    );
  }

  Widget _buildActiveWorkoutScreen() {
    String instruction;
    Color accentColor;
    if (_isHoldingPlank) {
      final orientationLabel = _detectedOrientation != null && _detectedOrientation != 'None'
          ? ' • $_detectedOrientation'
          : '';
      instruction = 'HOLDING STEADY$orientationLabel';
      accentColor = const Color(0xFF00FF88);
    } else {
      instruction = 'GET INTO PLANK POSITION';
      accentColor = const Color(0xFFFFCC00);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Value Display
        Text(
          '${_plankSeconds.toStringAsFixed(1)}s',
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
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 1.0),
        ),

        const SizedBox(height: 12),

        // Real-time Coaching / Feedback Pill
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHoldingPlank ? const Color(0xFF00FF88).withValues(alpha: 0.4) : Colors.white24,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isHoldingPlank ? Icons.check_circle_outline : Icons.info_outline,
                size: 16,
                color: _isHoldingPlank ? const Color(0xFF00FF88) : const Color(0xFFFFCC00),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _liveStateText,
                  style: TextStyle(
                    color: _isHoldingPlank ? const Color(0xFF00FF88) : Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 40),
        
        // Stop Button
        FilledButton(
          onPressed: _completeWorkout,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
          child: const Text('STOP WORKOUT', style: TextStyle(fontWeight: FontWeight.bold)),
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
            const Icon(Icons.timer, color: Color(0xFF00FF88), size: 64),
            const SizedBox(height: 16),
            const Text(
              'PLANK\nCOMPLETED',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1.1),
            ),
            const SizedBox(height: 12),
            Text(
              'Time: ${_plankSeconds.toStringAsFixed(1)}s',
              style: const TextStyle(color: Color(0xFF00FF88), fontSize: 24, fontWeight: FontWeight.bold),
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
