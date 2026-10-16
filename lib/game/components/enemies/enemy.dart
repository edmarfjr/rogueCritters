import 'package:creatures_rogue/game/pactos.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import 'package:creatures_rogue/game/components/enemies/aura_campeao.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:creatures_rogue/game/components/enemies/enemy_mixins.dart';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/audio/game_audio.dart';
import 'package:creatures_rogue/game/audio/game_music.dart';
import 'package:creatures_rogue/game/creatures_rogue_game.dart';
import 'package:creatures_rogue/game/audio/sfx.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/creature_data.dart';
import 'package:creatures_rogue/game/components/creatures/creature_progress.dart';
import 'package:creatures_rogue/game/components/creatures/creature_type.dart';
import 'package:creatures_rogue/game/components/creatures/movement_host.dart';
import 'package:creatures_rogue/game/components/effects/condition_icons.dart';
import 'package:creatures_rogue/game/components/effects/dot.dart';
import 'package:creatures_rogue/game/components/effects/movement_animator.dart';
import 'package:creatures_rogue/game/components/effects/sprite_effect.dart';
import 'package:creatures_rogue/game/components/effects/text_effect.dart';
import 'package:creatures_rogue/game/components/map/door.dart';
import 'package:creatures_rogue/game/components/map/obstacle.dart';
import 'package:creatures_rogue/game/components/map/wall_barrier.dart';
import 'package:creatures_rogue/game/components/projeteis/projectile.dart';
import 'package:creatures_rogue/game/game_settings.dart';
import 'package:creatures_rogue/l10n/creature_i18n.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';
import '../items/xp_pickup.dart';
import '../player/player.dart';
import '../utils/palette_swapper.dart';
import '../utils/y_sort.dart';

/// Os três sabores de inimigo campeão. Cada um acrescenta UMA regra em cima do
/// campeão base (maior, mais vida, mais XP) — e é a cor da aura no chão (ver
/// `AuraCampeao`) que diz ao jogador qual é, antes de ele descobrir apanhando.
enum CampeaoTipo {
  /// Aguenta empurrão. Sem isto, todo campeão era empurrável igual e o "tanque"
  /// não existia como papel.
  couracado(Palette.indigo),

  /// Bem mais rápido, sem vida extra além da do campeão base. O oposto do
  /// couraçado: não é esponja, é ameaça.
  veloz(Palette.amarelo),

  /// Explode ao morrer. Pune matar de perto e muda o posicionamento sem
  /// precisar de IA nova.
  explosivo(Palette.vermelho);

  const CampeaoTipo(this.corAura);

  /// Cor do anel no chão. NÃO é a cor do corpo: aquela pertence ao elemento da
  /// criatura (ver a doc de `AuraCampeao`).
  final Color corAura;
}

