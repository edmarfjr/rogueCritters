import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/utils/palette_swapper.dart';
import 'obstacle.dart';

class Door extends Obstacle {
  bool _isOpen;
  bool get isOpen => _isOpen;
  final double angleVal;
  final bool flipX;
  
  late Sprite _closedSprite;
  late Sprite _openSprite;

  final Color cor1;
  final Color cor2;
  final Color cor3;
  final Color cor4;

  final String spritePath;

  Door({
    required super.position,
    required this.angleVal,
    this.cor1 = Palette.marrom,
    this.cor2 = Palette.onyx,
    this.cor3 = Palette.verde,
    this.cor4 = Palette.branco,
    bool isOpen = false,
    this.flipX = false,
    required this.spritePath,
  })  : _isOpen = isOpen,
        
        super(
          spritePath: spritePath,
          cor1: cor1,
          cor2: cor2,  
          cor3: cor3,  
          size: Vector2(16, 16),
          collisionType: isOpen ? CollisionType.inactive : CollisionType.passive,
        ) {
    anchor = Anchor.center;
    angle = angleVal;
    if (flipX) {
      scale = Vector2(1, -1);
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    final ui.Image swappedImageClose = await PaletteSwapper.createSwappedImage(
      imagePath: spritePath,//'tileset/door1.png',
      lightGrayReplacement: cor1,
      darkGrayReplacement: cor2,
      whiteReplacement: cor3,
    );

    final ui.Image swappedImage = await PaletteSwapper.createSwappedImage(
      imagePath: 'tileset/floor1.png',//'tileset/doorOpen1.png',
      lightGrayReplacement: cor1,
      darkGrayReplacement: cor2,
      whiteReplacement: cor4,
    );
    
    _closedSprite = Sprite(swappedImageClose);
    _openSprite = Sprite(swappedImage);

  }

  void open() {
    _isOpen = true;
    hitbox.collisionType = CollisionType.inactive;
  }

  void close() {
    _isOpen = false;
    hitbox.collisionType = CollisionType.passive;
  }

  @override
  void onMount() {
    super.onMount();
    position += size / 2;
  }

  @override
  void render(Canvas canvas) {
    final sprite = _isOpen ? _openSprite : _closedSprite;
    sprite.render(canvas, size: size, overridePaint: paint);
  }
}