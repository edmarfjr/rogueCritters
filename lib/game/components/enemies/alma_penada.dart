import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/creature_type.dart';
import 'package:creatures_rogue/game/components/player/player.dart';
import 'package:creatures_rogue/game/components/utils/palette_swapper.dart';
import 'package:creatures_rogue/game/components/utils/y_sort.dart';

/// A alma que um inimigo abatido solta sob a maldição `Assombração`: um
/// fantasma translúcido que flutua devagar atrás do jogador e machuca no
/// toque.
///
/// NÃO é um `Enemy`, de propósito: como inimigo ela seguraria a sala
/// trancada, contaria como abate, dispararia os itens de abate (`Frenesi`,
/// `Agulha`), viraria alvo do `Enxame` e da `Telecinese`, daria XP e
/// entraria no bestiário. É só um perigo de passagem — atravessa parede,
/// some sozinha e não pode ser atingida.
class AlmaPenada extends PositionComponent {
  final Player alvo;

  AlmaPenada({required super.position, required this.alvo})
    : super(size: Vector2.all(16), anchor: Anchor.center);

  /// Bem mais lenta que o jogador: dá pra fugir, não dá pra ignorar.
  static const double velocidade = 24.0;

  /// Tempo subindo do corpo, sem perseguir nem machucar — o aviso.
  static const double surgimento = 0.5;

  static const double duracao = 5.0;

  /// Dano do toque: meio coração.
  static const double dano = 1.0;

  /// Distância do toque, de centro a centro.
  static const double alcance = 8.0;

  double _tempo = 0.0;
  Sprite? _sprite;

  /// O desenho olha pra esquerda; indo pra direita, espelha.
  bool _paraDireita = false;
  final Paint _paint = Paint()..filterQuality = FilterQuality.none;

  @override
  Future<void> onLoad() async {
    final ui.Image imagem = await PaletteSwapper.createSwappedImage(
      imagePath: 'projeteis/ghost.png',
      lightGrayReplacement: Palette.branco,
      darkGrayReplacement: Palette.cinza,
    );
    _sprite = Sprite(imagem);
    priority = ySortPriority(position.y + size.y / 2);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _tempo += dt;
    if (_tempo >= duracao) {
      removeFromParent();
      return;
    }
    if (_tempo < surgimento) {
      position.y -= 8 * dt;
      return;
    }

    final rumo = alvo.absolutePosition - absolutePosition;
    final distancia = rumo.length;
    if (distancia <= alcance) {
      alvo.takeDamage(dano, CreatureType.neutro);
      removeFromParent();
      return;
    }
    position += rumo / distancia * velocidade * dt;
    if (rumo.x.abs() > 1) _paraDireita = rumo.x > 0;
    priority = ySortPriority(position.y + size.y / 2);
  }

  @override
  void render(Canvas canvas) {
    final sprite = _sprite;
    if (sprite == null) return;
    // Aparece no surgimento, some no último segundo.
    final entrada = (_tempo / surgimento).clamp(0.0, 1.0);
    final saida = ((duracao - _tempo) / 1.0).clamp(0.0, 1.0);
    _paint.color = Palette.branco.withValues(alpha: 0.7 * entrada * saida);
    if (_paraDireita) {
      canvas.save();
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }
    sprite.render(canvas, size: size, overridePaint: _paint);
    if (_paraDireita) canvas.restore();
  }
}
