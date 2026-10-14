import 'dart:math';
import 'dart:ui' as ui;

import 'package:creatures_rogue/game/components/map/pedestal.dart';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/audio/game_audio.dart';
import 'package:creatures_rogue/game/audio/sfx.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/creature_type.dart';
import 'package:creatures_rogue/game/components/creatures/creature_data.dart';
import 'package:creatures_rogue/game/components/creatures/damageable_by_enemy.dart';
import 'package:creatures_rogue/game/components/effects/dot.dart';
import 'package:creatures_rogue/game/components/enemies/enemy.dart';
import 'package:creatures_rogue/game/components/map/obstacle.dart';
import 'package:creatures_rogue/game/components/map/wall_barrier.dart';
import 'package:creatures_rogue/game/components/map/porta_secreta.dart';
import 'package:creatures_rogue/game/components/player/player.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import 'package:creatures_rogue/game/components/utils/palette_swapper.dart';

/// Como o projétil se desloca a cada quadro.
enum ProjetilMovimento {
  /// Linha reta na [Projectile.direction], a [Projectile.speed] px/s.
  reto,

  /// Espiral que abre a partir do ponto onde nasceu: gira a
  /// [Projectile.velAngular] rad/s enquanto o raio cresce a
  /// [Projectile.speed] px/s.
  ///
  /// `speed` muda de sentido aqui — deixa de ser avanço e vira taxa de
  /// ABERTURA. É de propósito: as duas leituras são "quão rápido ele se
  /// afasta", e um segundo campo só pra isso ficaria nulo em todo projétil
  /// reto do jogo.
  espiral,

  /// Direção copiada de quem atirou, quadro a quadro, com velocidade PRÓPRIA:
  /// o projétil vai pro mesmo lado que o dono está indo, mais rápido que ele.
  /// Dono parado, projétil parado.
  ///
  /// A direção sai da DIFERENÇA de posição do dono entre dois quadros, não da
  /// `velocity` dele. É o que faz o esporo acompanhar também as esquivas, que
  /// se movem por `MoveByEffect` e não encostam em `velocity`.
  dirigidoPeloDono
}

class Projectile extends SpriteAnimationComponent with CollisionCallbacks, HasGameRef {
  final Vector2 direction;

  /// Última posição conhecida do dono, pro modo
  /// [ProjetilMovimento.dirigidoPeloDono]. Semeada no `onLoad` — semear no
  /// construtor pegaria a posição antes de o projétil entrar na árvore.
  final Vector2 _posAnteriorDono = Vector2.zero();

  /// Deslocamento mínimo por quadro (ao quadrado) pra o dono contar como em
  /// movimento.
  static const double _limiarParadoDono = 0.0001;
  double speed;
  bool isEnemy;
  String sprPath;
  Color cor1;
  Color cor2;
  double dmg;
  double kbForce;
  int fragmentos;
  double explosionSize;
  double radius;
  int atravessa;
  bool noChao;
  final CreatureType tipo;
  DotKind? dotKind;
  int dotTicks;
  double lentidaoDuracao;
  double lentidaoFator;
  double stunDuration;
  double cegoDuracao;
  double paralizDuracao;
  bool atravessaObstaculos;

  Map<PositionComponent,double> hits = {};
  final double hitCooldown = 0.3;
  final double? lifeTime;
  double lifeTimeIni = 10;
  double _age = 0;

  final ProjetilMovimento movimento;

  /// Só para [ProjetilMovimento.espiral]: rad/s. Positivo gira no sentido do
  /// relógio (o eixo Y da tela aponta pra baixo).
  final double velAngular;

  /// Centro e estado da espiral. O centro é o ponto de nascimento, capturado
  /// no [onLoad] — depois disso `position` já começou a girar e não serviria
  /// mais de referência.
  late final Vector2 _centroEspiral;
  late double _anguloEspiral;
  double _raioEspiral = 0.0;

  final bool estilhaca;
  final bool playSfx;

  /// `false` faz este projétil ignorar os do lado oposto: nenhum dos dois se
  /// gasta no encontro. É o que uma nuvem que só cega quer — sem isto ela
  /// virava escudo contra tiro sem ninguém ter pedido.
  final bool interageComProjeteis;

  /// Barreira: projétil do lado oposto que encosta some, e este não se gasta
  /// — nem perde pra vantagem de tipo. Ver [_resolverColisaoEntreProjeteis].
  final bool engoleProjeteis;

  /// Giro máximo rumo ao inimigo mais próximo, em rad/s (0 = sem guiamento
  /// próprio). Ver [_guiar].
  final double guiamento;

