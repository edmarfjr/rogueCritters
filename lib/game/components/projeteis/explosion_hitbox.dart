import 'dart:ui';
import 'package:creatures_rogue/game/audio/game_audio.dart';
import 'package:creatures_rogue/game/audio/sfx.dart';
import 'package:creatures_rogue/game/components/effects/dot.dart';
import 'package:creatures_rogue/game/components/projeteis/projectile.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/creature_type.dart';
import 'package:creatures_rogue/game/components/creatures/creature_data.dart';
import 'package:creatures_rogue/game/components/creatures/damageable_by_enemy.dart';
import 'package:creatures_rogue/game/components/enemies/enemy.dart'; // Mude para base_enemy se refatorou
import 'package:creatures_rogue/game/components/map/obstacle.dart';
import 'package:creatures_rogue/game/components/map/porta_secreta.dart';
import 'package:creatures_rogue/game/components/player/player.dart';

class ExplosionHitbox extends PositionComponent with CollisionCallbacks {
  double lifeTime = 0.2;
  double dmg;

  /// Se true, além do dano, atordoa (zera a ação) os inimigos atingidos.
  final double stunDuration;
  final double paraliseDuration;
  final bool isEnemy;

  /// Criatura que soltou a explosão, quando é de inimigo — só pro "derrotado
  /// por" do Game Over (ver `DamageableByEnemy.takeDamage`).
  final CreatureData? origem;

  /// Quem criou a explosão, quando foi um inimigo. Serve pra saber se ela
  /// saiu às cegas ([fogoAmigo]) e pra ela nunca acertar o próprio dono.
  final PositionComponent? dono;

  /// Explosão às cegas: o dono estava cego ao criá-la, então ela acerta os
  /// outros inimigos além do jogador. Ver `Projectile.fogoAmigo`.
  late final bool fogoAmigo;
  final Color cor1;
  final Color cor2;

  /// Força de empurrão aplicada aos inimigos atingidos. 0 = não empurra.
  final double knockback;

  /// Tipo elemental do dano, pro multiplicador de vantagem. `neutro` = 1.0.
  final CreatureType tipo;

  /// Condições de controle aplicadas no acerto. 0 = não aplica.
  final double lentidaoDuracao;
  final double lentidaoFator;
  final double cegoDuracao;
  final DotKind? dotKind;
  final int dotTicks;

  /// Explosão de verdade (estouro, detonação), e não um golpe de área
  /// (mordida, soco, latido): toca o som de explosão do elemento em vez do
  /// som de ataque.
  final bool explosao;

  Paint paintV = Paint();
  Paint paintB = Paint();

  final Set<PositionComponent> _hitEntities = {};

  ExplosionHitbox({
    required Vector2 position,
    this.dmg = 1,
    this.isEnemy = false,
    this.origem,
    this.dono,
    bool? forcarFogoAmigo,
    this.stunDuration = 0,
    this.paraliseDuration = 0,
    this.knockback = 50.0,
    this.tipo = CreatureType.neutro,
    this.lentidaoDuracao = 0,
    this.lentidaoFator = 0.5,
    this.cegoDuracao = 0,
    this.dotKind,
    this.dotTicks = 1,
    this.explosao = false,
    this.cor1 = Palette.vermelho,
    this.cor2 = Palette.branco,
    Vector2? size,
  })
      : super(position: position, size: size ?? Vector2(32, 32), anchor: Anchor.center) {
    final d = dono;
    fogoAmigo =
        forcarFogoAmigo ?? (isEnemy && d is Enemy && d.cegoTimer > 0);
  }

  @override
  Future<void> onLoad() async {
    // Explosão de inimigo sem elemento no DANO (neutra pra vantagem) ainda
    // soa como o elemento da criatura que a soltou: a Bomba de Fogo explode
    // com som de fogo sem passar a dar dano dobrado em planta.
    final tipoDoSom = tipo == CreatureType.neutro && origem != null
        ? origem!.tipo
        : tipo;
    final sfx = explosao ? tipoDoSom.explosaoSfx : tipo.attackSfx;
    if (sfx != null) GameAudio.instance.play(sfx);

    // CORREÇÃO 1: isSolid = true garante que o interior do círculo também seja "sólido"
    add(CircleHitbox(isSolid: true, collisionType: CollisionType.active));

    paintV = Paint()
    ..color = cor1
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.25
    ..filterQuality = FilterQuality.none;

    paintB = Paint()
    ..color = cor2
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.25
    ..filterQuality = FilterQuality.none;
  }

