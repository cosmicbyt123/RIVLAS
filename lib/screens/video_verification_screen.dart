import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/rivals_theme.dart';
import '../services/rivals_app_state.dart';
import '../services/squat_tracker_service.dart';

class VideoVerificationScreen extends StatefulWidget {
  final String exerciseTitle;
  final bool isChallengeMode;

  const VideoVerificationScreen({
    super.key,
    this.exerciseTitle = 'Squat',
    this.isChallengeMode = false,
  });

  @override
  State<VideoVerificationScreen> createState() => _VideoVerificationScreenState();
}

class _VideoVerificationScreenState extends State<VideoVerificationScreen>
    with SingleTickerProviderStateMixin {
  // Camera & ML Kit
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraReady = false;
  bool _isDetecting = false;
  bool _useRealCamera = true;
  Pose? _latestPose;
  Size _cameraImageSize = Size.zero;

  late PoseDetector _poseDetector;
  final SquatTrackerService _squatTracker = SquatTrackerService();

  // Biomechanics & Telemetry State
  late AnimationController _animationController;
  late String _currentExercise;
  int _repCount = 0;
  int _formScore = 95;
  double _depth = 175.0; // In degrees for squats (90° = parallel)
  int _rom = 92;
  double _tempo = 2.4;
  bool _isVerified = true;
  bool _flashGreen = false;
  String _coachingFeedback = 'Position full body in camera frame';

  @override
  void initState() {
    super.initState();
    _currentExercise = widget.exerciseTitle;
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _animationController.addListener(() {
      if (!_isCameraReady || !_useRealCamera) {
        // Telemetry in simulation mode
        final val = _animationController.value;
        if (mounted) {
          setState(() {
            _depth = 175.0 - (val * 90.0); // 175° down to 85° (deep parallel)
            _rom = (val * 100).toInt();
            _tempo = 2.0 + (val * 1.5);
          });
        }
      }
    });

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _useRealCamera = false;
            _coachingFeedback = 'Camera permission needed. Using AI Simulation.';
          });
        }
        return;
      }

      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        if (mounted) {
          setState(() {
            _useRealCamera = false;
            _coachingFeedback = 'No physical camera detected. Using AI Simulation.';
          });
        }
        return;
      }

      // Default to front camera for workout selfies
      _selectedCameraIndex = _availableCameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;

      await _startCameraStream();
    } catch (e) {
      if (mounted) {
        setState(() {
          _useRealCamera = false;
          _coachingFeedback = 'Camera fallback: $e';
        });
      }
    }
  }

  Future<void> _startCameraStream() async {
    if (_availableCameras.isEmpty) return;

    final camera = _availableCameras[_selectedCameraIndex];
    final prev = _cameraController;
    if (prev != null) {
      await prev.stopImageStream().catchError((_) {});
      await prev.dispose();
    }

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    try {
      await _cameraController!.initialize();
      await _cameraController!.startImageStream(_onCameraFrame);
      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _useRealCamera = true;
          _coachingFeedback = 'Ready! Step back so full body is visible';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _useRealCamera = false;
          _coachingFeedback = 'Camera error: $e';
        });
      }
    }
  }

  void _flipCamera() async {
    if (_availableCameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    await _startCameraStream();
  }

  Future<void> _onCameraFrame(CameraImage image) async {
    if (_isDetecting || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    _isDetecting = true;

    try {
      final camera = _cameraController!.description;
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);

      if (format == null || rotation == null) {
        _isDetecting = false;
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

      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isNotEmpty && mounted) {
        final pose = poses.first;
        final bool isRotated = rotation == InputImageRotation.rotation90deg ||
            rotation == InputImageRotation.rotation270deg;
        final rotatedSize = isRotated
            ? Size(image.height.toDouble(), image.width.toDouble())
            : Size(image.width.toDouble(), image.height.toDouble());

        // Process real squat biomechanics
        final squatResult = _squatTracker.processPose(pose);

        if (squatResult.repJustCompleted) {
          HapticFeedback.heavyImpact();
          _flashGreen = true;
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) setState(() => _flashGreen = false);
          });
        }

        setState(() {
          _latestPose = pose;
          _cameraImageSize = rotatedSize;
          _repCount = squatResult.repCount;
          _depth = squatResult.kneeAngle;
          _rom = squatResult.romPercentage;
          _tempo = squatResult.tempoSeconds;
          _formScore = squatResult.formScore;
          _coachingFeedback = squatResult.feedback;
          _isVerified = squatResult.isGoodForm;
        });
      }
    } catch (_) {
    } finally {
      _isDetecting = false;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cameraController?.stopImageStream().catchError((_) {});
    _cameraController?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  void _triggerSimulatedRep() {
    setState(() {
      _repCount++;
      _formScore = min(99, _formScore + 1);
      _flashGreen = true;
      _isVerified = true;
      _coachingFeedback = 'Parallel Squat Verified! (86° depth)';
    });

    HapticFeedback.mediumImpact();

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _flashGreen = false);
    });
  }

  void _finishSet() {
    final state = RivalsAppState.instance;
    state.recordCompletedSet(
      reps: max(1, _repCount),
      formScore: _formScore,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: RivalsTheme.surfaceHighlight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: RivalsTheme.neonLime, width: 1.5),
        ),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: RivalsTheme.neonLime),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Set Completed! $_repCount Verified Reps (+150 XP)',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Live Camera Preview or AI Simulated Lifter
            Positioned.fill(
              child: _useRealCamera && _isCameraReady && _cameraController != null
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _cameraController!.value.previewSize?.height ?? 720,
                        height: _cameraController!.value.previewSize?.width ?? 1280,
                        child: CameraPreview(_cameraController!),
                      ),
                    )
                  : AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _flashGreen
                              ? [
                                  RivalsTheme.neonLime.withValues(alpha: 0.35),
                                  Colors.black,
                                ]
                              : [
                                  const Color(0xFF131A13),
                                  const Color(0xFF090C09),
                                  Colors.black,
                                ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: CustomPaint(
                        painter: _AiAthletePosePainter(
                          animationValue: _animationController.value,
                          isGoodForm: _isVerified,
                        ),
                      ),
                    ),
            ),

            // Live Pose Skeleton Overlay (when on camera)
            if (_useRealCamera && _latestPose != null && _cameraImageSize != Size.zero)
              Positioned.fill(
                child: CustomPaint(
                  painter: _LivePoseSkeletonPainter(
                    pose: _latestPose!,
                    imageSize: _cameraImageSize,
                    isFrontCamera: _availableCameras.isNotEmpty &&
                        _availableCameras[_selectedCameraIndex].lensDirection ==
                            CameraLensDirection.front,
                  ),
                ),
              ),

            // Subtle scanlines & corner brackets
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ScanlineGridPainter(),
                ),
              ),
            ),

            // 2. Top Header Navigation Bar
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        widget.isChallengeMode ? 'CHALLENGE VERIFICATION' : 'AI VIDEO VERIFICATION',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        '$_currentExercise • Depth & Lockout',
                        style: const TextStyle(
                          color: RivalsTheme.neonLime,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (_availableCameras.length > 1)
                        GestureDetector(
                          onTap: _flipCamera,
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white12),
                            ),
                            child: const Icon(Icons.flip_camera_ios_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      GestureDetector(
                        onTap: () => _showInfoSheet(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Icon(Icons.help_outline_rounded,
                              color: Colors.white70, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 3. Status Badges Row (Rep Counter & Verified Tag)
            Positioned(
              top: 72,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left Pill: Rep Counter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Valid Reps: ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$_repCount',
                          style: const TextStyle(
                            color: RivalsTheme.neonLime,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right Pill: Camera / Sim Mode Toggle
                  GestureDetector(
                    onTap: () {
                      setState(() => _useRealCamera = !_useRealCamera);
                      if (_useRealCamera && !_isCameraReady) {
                        _initCamera();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _useRealCamera
                            ? RivalsTheme.neonLime.withValues(alpha: 0.2)
                            : RivalsTheme.surfaceHighlight,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: _useRealCamera ? RivalsTheme.neonLime : Colors.white24,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _useRealCamera ? Icons.camera_alt_rounded : Icons.smart_toy_rounded,
                            color: _useRealCamera ? RivalsTheme.neonLime : Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _useRealCamera ? 'Live Camera' : 'Simulator',
                            style: TextStyle(
                              color: _useRealCamera ? RivalsTheme.neonLime : Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 4. Center Coaching Cue Banner
            Positioned(
              top: 130,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _depth <= 95 ? RivalsTheme.neonLime : Colors.white12,
                    ),
                  ),
                  child: Text(
                    _coachingFeedback,
                    style: TextStyle(
                      color: _depth <= 95 ? RivalsTheme.neonLime : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

            // Tap on lifter (simulator test button)
            if (!_useRealCamera)
              Positioned(
                top: 190,
                bottom: 230,
                left: 30,
                right: 30,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _triggerSimulatedRep,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: RivalsTheme.neonLime.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: RivalsTheme.neonLime),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app_rounded, color: RivalsTheme.neonLime, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Tap to Simulate Verified Rep',
                                style: TextStyle(
                                  color: RivalsTheme.neonLime,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 5. Bottom Telemetry & Finish Set Button
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F140F).withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: Colors.white10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Telemetry Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildTelemetryItem(
                          value: '${_depth.toInt()}°',
                          label: _depth <= 95 ? 'Parallel Depth ✓' : 'Knee Angle',
                          statusColor: _depth <= 95 ? RivalsTheme.neonLime : Colors.white,
                        ),
                        Container(width: 1, height: 28, color: Colors.white10),
                        _buildTelemetryItem(
                          value: '$_rom%',
                          label: 'Full ROM',
                          statusColor: RivalsTheme.neonLime,
                        ),
                        Container(width: 1, height: 28, color: Colors.white10),
                        _buildTelemetryItem(
                          value: '${_tempo.toStringAsFixed(1)}s',
                          label: 'Tempo Pace',
                          statusColor: RivalsTheme.neonLime,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Finish Set Action Button
                    GestureDetector(
                      onTap: _finishSet,
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          color: RivalsTheme.neonLime,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: RivalsTheme.neonLime.withValues(alpha: 0.4),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _repCount > 0 ? 'FINISH SET ($_repCount REPS)' : 'FINISH SET',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryItem({
    required String value,
    required String label,
    required Color statusColor,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: statusColor,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: RivalsTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_rounded, color: RivalsTheme.neonLime, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'AI Squat & Pose Biomechanics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'How the AI validates your Squats:\n'
                '• 3D Hip-Knee-Ankle Angle is measured every frame (30-60 FPS)\n'
                '• Parallel Depth: Knee angle must reach 90° or lower (hip crease level with knee)\n'
                '• Stand Up: Must fully extend hips and knees (>155°) to complete each rep\n'
                '• Tempo: Controlled eccentric descent and explosive ascent\n\n'
                'Place your phone 2-3 meters away with full body visible.',
                style: TextStyle(color: Colors.white70, height: 1.4, fontSize: 13),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: RivalsTheme.surfaceHighlight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: RivalsTheme.neonLime),
                  ),
                  child: const Center(
                    child: Text(
                      'GOT IT',
                      style: TextStyle(
                        color: RivalsTheme.neonLime,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Painter that draws live Google ML Kit Pose Skeleton on top of real camera feed
class _LivePoseSkeletonPainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final bool isFrontCamera;

  _LivePoseSkeletonPainter({
    required this.pose,
    required this.imageSize,
    required this.isFrontCamera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width == 0 || imageSize.height == 0) return;

    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    Offset landmarkToOffset(PoseLandmarkType type) {
      final lm = pose.landmarks[type];
      if (lm == null) return Offset.zero;

      double x = lm.x * scaleX;
      if (isFrontCamera) {
        // Mirror for selfie camera
        x = size.width - x;
      }
      final double y = lm.y * scaleY;
      return Offset(x, y);
    }

    final bonePaint = Paint()
      ..color = RivalsTheme.neonLime.withValues(alpha: 0.9)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = RivalsTheme.neonLime.withValues(alpha: 0.35)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    final jointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final jointRingPaint = Paint()
      ..color = RivalsTheme.neonLime
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    void drawBone(PoseLandmarkType a, PoseLandmarkType b) {
      final p1 = landmarkToOffset(a);
      final p2 = landmarkToOffset(b);
      if (p1 != Offset.zero && p2 != Offset.zero) {
        canvas.drawLine(p1, p2, glowPaint);
        canvas.drawLine(p1, p2, bonePaint);
      }
    }

    // Connect skeleton bones
    drawBone(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    drawBone(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    drawBone(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    drawBone(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    drawBone(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

    drawBone(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    drawBone(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    drawBone(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

    // Legs for Squats!
    drawBone(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    drawBone(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    drawBone(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    drawBone(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

    // Draw Joint Nodes
    final keyJoints = [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];

    for (final j in keyJoints) {
      final pt = landmarkToOffset(j);
      if (pt != Offset.zero) {
        canvas.drawCircle(pt, 5.0, jointPaint);
        canvas.drawCircle(pt, 7.0, jointRingPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LivePoseSkeletonPainter oldDelegate) {
    return oldDelegate.pose != pose;
  }
}

/// Fallback Simulated AI Athlete Skeleton
class _AiAthletePosePainter extends CustomPainter {
  final double animationValue;
  final bool isGoodForm;

  _AiAthletePosePainter({
    required this.animationValue,
    required this.isGoodForm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height * 0.42;

    // Movement delta for squat cycle (hips and torso dipping down and up)
    final dipY = animationValue * 55.0;

    final skeletonPaint = Paint()
      ..color = (isGoodForm ? RivalsTheme.neonLime : Colors.redAccent).withValues(alpha: 0.9)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = (isGoodForm ? RivalsTheme.neonLime : Colors.redAccent).withValues(alpha: 0.35)
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round;

    final jointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final jointRingPaint = Paint()
      ..color = isGoodForm ? RivalsTheme.neonLime : Colors.redAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final barY = centerY - 110 + dipY;

    // Pose Keypoints
    final head = Offset(centerX, barY - 26);
    final neck = Offset(centerX, barY - 6);
    final leftShoulder = Offset(centerX - 42, barY + 12);
    final rightShoulder = Offset(centerX + 42, barY + 12);

    final midHip = Offset(centerX, centerY + 30 + (dipY * 1.3));
    final leftHip = Offset(centerX - 35, midHip.dy);
    final rightHip = Offset(centerX + 35, midHip.dy);

    final leftKnee = Offset(centerX - 70, centerY + 115 + (dipY * 0.5));
    final rightKnee = Offset(centerX + 70, centerY + 115 + (dipY * 0.5));

    final leftAnkle = Offset(centerX - 65, centerY + 185);
    final rightAnkle = Offset(centerX + 65, centerY + 185);

    // Draw Skeleton Lines
    final lines = [
      [leftShoulder, rightShoulder],
      [neck, midHip],
      [leftShoulder, leftHip],
      [rightShoulder, rightHip],
      [leftHip, rightHip],
      [leftHip, leftKnee],
      [leftKnee, leftAnkle],
      [rightHip, rightKnee],
      [rightKnee, rightAnkle],
    ];

    for (final line in lines) {
      canvas.drawLine(line[0], line[1], glowPaint);
      canvas.drawLine(line[0], line[1], skeletonPaint);
    }

    // Draw Head
    canvas.drawCircle(head, 18, Paint()..color = const Color(0xFF222822));
    canvas.drawCircle(
      head,
      18,
      Paint()
        ..color = RivalsTheme.neonLime.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Draw Joints
    final joints = [
      head,
      neck,
      leftShoulder,
      rightShoulder,
      leftHip,
      rightHip,
      leftKnee,
      rightKnee,
      leftAnkle,
      rightAnkle,
    ];

    for (final j in joints) {
      canvas.drawCircle(j, 5.0, jointPaint);
      canvas.drawCircle(j, 6.5, jointRingPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AiAthletePosePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isGoodForm != isGoodForm;
  }
}

/// Stylized camera scanlines
class _ScanlineGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..strokeWidth = 1.0;

    for (double y = 0; y < size.height; y += 8) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Corner brackets
    final cornerPaint = Paint()
      ..color = RivalsTheme.neonLime.withValues(alpha: 0.4)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const pad = 24.0;
    const len = 20.0;

    canvas.drawLine(const Offset(pad, pad), const Offset(pad + len, pad), cornerPaint);
    canvas.drawLine(const Offset(pad, pad), const Offset(pad, pad + len), cornerPaint);

    canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad - len, pad), cornerPaint);
    canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad, pad + len), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
