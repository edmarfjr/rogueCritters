import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:creatures_rogue/game/audio/game_audio.dart';
import 'package:creatures_rogue/game/audio/sfx.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/components/creatures/creature_data.dart';
import 'package:creatures_rogue/game/components/creatures/creature_type.dart';
import 'package:creatures_rogue/game/components/enemies/enemy.dart';
import 'package:creatures_rogue/game/components/player/player.dart';
import 'package:creatures_rogue/game/components/projeteis/projectile.dart';
import 'package:creatures_rogue/game/components/utils/palette_swapper.dart';
import 'package:creatures_rogue/game/components/utils/y_sort.dart';

/// Varredura de tentáculo em arco em volta de [dono] — o golpe corpo a corpo
/// do Calamarin (habilidade 1) e dos inimigos dele.
///
/// Não é projétil: não voa, não colide. O acerto é GEOMÉTRICO, a cada quadro:
/// quem estiver a até [alcance] do dono e dentro do ângulo já varrido leva o
/// golpe, uma vez só por varredura. Assim o arco de 120° e o giro de 360° do
/// Redemoinho saem da mesma conta, sem caso especial.
///
/// Do lado do jogador, o golpe também REBATE projéteis inimigos que alcança
/// (ver [_refletirProjeteis]).
///
/// O sprite (`projeteis/tentaculo.png`, desenhado apontando pra CIMA) gira
/// com a base presa no dono, então a ponta descreve o arco que o jogador vê.
class GolpeDeTentaculo extends PositionComponent {
  final PositionComponent dono;

  /// Direção do CENTRO do arco (a mira).
  final Vector2 direcao;

  /// Ângulo total varrido, em radianos (2π = volta inteira).
  final double arco;

  /// +1 varre no sentido do relógio, -1 no contrário.
  final double sentido;

  final double duracao;
  final double alcance;
  final double dano;
  final double empurrao;
  final CreatureType tipo;

  /// `true`: golpe de inimigo, acerta o jogador. `false`: acerta inimigos.
  final bool isEnemy;

  /// Quem golpeou, pro "derrotado por" — só faz sentido com [isEnemy].
  final CreatureData? origem;

  final Color cor1;
  final Color cor2;

  /// Desenha a área de acerto (o setor do arco) por cima do golpe — só pra
  /// teste e debug. Contorno = arco inteiro que o golpe vai cobrir;
  /// preenchido = parte já varrida, que é a que já pode acertar.
  static const bool mostrarHitbox = false;

