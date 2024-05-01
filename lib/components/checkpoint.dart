import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:pixel_adventure/components/player.dart';
import 'package:pixel_adventure/pixel_adventure.dart';

class Checkpoint extends SpriteAnimationComponent
    with HasGameRef<PixelAdventure>, CollisionCallbacks {
  // Constructeur du checkpoint
  Checkpoint({
    position,
    size,
    // Initialiser la class mère pour s'assurer que toutes les méthodes sont executées
  }) : super(
          position: position,
          size: size,
        );

  // Au chargement de l'objet
  @override
  FutureOr<void> onLoad() {
    // debugMode = true;
    // Il rajoute une hitbox
    add(RectangleHitbox(
      position: Vector2(18, 56), // Ancrage de la hitbox par rapport au checkpoint
      size: Vector2(12, 8),
      collisionType: CollisionType.passive,
    ));

    // Charge l'animation en cache et la joue ensuite
    animation = SpriteAnimation.fromFrameData(
      game.images
          .fromCache('Items/Checkpoints/Checkpoint/Checkpoint (No Flag).png'),
      SpriteAnimationData.sequenced(
        amount: 1, // Quantité d'image dans l'animation
        stepTime: 1, // interval en seconde entre chaque image
        textureSize: Vector2.all(64), // Taille de la texture (64,64)
      ),
    );
    return super.onLoad(); // On passe ça à la class mère
  }

  // Event sur les collisions gérés par flame
  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is Player) _reachedCheckpoint(); // Appelle notre méthode reached
    super.onCollisionStart(intersectionPoints, other); // Envoie ça à la mère
  }

  void _reachedCheckpoint() async {
    animation = SpriteAnimation.fromFrameData(
      game.images.fromCache(
          'Items/Checkpoints/Checkpoint/Checkpoint (Flag Out) (64x64).png'),
      SpriteAnimationData.sequenced(
        amount: 26,
        stepTime: 0.05,
        textureSize: Vector2.all(64),
        loop: false,
      ),
    );

    await animationTicker?.completed; // Attend que l'animation soit complétée

    animation = SpriteAnimation.fromFrameData(
      game.images.fromCache(
          'Items/Checkpoints/Checkpoint/Checkpoint (Flag Idle)(64x64).png'),
      SpriteAnimationData.sequenced(
        amount: 10,
        stepTime: 0.05,
        textureSize: Vector2.all(64),
      ),
    );
  }
}
