import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:creatures_rogue/game/audio/game_audio.dart';
import 'package:creatures_rogue/game/audio/sfx.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/creature_data.dart';
import 'package:creatures_rogue/game/components/creatures/creature_type.dart';
import 'package:creatures_rogue/game/components/enemies/enemy.dart';
import 'package:creatures_rogue/game/components/map/door.dart';
import 'package:creatures_rogue/game/components/map/obstacle.dart';
import 'package:creatures_rogue/game/components/map/wall_barrier.dart';
import 'package:creatures_rogue/game/components/player/player.dart';
import 'package:creatures_rogue/game/components/utils/y_sort.dart';

/// Raio contínuo do Zapeye (habilidade 1) e dos inimigos dele: um feixe que
/// sai do [dono] na [direcao] e PARA no primeiro alvo ou obstáculo — preciso,
/// não perfurante (a lança do Leão é quem atravessa).
///
/// Não colide: a cada quadro anda pela linha em passos de 3px e para no
/// primeiro inimigo (ou jogador, do lado inimigo), pedra, parede ou porta
/// fechada — a mesma regra que apaga projétil. Buraco não bloqueia.
///
/// [direcao] é uma função, não um vetor: o jogador passa a mira ao vivo, o
/// inimigo passa uma direção travada, e o boss um ângulo que gira — um
/// componente só pros três.
///
/// Vive [vida] segundos, renovável por [renovar]: a habilidade do jogador
/// renova o mesmo feixe a cada disparo enquanto ele segura a mira, então o
/// acúmulo de atordoamento e de rampa sobrevive entre um disparo e outro.
class FeixeEletrico extends PositionComponent {
  final PositionComponent dono;
  final Vector2 Function() direcao;
  final double alcance;

  /// Dano de cada tique.
  final double danoPorTique;
  final double intervaloTique;
  final CreatureType tipo;

  /// `true`: feixe de inimigo, acerta o jogador.
  final bool isEnemy;

  /// Quem disparou, pro "derrotado por".
  final CreatureData? origem;

  final Color cor1;
  final Color cor2;

  /// Segundos seguidos no mesmo alvo até atordoar. `0` desliga.
  final double tempoParaAtordoar;
  final double atordoamento;

  /// Multiplicador máximo de dano por manter o feixe no mesmo alvo (1 = sem
  /// rampa), alcançado depois de [tempoRampa] segundos.
  final double rampaMaxima;
  final double tempoRampa;

  /// Largura do feixe em px (o brilho; o núcleo tem metade). Também alarga
  /// a área de acerto, na mesma proporção.
  final double espessura;

  double vida;

  FeixeEletrico({
    required this.dono,
    required this.direcao,
    required this.vida,
    required this.danoPorTique,
    required this.tipo,
    required this.cor1,
    required this.cor2,
    this.alcance = 150,
    this.intervaloTique = 0.18,
    this.isEnemy = false,
    this.origem,
    this.tempoParaAtordoar = 0,
    this.atordoamento = 0.5,
    this.rampaMaxima = 1.0,
    this.tempoRampa = 1.5,
    this.espessura = 4,
  });

  /// Recarga de atordoamento por alvo: sem ela um feixe contínuo deixaria
  /// o alvo (inclusive boss) atordoado boa parte do tempo.
  static const double _recargaAtordoamento = 2.0;

  /// Do lado inimigo, cada alvo leva no máximo um golpe por este intervalo:
  /// o feixe toca várias vezes por segundo, e cada toque rolaria evasão,
  /// gastaria escudo e dispararia ganchos de "tomou dano".
  static const double _recargaAcertoInimigo = 0.5;

  /// Disparado às cegas: acerta os outros inimigos também (ver
  /// `Projectile.fogoAmigo`).
  bool _fogoAmigo = false;

  /// Espécie do jogador quando o feixe nasceu: trocar de criatura no meio
  /// apaga o feixe, senão a criatura nova sairia disparando o raio da outra.
  String? _idDoDono;

  Vector2 _direcaoAtual = Vector2(0, 1);
  Vector2 _fim = Vector2.zero();
  PositionComponent? _alvo;
  double _tempoNoAlvo = 0.0;
  double _tempoFoco = 0.0;
  double _tique = 0.0;
  final Map<PositionComponent, double> _recargas = {};
  final Map<PositionComponent, double> _recargasAtordoar = {};
  final Random _random = Random();

  void renovar(double segundos) {
    if (segundos > vida) vida = segundos;
  }

