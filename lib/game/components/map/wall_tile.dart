import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/utils/palette_swapper.dart';

class WallTile extends SpriteComponent with HasGameReference {
  final String spritePath;
  final double angleVal;
  final Color cor1;
  final Color cor2;
  final Color cor3;

  WallTile({
    required Vector2 position,
    required this.spritePath,
    this.angleVal = 0,
    this.cor1 = Palette.marrom,
    this.cor2 = Palette.onyx,
    this.cor3 = Palette.laranja,
  }) : super(
         position: position,
         size: Vector2(16, 16),
       ) {
    anchor = Anchor.center; 
    angle = angleVal;
  }

  @override
  Future<void> onLoad() async {
    final ui.Image swappedImage = await PaletteSwapper.createSwappedImage(
      imagePath: spritePath,
      lightGrayReplacement: cor1,
      darkGrayReplacement: cor2,
      whiteReplacement: cor3,
    );
    
    sprite = Sprite(swappedImage);
    
    paint.filterQuality = FilterQuality.none;
  }

  @override
  void onMount() {
    super.onMount();
    position += size / 2; // Centraliza a âncora no grid
  }
}