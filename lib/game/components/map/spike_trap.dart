import 'dart:ui' as ui;
import 'package:creatures_rogue/game/components/creatures/creature_type.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/audio/game_audio.dart';
import 'package:creatures_rogue/game/audio/sfx.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/damageable_by_enemy.dart';
import 'package:creatures_rogue/game/components/enemies/enemy.dart';
import 'package:creatures_rogue/game/components/player/player.dart';
import 'package:creatures_rogue/game/components/utils/palette_swapper.dart';
import 'package:creatures_rogue/game/components/utils/y_sort.dart';

enum _FaseArmadilha { esperando, subindo, ativa, descendo }

/// Armadilha de espinhos: NÃO é um [Obstacle] de propósito — não bloqueia
/// movimento (hitbox `passive`, e nenhum código de colisão em jogador ou
/// inimigo trata `SpikeTrap` como parede, ao contrário de `is Obstacle`).
///
/// Fica esperando (espinhos recolhidos) até alguém passar por cima. Aí sobe,
/// fica ativa por [duracaoAtiva] causando dano a quem tocar (uma vez por
/// vítima por ativação, igual `ExplosionHitbox`), e desce de volta a esperar.
///
/// `trap.png` é uma tira de 4 quadros 16x16: esperando, subindo, ativa,
/// descendo — nessa ordem.
class SpikeTrap extends PositionComponent with CollisionCallbacks, HasGameReference {
  static const double _duracaoSubida = 0.5;
  static const double duracaoAtiva = 1.5;
  static const double _duracaoDescida = 0.2;

  final double dano;
  final Color cor1;
  final Color cor2;

  late final List<Sprite> _quadros;
  _FaseArmadilha _fase = _FaseArmadilha.esperando;
  double _timer = 0.0;

  /// Quem já foi atingido nesta ativação — evita golpe duplo tanto de quem
  /// fica parado em cima quanto do duplo callback dos dois hitboxes do Player.
  final Set<PositionComponent> _atingidosNestaAtivacao = {};

  final Paint _paint = Paint()..filterQuality = FilterQuality.none;

  SpikeTrap({
    required Vector2 position,
    this.dano = 2,
    this.cor1 = Palette.cinzaEsc,
    this.cor2 = Palette.preto,
    Vector2? size,
  }) : super(position: position, size: size ?? Vector2(16, 16));

  @override
  Future<void> onLoad() async {
    final ui.Image swapped = await PaletteSwapper.createSwappedImage(
      imagePath: 'tileset/trap.png',
      lightGrayReplacement: cor1,
      darkGrayReplacement: cor2,
    );
    _quadros = List.generate(
      4,
      (i) => Sprite(swapped, srcPosition: Vector2(i * 16.0, 0), srcSize: Vector2(16, 16)),
    );

    add(RectangleHitbox(collisionType: CollisionType.passive));
    priority = ySortPriority(position.y + size.y / 2);
  }

  void _ativar() {
    if (_fase != _FaseArmadilha.esperando) return;
    _fase = _FaseArmadilha.subindo;
    _timer = _duracaoSubida;
    GameAudio.instance.play(Sfx.hit);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_fase == _FaseArmadilha.esperando) return;

    _timer -= dt;
    if (_timer > 0) return;

    switch (_fase) {
      case _FaseArmadilha.subindo:
        _fase = _FaseArmadilha.ativa;
        _timer = duracaoAtiva;
      case _FaseArmadilha.ativa:
        _fase = _FaseArmadilha.descendo;
        _timer = _duracaoDescida;
        _atingidosNestaAtivacao.clear();
      case _FaseArmadilha.descendo:
        _fase = _FaseArmadilha.esperando;
      case _FaseArmadilha.esperando:
        break;
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    // Quem passa por baixo não pisa na placa de pressão. Antes do `_ativar`,
    // e não só no `onCollision` de dano, porque o próprio armar da armadilha
    // toca `Sfx.hit` — um espinho subindo sozinho denunciaria o jogador
    // enterrado, que é exatamente o que o mergulho comprou.
    if (other is Player && other.submerso) return;
    if (other is Player || other is Enemy) _ativar();
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (_fase != _FaseArmadilha.ativa) return;
    if (other is Player && other.submerso) return;
    if (_atingidosNestaAtivacao.contains(other)) return;

    if (other is Enemy) {
      _atingidosNestaAtivacao.add(other);
      other.takeDamage(2, tipoAtacante:CreatureType.neutro);
    } else if (other is DamageableByEnemy) {
      _atingidosNestaAtivacao.add(other);
      other.takeDamage(1, CreatureType.neutro, porArmadilha: true);
    }
  }

  @override
  void render(Canvas canvas) {
    final quadro = switch (_fase) {
      _FaseArmadilha.esperando => 0,
      _FaseArmadilha.subindo => 1,
      _FaseArmadilha.ativa => 2,
      _FaseArmadilha.descendo => 3,
    };
    _quadros[quadro].render(canvas, size: size, overridePaint: _paint);
  }
}