  @override
  Future<void> onLoad() async {
    final d = dono;
    _fogoAmigo = isEnemy && d is Enemy && d.cegoTimer > 0;
    if (d is Player) _idDoDono = d.creatureData.id;
    _posicionar();
    _tocarSom();
  }

  /// Feixe é contínuo: o som do elemento repete enquanto ele existe, no
  /// ritmo em que a habilidade do jogador renova o feixe (0,4 s). Um toque só
  /// no nascimento deixaria mudo o raio segurado — e o do chefe, que dura.
  static const double _intervaloSom = 0.4;
  double _somTimer = 0.0;

  void _tocarSom() {
    _somTimer = _intervaloSom;
    final sfx = tipo.attackSfx;
    if (sfx != null) GameAudio.instance.play(sfx);
  }

  bool get _donoSumiu {
    final d = dono;
    if (!d.isMounted) return true;
    if (d is Player) return d.creatureData.id != _idDoDono || d.estaMorrendo;
    if (d is Enemy) return d.health <= 0;
    return false;
  }

  void _posicionar() {
    position = dono.absolutePosition.clone();
    priority = ySortPriority(position.y) + 1;
  }

  @override
  void update(double dt) {
    super.update(dt);
    vida -= dt;
    _somTimer -= dt;
    if (_somTimer <= 0 && vida > 0) _tocarSom();
    if (vida <= 0 || _donoSumiu) {
      removeFromParent();
      return;
    }
    _posicionar();

    final d = dono;
    // Mirando o raio, o olho não corre: o jogador anda mais devagar enquanto
    // dispara (ver o `temEfeito(#focoDoRaio)` no `Player.update`).
    if (d is Player) d.aplicarEfeito(#focoDoRaio, 0.1);

    final dir = direcao();
    if (!dir.isZero()) _direcaoAtual = dir.normalized();

    _recargas.updateAll((_, t) => t - dt);
    _recargas.removeWhere((_, t) => t <= 0);
    _recargasAtordoar.updateAll((_, t) => t - dt);
    _recargasAtordoar.removeWhere((_, t) => t <= 0);

    final alvoAnterior = _alvo;
    _tracar();
    if (_alvo != null && _alvo == alvoAnterior) {
      _tempoNoAlvo += dt;
      _tempoFoco += dt;
    } else {
      _tempoNoAlvo = 0;
      _tempoFoco = 0;
    }

    _tique -= dt;
    final alvo = _alvo;
    if (alvo == null) return;
    if (_tique <= 0) {
      _tique = intervaloTique;
      _ferir(alvo);
    }
    if (tempoParaAtordoar > 0 &&
        _tempoNoAlvo >= tempoParaAtordoar &&
        alvo is Enemy &&
        !_recargasAtordoar.containsKey(alvo)) {
      alvo.applyStun(atordoamento);
      _recargasAtordoar[alvo] = _recargaAtordoamento;
      _tempoNoAlvo = 0;
    }
  }

  /// Anda pela linha até o primeiro alvo ou bloqueio e guarda o ponto final
  /// (em coordenadas locais) e o alvo atingido.
  void _tracar() {
    final inicio = dono.absolutePosition;
    final bloqueios = _bloqueios();
    final alvos = _alvosPossiveis();
    const passo = 3.0;
    final passos = (alcance / passo).ceil();
    _alvo = null;
    for (var i = 1; i <= passos; i++) {
      final p = inicio + _direcaoAtual * (i * passo);
      final ponto = Offset(p.x, p.y);
      if (bloqueios.any((r) => r.contains(ponto))) {
        _fim = p - inicio;
        return;
      }
      for (final (alvo, rect) in alvos) {
        if (rect.contains(ponto)) {
          _alvo = alvo;
          _fim = p - inicio;
          return;
        }
      }
    }
    _fim = _direcaoAtual * alcance;
  }

  List<Rect> _bloqueios() {
    final d = dono;
    final sala = d is Player
        ? d.currentRoom
        : d is Enemy
        ? d.currentRoom
        : null;
    if (sala == null) return const [];
    return [
      for (final c in sala.children.whereType<PositionComponent>())
        if (c is WallBarrier ||
            c is Rock ||
            (c is Door && c.hitbox.collisionType != CollisionType.inactive))
          c.toAbsoluteRect(),
    ];
  }

  List<(PositionComponent, Rect)> _alvosPossiveis() {
    final inimigos = dono.parent?.children.whereType<Enemy>() ?? const <Enemy>[];
    final lista = <(PositionComponent, Rect)>[];
    if (!isEnemy || _fogoAmigo) {
      for (final e in inimigos) {
        if (e == dono || e.summonTimer > 0 || e.health <= 0) continue;
        lista.add((e, e.enemyHitbox.toAbsoluteRect().inflate(espessura / 4)));
      }
    }
    final d = dono;
    if (isEnemy && d is Enemy) {
      final jogador = d.playerTarget;
      if (!jogador.submerso) {
        lista.add((
          jogador,
          jogador.playerHitbox.toAbsoluteRect().inflate(espessura / 4),
        ));
      }
    }
    return lista;
  }

  void _ferir(PositionComponent alvo) {
    if (alvo is Player) {
      if (_recargas.containsKey(alvo)) return;
      _recargas[alvo] = _recargaAcertoInimigo;
      alvo.takeDamage(danoPorTique, tipo, origem: origem);
      return;
    }
    if (alvo is! Enemy) return;
    if (isEnemy) {
      // Fogo amigo: sem crítico nem bônus de item, com a mesma recarga.
      if (_recargas.containsKey(alvo)) return;
      _recargas[alvo] = _recargaAcertoInimigo;
      alvo.takeDamage(danoPorTique, tipoAtacante: tipo, doJogador: false);
      return;
    }
    final rampa =
        1 + (rampaMaxima - 1) * (_tempoFoco / tempoRampa).clamp(0.0, 1.0);
    alvo.takeDamage(
      danoPorTique * rampa * Player.danoMult * Player.danoMultDerivado,
      tipoAtacante: tipo,
    );
  }

  @override
  void render(Canvas canvas) {
    final fim = Offset(_fim.x, _fim.y);
    final brilho = Paint()
      ..color = cor2
      ..strokeWidth = espessura
      ..strokeCap = StrokeCap.square
      ..isAntiAlias = false;
    final nucleo = Paint()
      ..color = cor1
      ..strokeWidth = espessura / 2
      ..isAntiAlias = false;
    canvas.drawLine(Offset.zero, fim, brilho);
    canvas.drawLine(Offset.zero, fim, nucleo);

    // Faísca: uma linha quebrada que treme em volta do núcleo, sorteada de
    // novo a cada quadro — é o que faz o feixe parecer eletricidade, e não
    // um laser liso.
    final comprimento = _fim.length;
    if (comprimento < 6) return;
    final perpendicular = Offset(-_direcaoAtual.y, _direcaoAtual.x);
    final faisca = Path()..moveTo(0, 0);
    for (double t = 6; t < comprimento; t += 6) {
      final desvio = (_random.nextDouble() * 2 - 1) * espessura * 0.625;
      final base = Offset(_direcaoAtual.x * t, _direcaoAtual.y * t);
      final q = base + perpendicular * desvio;
      faisca.lineTo(q.dx, q.dy);
    }
    faisca.lineTo(fim.dx, fim.dy);
    canvas.drawPath(
      faisca,
      Paint()
        ..color = Palette.branco
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..isAntiAlias = false,
    );
  }
}

/// Linha fina de mira mostrada antes do feixe de um inimigo: o aviso de onde
/// o raio vai passar. Não fere ninguém.
class AvisoDeFeixe extends PositionComponent {
  final PositionComponent dono;
  final Vector2 Function() direcao;
  final double alcance;
  double vida;

  AvisoDeFeixe({
    required this.dono,
    required this.direcao,
    required this.vida,
    this.alcance = 150,
  });

  final Paint _tinta = Paint()
    ..color = Palette.vermelho
    ..strokeWidth = 1
    ..isAntiAlias = false;

  @override
  void update(double dt) {
    super.update(dt);
    vida -= dt;
    if (vida <= 0 || !dono.isMounted) {
      removeFromParent();
      return;
    }
    position = dono.absolutePosition.clone();
    priority = ySortPriority(position.y) + 1;
  }

  @override
  void render(Canvas canvas) {
    final dir = direcao();
    if (dir.isZero()) return;
    final d = dir.normalized();
    // Tracejada e piscando: lê como aviso, não como o raio em si.
    if ((vida * 12).floor().isOdd) return;
    for (double t = 0; t < alcance; t += 6) {
      canvas.drawLine(
        Offset(d.x * t, d.y * t),
        Offset(d.x * (t + 3), d.y * (t + 3)),
        _tinta,
      );
    }
  }
}