  /// Tiro que saiu ÀS CEGAS: o inimigo que disparou estava cego no instante
  /// do disparo. Acerta os outros inimigos além do jogador — nunca quem
  /// atirou. Fotografado no nascimento: recuperar a visão depois não chama o
  /// tiro de volta.
  late final bool fogoAmigo;

  final PositionComponent owner;

  /// Criatura por trás do disparo, quando quem atirou é inimigo.
  CreatureData? get _origem {
    final dono = owner;
    return dono is Enemy ? dono.creature : null;
  }

  final double stepTime;

  Projectile({
    required Vector2 position,
    required this.direction,
    required this.owner,
    this.isEnemy = false,
    this.speed = 200,
    this.kbForce = 20,
    this.sprPath = 'projeteis/tiro.png',
    this.stepTime = 0.2,
    this.cor1 = Palette.azul,
    this.cor2 = Palette.verdeEsc,
    this.dmg = 1,
    this.lifeTime,
    this.fragmentos = 0,
    this.explosionSize = 0,
    this.radius = 5,
    this.atravessa = 1,
    this.tipo = CreatureType.neutro,
    this.dotKind,
    this.dotTicks = 1,
    this.lentidaoDuracao = 0,
    this.lentidaoFator = 0.5,
    this.stunDuration = 0,
    this.cegoDuracao = 0,
    this.paralizDuracao = 0,
    this.atravessaObstaculos = false,
    this.movimento = ProjetilMovimento.reto,
    this.velAngular = 3.0,
    this.estilhaca = false,
    this.playSfx = true,
    this.noChao = false,
    this.interageComProjeteis = true,
    this.engoleProjeteis = false,
    this.guiamento = 0.0,
    Vector2? size,
    int priority = 0,
    }): super(
      position: position,
      size: size ?? Vector2(16, 16),
      anchor: Anchor.center,
      priority: priority,
    ) {
    final dono = owner;
    fogoAmigo = isEnemy && dono is Enemy && dono.cegoTimer > 0;
  }

  @override
  Future<void> onLoad() async {
    final sfx = tipo.attackSfx;
    if (sfx != null && playSfx) GameAudio.instance.play(sfx);

    lifeTimeIni = lifeTime ?? 10;

    _centroEspiral = position.clone();
    // Começa apontando pra `direction`, então a espiral abre no sentido em que
    // o projétil foi lançado em vez de sempre pra direita. `Vector2.zero()`
    // cai em ângulo 0, que é o comportamento certo pra quem não tem direção.
    _anguloEspiral = atan2(direction.y, direction.x);

    final ui.Image img = await PaletteSwapper.createSwappedImage(
      imagePath: sprPath,
      lightGrayReplacement: cor1,
      darkGrayReplacement: cor2,
    );
    animation = SpriteAnimation.fromFrameData(
      img,
      SpriteAnimationData.sequenced(amount: (img.width/img.height).toInt(), stepTime: stepTime, textureSize: Vector2(16, 16)),
    );

    paint = Paint()..filterQuality = FilterQuality.none;
    angle = direction.screenAngle();
    // Semeado aqui e não no construtor: só depois de montado o `owner` tem
    // posição final, e a primeira diferença precisa dar zero em vez de um
    // salto do projétil no primeiro quadro.
    _posAnteriorDono.setFrom(owner.position);
    add(CircleHitbox(collisionType: CollisionType.active,radius: radius,anchor: Anchor.center,position: size/2));
    //debugMode = true;
  }

  void onDestroy(){
    if(fragmentos > 0){
      for (int i = 0; i < fragmentos; i++) {
        double angle = Random().nextDouble() * 2 * pi;
        Vector2 dir = Vector2(cos(angle), sin(angle));
        parent?.add(Projectile(
          owner: owner, 
          position: position.clone(),
          direction: dir,
          speed: speed,
          dmg: dmg,
          kbForce: kbForce,
          lifeTime: lifeTime,
          sprPath: sprPath,
          cor1: cor1,
          cor2: cor2,
          isEnemy: isEnemy,
          tipo: tipo,
          dotKind: dotKind,
          dotTicks: dotTicks,
          stunDuration: stunDuration,
          playSfx: false,
        ));
      }
    }
    if(explosionSize > 0){
      parent?.add(ExplosionHitbox(
        position: position.clone(),
        size:Vector2(explosionSize, explosionSize),
        tipo: tipo,
        isEnemy: isEnemy,
        origem: _origem,
        dono: owner,
        forcarFogoAmigo: fogoAmigo,
      ));
    }

    if(estilhaca){
      final anguloRad = 20 * pi / 180;
      for (final offset in [-anguloRad, 0.0, anguloRad]) {
        final rotated = direction.clone()..rotate(offset);
          parent?.add(Projectile(
          owner: owner,
          position: position.clone(),
          direction: rotated*-1,
          speed: speed,
          dmg: dmg,
          lifeTime: lifeTime,
          sprPath: sprPath,
          cor1: cor1,
          cor2: cor2,
          isEnemy: isEnemy,
          tipo: tipo,
          playSfx: false,
        ));
      }

    }

    removeFromParent();
  }