  @override
  void update(double dt) {
    super.update(dt);
    lifeTime -= dt;

    // CORREÇÃO 2: Aumentamos o tamanho (scale) da explosão rapidamente a cada frame!
    // Isso força o motor de física a se atualizar e gera um efeito de onda de choque.
    scale += Vector2.all(dt * 5); 

    if (lifeTime <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    // Desenha o clarão visual
    canvas.drawCircle(Offset(size.x/2, size.y/2), size.x/2, paintB);
    canvas.drawCircle(Offset(size.x/2, size.y/2), size.x/2 + 1, paintV);
    canvas.drawCircle(Offset(size.x/2, size.y/2), size.x/2 - 1, paintV);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints.cast<Vector2>(), other);
    
    if (_hitEntities.contains(other)) return; 
    _hitEntities.add(other);

    if (isEnemy) {
      if(other is Projectile && !other.isEnemy){
        if (typeMultiplier(tipo, other.tipo) > 1.0) return;
          other.onDestroy();
          return;
      }
    }else{
      if(other is Projectile && other.isEnemy){
       if (typeMultiplier(tipo, other.tipo) > 1.0) return;
          other.onDestroy();
          return;
      }
    }

    if (other is Rock) {
      other.blowUp();
    } else if (other is PortaSecreta && !isEnemy) {
      other.atingir(forte: true);
    } else if (other is Enemy && !isEnemy) {
      if(other.summonTimer > 0) return;
      // Mesma razão do Projectile: os upgrades de dano da run entram no ponto
      // de acerto, não nas habilidades.
      //
      // `dmg > 0` porque existe explosão de dano ZERO, que serve só pra
      // empurrar (a Bolha Protetora ao estourar). Sem a guarda, cada inimigo
      // pego ganhava um "0.0" flutuando na cabeça, um `Sfx.hit` e uma rolagem
      // de crítico — tudo por um golpe que não existiu.
      if (dmg > 0) {
        other.takeDamage(
          dmg * Player.danoMult * Player.danoMultDerivado,
          tipoAtacante: tipo,
        );
      }
      if (stunDuration>0){
        other.applyStun(stunDuration);
      }
      if(paraliseDuration>0){
        other.applyParalise(paraliseDuration);
      }
      if (lentidaoDuracao > 0) other.applyLentidao(lentidaoDuracao, fator: lentidaoFator);
      if (cegoDuracao > 0) other.applyCego(cegoDuracao);
      if (knockback > 0) other.applyKnockback(absolutePosition, knockback);
      final kind = dotKind;
      if (kind != null) other.applyDot(kind, dotTicks);
    } else if (other is Enemy && fogoAmigo && other != dono) {
      if (other.summonTimer > 0) return;
      // Mesmo efeito que teria no jogador, sem crítico nem bônus de item.
      if (dmg > 0) other.takeDamage(dmg, tipoAtacante: tipo, doJogador: false);
      if (lentidaoDuracao > 0) {
        other.applyLentidao(lentidaoDuracao, fator: lentidaoFator);
      }
      if (cegoDuracao > 0) other.applyCego(cegoDuracao);
      if (knockback > 0) other.applyKnockback(absolutePosition, knockback);
    } else if (other is DamageableByEnemy && isEnemy) {
      other.takeDamage(dmg, tipo, origem: origem);
      if (lentidaoDuracao > 0) other.aplicarLentidao(lentidaoDuracao, fator: lentidaoFator);
      if (cegoDuracao > 0) other.aplicarCegueira(cegoDuracao);
      if (knockback > 0) other.applyKnockback(absolutePosition, knockback);
    }
  }
}