  final Paint _hitboxContorno = Paint()
    ..color = const Color(0xFFFF0000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5;
  final Paint _hitboxVarrida = Paint()..color = const Color(0x55FF0000);

  /// Golpe às cegas: o inimigo dono estava cego ao golpear, então o
  /// tentáculo acerta os outros inimigos além do jogador.
  bool _fogoAmigo = false;

  final Set<PositionComponent> _atingidos = {};
  double _tempo = 0.0;
  late final double _anguloInicial;
  SpriteComponent? _visual;

  GolpeDeTentaculo({
    required this.dono,
    required this.direcao,
    required this.arco,
    required this.duracao,
    required this.alcance,
    required this.dano,
    required this.tipo,
    required this.cor1,
    required this.cor2,
    this.sentido = 1.0,
    this.empurrao = 30.0,
    this.isEnemy = false,
    this.origem,
  }) : super(anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    // Um toque por golpe, com o som do elemento, como todo ataque.
    final sfx = tipo.attackSfx;
    if (sfx != null) GameAudio.instance.play(sfx);
    final quem = dono;
    _fogoAmigo = isEnemy && quem is Enemy && quem.cegoTimer > 0;
    final mira = direcao.length == 0 ? Vector2(0, 1) : direcao.normalized();
    _anguloInicial = atan2(mira.y, mira.x) - sentido * arco / 2;
    position = dono.absolutePosition.clone()+(direcao.normalized()*8);

    final img = await PaletteSwapper.createSwappedImage(
      imagePath: 'projeteis/tentaculo.png',
      lightGrayReplacement: cor1,
      darkGrayReplacement: cor2,
    );
    final visual = SpriteComponent(
      sprite: Sprite(img),
      size: Vector2(alcance*0.75, alcance*0.75),
      // Base do tentáculo no centro do dono: girar em volta dela faz a ponta
      // varrer o arco.
      anchor: Anchor.bottomCenter,
    );
    _visual = visual;
    add(visual);
    _posicionar(0.0);
  }

  /// Ângulo atual da ponta, em radianos matemáticos (0 = direita).
  double _anguloEm(double fracao) => _anguloInicial + sentido * arco * fracao;

  void _posicionar(double fracao) {
    position = dono.absolutePosition.clone()+(direcao.normalized()*8);
    priority = ySortPriority(position.y) + 1;
    // O sprite aponta pra cima (-y), que é o ângulo matemático -π/2; somar
    // π/2 converte "pra onde a ponta vai" em rotação do componente.
    _visual?.angle = _anguloEm(fracao) + pi / 2;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!dono.isMounted) {
      removeFromParent();
      return;
    }

    _tempo += dt;
    final fracao = (_tempo / duracao).clamp(0.0, 1.0);
    _posicionar(fracao);
    _acertar(arco * fracao);

    if (_tempo >= duracao) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!mostrarHitbox || !isLoaded) return;
    // O componente não gira (quem gira é o sprite filho) e está na posição do
    // dono com tamanho zero, então a origem do canvas é o centro do arco.
    final area = Rect.fromCircle(center: Offset.zero, radius: alcance);
    canvas.drawArc(area, _anguloInicial, sentido * arco, true, _hitboxContorno);
    final fracao = (_tempo / duracao).clamp(0.0, 1.0);
    canvas.drawArc(area, _anguloInicial, sentido * arco * fracao, true, _hitboxVarrida);
  }

  /// Quanto do arco o alvo em [ponto] está "depois" do início da varredura,
  /// no sentido dela — de 0 a 2π.
  double _anguloPercorridoAte(Vector2 ponto) {
    final rel = ponto - dono.absolutePosition;
    final alvo = atan2(rel.y, rel.x);
    final diff = (alvo - _anguloInicial) * sentido;
    return diff % (2 * pi);
  }

  /// O alvo é um círculo de raio [raioAlvo] em volta de [ponto], não um
  /// ponto: basta o tentáculo encostar no corpo. Sem isso o golpe só contava
  /// quando o CENTRO do inimigo entrava no setor, e dava pra ver o tentáculo
  /// atravessar metade do corpo dele sem acertar nada.
  ///
  /// Vale pras duas medidas — distância (alcance + raio) e ângulo (a folga
  /// angular que o raio ocupa àquela distância), inclusive um pouco ANTES da
  /// borda inicial do arco, onde o ângulo dá a volta perto de 2π.
  bool _alcanca(Vector2 ponto, double raioAlvo, double varrido) {
    final distancia = ponto.distanceTo(dono.absolutePosition);
    if (distancia > alcance + raioAlvo) return false;
    // Encostado no dono, qualquer ângulo vale: o corpo cobre o centro do arco.
    if (distancia <= raioAlvo) return true;
    final folga = asin((raioAlvo / distancia).clamp(0.0, 1.0));
    final percorrido = _anguloPercorridoAte(ponto);
    return percorrido <= varrido + folga || percorrido >= 2 * pi - folga;
  }

  /// Meia maior medida da hitbox: o raio do círculo que a envolve por dentro.
  static double _raioDe(RectangleHitbox h) => max(h.size.x, h.size.y) / 2;

  void _acertar(double varrido) {
    if (isEnemy) {
      final d = dono;
      if (d is! Enemy) return;
      if (_fogoAmigo) _acertarInimigosAsCegas(varrido);
      final jogador = d.playerTarget;
      if (_atingidos.contains(jogador)) return;
      // Pulando ou enterrado, o tentáculo passa por baixo/por cima.
      if (jogador.isAirborne || jogador.submerso) return;
      final corpo = jogador.playerHitbox;
      if (!_alcanca(corpo.absoluteCenter, _raioDe(corpo), varrido)) return;
      _atingidos.add(jogador);
      jogador.takeDamage(dano, tipo, origem: origem);
      jogador.applyKnockback(dono.absolutePosition, empurrao);
      return;
    }

    final inimigos =
        dono.parent?.children.whereType<Enemy>() ?? const <Enemy>[];
    for (final inimigo in inimigos.toList()) {
      if (_atingidos.contains(inimigo)) continue;
      if (inimigo.summonTimer > 0 || inimigo.health <= 0) continue;
      final corpo = inimigo.enemyHitbox;
      if (!_alcanca(corpo.absoluteCenter, _raioDe(corpo), varrido)) continue;
      _atingidos.add(inimigo);
      // Mesmos multiplicadores do projétil do jogador; crítico e bônus de
      // elemento já saem de dentro do `Enemy.takeDamage`.
      inimigo.takeDamage(
        dano * Player.danoMult * Player.danoMultDerivado,
        tipoAtacante: tipo,
      );
      inimigo.applyKnockback(dono.absolutePosition, empurrao);
    }

    _refletirProjeteis(varrido);
  }

  /// Fogo amigo do tentáculo inimigo cego: acerta os outros inimigos no
  /// alcance, nunca o dono, sem crítico nem bônus de item.
  void _acertarInimigosAsCegas(double varrido) {
    final inimigos =
        dono.parent?.children.whereType<Enemy>() ?? const <Enemy>[];
    for (final inimigo in inimigos.toList()) {
      if (inimigo == dono || _atingidos.contains(inimigo)) continue;
      if (inimigo.summonTimer > 0 || inimigo.health <= 0) continue;
      final corpo = inimigo.enemyHitbox;
      if (!_alcanca(corpo.absoluteCenter, _raioDe(corpo), varrido)) continue;
      _atingidos.add(inimigo);
      inimigo.takeDamage(dano, tipoAtacante: tipo, doJogador: false);
      inimigo.applyKnockback(dono.absolutePosition, empurrao);
    }
  }

  /// Golpe do JOGADOR rebate tiro inimigo que o tentáculo alcança: o projétil
  /// some e volta pelo caminho de onde veio, agora do lado do jogador (mesma
  /// regra de dano do Casco Fechado, ver `Projectile.refleteProjetil`).
  ///
  /// Nuvens e outros projéteis parados (`speed == 0`) ficam de fora: não há
  /// o que rebater, e o tentáculo apagaria a cortina de tinta do boss.
  void _refletirProjeteis(double varrido) {
    final projeteis =
        dono.parent?.children.whereType<Projectile>() ?? const <Projectile>[];
    for (final tiro in projeteis.toList()) {
      if (!tiro.isEnemy || tiro.speed == 0) continue;
      if (_atingidos.contains(tiro)) continue;
      if (!_alcanca(tiro.absolutePosition, tiro.radius, varrido)) continue;
      _atingidos.add(tiro);
      tiro.refleteProjetil(dono);
      tiro.onDestroy();
    }
  }
}