abstract class Enemy extends PositionComponent
    with
        CollisionCallbacks,
        HasGameReference,
        MovementHost,
        WanderMovement,
        ChaseMovement {
  final Player playerTarget;

  @override
  double speed;
  double health;

  /// Vida com que este inimigo nasceu. Só serve pra calcular fração de vida
  /// (barra de boss) — nada no jogo cura inimigo, então nunca muda.
  /// Não é `final`: a promoção a campeão (ver [promoverACampeao]) acontece
  /// depois do construtor e precisa reescrever os dois valores de vida.
  late double maxHealth;

  int dmg;

  /// Setado de fora (ver `CreaturesRogueGame._buildRunBoss`) só pra este
  /// inimigo dar mais XP de evolução na morte — não muda nenhum outro
  /// comportamento (vida/dano de boss já vêm tunados por classe).
  bool ehBoss = false;

  /// Inimigo campeão: versão reforçada de um inimigo comum, sorteada no
  /// nascimento da sala (ver `RoomComponent._spawnEnemies`).
  ///
  /// Não é um tipo de inimigo à parte — é o MESMO inimigo com os números
  /// mexidos depois de construído. Tinha que ser assim: cada criatura tem seu
  /// `enemyBuilder` chamando o construtor com tamanho e vida já fixos, e são
  /// 34 deles.
  bool ehCampeao = false;

  /// Quanto o campeão cresce, no visual e na hitbox. 1,5 em cima dos 16px
  /// padrão dá 24 — grande o bastante pra notar, e longe dos 32 que os bosses
  /// usam, pra não ler como boss.
  static const double campeaoEscala = 1.3;

  static const double campeaoVidaMult = 1.5;

  /// Fração do empurrão que o campeão ainda sofre. Reduz em vez de anular
  /// (o boss anula, ver [applyKnockback]): empurrão zero faria o campeão
  /// parecer um boss pequeno.
  static const double campeaoEmpurraoFator = 0.5;

  /// Piso de XP do campeão. Inimigo comum solta `nextInt(3)`, que dá ZERO uma
  /// vez em três — num campeão isso seria matar um bicho raro e reforçado pra
  /// receber nada. O piso é o ponto todo da recompensa; o teto importa menos.
  static const int campeaoXpMin = 3;

  /// Transforma este inimigo num campeão. Chamar ANTES de montar na árvore:
  /// `onLoad` lê `size`, `hitboxSize` e `shadowOffset` pra construir sprite,
  /// hitbox e sombra, e depois disso mexer neles não reconstrói nada.
  ///
  /// REGRA: aqui só se mexe em DADO — `size`, `hitboxSize`, `shadowOffset`,
  /// vida e velocidade. NUNCA nos componentes que o `onLoad` cria (`visual`,
  /// `shadow`, `shieldVisual`, `conditionIcons`, `aura`): como isto roda
  /// antes dele, esses campos ainda não existem, e tocá-los estoura
  /// `LateInitializationError` no meio do `update` — o jogo trava, e trava
  /// só na sala que sorteou campeão, o que faz parecer aleatório.
  ///
  /// Não é preciso ajustar a sombra na mão: o `onLoad` calcula o raio dela
  /// como `hitboxSize.x / 2`, e a hitbox já foi escalada duas linhas acima.
  void promoverACampeao(CampeaoTipo tipo) {
    assert(
      !isLoaded,
      'promoverACampeao precisa rodar antes do onLoad — ver a regra na doc.',
    );
    if (ehCampeao || ehBoss) return;
    ehCampeao = true;
    campeaoTipo = tipo;

    size.scale(campeaoEscala);
    hitboxSize.scale(campeaoEscala);
    shadowOffset.scale(campeaoEscala);

    health *= campeaoVidaMult;
    maxHealth = health;

    if (tipo == CampeaoTipo.veloz) {
      // Os dois campos: `speed` é a velocidade de agora e `speedBase` é pra
      // onde a lentidão devolve quando passa. Mexer só num deixaria o campeão
      // veloz lento pra sempre depois do primeiro efeito de lentidão.
      speed *= campeaoVelocidadeMult;
      speedBase = speed;
    }
  }

  /// Qual campeão este inimigo é. `null` enquanto [ehCampeao] for falso.
  CampeaoTipo? campeaoTipo;

  static const double campeaoVelocidadeMult = 1.6;

  /// Dano da explosão do campeão [CampeaoTipo.explosivo], em cima do `dmg` de
  /// contato dele — não é um número solto: um inimigo que bate forte explode
  /// forte.
  static const double campeaoExplosaoCoef = 1.5;
  static const double campeaoExplosaoRaio = 24.0;

  double bltSpeed;
  String bltImg;
  Color bltCor1;
  Color bltCor2;

  Color corClara;
  Color corEscura;
  Color corBranco;
  late Vector2 hitboxSize;
  late Vector2 shadowOffset;
  @override
  late RectangleHitbox enemyHitbox;
  @override
  late RectangleHitbox physicsHitbox;

  /// A criatura que este inimigo é. Quando passada, fornece sprite, cores,
  /// hitbox e estilo de animação — a subclasse só precisa codificar
  /// COMPORTAMENTO. Stats (speed/health/dmg) continuam tunados à mão por
  /// classe, usando `creature.stats` apenas como referência de projeto.
  final CreatureData? creature;

  /// Satisfaz o contrato de `ShooterAttack` (ver `enemy_mixins.dart`) pra
  /// quem usa esse mixin — não precisa reimplementar por inimigo, já que o
  /// som é sempre o do tipo elemental da própria criatura.
  Sfx? get attackSfx => creature?.tipo.attackSfx;

  final String spritePath;

  @override
  late final SpriteComponent visual;
  late final Vector2 _visualBasePosition;
  late final CircleComponent shadow ;
  // `isAirborne` vem de MovementHost; valor inicial é atribuído no corpo do
  // construtor (ver abaixo), já que `this.isAirborne` shorthand só funciona
  // pra campo declarado na própria classe.

  late final SpriteComponent shieldVisual;
  /// Inerte por causa de uma cena (ver `BossCutscene`): não pensa, não anda e
  /// não ataca.
  ///
  /// Campo próprio em vez de reaproveitar `paralisedTimer`/`stunTimer`: os dois
  /// acendem ícone de condição em cima do inimigo, e aqui não há condição
  /// nenhuma — é a luta que ainda não começou. `stunTimer` além disso ainda
  /// chama `updateWanderMovement`, ou seja, o inimigo continuaria vagando.
  bool emCutscene = false;

  bool shieldVisualActive = false;

  late final ConditionIcons conditionIcons;

  /// Estilo de animação de movimento (ver MovementAnimator). Null = inimigo
  /// sem animação genérica de movimento — ou porque o próprio mecanismo de
  /// movimento já é a animação (ex.: JumpMovement, que pula de verdade), ou
  /// porque ele nunca se move (ex.: boneco de treino).
  final MovementAnimation? moveAnim;
  MovementAnimator? _moveAnimator;

  /// Se false, o inimigo não é empurrado por outros inimigos (planta, torreta...)
  bool isPushable;

  // `knockbackVelocity` vem de MovementHost.

  /// Gancho usado por habilidades de controle de grupo (ex.: Corrente
  /// Estática). Enquanto > 0, o inimigo não chama `movimento`.
  double stunTimer = 0.0;
  double paralisedTimer = 0.0;
  double fearTimer = 0.0;

  /// Gancho de guarda defensiva (ex.: casco fechado da tartaruga). Neutro por
  /// padrão: 0.0 não muda nada. Lido em `takeDamage`.
  double damageReduction = 0.0;

  /// Danos ao longo do tempo ativos, no máximo um por variante — reaplicar
  /// veneno em cima de veneno acumula ticks no mesmo Dot em vez de criar um
  /// segundo. Ver [Dot].
  final Map<DotKind, Dot> dots = {};

  /// Lentidão: enquanto > 0, a velocidade efetiva é [speed] * [lentidaoFator].
  /// Reaplicar renova a duração e mantém o fator mais forte — nunca multiplica
  /// um sobre o outro, senão duas aplicações travam o inimigo de vez.
  /// `lentidaoFator` vem de MovementHost.
  double lentidaoTimer = 0.0;

  // `cegoTimer` vem de MovementHost. Cegueira: enquanto > 0, o inimigo perde
  // o rastro do jogador — quem persegue passa a andar a esmo e quem atira
  // para de mirar. Ver ChaseMovement e ShooterAttack.

  /// Velocidade sem lentidão, fotografada no construtor. Os mixins de
  /// movimento leem [speed] direto todo frame, então a lentidão escreve nele;
  /// sem uma base pra restaurar, duas aplicações sobrepostas corromperiam a
  /// velocidade permanentemente.
  ///
  /// NÃO é `final`, pelo mesmo motivo do [maxHealth]: a promoção a campeão
  /// (ver [promoverACampeao]) acontece depois do construtor e reescreve a
  /// velocidade do campeão VELOZ. Como `late final`, essa segunda escrita
  /// estourava `LateInitializationError` em pleno `update` — e só nele, o que
  /// fazia o travamento parecer aleatório: só acontecia na sala que sorteava
  /// campeão E tirava justamente o tipo veloz.
  late double speedBase;

  /// Relógio do pisca-pisca de vida baixa (< 30% de maxHealth). Só avança
  /// enquanto a condição vale; ver `update`.
  double _lowHpBlinkClock = 0.0;

  double summonTimer = 1.0;

  /// Anel do campeão. `null` em inimigo comum — era `late final`, e como só
  /// é atribuído pra campeão, qualquer leitura num inimigo comum estourava
  /// `LateInitializationError` em tempo de execução, sem o analisador ver.
  AuraCampeao? aura;

  Enemy({
    required Vector2 position,
    required this.playerTarget,
    this.creature,
    String? spritePath,
    Color? corClara,
    Color? corEscura,
    MovementAnimation? moveAnim,
    this.speed = 30.0,
    this.health = 1,
    this.dmg = 1,
    this.bltSpeed = 75,
    bool isAirborne = false,
    bool pulando = false,
    this.bltCor1 = Palette.vermelho,
    this.bltCor2 = Palette.laranja,
    this.bltImg = 'projeteis/tiro2.png',
    this.isPushable = true,
    this.corBranco = Palette.branco,
    Vector2? size,
    Vector2? hitboxSize,
    Vector2? shadowOffset,
  }) : spritePath = spritePath ?? creature?.spritePath ?? 'actors/dummy.png',
       corClara = corClara ?? creature?.corClara ?? Palette.cinza,
       corEscura = corEscura ?? creature?.corEscura ?? Palette.cinzaEsc,
       moveAnim = moveAnim ?? creature?.moveAnim,
       super(
         position: position,
         size: size ?? Vector2(16, 16), // Tamanho VISUAL padrão
         anchor: Anchor.center,
       ) {
    maxHealth = health;
    speedBase = speed;
    this.isAirborne = isAirborne;
    this.pulando = pulando;

    // Hitbox: explícita > da criatura > tamanho visual.
    //
    // `.clone()` NÃO é zelo: `creature.hitboxSize` é um `Vector2` de um
    // `CreatureData` que mora num `static final` do registro, e portanto é o
    // MESMO objeto pra todo inimigo da espécie e pro jogador quando ele usa
    // essa criatura. Sem a cópia, o `hitboxSize.scale()` da promoção a
    // campeão reescrevia o registro: a espécie inteira ficava maior daquele
    // ponto da run em diante, multiplicando de novo a cada campeão novo, e a
    // hitbox do próprio jogador crescia junto.
    this.hitboxSize =
        (hitboxSize ?? creature?.hitboxSize ?? (size ?? Vector2(16, 16)))
            .clone();
    this.shadowOffset = (shadowOffset ?? Vector2.zero()).clone();
  }

  /// O jogador — alvo fixo de todo `Enemy` (ver PIVOT_TREINADOR.md §3.4).
  @override
  PositionComponent get currentTarget => playerTarget;

  /// Última posição em que este inimigo VIU o jogador — gravada no instante
  /// em que fica cego e atualizada quando o jogador o acerta (o golpe
  /// denuncia de onde veio). Sem cegueira não é usada.
  Vector2? _posicaoVista;

  /// Pra onde o inimigo mira, anda, pula e golpeia. Sem cegueira, o jogador;
  /// cego, o ponto onde o viu por último — ele continua atacando, só que no
  /// lugar errado. É isso que separa a cegueira do atordoado, que desliga a
  /// IA. Toda mira dos inimigos passa por aqui, nunca por
  /// `playerTarget.absolutePosition` direto.
  Vector2 get alvoPosicao {
    final vista = _posicaoVista;
    if (cegoTimer > 0 && vista != null) return vista.clone();
    return playerTarget.absolutePosition;
  }

  @override
  Vector2 get posicaoDoAlvo => alvoPosicao;

  @override
  Future onLoad() async {
    // Pactos `Couro Grosso` e `Chefe Implacável`: aqui, depois de uma
    // eventual promoção a campeão, que também mexe na vida.
    final multVida =
        Pactos.multVidaInimigo * (ehBoss ? Pactos.multVidaChefe : 1.0);
    if (multVida != 1.0) {
      health *= multVida;
      maxHealth = health;
    }
    final ui.Image enemyImage = await PaletteSwapper.createSwappedImage(
      imagePath: spritePath,
      lightGrayReplacement: corClara,
      darkGrayReplacement: corEscura,
      whiteReplacement: corBranco,
    );

    _visualBasePosition = Vector2(size.x / 2, size.y);
    final anim = moveAnim;
    if (anim != null) _moveAnimator = MovementAnimator(anim);

    visual = SpriteComponent(
      sprite: Sprite(enemyImage),
      size: size,
      anchor: Anchor.bottomCenter,
      position: _visualBasePosition.clone(),
      paint: Paint()..filterQuality = FilterQuality.none,
    );
    add(visual);

    final ui.Image shieldImage = await PaletteSwapper.createSwappedImage(
      imagePath: 'projeteis/bolha.png',
      lightGrayReplacement: corClara,
      darkGrayReplacement: corEscura,
      whiteReplacement: corBranco,
    );
    shieldVisual = SpriteComponent(
      sprite: Sprite(shieldImage),
      size: Vector2.all(24),
      anchor: Anchor.center,
      position: size / 2,
      paint: Paint()..filterQuality = FilterQuality.none,
      priority: 5,
    );
    shieldVisual.setOpacity(0.0); // só aparece enquanto shieldVisualActive
    add(shieldVisual);

    conditionIcons = ConditionIcons()..position = Vector2(size.x / 2, -2);
    add(conditionIcons);

    enemyHitbox = RectangleHitbox(
      size: hitboxSize,
      anchor: Anchor.bottomCenter,
      position: _visualBasePosition,
      collisionType: CollisionType.active,
    );
    add(enemyHitbox);

    physicsHitbox = RectangleHitbox(
      size: Vector2(hitboxSize.x, hitboxSize.x * 0.5),
      anchor: Anchor.center,
      position: size / 2 + Vector2(0, hitboxSize.y / 2) + shadowOffset,
      collisionType: CollisionType.active,
    );
    add(physicsHitbox);

    final shadowPaint = Paint()
      ..color = Palette.preto; // Preto com 40% de opacidade

    shadow = CircleComponent(
      radius: hitboxSize.x / 2, // O raio é metade da largura da Hitbox
      anchor: Anchor.center,
      position: _visualBasePosition + shadowOffset,
      paint: shadowPaint,
      priority: -1,
    )..scale = Vector2(1.0, 0.75);

    add(shadow);

    final tipo = campeaoTipo;
    if (tipo != null) {
      final novaAura = AuraCampeao(
          cor: tipo.corAura,
          // Some junto com o corpo durante a invocação — ver a doc de
          // `AuraCampeao.visivel`.
          visivel: () => summonTimer <= 0,
          // Um pouco maior que a sombra pra emoldurar o corpo em vez de
          // ficar escondido embaixo dele.
          raioBase: hitboxSize.x / 2 + 3,
          position: _visualBasePosition + shadowOffset,
        );
      aura = novaAura;
      add(novaAura);
    }
  }

  @override
  void update(double dt) {
    // Relógio Parado: o tempo do inimigo inteiro anda mais devagar —
    // movimento, pulo, recarga de ataque e os efeitos filhos dele. Escalar o
    // `dt` aqui alcança todo comportamento de uma vez, inclusive os que não
    // usam `speed` (quem pula, quem tem cronômetro de ataque).
    dt *= playerTarget.tempoInimigos * Pactos.multTempoInimigo;
    super.update(dt);

    // Anchor.center: o "chão" (pés) fica meio size.y abaixo do centro.
    priority = ySortPriority(position.y + size.y / 2);

    if(summonTimer>0){
      summonTimer -= dt;
      // Fim do surgimento: é aí que o campeão "chega" — antes disso o som
      // brigaria com o da sala trancando, que toca no mesmo instante.
      if (summonTimer <= 0 && ehCampeao) GameAudio.instance.play(Sfx.campeao);
      return;
    }

    // Pisca vermelho com vida abaixo de 30%. Roda independente de stun/raiz/
    // knockback — é indicador de vida, não movimento — mas só enquanto o
    // inimigo está vivo, senão `death()` já matou o componente.
    if (health > 0 && (health / maxHealth) < 0.3) {
      _lowHpBlinkClock += dt;
      visual.paint.colorFilter = (_lowHpBlinkClock % 0.4) < 0.2
          ? const ColorFilter.mode(Palette.vermelho, BlendMode.srcATop)
          : null;
    } else if (_lowHpBlinkClock != 0.0) {
      _lowHpBlinkClock = 0.0;
      visual.paint.colorFilter = null;
    }
    shieldVisual.setOpacity(shieldVisualActive ? 1.0 : 0.0);

    // Condições correm ANTES dos returns de knockback e stun. Se ficassem no
    // fim, um atordoamento de 1.5s comeria uma queimadura inteira (0.7s) sem
    // ela tickar uma vez — o veneno antigo escondia isso por durar 3s.
    updateCondicoes(dt);
    // Um tick de DoT pode ter matado o inimigo. `removeFromParent` só tira o
    // componente no fim do frame, então `isMounted` ainda estaria true aqui —
    // a vida é o teste confiável.
    if (health <= 0) return;
    conditionIcons.stunAtivo = stunTimer > 0;
    conditionIcons.venenoAtivo = dots.containsKey(DotKind.veneno);
    conditionIcons.queimaduraAtivo = dots.containsKey(DotKind.queimadura);
    conditionIcons.lentidaoAtivo = lentidaoTimer > 0;
    conditionIcons.cegoAtivo = cegoTimer > 0;
    conditionIcons.paralisadoAtivo = paralisedTimer > 0;
    conditionIcons.medoAtivo = fearTimer > 0;

    if (!knockbackVelocity.isZero()) {
      position += knockbackVelocity * dt;

      double drop = 120.0 * dt; // Atrito
      if (knockbackVelocity.length < drop) {
        knockbackVelocity.setZero();
      } else {
        knockbackVelocity -= knockbackVelocity.normalized() * drop;
      }
      return; // Pula o método de movimento, o inimigo não "pensa" enquanto voa pra trás
    }

    if (emCutscene) return;

    if (paralisedTimer > 0) {
      paralisedTimer -= dt;
      return;
    }
    if (stunTimer > 0) {
      stunTimer -= dt;
      updateWanderMovement(dt, minPause: 0.2, maxPause: 0.5,minMove: 0.2, maxMove: 0.5);
      return;
    }
    if (fearTimer > 0) {
      fearTimer -= dt;
      updateChaseMovement(dt, velAux: -1.0);
      return;
    }
    movimento(dt);
  }

  static final Paint _hpBarraMoldura = Paint()..color = Palette.preto;
  static final Paint _hpBarraFundo = Paint()..color = Palette.cinzaEsc;
  static const double _hpBarraLargura = 14.0;
  static const double _hpBarraAltura = 2.0;

  void _renderBarraVida(Canvas canvas) {
    final porcentagem = (health / maxHealth);
    final left = (size.x - _hpBarraLargura) / 2;
    final top = -4.0;

    Paint hpBarraPreenchimento = Paint()
      ..color = (health / maxHealth) < 0.3 ? Palette.vermelho : Palette.verde;

    canvas.drawRect(
      Rect.fromLTWH(left - 1, top - 1, _hpBarraLargura + 2, _hpBarraAltura + 2),
      _hpBarraMoldura,
    );
    canvas.drawRect(
      Rect.fromLTWH(left, top, _hpBarraLargura, _hpBarraAltura),
      _hpBarraFundo,
    );
    canvas.drawRect(
      Rect.fromLTWH(left, top, _hpBarraLargura * porcentagem, _hpBarraAltura),
      hpBarraPreenchimento,
    );
  }

  @override
  void render(Canvas canvas) {
    if(summonTimer>0){
      visual.setOpacity(0);
      shadow.setOpacity(0);
      canvas.drawCircle(Offset(size.x/2,size.y/2), size.x * summonTimer / 1, Paint()..color = Palette.vermelho..style = PaintingStyle.stroke..strokeWidth=1.0..isAntiAlias = false);
      return;
    }else{
      if(visual.opacity == 0){
        visual.setOpacity(1.0);
        shadow.setOpacity(1.0);
        final effect = SpriteEffect(
          position: position.clone(),
          size: Vector2(24, 24),
          corClara: Palette.cinza,
          corEscura: Palette.indigo,
          corBranco: Palette.branco,
          spritePath: 'effects/summon.png',
          textureSize: Vector2(24, 24),
        );
        effect.priority = priority + 10;
        parent?.add(effect);
      }
    }
    super.render(canvas);
    
    if(!ehBoss)_renderBarraVida(canvas);
  }

  void applyDot(DotKind kind, int ticks) {
    if (ticks <= 0) return;
    final atual = dots[kind];
    if (atual == null) {
      dots[kind] = Dot.criar(kind, ticks);
    } else {
      atual.reaplicar(ticks);
    }
  }

  /// Reaplicar renova a duração e fica com a maior — nunca sobrescreve seco,
  /// mesma regra de [applyLentidao] logo abaixo. Sem isso, duas retaliações
  /// de passiva atordoando no mesmo frame (ver PIVOT_TREINADOR.md) deixavam
  /// a duração final depender só da ordem de processamento da lista.
  void applyStun(double t) {
    if (stunTimer <= 0 && t > 0) GameAudio.instance.play(Sfx.atordoado);
    stunTimer = t > stunTimer ? t : stunTimer;
  }

  void applyParalise(double t) {
    paralisedTimer = t > paralisedTimer ? t : paralisedTimer;
  }

  /// [fator] é a fração da velocidade original (0.5 = metade). Reaplicar
  /// renova a duração e fica com o fator mais forte, nunca multiplica um
  /// sobre o outro.
  void applyLentidao(double duracao, {double fator = 0.5}) {
    lentidaoTimer = duracao > lentidaoTimer ? duracao : lentidaoTimer;
    lentidaoFator = fator < lentidaoFator ? fator : lentidaoFator;
    speed = speedBase * lentidaoFator;
  }

  /// [vista] é o ponto que fica gravado como "onde viu o jogador". Sem ele,
  /// a posição atual do jogador — quem passa outro é a `Piscadela`, que cega
  /// depois de um teleporte e precisa do ponto de PARTIDA.
  void applyCego(double duracao, {Vector2? vista}) {
    // Só grava ao FICAR cego: renovar a cegueira não pode atualizar o ponto,
    // senão uma nuvem reaplicando a cada quadro seguiria o jogador.
    if (cegoTimer <= 0) {
      _posicaoVista = vista?.clone() ?? playerTarget.absolutePosition;
    }
    if (duracao > cegoTimer) cegoTimer = duracao;
  }

  void updateCondicoes(double dt) {
    // Cópia da lista: um tick pode remover o Dot ou matar o inimigo.
    for (final dot in dots.values.toList()) {
      dot.timer -= dt;
      if (dot.timer > 0) continue;

      dot.ticks--;
      dot.timer = dot.intervalo;
      if (dot.ticks <= 0) dots.remove(dot.kind);

      takeDamage(
        dot.dano,
        corTxt: dot.cor,
        tipoAtacante: dot.tipo,
        revela: false,
      );
      if (health <= 0) return;
    }

    if (lentidaoTimer > 0) {
      lentidaoTimer -= dt;
      if (lentidaoTimer <= 0) {
        lentidaoFator = 1.0;
        speed = speedBase;
      }
    }

    if (cegoTimer > 0) cegoTimer -= dt;
  }

  void movimento(double dt);

  /// Toca a animação de movimento genérica (se a criatura tiver uma —
  /// ver [moveAnim]). Mixins de movimento contínuo (WanderMovement,
  /// ChaseMovement) chamam isso a cada frame com o estado atual.
  @override
  void animateMovement(
    double dt, {
    required bool isMoving,
    double horizontalDir = 0.0,
  }) {
    _moveAnimator?.update(
      visual: visual,
      basePosition: _visualBasePosition,
      isMoving: isMoving,
      horizontalDir: horizontalDir,
      dt: dt,
    );
  }

  // `currentRoom` e `roomColliders` vêm de MovementHost.

  void shoot(Vector2 direction, {double? lifeTime}) {
    parent?.add(
      Projectile(
        owner: this,
        position: position.clone() + direction * size.x,
        direction: direction,
        isEnemy: true,
        speed: bltSpeed,
        dmg: dmg.toDouble(),
        sprPath: bltImg,
        cor1: bltCor1,
        cor2: bltCor2,
        lifeTime: lifeTime,
        // Só importa se o tiro for refletido (casco fechado) e virar tiro do
        // jogador: o Player não sofre multiplicador de tipo.
        tipo: creature?.tipo ?? CreatureType.neutro,
      ),
    );
  }

  /// [tipoAtacante] aplica a vantagem elemental (ver `typeMultiplier`).
  /// `neutro` — o padrão — vale 1.0, então quem não passa tipo não muda nada.
  /// [doJogador] `false` é o fogo amigo de um inimigo cego (ver
  /// `Projectile.fogoAmigo`): só tipo e redução de dano contam. Crítico,
  /// bônus de item, Prisma e god mode são do JOGADOR, e não podem valer num
  /// golpe que ele não deu.
  ///
  /// [revela] `false` pra dano que não denuncia o jogador — tique de veneno e
  /// queimadura chegam sozinhos, sem um golpe vindo de algum lugar.
  void takeDamage(
    double amount, {
    Color corTxt = Palette.amarelo,
    CreatureType tipoAtacante = CreatureType.neutro,
    bool doJogador = true,
    bool revela = true,
  }) {
    if (doJogador && revela && amount > 0 && cegoTimer > 0) {
      _posicaoVista = playerTarget.absolutePosition;
    }
    var mult = typeMultiplier(
      tipoAtacante,
      creature?.tipo ?? CreatureType.neutro,
    );
    // `Prisma`: a desvantagem (0,5x) vira 1,0x. Antes do bloco de cor logo
    // abaixo, de propósito — depois dele o número sairia cinza, a cor de
    // "resistiu", enquanto o dano na verdade saiu inteiro, e o jogador nunca
    // veria o item funcionando.
    if (doJogador && mult < 1.0 && playerTarget.ignoraDesvantagemElemental) {
      mult = 1.0;
    }
    double fontSize = 6;

    if (mult > 1.0) {
      fontSize = 12;
    } else if (mult < 1.0) {
      //fontSize = 4;
      corTxt = Palette.cinza;
    }
    // Guarda defensiva ativa (casco fechado) reduz o dano recebido.
    // Bônus elemental dos itens (ver `PedraElemental`). Aplicado AQUI e não
    // no ponto do disparo porque este é o único lugar que sabe de que
    // elemento é o golpe — inclusive nos tiques de veneno e queimadura, que
    // chegam por `applyDot` com o tipo da fonte.
    final bonusElemento = doJogador
        ? playerTarget.danoElementalDerivado[tipoAtacante] ?? 1.0
        : 1.0;
    // `FaroDeSangue`: alvo abaixo da metade da vida apanha mais. Aqui, e não
    // no disparo, porque este é o único ponto que conhece a vida do alvo.
    final bonusFerido = doJogador && health < maxHealth * 0.5
        ? 1.0 + playerTarget.bonusAlvoFerido
        : 1.0;
    double amountFinal =
        amount * mult * bonusElemento * bonusFerido * (1 - damageReduction);
    if (amountFinal < 0) amountFinal = 0;

    // `rolagem` era chamada de `critChance` e sombreava o stat de mesmo nome,
    // o que fazia a linha de baixo ler ao contrário do que faz.
    final rolagem = Random().nextDouble() * 100;
    var critou = false;
    final chanceTotal =
        playerTarget.critChance +
        playerTarget.creatureData.stats.critBonus +
        playerTarget.critChanceDerivada;
    if (!doJogador) {
      // Fogo amigo: sem rolagem, e sem mexer na contagem do `SangueFrio`.
    } else if (chanceTotal >= rolagem) {
      critou = true;
      amountFinal *= playerTarget.critMult;
      corTxt = Palette.vermelho;
      playerTarget.golpesSemCrit = 0;
      for (final item in playerTarget.itens) {
        item.aoCritar(playerTarget, this);
      }
      playerTarget.creatureData.passive?.aoCritar(playerTarget, this);
    } else {
      playerTarget.golpesSemCrit++;
    }
    // Depois da rolagem: o crítico TROCA o som do golpe em vez de somar
    // outro por cima — o limitador de toques cortaria o segundo.
    GameAudio.instance.play(critou ? Sfx.critico : Sfx.hit);

    // Cheat (ver GameSettings.godMode): qualquer golpe que passe da redução
    // de dano mata na hora, não importa a vida restante.
    if (doJogador && amountFinal > 0) {
      for (final item in playerTarget.itens) {
        amountFinal = item.ajustarGolpe(playerTarget, this, amountFinal);
      }
      // Afinidade de fogo: queimando, o alvo apanha mais.
      if (dots.containsKey(DotKind.queimadura)) {
        amountFinal *= 1 + playerTarget.danoContraQueimando;
      }
    }
    if (doJogador && GameSettings.instance.godMode && amountFinal > 0) {
      amountFinal = health;
    }
    if(amountFinal>0){
      parent?.add(
        TextEffect.dano(
          amountFinal,
          position: position.clone() + Vector2(0, -size.y / 2 - 4),
          color: corTxt,
          fontSize: fontSize,
        ),
      );
    }
    

    health -= amountFinal;
    if (health <= 0) {
      death();
    }
  }

  // `direcaoLivre` e `spawnAlerta` vêm de MovementHost.

  /// Já morreu? `removeFromParent()` só tira o componente no FIM do quadro
  /// (mesma armadilha documentada no `Collectible`), e `takeDamage` chama
  /// `death()` sempre que a vida fica <= 0 — então dois projéteis que acertam
  /// no mesmo quadro matam o mesmo inimigo duas vezes. Sem esta trava saem
  /// dois drops de XP, dois sons e, agora, dois [aoMatarInimigo].
  bool _morto = false;

  void death() {
    if (_morto) return;
    _morto = true;
    GameAudio.instance.play(ehBoss ? Sfx.bossDerrotado : Sfx.enemyDie);

    // Boss caiu: a masmorra volta ao normal, e a trilha junto.
    if (ehBoss) GameMusic.instance.play(GameMusic.run);

    // Antes do `removeFromParent` lá embaixo, pela mesma razão da explosão do
    // campeão: quem reage ao abate pode querer nascer no mundo, e `parent`
    // deixa de existir pra este componente assim que ele sai da árvore.
    for (final item in playerTarget.itens) {
      item.aoMatarInimigo(playerTarget, this);
    }
    playerTarget.abatesSeguidos++;
    final jogo = game;
    if (jogo is CreaturesRogueGame) {
      jogo.abatesDaRun++;
      if (ehBoss) jogo.bossesDaRun++;
    }
    playerTarget.tempoDesdeAbate = 0.0;

    // Antes do `removeFromParent` lá embaixo, e antes do XP: a explosão nasce
    // no mundo (`parent`), que deixa de existir pra este componente assim que
    // ele sai da árvore.
    if (campeaoTipo == CampeaoTipo.explosivo) {
      parent?.add(
        ExplosionHitbox(
          explosao: true,
          position: position.clone(),
          isEnemy: true,
          origem: creature,
          dono: this,
          dmg: dmg * campeaoExplosaoCoef,
          knockback: 70,
          size: Vector2.all(campeaoExplosaoRaio),
          cor1: CampeaoTipo.explosivo.corAura,
          cor2: Palette.vermelho,
          tipo: creature?.tipo ?? CreatureType.neutro,
        ),
      );
    }

    _dropXp();
    // Sem await de propósito: death() não é async (chamado de dentro de
    // takeDamage, síncrono), e a contagem não precisa bloquear a morte —
    // só precisa acabar gravada eventualmente.
    final id = creature?.id;
    if (id != null) CreatureProgress.instance.incrementKill(id);

    final effect = SpriteEffect(
      position: position.clone(),
      size: Vector2(16, 16),
      corClara: Palette.indigo,
      corEscura: Palette.cinzaEsc,
      corBranco: Palette.branco,
      spritePath: 'effects/enemy_death.png',
      textureSize: Vector2(16, 16),
    );
    parent?.add(effect);
    removeFromParent();
  }

  /// Itens de XP (ver `XpPickup`) que este inimigo derruba ao morrer —
  /// substituiu o XP fixo por golpe direto em `playerTarget.ganharXp`: comum
  /// solta de 0 a 2, boss solta 10. Pequeno espalhamento aleatório na
  /// posição pra não empilhar tudo exatamente no mesmo pixel quando é mais
  /// de um item.
  void _dropXp() {
    final random = Random();
    final int quantidade;
    if (ehBoss) {
      quantidade = 10;
    } else if (ehCampeao) {
      // Piso, não multiplicador: ver `campeaoXpMin`.
      quantidade = campeaoXpMin + random.nextInt(2);
    } else {
      quantidade = random.nextInt(3);
    }
    for (var i = 0; i < quantidade; i++) {
      parent?.add(
        XpPickup(
          position:
              position +
              Vector2(
                random.nextDouble() * 16 - 8,
                random.nextDouble() * 16 - 8,
              ),
        ),
      );
    }
  }

  /// Libera `creature` pra jogar e avisa na tela — cada boss chama isto no
  /// próprio `death()`, antes do `super.death()`. Centralizado aqui (em vez
  /// de repetir o texto em cada boss) porque todos já têm `creature`, `parent`
  /// e `position` prontos pelo mesmo motivo do dano em `takeDamage`.
  void unlockCreature() {
    final data = creature;
    if (data == null) return;

    CreatureProgress.instance.unlock(data.id);
    final context = game.buildContext!;
    parent?.add(
      TextEffect(
        text: context.l10n.effect_criaturaLiberada(
          creatureName(context, data.id),
        ),
        position: position.clone() + Vector2(0, -size.y / 2 - 4),
        color: Palette.branco,
      ),
    );
  }

  void applyKnockback(Vector2 sourcePosition, double force) {
    if (ehBoss) return;
    Vector2 direction = (absolutePosition - sourcePosition).normalized();
    // Só o COURAÇADO resiste. Se todo campeão resistisse, o couraçado não
    // teria identidade nenhuma — seria "o campeão sem nada de especial".
    final fator = campeaoTipo == CampeaoTipo.couracado
        ? campeaoEmpurraoFator
        : 1.0;
    knockbackVelocity = direction * force * fator;
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints.cast<Vector2>(), other);
    if (other is Projectile) {
      if (other.isEnemy) return;

      // Só o flash visual aqui. O dano já é aplicado do lado do projétil
      // (`Projectile.onCollisionStart`, ramo `other is Enemy`), que sabe o
      // tipo elemental, `Player.danoMult`, knockback e perfuração — chamar
      // `takeDamage` de novo aqui duplicava o golpe: uma vez com tipo (o do
      // projétil) e outra sem (esta, com `other.dmg` cru).
      visual.paint.colorFilter = const ColorFilter.mode(
        Colors.white,
        BlendMode.srcATop,
      );

      Future.delayed(const Duration(milliseconds: 100), () {
        if (!isRemoved) {
          visual.paint.colorFilter = null;
        }
      });
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    // --- Lógica de Flocking (esbarrão entre inimigos) ---
    if (other is Enemy) {
      // Inimigos fixos (planta) não saem do lugar; o OUTRO inimigo se desvia
      if (!isPushable) return;

      Vector2 separationVector = absolutePosition - other.absolutePosition;
      final desvio = separationVector.length > 0
          ? separationVector.normalized() * 0.5
          : Vector2(0.5, 0);

      // Só desvia se o destino estiver livre. Sem esta checagem o esbarrão
      // enfia o inimigo dentro da parede — e como boss tem isPushable false,
      // ele vira um pistão empurrando os comuns pra dentro do cenário.
      if (!_paredeNoCaminho(desvio)) position += desvio;
      return;
    }

    // --- Lógica de Paredes e Obstáculos ---
    if (other is WallBarrier || other is Obstacle) {
      // AQUI ESTÁ A MÁGICA: Se a colisão não foi nos pés (sombra), ignora a parede!
      if (!isPhysicsCollision(other)) return;

      // Empurra pela profundidade real do overlap. O rect é lido AGORA, não no
      // começo do frame: numa quina chegam duas chamadas de onCollision no
      // mesmo frame, e a segunda precisa ver a correção que a primeira fez.
      final empurrao = empurraoParaFora(
        corpo: physicsHitbox.toAbsoluteRect(),
        alvo: other.toAbsoluteRect(),
      );
      if (empurrao.isZero()) return;

      position += empurrao;

      // Corta o knockback só no eixo empurrado. Zerar tudo (como antes) mata
      // também o empurrão tangencial, que é o que deslizaria pela parede.
      if (empurrao.x != 0) knockbackVelocity.x = 0;
      if (empurrao.y != 0) knockbackVelocity.y = 0;
    }
  }

  /// Se mover a sombra por [desvio] encostaria em parede ou obstáculo sólido.
  /// Usado pelo esbarrão entre inimigos, que escreve position direto e por isso
  /// não passa pela resolução de parede.
  bool _paredeNoCaminho(Vector2 desvio) {
    final destino = physicsHitbox.toAbsoluteRect().shift(
      Offset(desvio.x, desvio.y),
    );

    for (final componente in parent?.children ?? const Iterable.empty()) {
      if (componente is! WallBarrier && componente is! Obstacle) continue;
      // Voando passa por cima de pedra/buraco, mas NUNCA de porta: `Door`
      // também é `Obstacle`, e sem esta exceção o inimigo voador saía da sala
      // trancada — e, como ele continua em `activeEnemies`, a sala nunca
      // destrancava.
      if (componente is Obstacle && componente is! Door && isAirborne) continue;
      if (destino.overlaps(
        (componente as PositionComponent).toAbsoluteRect(),
      )) {
        return true;
      }
    }
    return false;
  }

  bool isPhysicsCollision(PositionComponent other) {
    // 1. Se está voando, passa limpo por cima de obstáculos (pedras/buracos).
    //    Porta fica de fora: `Door` estende `Obstacle`, e deixá-la aqui fazia o
    //    inimigo voador atravessar porta trancada.
    if (other is Obstacle && other is! Door && isAirborne) return false;

    // 2. Só valida a colisão se a hitbox da SOMBRA (pés) encostar no objeto.
    // Isso permite que a cabeça/corpo cruze a parede visualmente lá no alto.
    if (!physicsHitbox.toAbsoluteRect().overlaps(other.toAbsoluteRect())) {
      return false;
    }

    return true;
  }
}
