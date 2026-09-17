import 'dart:async';
import 'dart:math';

enum BotLevel {
  beginner,
  intermediate,
  advanced,
}

enum BotPushupPhase {
  lockout,
  descending,
  bottom,
  ascending,
  resting,
  finished, // Bot has "submitted" and is done
}

/// Simulated AI Rival that acts like a real human player.
///
/// The bot picks a random rep target (4, 6, 8, 10, or rarely 15),
/// performs push-ups at a realistic pace with fatigue pauses, then
/// "submits" and waits for the user to finish.
class PrototypeBotEngine {
  String name;
  BotLevel level = BotLevel.intermediate;

  int _repCount = 0;
  int _targetReps = 6; // How many reps the bot will do this round
  BotPushupPhase _phase = BotPushupPhase.lockout;
  double _phaseProgress = 0.0;
  String _statusMessage = 'Warming up...';
  bool _isRunning = false;
  bool _hasSubmitted = false;

  Timer? _ticker;
  final Random _rng = Random();

  // Timing
  int _repDurationMs = 2400;
  int _currentRepElapsedMs = 0;
  int _restElapsedMs = 0;
  int _restDurationMs = 0;

  // Pre-round delay (bot "getting ready" before first rep)
  int _preStartDelayMs = 0;
  int _preStartElapsedMs = 0;
  bool _preStartDone = false;

  // Callbacks
  void Function(int reps, BotPushupPhase phase, double progress, String status)? onUpdate;
  void Function(int newRep)? onRepCompleted;
  void Function()? onBotSubmitted; // Called when bot finishes its set and "submits"

  PrototypeBotEngine({
    this.name = 'Bot Companion',
  });

  int get repCount => _repCount;
  int get targetReps => _targetReps;
  BotPushupPhase get phase => _phase;
  double get phaseProgress => _phaseProgress;
  String get statusMessage => _statusMessage;
  bool get isRunning => _isRunning;
  bool get hasSubmitted => _hasSubmitted;

  /// Pick a realistic random rep target.
  /// Sometimes stops at 4 or 6, sometimes goes to 10, maximum 15.
  void _pickTargetReps() {
    List<int> targets;
    switch (level) {
      case BotLevel.beginner:
        targets = [3, 4, 5, 6];
        break;
      case BotLevel.intermediate:
        targets = [4, 5, 6, 7, 8, 10];
        break;
      case BotLevel.advanced:
        targets = [8, 10, 12, 14, 15];
        break;
    }
    _targetReps = targets[_rng.nextInt(targets.length)];
    _repDurationMs = 2000 + _rng.nextInt(800); // Moderate pace
  }

  /// Start the bot simulation. It will "get ready" for 1-3 seconds, then
  /// begin performing push-ups up to the target, then submit.
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _hasSubmitted = false;
    _currentRepElapsedMs = 0;
    _restElapsedMs = 0;
    _restDurationMs = 0;
    _preStartDone = false;
    _preStartDelayMs = 1500 + _rng.nextInt(2500); // 1.5 - 4 seconds "getting ready"
    _preStartElapsedMs = 0;
    _phase = BotPushupPhase.lockout;

    _pickTargetReps();
    _statusMessage = 'Getting into position...';

    _ticker = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      _tick(33);
    });
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _isRunning = false;
  }

  void reset() {
    stop();
    _repCount = 0;
    _phaseProgress = 0.0;
    _phase = BotPushupPhase.lockout;
    _statusMessage = 'Ready';
    _hasSubmitted = false;
    _preStartDone = false;
  }

  void _tick(int deltaMs) {
    if (!_isRunning) return;

    // Pre-start delay: bot is "getting ready"
    if (!_preStartDone) {
      _preStartElapsedMs += deltaMs;
      _phaseProgress = 0.0;
      if (_preStartElapsedMs >= _preStartDelayMs) {
        _preStartDone = true;
        _statusMessage = 'Starting push-ups!';
        _currentRepElapsedMs = 0;
      }
      onUpdate?.call(_repCount, _phase, _phaseProgress, _statusMessage);
      return;
    }

    // Already finished all target reps → bot has submitted
    if (_hasSubmitted) {
      _phase = BotPushupPhase.finished;
      _phaseProgress = 1.0;
      onUpdate?.call(_repCount, _phase, _phaseProgress, _statusMessage);
      return;
    }

    // Resting between cluster sets
    if (_phase == BotPushupPhase.resting) {
      _restElapsedMs += deltaMs;
      _phaseProgress = 0.0;
      if (_restElapsedMs >= _restDurationMs) {
        _phase = BotPushupPhase.lockout;
        _restElapsedMs = 0;
        _currentRepElapsedMs = 0;
        _statusMessage = 'Resuming...';
      }
      onUpdate?.call(_repCount, _phase, _phaseProgress, _statusMessage);
      return;
    }

    // Advance rep progress
    _currentRepElapsedMs += deltaMs;

    // Fatigue: gets slower as reps increase
    final double fatigueFactor = 1.0 + (_repCount / 15.0) * 0.40;
    final int effectiveRepDuration = (_repDurationMs * fatigueFactor).toInt();

    final double normalizedRepTime =
        (_currentRepElapsedMs / effectiveRepDuration).clamp(0.0, 1.0);
    _phaseProgress = normalizedRepTime;

    if (normalizedRepTime < 0.15) {
      _phase = BotPushupPhase.lockout;
    } else if (normalizedRepTime < 0.50) {
      _phase = BotPushupPhase.descending;
    } else if (normalizedRepTime < 0.60) {
      _phase = BotPushupPhase.bottom;
    } else if (normalizedRepTime < 0.95) {
      _phase = BotPushupPhase.ascending;
    } else {
      // Rep completed
      _repCount++;
      _currentRepElapsedMs = 0;
      _phase = BotPushupPhase.lockout;
      _phaseProgress = 0.0;
      onRepCompleted?.call(_repCount);

      // Check if target reached → bot "submits"
      if (_repCount >= _targetReps) {
        _hasSubmitted = true;
        _phase = BotPushupPhase.finished;
        _phaseProgress = 1.0;
        final submitMessages = [
          'Done! Submitted $_repCount reps 💪',
          'Finished! $_repCount push-ups submitted',
          '$_repCount reps locked in! Your turn...',
        ];
        _statusMessage = submitMessages[_rng.nextInt(submitMessages.length)];
        onBotSubmitted?.call();
        onUpdate?.call(_repCount, _phase, _phaseProgress, _statusMessage);
        return;
      }

      // Random fatigue rest at certain rep counts (e.g. after 3-4 reps take a breather)
      if (_repCount > 0 && _repCount % (3 + _rng.nextInt(3)) == 0) {
        _phase = BotPushupPhase.resting;
        _restDurationMs = 1500 + _rng.nextInt(2500); // 1.5-4s rest
        _restElapsedMs = 0;
        final restMessages = [
          'Quick breather...',
          'Catching breath...',
          'Short pause...',
          'Breathing...',
        ];
        _statusMessage = restMessages[_rng.nextInt(restMessages.length)];
      } else {
        final repMessages = [
          'Rep #$_repCount ✓',
          'Good form! #$_repCount',
          '#$_repCount done',
          'Solid! #$_repCount',
        ];
        _statusMessage = repMessages[_rng.nextInt(repMessages.length)];
      }
    }

    onUpdate?.call(_repCount, _phase, _phaseProgress, _statusMessage);
  }

  void dispose() {
    stop();
  }
}
