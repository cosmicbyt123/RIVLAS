import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/pose_service.dart';
import '../services/stats_service.dart';
import '../services/progression_service.dart';

class GameModeScreen extends StatefulWidget {
  const GameModeScreen({super.key});

  @override
  State<GameModeScreen> createState() => _GameModeScreenState();
}

class _GameModeScreenState extends State<GameModeScreen>
    with SingleTickerProviderStateMixin {
  // Camera & ML Kit (Reusing existing MultiPoseTracker + PoseService)
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isProcessingFrame = false;

  late FaceDetector _faceDetector;
  late PoseDetector _poseDetector;
  final PoseService _poseService = PoseService()..mode = TrackingMode.selfieCamera;

  // Single player tracking now
  double? _liveNoseRatio;
  bool _isFaceDetected = false;
  String _liveTrackingState = 'Waiting for Face...';
  String _coachingFeedback = 'Position phone & face camera';
  bool _isAscending = false;

  // 60 FPS Physics Loop
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  double _idleHoverTime = 0.0;

  // Game state
  bool _isPlaying = false;
  bool _isGameOver = false;
  int _score = 0;
  int _pushupCount = 0;
  String _lastJumpText = 'HOLD HEIGHT! 🪽';
  DateTime _lastJumpTime = DateTime.now();

  // Bird physics
  static const double _birdRadius = 18.0;
  static const double _birdX = 85.0;
  double _birdY = 260.0;
  double _birdVelocity = 0.0; // Used for smoothing now
  static const double _kMinNoseRatio = 0.25; // Top lockout
  static const double _kMaxNoseRatio = 0.55; // More forgiving depth (no need to touch ground)

  // Obstacles
  final List<_PipeObstacle> _pipes = [];
  double _timeSinceLastPipe = 0.0;
  static const double _pipeSpawnInterval = 6.0; // 6 seconds between pipes! Lots of time to do a pushup.
  static const double _pipeSpeed = 65.0; // Very slow movement
  static const double _pipeWidth = 64.0;
  static const double _pipeGap = 320.0; // Massive gap to easily fly through

  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false,
        enableLandmarks: false,
        enableClassification: false,
        enableTracking: true,
        minFaceSize: 0.1, // robust to face distance
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );

    _initCamera();
    _initGameLoop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pipes.isEmpty) {
      final screenHeight = MediaQuery.of(context).size.height;
      final screenWidth = MediaQuery.of(context).size.width;
      final groundY = screenHeight - 60.0;
      _spawnInitialPipes(screenWidth, groundY);
    }
  }

  void _spawnInitialPipes(double screenWidth, double groundY) {
    _pipes.clear();
    final double startX = screenWidth * 0.75;
    const double spacing = 280.0;
    for (int i = 0; i < 3; i++) {
      final minGap = 90.0;
      final maxGap = groundY - _pipeGap - 80.0;
      
      double prevGapTop = _pipes.isNotEmpty ? _pipes.last.gapTop : (minGap + maxGap) / 2;
      double minNext = (prevGapTop - 60.0).clamp(minGap, maxGap);
      double maxNext = (prevGapTop + 60.0).clamp(minGap, maxGap);
      
      final gapTop = minNext + _rng.nextDouble() * (maxNext - minNext);
      
      _pipes.add(_PipeObstacle(
        x: startX + (i * spacing),
        gapTop: gapTop,
        gapHeight: _pipeGap,
      ));
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _faceDetector.close();
    _poseDetector.close();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return;

    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    CameraDescription? frontCam;
    for (var c in _cameras) {
      if (c.lensDirection == CameraLensDirection.front) {
        frontCam = c;
        break;
      }
    }

    _cameraController = CameraController(
      frontCam ?? _cameras.first,
      ResolutionPreset.low,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });

      _cameraController!.startImageStream(_processCameraFrame);
    } catch (e) {
      debugPrint('Game camera error: $e');
    }
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    if (_isProcessingFrame || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    _isProcessingFrame = true;

    try {
      final camera = _cameraController!.description;
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);

      if (format == null || rotation == null) {
        _isProcessingFrame = false;
        return;
      }

      final inputImage = InputImage.fromBytes(
        bytes: image.planes.first.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);
      // Only run pose detection every few frames or strictly if we have faces, to save CPU
      // Actually running it in parallel is fine for a quick gate check
      final poses = await _poseDetector.processImage(inputImage);
      
      double? currentFaceY;
      bool faceOk = false;
      String stateText = 'Position Face';

      if (faces.isNotEmpty) {
        final face = faces.first;
        faceOk = true;
        
        final rotationInt = camera.sensorOrientation;
        
        double normalizedY;
        if (rotationInt == 270) {
          normalizedY = face.boundingBox.center.dx / image.width;
        } else if (rotationInt == 90) {
          normalizedY = 1.0 - (face.boundingBox.center.dx / image.width);
        } else {
          normalizedY = face.boundingBox.center.dy / image.height;
        }
        
        currentFaceY = normalizedY.clamp(0.0, 1.0);
        stateText = 'Face Tracking OK';

        // ── GATE CHECK: Pushup form enforcement ──
        // Only enforce the check if they are near the top of the pushup (faceY < 0.35)
        // because at the bottom, their shoulders might disappear from camera!
        if (currentFaceY < 0.35) {
          bool isPlank = false;
          if (poses.isNotEmpty) {
             final rotatedSize = Size(image.height.toDouble(), image.width.toDouble());
             final eval = _poseService.evaluatePlankPose(poses.first, rotatedSize);
             isPlank = eval.isPlank;
          }
          if (!isPlank) {
             faceOk = false;
             currentFaceY = null;
             stateText = 'Get in Pushup Position!';
          }
        }
        
        if (faceOk) {
          // Simple mock rep tracking
          if (currentFaceY! > 0.5) {
            if (!_isAscending) {
              _isAscending = true;
            }
          } else if (currentFaceY < 0.3) {
            if (_isAscending) {
              _isAscending = false;
              _triggerFlap(isRealPushup: true); // They did a rep!
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _liveNoseRatio = currentFaceY;
          _isFaceDetected = faceOk;
          _liveTrackingState = stateText;
          _coachingFeedback = faceOk ? 'Play!' : 'Move face into view';
        });
      }
    } catch (e) {
      debugPrint('Game face detection error: $e');
    }

    _isProcessingFrame = false;
  }

  /// Flap trigger: Can be initiated via real Push-Up OR via screen tap/Test Rep button
  void _triggerFlap({required bool isRealPushup}) {
    if (_isGameOver) return;

    // Start game if waiting
    if (!_isPlaying) {
      _isPlaying = true;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      if (isRealPushup) {
        _pushupCount++;
        _lastJumpText = 'PUSH-UP #$_pushupCount! 🚀';
      } else {
        _lastJumpText = 'HOLD HEIGHT! 🪽';
      }
      _lastJumpTime = DateTime.now();
    });
  }

  void _initGameLoop() {
    _ticker = createTicker(_updatePhysics)..start();
  }

  void _updatePhysics(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }

    final double dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;

    if (_isGameOver || dt <= 0 || dt > 0.1) return;

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final groundY = screenHeight - 60.0;

    setState(() {
      // 1. Idle state before first tap or push-up: bird hovers gently, pipes sit in place
      if (!_isPlaying) {
        _idleHoverTime += dt;
        _birdY = 260.0 + sin(_idleHoverTime * 3.5) * 10.0;
        _birdVelocity = 0.0;
        return;
      }

      // 2. Active Game: Analog Push-up Physics
      if (_liveNoseRatio != null) {
        double mappedY = ((_liveNoseRatio! - _kMinNoseRatio) / (_kMaxNoseRatio - _kMinNoseRatio)) * groundY;
        mappedY = mappedY.clamp(0.0, groundY);
        // Smoothly glide the bird to the mapped height
        _birdY += (mappedY - _birdY) * 8.0 * dt;
      }

      // Ground collision
      if (_birdY + _birdRadius >= groundY) {
        // Soft ground boundary, don't kill immediately unless hit pipe
        _birdY = groundY - _birdRadius;
      }

      // Ceiling collision
      if (_birdY - _birdRadius <= 0) {
        _birdY = _birdRadius;
        _birdVelocity = 0;
      }

      // 3. Move & check pipe collisions
      for (int i = _pipes.length - 1; i >= 0; i--) {
        final pipe = _pipes[i];
        pipe.x -= _pipeSpeed * dt;

        // Scoring when bird clears pipe
        if (!pipe.isScored && pipe.x + _pipeWidth < _birdX) {
          pipe.isScored = true;
          _score++;
          HapticFeedback.lightImpact();
        }

        // Pipe collision
        if (_checkPipeCollision(pipe, _birdX, _birdY, _birdRadius)) {
          _triggerGameOver();
          return;
        }

        // Remove off-screen pipe
        if (pipe.x < -_pipeWidth - 20) {
          _pipes.removeAt(i);
        }
      }

      // 4. Continuously spawn new pipes
      _timeSinceLastPipe += dt;
      if (_timeSinceLastPipe >= _pipeSpawnInterval) {
        _timeSinceLastPipe = 0;

        final minGapTop = 90.0;
        final maxGapTop = groundY - _pipeGap - 80.0;
        
        // Determine next gap strictly, allowing up to 200px variance for random up/down paths
        double prevGapTop = _pipes.isNotEmpty ? _pipes.last.gapTop : (minGapTop + maxGapTop) / 2;
        double minNext = (prevGapTop - 200.0).clamp(minGapTop, maxGapTop);
        double maxNext = (prevGapTop + 200.0).clamp(minGapTop, maxGapTop);

        final gapTop = minNext + _rng.nextDouble() * (maxNext - minNext);

        _pipes.add(_PipeObstacle(
          x: screenWidth + 20,
          gapTop: gapTop,
          gapHeight: _pipeGap,
        ));
      }
    });
  }

  bool _checkPipeCollision(_PipeObstacle pipe, double bx, double by, double br) {
    if (bx + br < pipe.x || bx - br > pipe.x + _pipeWidth) {
      return false;
    }
    // Top pipe collision
    if (by - br < pipe.gapTop) {
      return true;
    }
    // Bottom pipe collision
    if (by + br > pipe.gapTop + pipe.gapHeight) {
      return true;
    }
    return false;
  }

  void _triggerGameOver() {
    if (_isGameOver) return;
    HapticFeedback.vibrate();
    _isGameOver = true;
    _isPlaying = false;
    
    // Save stats
    if (_pushupCount > 0) {
      ProgressionService.instance.addWorkoutReps(
        athleteName: 'Player 1',
        reps: _pushupCount,
        formScore: 100,
      );
      StatsService.addWorkoutCompleted();
    }
    StatsService.updateFlappyScore(_score);
  }

  void _resetGame() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final groundY = screenHeight - 60.0;

    setState(() {
      _isGameOver = false;
      _isPlaying = false;
      _score = 0;
      _pushupCount = 0;
      _pipes.clear();
      _timeSinceLastPipe = 0.0;
      _birdY = 260.0;
      _birdVelocity = 0.0;
      _lastJumpText = '';
      _isAscending = false;
      _spawnInitialPipes(screenWidth, groundY);
      _initGameLoop();
    });
  }

  String _getEnduranceRating(int pushups) {
    if (pushups == 0) return 'Needs Practice';
    if (pushups < 5) return 'Novice';
    if (pushups < 15) return 'Intermediate';
    if (pushups < 30) return 'Advanced';
    return 'Elite Athlete 🔥';
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final groundY = screenSize.height - 60.0;

    return Scaffold(
      backgroundColor: const Color(0xFF070B19),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Arcade Game Canvas (Tap screen to flap!)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _triggerFlap(isRealPushup: false),
              child: CustomPaint(
                size: screenSize,
                painter: _GameArcadePainter(
                  birdX: _birdX,
                  birdY: _birdY,
                  birdRadius: _birdRadius,
                  birdVelocity: _birdVelocity,
                  pipes: _pipes,
                  pipeWidth: _pipeWidth,
                  groundY: groundY,
                  score: _score,
                ),
              ),
            ),

            // 2. Rep Completion Float Banner
            if (_lastJumpText.isNotEmpty &&
                DateTime.now().difference(_lastJumpTime).inMilliseconds < 1200)
              Positioned(
                top: 140,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00FF88).withValues(alpha: 0.6),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Text(
                      _lastJumpText,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),

            // 3. Top Header: Back button, Score, Push-ups
            Positioned(
              top: 10,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),

                  // Score pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFCC00), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFFFCC00), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '$_score',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Reps counter pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF00FF88), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.fitness_center, color: Color(0xFF00FF88), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '$_pushupCount REPS',
                          style: const TextStyle(
                            color: Color(0xFF00FF88),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 4. Picture-in-Picture (PiP) Selfie Camera Preview with Live Skeletons
            Positioned(
              top: 66,
              right: 14,
              child: Container(
                width: 125,
                height: 165,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isFaceDetected ? const Color(0xFF00FF88) : Colors.white30,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_isCameraInitialized && _cameraController != null) ...[
                        FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _cameraController!.value.previewSize?.height ?? 125,
                            height: _cameraController!.value.previewSize?.width ?? 165,
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                      ] else
                        const Center(
                          child: CircularProgressIndicator(color: Color(0xFF00FF88), strokeWidth: 2),
                        ),

                      // Live Coaching Feedback Pill at bottom of PiP
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                          color: Colors.black.withValues(alpha: 0.8),
                          child: Text(
                            _coachingFeedback,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _isFaceDetected ? const Color(0xFF00FF88) : Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 5. LIVE TRACKING DIAGNOSTIC GAUGE (Shows user exact nose position & lockout/depth lines!)
            Positioned(
              top: 66,
              left: 14,
              child: Container(
                width: 140,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.face,
                          size: 14,
                          color: _isFaceDetected ? const Color(0xFF00FF88) : Colors.white38,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isFaceDetected ? 'Face OK ✓' : 'Looking for face',
                          style: TextStyle(
                            color: _isFaceDetected ? const Color(0xFF00FF88) : Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Vertical Depth Meter
                    Row(
                      children: [
                        // The track gauge
                        Container(
                          width: 14,
                          height: 65,
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              // Top Lockout Line at 35%
                              Positioned(
                                top: 65 * 0.35,
                                left: 0,
                                right: 0,
                                child: Container(height: 2, color: const Color(0xFF00FF88)),
                              ),
                              // Bottom Depth Cutoff Line at 65%
                              Positioned(
                                top: 65 * 0.65,
                                left: 0,
                                right: 0,
                                child: Container(height: 2, color: const Color(0xFFFFCC00)),
                              ),
                              // Real-time Nose Marker
                              if (_liveNoseRatio != null)
                                Positioned(
                                  top: (65 * _liveNoseRatio!).clamp(0.0, 57.0),
                                  child: Container(
                                    width: 12,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: const [
                                        BoxShadow(color: Colors.cyan, blurRadius: 4),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Gauge text labels
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('▲ 35% Top', style: TextStyle(color: Color(0xFF00FF88), fontSize: 9)),
                              const SizedBox(height: 14),
                              const Text('▼ 65% Depth', style: TextStyle(color: Color(0xFFFFCC00), fontSize: 9)),
                              const SizedBox(height: 6),
                              Text(
                                _liveNoseRatio != null ? 'Nose: ${(_liveNoseRatio! * 100).toInt()}%' : 'Nose: --',
                                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Tracking state pill
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _liveTrackingState,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 6. "🧪 SIMULATE REP (TEST)" BUTTON & TAP HINT
            Positioned(
              bottom: 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  // Test Button for immediate zero-effort testing!
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _triggerFlap(isRealPushup: true),
                      icon: const Icon(Icons.science, size: 18, color: Colors.black),
                      label: const Text(
                        '🧪 TEST REP (+1 FLAP)',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF88),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 7. Start Game Hint Banner (before first pushup/tap)
            if (!_isPlaying && !_isGameOver)
              Positioned(
                bottom: 70,
                left: 24,
                right: 24,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF00FF88), width: 1.5),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app, color: Color(0xFF00FF88), size: 28),
                        SizedBox(height: 6),
                        Text(
                          'TAP SCREEN OR DO PUSH-UP TO FLY!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Pillars are ahead. Each push-up or tap lifts the bird!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 8. Game Over Overlay (Apple Aesthetic)
            if (_isGameOver)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.05),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E).withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Game Over',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Endurance Rating
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _pushupCount >= 15 ? const Color(0xFFFFCC00).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _pushupCount >= 15 ? const Color(0xFFFFCC00) : Colors.white24),
                              ),
                              child: Text(
                                'Endurance Rating: ${_getEnduranceRating(_pushupCount)}',
                                style: TextStyle(
                                  color: _pushupCount >= 15 ? const Color(0xFFFFCC00) : Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Score breakdown
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatCard('Pipes', '$_score', Colors.white),
                                Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.1)),
                                _buildStatCard('Push-ups', '$_pushupCount', const Color(0xFF34C759)),
                              ],
                            ),
                            const SizedBox(height: 32),

                            // Try Again Button
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _resetGame,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text(
                                  'Play Again',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Exit Button
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white54,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text('Exit to Menu', style: TextStyle(fontSize: 15)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(color: color, fontSize: 30, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _PipeObstacle {
  double x;
  final double gapTop;
  final double gapHeight;
  bool isScored = false;

  _PipeObstacle({
    required this.x,
    required this.gapTop,
    required this.gapHeight,
  });
}

/// CustomPainter that renders cyber arcade sky, scrolling neon pipes (top and bottom), ground, and the bird
class _GameArcadePainter extends CustomPainter {
  final double birdX;
  final double birdY;
  final double birdRadius;
  final double birdVelocity;
  final List<_PipeObstacle> pipes;
  final double pipeWidth;
  final double groundY;
  final int score;

  _GameArcadePainter({
    required this.birdX,
    required this.birdY,
    required this.birdRadius,
    required this.birdVelocity,
    required this.pipes,
    required this.pipeWidth,
    required this.groundY,
    required this.score,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Background gradient (Cyber Arcade Sky)
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF060914),
          Color(0xFF101935),
          Color(0xFF1B1842),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Render Obstacle Pipes (Top and Bottom pillars)
    final pipeBodyPaint = Paint()
      ..color = const Color(0xFF00897B)
      ..style = PaintingStyle.fill;

    final pipeCapPaint = Paint()
      ..color = const Color(0xFF26A69A)
      ..style = PaintingStyle.fill;

    final pipeBorderPaint = Paint()
      ..color = const Color(0xFF80CBC4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final pipe in pipes) {
      // Top Pipe (coming down from ceiling to gapTop)
      if (pipe.gapTop > 0) {
        final topRect = Rect.fromLTWH(pipe.x, 0, pipeWidth, pipe.gapTop);
        final topCapRect = Rect.fromLTWH(pipe.x - 4, pipe.gapTop - 24, pipeWidth + 8, 24);

        canvas.drawRect(topRect, pipeBodyPaint);
        canvas.drawRect(topRect, pipeBorderPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(topCapRect, const Radius.circular(4)), pipeCapPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(topCapRect, const Radius.circular(4)), pipeBorderPaint);
      }

      // Bottom Pipe (coming up from gapTop + gapHeight to ground)
      final bottomTop = pipe.gapTop + pipe.gapHeight;
      final bottomHeight = groundY - bottomTop;
      if (bottomHeight > 0) {
        final bottomRect = Rect.fromLTWH(pipe.x, bottomTop, pipeWidth, bottomHeight);
        final bottomCapRect = Rect.fromLTWH(pipe.x - 4, bottomTop, pipeWidth + 8, 24);

        canvas.drawRect(bottomRect, pipeBodyPaint);
        canvas.drawRect(bottomRect, pipeBorderPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(bottomCapRect, const Radius.circular(4)), pipeCapPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(bottomCapRect, const Radius.circular(4)), pipeBorderPaint);
      }
    }

    // 3. Ground Line
    final groundPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRect(Rect.fromLTWH(0, groundY, size.width, size.height - groundY), groundPaint);

    final groundLinePaint = Paint()
      ..color = const Color(0xFF00FF88)
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(0, groundY), Offset(size.width, groundY), groundLinePaint);

    // 4. Render Bird / Phoenix
    canvas.save();
    canvas.translate(birdX, birdY);

    final double tilt = (birdVelocity / 600.0).clamp(-0.5, 1.0);
    canvas.rotate(tilt);

    // Bird glow
    final glowPaint = Paint()
      ..color = const Color(0xFFFFCC00).withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset.zero, birdRadius + 4, glowPaint);

    // Bird body
    final birdBodyPaint = Paint()..color = const Color(0xFFFFCC00);
    canvas.drawCircle(Offset.zero, birdRadius, birdBodyPaint);

    // Wing
    final wingPaint = Paint()..color = const Color(0xFFFF9900);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-4, 2), width: 16, height: 10),
      wingPaint,
    );

    // Eye
    final eyePaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(7, -5), 5, eyePaint);
    final pupilPaint = Paint()..color = Colors.black;
    canvas.drawCircle(const Offset(9, -5), 2.5, pupilPaint);

    // Beak
    final beakPaint = Paint()..color = const Color(0xFFFF5722);
    final beakPath = Path()
      ..moveTo(12, -2)
      ..lineTo(22, 2)
      ..lineTo(12, 6)
      ..close();
    canvas.drawPath(beakPath, beakPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GameArcadePainter oldDelegate) {
    return true;
  }
}
