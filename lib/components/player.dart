import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:pixel_adventure/components/checkpoint.dart';
import 'package:pixel_adventure/components/chicken.dart';
import 'package:pixel_adventure/components/collision_block.dart';
import 'package:pixel_adventure/components/custom_hitbox.dart';
import 'package:pixel_adventure/components/fruit.dart';
import 'package:pixel_adventure/components/saw.dart';
import 'package:pixel_adventure/components/utils.dart';
import 'package:pixel_adventure/pixel_adventure.dart';

enum PlayerState {
  idle,
  running,
  jumping,
  falling,
  hit,
  appearing,
  disappearing,
  dj,
  wj,
}

class Player extends SpriteAnimationGroupComponent
    with HasGameRef<PixelAdventure>, KeyboardHandler, CollisionCallbacks {
  String character;
  Player({
    position,
    this.character = 'Ninja Frog',
  }) : super(position: position);

  final double stepTime = 0.05;
  late final SpriteAnimation idleAnimation;
  late final SpriteAnimation runningAnimation;
  late final SpriteAnimation jumpingAnimation;
  late final SpriteAnimation fallingAnimation;
  late final SpriteAnimation hitAnimation;
  late final SpriteAnimation appearingAnimation;
  late final SpriteAnimation disappearingAnimation;
  late final SpriteAnimation doubleJumpAnimation;
  late final SpriteAnimation wallJumpAnimation;


  final double _gravity = 9.8;
  final double _jumpForce = 260;
  final double _terminalVelocity = 300;
  double horizontalMovement = 0;
  double moveSpeed = 100;
  Vector2 startingPosition = Vector2.zero();
  Vector2 velocity = Vector2.zero();
  bool isOnGround = false;
  bool isOnAir = false;
  int jumpMax = 0;
  bool hasDoubleJumped = false;
  bool hasJumped = false;
  bool playingDJAnimation = false;
  bool gotHit = false;
  bool reachedCheckpoint = false;
  bool isWallJump = false;
  List<CollisionBlock> collisionBlocks = [];
  CustomHitbox hitbox = CustomHitbox(
    offsetX: 10,
    offsetY: 4,
    width: 14,
    height: 28,
  );
  double fixedDeltaTime = 1 / 60;
  double accumulatedTime = 0;

  @override
  FutureOr<void> onLoad() {
    _loadAllAnimations();
    // debugMode = true;

    startingPosition = Vector2(position.x, position.y);

    add(RectangleHitbox(
      position: Vector2(hitbox.offsetX, hitbox.offsetY),
      size: Vector2(hitbox.width, hitbox.height),
    ));
    return super.onLoad();
  }

  @override
  void update(double dt) {
    accumulatedTime += dt;

    while (accumulatedTime >= fixedDeltaTime) {
      if (!gotHit && !reachedCheckpoint) {
        _updatePlayerState();
        _updatePlayerMovement(fixedDeltaTime);
        _checkHorizontalCollisions();
        _applyGravity(fixedDeltaTime);
        _checkVerticalCollisions();
      }

      accumulatedTime -= fixedDeltaTime;
    }

    super.update(dt);
  }

  @override
  bool onKeyEvent(RawKeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    horizontalMovement = 0;
    final isLeftKeyPressed = keysPressed.contains(LogicalKeyboardKey.keyA) ||
        keysPressed.contains(LogicalKeyboardKey.arrowLeft);
    final isRightKeyPressed = keysPressed.contains(LogicalKeyboardKey.keyD) ||
        keysPressed.contains(LogicalKeyboardKey.arrowRight);

    horizontalMovement += isLeftKeyPressed ? -1 : 0;
    horizontalMovement += isRightKeyPressed ? 1 : 0;

     if(keysPressed.contains(LogicalKeyboardKey.space)) {

       if(isOnGround) {
         hasJumped=true;
         jumpMax++;
         isOnAir = true;
         isOnGround=false;
       }

       if (isWallJump) {
         isWallJump=true;
         hasJumped=true;
         jumpMax++;
         isOnAir = true;
         isOnGround=false;
       };
     };

    if(keysPressed.contains(LogicalKeyboardKey.arrowUp)) {
     if (isOnAir  && jumpMax < 2) {

       hasDoubleJumped = true;
        jumpMax++;

      }
    }

    return super.onKeyEvent(event, keysPressed);
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    if (!reachedCheckpoint) {
      if (other is Fruit) other.collidedWithPlayer();
      if (other is Saw) _respawn();
      if (other is Chicken) other.collidedWithPlayer();
      if (other is Checkpoint) _reachedCheckpoint();
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  void _loadAllAnimations() {
    idleAnimation = _spriteAnimation('Idle', 11);
    runningAnimation = _spriteAnimation('Run', 12);
    jumpingAnimation = _spriteAnimation('Jump', 1);
    fallingAnimation = _spriteAnimation('Fall', 1);
    hitAnimation = _spriteAnimation('Hit', 7)..loop = false;
    appearingAnimation = _specialSpriteAnimation('Appearing', 7);
    disappearingAnimation = _specialSpriteAnimation('Desappearing', 7);
    doubleJumpAnimation = _spriteAnimation('Double Jump', 6);
    wallJumpAnimation = _spriteAnimation("Wall Jump", 5)..loop=true;

    // List of all animations
    animations = {
      PlayerState.idle: idleAnimation,
      PlayerState.running: runningAnimation,
      PlayerState.jumping: jumpingAnimation,
      PlayerState.falling: fallingAnimation,
      PlayerState.hit: hitAnimation,
      PlayerState.appearing: appearingAnimation,
      PlayerState.dj: doubleJumpAnimation,
      PlayerState.disappearing: disappearingAnimation,
      PlayerState.wj : wallJumpAnimation,
    };

    // Set current animation
    current = PlayerState.idle;
  }

  SpriteAnimation _spriteAnimation(String state, int amount) {
    return SpriteAnimation.fromFrameData(
      game.images.fromCache('Main Characters/$character/$state (32x32).png'),
      SpriteAnimationData.sequenced(
        amount: amount,
        stepTime: stepTime,
        textureSize: Vector2.all(32),
      ),
    );
  }

  SpriteAnimation _specialSpriteAnimation(String state, int amount) {
    return SpriteAnimation.fromFrameData(
      game.images.fromCache('Main Characters/$state (96x96).png'),
      SpriteAnimationData.sequenced(
        amount: amount,
        stepTime: stepTime,
        textureSize: Vector2.all(96),
        loop: false,
      ),
    );
  }

  void _updatePlayerState() {
    PlayerState playerState = PlayerState.idle;

    if (velocity.x < 0 && scale.x > 0) {
      flipHorizontallyAroundCenter();
    } else if (velocity.x > 0 && scale.x < 0) {
      flipHorizontallyAroundCenter();
    }

    // Check if moving, set running
    if (velocity.x > 0 || velocity.x < 0) playerState = PlayerState.running;

    // check if Falling set to falling
    if (velocity.y > 0) playerState = PlayerState.falling;

    // Checks if jumping, set to jumping
    if (hasJumped) playerState = PlayerState.jumping;

    if (playingDJAnimation) playerState = PlayerState.dj;

    if (isWallJump) playerState = PlayerState.wj;


    current = playerState;
    //print(current);
  }

  void _updatePlayerMovement(double dt) {
    if(hasJumped && !isWallJump) _playerJump(dt, jumpMax);
    if(hasDoubleJumped) _playerDoubleJump(dt, jumpMax);
    if(isWallJump && hasJumped) _playerWallJump(dt, jumpMax);

    // if (velocity.y > _gravity) isOnGround = false; // optional

    velocity.x = horizontalMovement * moveSpeed;
    position.x += velocity.x * dt;
  }

  void _playerJump(double dt, cpt) {
    if (game.playSounds) FlameAudio.play('jump.wav', volume: game.soundVolume);
    velocity.y = -_jumpForce;
    position.y += velocity.y * dt;
    isOnGround = false;
    hasJumped = false;
  }

  void _playerDoubleJump(double dt, cpt) async{
    if (game.playSounds) FlameAudio.play('jump.wav', volume: game.soundVolume);
    velocity.y = -_jumpForce;
    position.y += velocity.y * dt;
    hasDoubleJumped = false;
    playingDJAnimation = true;
    const durationWaiting = Duration(milliseconds: 300);
    Future.delayed(durationWaiting, () => playingDJAnimation=false);
  }

  void _playerWallJump(double dt, cpt) {
    print(velocity.x);
    // Appliquer une force de saut modifiée ou une dynamique différente pour un saut mural.
    velocity.y = -_jumpForce/2;  // Force de saut peut-être augmentée ou modifiée
    velocity.x = -velocity.x * 10.5;  // Ajouter un coup de pouce horizontal pour se détacher du mur
    // Vous pouvez également ajuster la position horizontale pour éloigner le joueur du mur.
    position.x += velocity.y + 50 * dt;
    // Ajustement de la position verticale basé sur la nouvelle vélocité.
    position.y += velocity.y * dt;
    // Marquer le joueur comme n'étant plus sur le sol.
    isOnGround = false;
    // Réinitialiser le flag de saut après le saut.
    hasJumped = false;
    // Réinitialiser isWallJump après l'exécution pour éviter des sauts muraux répétés non désirés.
    isWallJump = false;
  }

  // Cette méthode parcourt tous les blocs de collision pour vérifier les collisions horizontales.
  void _checkHorizontalCollisions() {
    // Itération sur chaque bloc dans la liste des blocs de collision.
    for (final block in collisionBlocks) {
      // Vérifier si le bloc n'est pas une plateforme.
      if (!block.isPlatform) {
        // Vérifier si une collision se produit entre le joueur et le bloc.
        if (checkCollision(this, block)) {
          // Si le joueur se déplace vers la droite (vitesse x positive)...
          if (velocity.x > 0) {
            // Arrêter le mouvement horizontal en réinitialisant la vitesse horizontale à zéro.
            velocity.x = 0;
            // Repositionner le joueur juste à gauche du bloc pour éviter de le traverser.
            position.x = block.x - hitbox.offsetX - hitbox.width;
            // Arrêter la boucle après avoir traité la collision pour éviter des calculs inutiles.

            if (isOnAir) {
              isWallJump = true;
              hasJumped = false;
              jumpMax = 0;
            }

            break;
          }
          // Si le joueur se déplace vers la gauche (vitesse x négative)...
          if (velocity.x < 0) {
            // Arrêter le mouvement horizontal en réinitialisant la vitesse horizontale à zéro.
            velocity.x = 0;
            // Repositionner le joueur juste à droite du bloc pour éviter de le traverser.
            position.x = block.x + block.width + hitbox.width + hitbox.offsetX;
            // Arrêter la boucle après avoir traité la collision pour éviter des calculs inutiles.

            if (isOnAir) {
              isWallJump = true;
              hasJumped = false;
              jumpMax = 0;
            }

            break;
          }
        }
      }
    }
  }

  void _applyGravity(double dt) {
    velocity.y += _gravity;
    velocity.y = velocity.y.clamp(-_jumpForce, _terminalVelocity);
    position.y += velocity.y * dt;
  }

  // Cette méthode vérifie les collisions verticales entre le joueur et les blocs de collision.
  void _checkVerticalCollisions() {
    // Itérer sur chaque bloc de collision stocké dans collisionBlocks.
    for (final block in collisionBlocks) {
      // Vérifie si le bloc actuel est marqué comme une plateforme.
      if (block.isPlatform) {
        // Si le joueur entre en collision avec une plateforme...
        if (checkCollision(this, block)) {
          // Et si le joueur est en train de tomber (vitesse y positive indique une descente)...
          if (velocity.y > 0) {
            // Arrêter le mouvement vers le bas en réinitialisant la vitesse verticale.
            velocity.y = 0;
            // Positionner le joueur juste au-dessus du bloc pour éviter un enfoncement dans le bloc.
            position.y = block.y - hitbox.height - hitbox.offsetY;
            // Marquer le joueur comme étant sur le sol, permettant ainsi de sauter à nouveau.
            isOnGround = true;
            // Indiquer que le joueur n'est plus en l'air.
            isOnAir = false;
            // Réinitialiser le compteur de sauts.
            jumpMax = 0;
            // Arrêter la boucle après la première collision significative pour optimiser la performance.
            isWallJump = false;
            break;
          }
        }
      } else {
        // Si le bloc n'est pas une plateforme, traiter les collisions de manière générique.
        if (checkCollision(this, block)) {
          // Si le joueur tombe et entre en collision avec le bloc...
          if (velocity.y > 0) {
            // Réinitialiser la vitesse verticale pour arrêter la descente.
            velocity.y = 0;
            // Positionner le joueur sur le bloc.
            position.y = block.y - hitbox.height - hitbox.offsetY;
             // Marquer le joueur comme étant sur le sol.
            isOnGround = true;
            // Indiquer que le joueur n'est plus en l'air.
            isOnAir = false;
            // Réinitialiser le compteur de sauts.
            jumpMax = 0;
            // Arrêter la boucle pour éviter des traitements inutiles après une collision.
            isWallJump = false;
            break;
          }
          // Si le joueur monte et entre en collision avec le dessous d'un bloc...
          if (velocity.y < 0) {
            // Arrêter le mouvement ascendant.
            velocity.y = 0;
            // Ajuster la position pour éviter le bloc.
            position.y = block.y + block.height - hitbox.offsetY;
          }
        }
      }
    }
  }

  void _respawn() async {
    if (game.playSounds) FlameAudio.play('hit.wav', volume: game.soundVolume);
    const canMoveDuration = Duration(milliseconds: 400);
    gotHit = true;
    current = PlayerState.hit;

    await animationTicker?.completed;
    animationTicker?.reset();

    scale.x = 1;
    position = startingPosition - Vector2.all(32);
    current = PlayerState.appearing;

    await animationTicker?.completed;
    animationTicker?.reset();

    velocity = Vector2.zero();
    position = startingPosition;
    _updatePlayerState();
    Future.delayed(canMoveDuration, () => gotHit = false);
  }

  void _reachedCheckpoint() async {
    reachedCheckpoint = true;
    if (game.playSounds) {
      FlameAudio.play('disappear.wav', volume: game.soundVolume);
    }
    if (scale.x > 0) {
      position = position - Vector2.all(32);
    } else if (scale.x < 0) {
      position = position + Vector2(32, -32);
    }

    current = PlayerState.disappearing;

    await animationTicker?.completed;
    animationTicker?.reset();

    reachedCheckpoint = false;
    position = Vector2.all(-640);

    const waitToChangeDuration = Duration(seconds: 3);
    Future.delayed(waitToChangeDuration, () => game.loadNextLevel());
  }

  void collidedwithEnemy() {
    _respawn();
  }
}