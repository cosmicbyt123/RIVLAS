import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/pose_service.dart';
import '../services/multi_pose_tracker.dart';
import '../services/progression_service.dart';
import '../painters/pose_painter.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _availableCameras = [];
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;
  bool _isDetecting = false;
  bool _isTorchOn = false;
  String _statusMessage = 'Starting camera...';

  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );

  final MultiPoseTracker _multiTracker = MultiPoseTracker();
  List<PlayerTrack> _trackedPlayers = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadCamerasAndInit();
  }

  Future<void> _loadCamerasAndInit() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) setState(() => _statusMessage = 'Camera permission required for AI tracking');
      return;
    }

    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        if (mounted) setState(() => _statusMessage = 'No cameras found on device');
        return;
      }

      _selectedCameraIndex = _availableCameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;

      await _initCurrentCamera();
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'Camera initialization error: $e');
    }
  }

  Future<void> _initCurrentCamera() async {
    final camera = _availableCameras[_selectedCameraIndex];

    final prev = _controller;
    if (prev != null) {
      await prev.stopImageStream().catchError((_) {});
      await prev.dispose();
    }

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    try {
      await _controller!.initialize();
      _isTorchOn = false;
      await _controller!.startImageStream(_processFrame);
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _trackedPlayers = _multiTracker.allPlayers;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'Camera error: $e');
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isDetecting || _controller == null || !_controller!.value.isInitialized) return;
    _isDetecting = true;

    try {
      final camera = _controller!.description;
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

      final bool isRotated = rotation == InputImageRotation.rotation90deg ||
          rotation == InputImageRotation.rotation270deg;
      final Size rotatedSize = isRotated
          ? Size(image.height.toDouble(), image.width.toDouble())
          : Size(image.width.toDouble(), image.height.toDouble());

      final updatedPlayers = _multiTracker.processFramePoses(poses, rotatedSize);

      // Check haptics for newly completed reps across all active athletes
      for (final p in updatedPlayers) {
        if (p.lastAnalysis?.repJustCompleted == true) {
          HapticFeedback.mediumImpact();
        }
      }

      if (mounted) {
        setState(() => _trackedPlayers = updatedPlayers);
      }
    } catch (e) {
      debugPrint('Frame processing error: $e');
    }

    _isDetecting = false;
  }

  Future<void> _toggleTorch() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final next = !_isTorchOn;
      await _controller!.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      setState(() => _isTorchOn = next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Torch is only supported on the back camera'),
          duration: Duration(seconds: 1),
          backgroundColor: Color(0xFF1E293B),
        ),
      );
    }
  }

  Future<void> _flipCamera() async {
    if (_availableCameras.length < 2) return;
    setState(() => _isInitialized = false);
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    await _initCurrentCamera();
  }

  void _toggleTrackingMode() {
    setState(() {
      if (_multiTracker.mode == TrackingMode.sideProfile) {
        _multiTracker.mode = TrackingMode.frontFloor;
      } else if (_multiTracker.mode == TrackingMode.frontFloor) {
        _multiTracker.mode = TrackingMode.selfieCamera;
      } else {
        _multiTracker.mode = TrackingMode.sideProfile;
      }
    });

    IconData modeIcon;
    String modeText;
    switch (_multiTracker.mode) {
      case TrackingMode.sideProfile:
        modeIcon = Icons.stay_current_landscape;
        modeText = 'Side Profile Mode (Phone to the side)';
        break;
      case TrackingMode.frontFloor:
        modeIcon = Icons.phone_android;
        modeText = 'Front Floor Mode (Phone on the floor)';
        break;
      case TrackingMode.selfieCamera:
        modeIcon = Icons.face_rounded;
        modeText = 'Selfie Mode (Phone against wall)';
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(modeIcon, color: const Color(0xFFFFCC00), size: 18),
            const SizedBox(width: 8),
            Text(modeText, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }

  void _showEditNameDialog(int playerIndex) {
    if (playerIndex >= _trackedPlayers.length) return;
    final player = _trackedPlayers[playerIndex];
    final controller = TextEditingController(text: player.name);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: player.themeColor.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: player.themeColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Rename Athlete (Player ${player.id})',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Enter athlete name...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: player.themeColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: player.themeColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _multiTracker.setPlayerName(playerIndex, controller.text));
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: player.themeColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Save Athlete Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWorkoutSummaryDialog() {
    final active = _trackedPlayers.where((p) => p.repCount > 0 || p.isPresent).toList();
    if (active.isEmpty) return;

    int selectedAthleteIndex = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Dialog(
            backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: const Color(0xFFFFCC00).withValues(alpha: 0.4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.terrain_rounded, color: Color(0xFFFFCC00), size: 50),
                  const SizedBox(height: 10),
                  const Text(
                    'Workout Complete!',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    active.length >= 2 
                        ? 'Select athlete to credit for Mountain Climb:'
                        : 'Your push-ups will power your Mountain Climb!',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(active.length, (i) {
                    final p = active[i];
                    final isSelected = selectedAthleteIndex == i;

                    return GestureDetector(
                      onTap: () {
                        setDialogState(() => selectedAthleteIndex = i);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? p.themeColor.withValues(alpha: 0.15)
                              : const Color(0xFF1E293B).withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? p.themeColor : Colors.white12,
                            width: isSelected ? 2.0 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: p.themeColor.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.person,
                                color: p.themeColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Form: ${p.formScore ?? 100}% • +${(p.repCount * 5)}m Climb',
                                    style: TextStyle(color: p.themeColor, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${p.repCount}',
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(width: 4),
                            const Text('reps', style: TextStyle(color: Colors.white60, fontSize: 11)),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final chosen = active[selectedAthleteIndex];
                        // Credit reps to 3D Mountain Progression
                        ProgressionService.instance.addWorkoutReps(
                          athleteName: chosen.name,
                          reps: chosen.repCount,
                          formScore: chosen.formScore ?? 100,
                        );

                        _multiTracker.resetAll();
                        setState(() {});
                        Navigator.pop(ctx); // Close dialog
                        Navigator.pop(context); // Return to main tabs to watch mountain climb!
                      },
                      icon: const Icon(Icons.hiking_rounded, size: 20),
                      label: const Text(
                        'Upload & Climb Mountain 🏔️',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFCC00),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.stopImageStream().catchError((_) {});
    _controller?.dispose();
    _poseDetector.close();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isInitialized ? _buildCameraUI() : _buildLoading(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.8),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFCC00).withValues(alpha: 0.5)),
            ),
            child: const CircularProgressIndicator(color: Color(0xFFFFCC00), strokeWidth: 3),
          ),
          const SizedBox(height: 20),
          Text(
            _statusMessage,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraUI() {
    final bool isFrontCamera = _controller?.description.lensDirection == CameraLensDirection.front;

    final previewSize = _controller!.value.previewSize;
    final double previewW = previewSize?.height ?? MediaQuery.of(context).size.width;
    final double previewH = previewSize?.width ?? MediaQuery.of(context).size.height;

    // Determine active visible players
    final activePlayers = _trackedPlayers.where((p) => p.currentPose != null || p.repCount > 0).toList();
    final bool isMultiplayer = activePlayers.length >= 2;

    return Stack(
      children: [
        // 1. Live Camera Preview (Exact BoxFit.cover fill)
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: previewW,
              height: previewH,
              child: CameraPreview(_controller!),
            ),
          ),
        ),

        // 2. Multi-Person Glowing Skeletons + AR Nametags
        CustomPaint(
          painter: PosePainter(
            players: _trackedPlayers,
            imageSize: Size(previewW, previewH),
            isFrontCamera: isFrontCamera,
          ),
          child: const SizedBox.expand(),
        ),

        // Dark Atmospheric Vignette
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.65),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.8),
                ],
                stops: const [0.0, 0.18, 0.72, 1.0],
              ),
            ),
          ),
        ),

        // 3. Frosted Glass Top Bar
        Positioned(
          top: 48,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back Button
              _glassCircleButton(
                icon: Icons.arrow_back_ios_new_rounded,
                size: 18,
                onTap: () => Navigator.pop(context),
              ),

              // Mode Capsule
              GestureDetector(
                onTap: _toggleTrackingMode,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFFFCC00).withValues(alpha: 0.6), width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _multiTracker.mode == TrackingMode.sideProfile
                                ? Icons.stay_current_landscape
                                : _multiTracker.mode == TrackingMode.frontFloor
                                    ? Icons.phone_android
                                    : Icons.face_rounded,
                            color: const Color(0xFFFFCC00),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _multiTracker.mode == TrackingMode.sideProfile
                                ? 'Side Mode'
                                : _multiTracker.mode == TrackingMode.frontFloor
                                    ? 'Floor Mode'
                                    : 'Selfie Mode',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.swap_horiz_rounded, color: Colors.white70, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Action Utilities (Swap Slots, Torch, Flip Camera)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_trackedPlayers.length >= 2)
                    _glassCircleButton(
                      icon: Icons.swap_calls_rounded,
                      size: 20,
                      tooltip: 'Swap Athlete Slots',
                      onTap: () => setState(() => _multiTracker.swapPlayers(0, 1)),
                    ),
                  if (_trackedPlayers.length >= 2) const SizedBox(width: 6),
                  _glassCircleButton(
                    icon: _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    iconColor: _isTorchOn ? const Color(0xFFFFCC00) : Colors.white70,
                    size: 20,
                    onTap: _toggleTorch,
                  ),
                  const SizedBox(width: 6),
                  _glassCircleButton(
                    icon: Icons.flip_camera_ios_rounded,
                    size: 20,
                    onTap: _flipCamera,
                  ),
                ],
              ),
            ],
          ),
        ),

        // 4. Adaptive Telemetry HUD: Solo Mode vs Rivals Multi-Player Duel
        Positioned(
          top: 112,
          left: 16,
          right: 16,
          child: isMultiplayer
              ? _buildMultiplayerHUD(activePlayers)
              : _buildSoloHUD(_trackedPlayers.first),
        ),

        // 5. Dynamic Movement Coaching Feedback Banner
        Positioned(
          bottom: 124,
          left: 20,
          right: 20,
          child: _buildCoachingBanner(_trackedPlayers.first),
        ),

        // 6. Bottom Glass Action Dock (Reset & Finish Workout)
        Positioned(
          bottom: 38,
          left: 20,
          right: 20,
          child: Row(
            children: [
              // Reset Button
              _glassActionBtn(
                icon: Icons.refresh_rounded,
                label: 'Reset',
                onTap: () {
                  _multiTracker.resetAll();
                  setState(() {});
                },
              ),
              const SizedBox(width: 12),
              // Submit Workout Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _trackedPlayers.any((p) => p.repCount > 0)
                      ? _showWorkoutSummaryDialog
                      : null,
                  icon: const Icon(Icons.check_circle_rounded, size: 22),
                  label: const Text(
                    'Finish & Submit',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFCC00),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white12,
                    disabledForegroundColor: Colors.white30,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Solo Athlete Floating Glass HUD (Clean, no 'Player 1' clutter)
  Widget _buildSoloHUD(PlayerTrack player) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: player.themeColor.withValues(alpha: 0.35), width: 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${player.repCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 78,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                  ),
                ),
                const SizedBox(height: 6),
                if (player.formScore != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: player.themeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: player.themeColor),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Form: ${player.formScore}%',
                          style: TextStyle(color: player.themeColor, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFCC00)),
                      ),
                      const SizedBox(width: 6),
                      const Text('Ready', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Multiplayer Rivals Dual Split Glass HUD
  Widget _buildMultiplayerHUD(List<PlayerTrack> players) {
    return Row(
      children: [
        for (int i = 0; i < players.take(2).length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: players[i].themeColor.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _showEditNameDialog(i),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                players[i].name,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.edit_rounded, color: Colors.white38, size: 12),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${players[i].repCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        players[i].formScore != null ? 'Form: ${players[i].formScore}%' : 'Ready',
                        style: TextStyle(
                          color: players[i].themeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Dynamic Coaching Pill
  Widget _buildCoachingBanner(PlayerTrack player) {
    final state = player.lastAnalysis?.repState;
    final isGoodForm = player.isGoodForm;

    Color bannerColor = const Color(0xFF0F172A).withValues(alpha: 0.85);
    if (!isGoodForm) {
      bannerColor = const Color(0xFFEF4444).withValues(alpha: 0.9);
    } else if (state == RepState.bottom) {
      bannerColor = const Color(0xFF10B981).withValues(alpha: 0.9);
    } else if (state == RepState.descending) {
      bannerColor = const Color(0xFFF59E0B).withValues(alpha: 0.9);
    } else if (state == RepState.ascending) {
      bannerColor = const Color(0xFF2563EB).withValues(alpha: 0.9);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: bannerColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isGoodForm ? Icons.fitness_center_rounded : Icons.warning_amber_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  player.feedback,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
    double size = 20,
    String? tooltip,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.75),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, color: iconColor, size: size),
          ),
        ),
      ),
    );
  }

  Widget _glassActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white70, size: 20),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}