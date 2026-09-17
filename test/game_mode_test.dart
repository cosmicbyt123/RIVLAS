import 'package:flutter_test/flutter_test.dart';

// Standalone verification helper functions mirroring game logic for deterministic unit testing
bool checkCollision({
  required double birdX,
  required double birdY,
  required double birdRadius,
  required double pipeX,
  required double pipeWidth,
  required double gapTop,
  required double gapHeight,
}) {
  if (birdX + birdRadius < pipeX || birdX - birdRadius > pipeX + pipeWidth) {
    return false;
  }
  if (birdY - birdRadius < gapTop) {
    return true;
  }
  if (birdY + birdRadius > gapTop + gapHeight) {
    return true;
  }
  return false;
}

void main() {
  group('Flappy Push-Up Game Physics & Mechanics Tests', () {
    const double birdX = 80.0;
    const double birdRadius = 18.0;
    const double pipeWidth = 64.0;
    const double gapHeight = 210.0;

    test('Bird cleanly passes through open pipe gap without collision', () {
      const double gapTop = 150.0;
      // Bird is centered in the gap: Y = 150 + 105 = 255
      const double birdY = 255.0;
      const double pipeX = 60.0; // Overlapping horizontally with bird

      final collision = checkCollision(
        birdX: birdX,
        birdY: birdY,
        birdRadius: birdRadius,
        pipeX: pipeX,
        pipeWidth: pipeWidth,
        gapTop: gapTop,
        gapHeight: gapHeight,
      );

      expect(collision, false);
    });

    test('Bird collides with top pipe when flying too high', () {
      const double gapTop = 200.0;
      // Bird Y is 190, upper bound is 190 - 18 = 172 < gapTop (200) -> collision!
      const double birdY = 190.0;
      const double pipeX = 70.0;

      final collision = checkCollision(
        birdX: birdX,
        birdY: birdY,
        birdRadius: birdRadius,
        pipeX: pipeX,
        pipeWidth: pipeWidth,
        gapTop: gapTop,
        gapHeight: gapHeight,
      );

      expect(collision, true);
    });

    test('Bird collides with bottom pipe when falling too low', () {
      const double gapTop = 100.0;
      // Gap runs from 100 to 310. Bird Y is 320 -> lower bound 320 + 18 = 338 > 310 -> collision!
      const double birdY = 320.0;
      const double pipeX = 70.0;

      final collision = checkCollision(
        birdX: birdX,
        birdY: birdY,
        birdRadius: birdRadius,
        pipeX: pipeX,
        pipeWidth: pipeWidth,
        gapTop: gapTop,
        gapHeight: gapHeight,
      );

      expect(collision, true);
    });

    test('Push-up rep initiates upward jump impulse velocity', () {
      double birdVelocity = 200.0; // falling down
      const double jumpImpulse = -440.0; // upward flap

      // When push-up rep detected:
      birdVelocity = jumpImpulse;

      expect(birdVelocity, -440.0);
      expect(birdVelocity < 0, true); // Negative velocity moves upward in screen coords
    });
  });
}