  @override
  void update(double dt) {
    super.update(dt);

    switch (movimento) {
      case ProjetilMovimento.reto:
        _guiar(dt);
        position += direction * speed * dt;
      case ProjetilMovimento.espiral:
        _anguloEspiral += velAngular * dt;
        _raioEspiral += speed * dt;
        position = _centroEspiral +
            Vector2(cos(_anguloEspiral), sin(_anguloEspiral)) * _raioEspiral;
      case ProjetilMovimento.dirigidoPeloDono:
        final deslocamento = owner.position - _posAnteriorDono;
        _posAnteriorDono.setFrom(owner.position);
        // Limiar pra tremor de analógico não virar direção: abaixo disto o
        // dono conta como parado, e o projétil para junto.
        if (deslocamento.length2 > _limiarParadoDono) {
          direction.setFrom(deslocamento.normalized());
          angle = direction.screenAngle();
        } else {
          break;
        }
        position += direction * speed * dt;
    }

    if (hits.isNotEmpty) {
      hits.updateAll((enemy, timeRestante) => timeRestante - dt);
      hits.removeWhere((enemy, timeRestante) => timeRestante <= 0);
    }

    if (lifeTime != null) {
      _age += dt;
      if (_age >= lifeTime!) onDestroy();
    }
  }


  //@override
  //void render(Canvas canvas) {
  //  super.render(canvas);
  //  canvas.drawCircle(Offset(size.x/2,size.y/2), radius, Paint()..color=Palette.rosa..style = PaintingStyle.stroke..strokeWidth = 1.25..filterQuality = FilterQuality.none);
  //}

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    
    // Parede rachada da sala secreta: golpe do jogador conta, tiro inimigo
    // só se desfaz nela, como numa parede.
    if (other is PortaSecreta && !other.isOpen && !atravessaObstaculos) {
      if (!isEnemy) other.atingir();
      onDestroy();
      return;
    }

    if ((other is WallBarrier || other is Rock || other is PedestalComponent) && !atravessaObstaculos) {
      onDestroy();
      return; 
    }

    if((noChao && (other is Projectile && !other.noChao))
    ||(!noChao && (other is Projectile && other.noChao))
    ){
      return;
    }

    if (isEnemy) {
      if(other is Projectile && !other.isEnemy){
        _resolverColisaoEntreProjeteis(other);
        return;
      }
      if (fogoAmigo && other is Enemy && other != owner) {
        _acertarAsCegas(other);
        return;
      }
      
      if (other is DamageableByEnemy) {
        if(noChao && other is Player && other.isAirborne){
          return;
        }
        // Enterrado, o jogador não está na linha de tiro — e `takeDamage`
        // recusar o dano aqui em cima não bastaria: o `atravessa--` logo
        // abaixo ainda apagaria o projétil, que sumiria no ar em cima de uma
        // sombra vazia. Vale pra tiro de qualquer altura, ao contrário do
        // `isAirborne` acima (só `noChao`), porque não há altura de tiro que
        // alcance quem está debaixo da terra.
        if (other is Player && other.submerso) {
          return;
        }
        if(other.refleteProjetil){
          refleteProjetil(other);
          onDestroy();
        }
        if (lentidaoDuracao > 0) other.aplicarLentidao(lentidaoDuracao, fator: lentidaoFator);
        if (cegoDuracao > 0) other.aplicarCegueira(cegoDuracao);

        if (dmg > 0) {
          other.takeDamage(dmg, tipo, origem: _origem);
          atravessa--;
          if (atravessa <= 0) onDestroy();
        }
      }
    } else {
      if(other is Projectile && other.isEnemy){
        _resolverColisaoEntreProjeteis(other);
        return;
      }
      if (other is Enemy) {
        if(other.summonTimer > 0) return;
        if (hits.containsKey(other)) {
          return; 
        }
        if (!other.enemyHitbox.toAbsoluteRect().overlaps(toAbsoluteRect())) {
          return; 
        }
        hits[other] = hitCooldown;
        final kind = dotKind;
        if (kind != null) other.applyDot(kind, dotTicks);
        if (lentidaoDuracao > 0) other.applyLentidao(lentidaoDuracao, fator: lentidaoFator);
        if (cegoDuracao > 0) other.applyCego(cegoDuracao);
        if (paralizDuracao > 0) other.applyParalise(paralizDuracao);
        if (stunDuration>0){
          other.applyStun(stunDuration);
        }
        
        // `dmg > 0`, mesma guarda do `ExplosionHitbox`: nuvem de dano zero
        // (tinta, fumaça) só aplica status. Sem isso cada inimigo na nuvem
        // levava um "0.0", um `Sfx.hit` e uma rolagem de crítico — que
        // alimentava `SangueFrio` e disparava os ganchos de `aoCritar` por
        // um golpe que não existiu.
        if (dmg > 0) {
          other.takeDamage(
            dmg * Player.danoMult * Player.danoMultDerivado,
            tipoAtacante: tipo,
          );
          other.applyKnockback(absolutePosition, kbForce);
        }
        atravessa--;
        if (atravessa <= 0) onDestroy();
        
      }
    }
  }

  /// Fogo amigo: o tiro às cegas atinge outro inimigo com o mesmo efeito que
  /// teria no jogador. `doJogador: false` deixa crítico e bônus de item de
  /// fora — o golpe não é dele.
  void _acertarAsCegas(Enemy alvo) {
    if (alvo.summonTimer > 0 || hits.containsKey(alvo)) return;
    if (!alvo.enemyHitbox.toAbsoluteRect().overlaps(toAbsoluteRect())) return;
    hits[alvo] = hitCooldown;
    if (lentidaoDuracao > 0) {
      alvo.applyLentidao(lentidaoDuracao, fator: lentidaoFator);
    }
    if (cegoDuracao > 0) alvo.applyCego(cegoDuracao);
    if (dmg > 0) {
      alvo.takeDamage(dmg, tipoAtacante: tipo, doJogador: false);
      alvo.applyKnockback(absolutePosition, kbForce);
      atravessa--;
      if (atravessa <= 0) onDestroy();
    }
  }

  /// Curva rumo ao inimigo mais próximo, quando o dono é o jogador e algum
  /// item liga o guiamento (ver `Telecinese`) — ou quando o próprio projétil
  /// nasceu guiado ([guiamento] > 0, ex.: os bichos do `Enxame`).
  ///
  /// Gira no máximo `taxa * dt` por quadro: curva, não teleporta pra mira.
  /// Projétil parado (nuvem, poça) não tem o que girar.
  void _guiar(double dt) {
    if (speed == 0 || isEnemy) return;
    final dono = owner;
    final taxa = guiamento > 0
        ? guiamento
        : dono is Player
        ? dono.guiamentoTiros
        : 0.0;
    if (taxa <= 0) return;

    Enemy? alvo;
    var melhor = _alcanceGuiamento * _alcanceGuiamento;
    for (final e in parent?.children.whereType<Enemy>() ?? const <Enemy>[]) {
      if (e.health <= 0 || e.summonTimer > 0) continue;
      final d2 = e.absolutePosition.distanceToSquared(absolutePosition);
      if (d2 < melhor) {
        melhor = d2;
        alvo = e;
      }
    }
    if (alvo == null) return;

    final atual = atan2(direction.y, direction.x);
    final rumo = alvo.absolutePosition - absolutePosition;
    final desejado = atan2(rumo.y, rumo.x);
    var diff = desejado - atual;
    while (diff > pi) {
      diff -= 2 * pi;
    }
    while (diff < -pi) {
      diff += 2 * pi;
    }
    final passo = diff.clamp(-taxa * dt, taxa * dt);
    final novo = atual + passo;
    direction.setValues(cos(novo), sin(novo));
    angle = direction.screenAngle();
  }

  /// Até onde o guiamento procura alvo.
  static const double _alcanceGuiamento = 110.0;

  /// Cada lado do encontro chama isto pra SI MESMO (o Flame dispara o
  /// `onCollisionStart` nos dois), então aqui só se decide o destino deste.
  void _resolverColisaoEntreProjeteis(Projectile other) {
    if (!interageComProjeteis || !other.interageComProjeteis) return;
    if (other.engoleProjeteis) {
      onDestroy();
      return;
    }
    if (engoleProjeteis) return;
    if (typeMultiplier(tipo, other.tipo) > 1.0) return;
    atravessa-=1;
    if(atravessa<=0)onDestroy();
  }

  void refleteProjetil(PositionComponent owner) {
    var dano = dmg;
    if (owner is Player){
      dano = owner.creatureData.stats.ataque;
    }
    parent?.add(Projectile(
          owner: owner,
          position: position.clone(),
          direction: direction.clone()*-1,
          speed: speed,
          dmg: dano,
          kbForce: kbForce,
          lifeTime: lifeTimeIni,
          sprPath: sprPath,
          cor1: cor1,
          cor2: cor2,
          tipo: tipo, 
        ));
  }
}
