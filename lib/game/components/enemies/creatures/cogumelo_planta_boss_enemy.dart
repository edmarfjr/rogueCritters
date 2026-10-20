import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/effects/dot.dart';
import 'package:creatures_rogue/game/components/projeteis/projectile.dart';
import '../enemy.dart';

/// Cogumelo de Planta Boss: parado como a forma comum, mas pulsando ANÉIS de
/// esporo — e, na fase 2, devolvendo ao jogador a própria mecânica dele.
///
/// Fase 1 — pulsa um anel de nuvens PARADAS ao redor, com uma brecha. O
/// jogador lê a brecha e passa por ela. A sala não fecha; o que cobra é a
/// leitura.
///
/// Fase 2 (≤50% da vida) — as nuvens do anel passam a DERIVAR pra fora, e o
/// boss salta pra outro ponto da sala entre um anel e outro. É a mecânica da
/// criatura jogável espelhada: lá o jogador conduz esporos andando e os fixa
/// parando; aqui o boss força o oposto, enchendo a sala de coisa que se move
/// e tirando do jogador o direito de ficar parado.
class CogumeloPlantaBossEnemy extends Enemy {
  static const double _vidaInicial = 120.0;

  /// Em quantas posições o anel é dividido. Uma delas fica VAGA a cada pulso
  /// — é por essa brecha que o jogador passa, e sorteá-la a cada anel é o que
  /// impede a luta de virar esperar parado num canto seguro.
  static const int _setoresDoAnel = 8;

  static const double _raioAnel = 34.0;
  static const double _coefNuvem = 0.8;
  static const double _duracaoNuvem = 4.0;
  static const double _raioNuvem = 11.0;

  static const double _intervaloFase1 = 2.6;
  static const double _intervaloFase2 = 1.8;

  /// Velocidade da deriva das nuvens na fase 2. Baixa de propósito: elas
  /// precisam ser desviáveis, não perseguir.
  static const double _derivaFase2 = 22.0;

  bool _faseDois = false;
  double _timer = 0.0;
  final Random _random = Random();

  CogumeloPlantaBossEnemy({
    required super.position,
    required super.playerTarget,
  }) : super(
         creature: CreatureRegistry.cogumeloPlantaEvo,
         // NÃO é locomoção: este boss nunca anda. `speed` existe aqui porque
         // `direcaoLivre` mede o caminho à frente como `speed * segundos`, e
         // com zero a checagem de parede daria sempre "livre". É a unidade de
         // distância do salto, nada mais.
         speed: 60,
         health: _vidaInicial,
         dmg: 2,
         size: Vector2(32, 32),
         hitboxSize: Vector2(22, 20),
         shadowOffset: Vector2(0, 4),
         isPushable: false,
       );

  double get _intervalo => _faseDois ? _intervaloFase2 : _intervaloFase1;

  @override
  void movimento(double dt) {
    if (!_faseDois && health <= _vidaInicial / 2) {
      _faseDois = true;
      // A sala muda de regra aqui; mudar sem sinal leria como bug.
      spawnAlerta(duracao: 0.6);
    }

    _timer += dt;
    if (_timer < _intervalo) return;
    _timer = 0.0;

    _pulsarAnel();
    if (_faseDois) _saltar();
  }

  /// Anel de nuvens com UMA brecha: [_nuvensPorAnel] nuvens distribuídas em
  /// [_setoresDoAnel] posições, então sempre sobra um setor vazio. O setor
  /// vago é sorteado a cada pulso, senão o jogador decoraria o lado seguro e
  /// a luta viraria esperar parado no mesmo canto.
  void _pulsarAnel() {
    final setorVago = _random.nextInt(_setoresDoAnel);

    for (var i = 0; i < _setoresDoAnel; i++) {
      if (i == setorVago) continue;

      final angulo = (2 * pi / _setoresDoAnel) * i;
      final direcao = Vector2(cos(angulo), sin(angulo));

      parent?.add(
        Projectile(
          owner: this,
          position: position.clone() + direcao * _raioAnel,
          direction: direcao,
          // Fase 1 as nuvens ficam onde nascem; fase 2 elas abrem.
          speed: _faseDois ? _derivaFase2 : 0,
          isEnemy: true,
          dmg: dmg * _coefNuvem,
          kbForce: 0,
          sprPath: 'projeteis/nuvem.png',
          cor1: creature?.corClara ?? CreatureRegistry.cogumeloPlantaEvo.corClara,
          cor2:
              creature?.corEscura ?? CreatureRegistry.cogumeloPlantaEvo.corEscura,
          tipo: creature?.tipo ?? CreatureRegistry.cogumeloPlantaEvo.tipo,
          dotKind: DotKind.veneno,
          dotTicks: 2,
          atravessa: 100,
          size: Vector2.all(_raioNuvem * 2),
          lifeTime: _duracaoNuvem,
          radius: _raioNuvem,
          // Sete nuvens no mesmo quadro estouram o throttle do `GameAudio`.
          playSfx: false,
        ),
      );
    }
  }

  /// Quanto tempo de caminho o salto cobre. Multiplicado por `speed` vira a
  /// distância — e é a MESMA conta que `direcaoLivre` usa, então o que a
  /// checagem aprova é exatamente o que o boss percorre.
  static const double _segundosDoSalto = 0.7;

  /// Salta pra uma direção livre, escolhida na hora.
  ///
  /// `direcaoLivre` pela mesma razão que a Roda de Fogo usa: é a checagem que
  /// respeita a regra de solidez do mapa (`barraMovimento`), então o boss não
  /// aterrissa dentro de parede. Oito tentativas e desiste — numa sala muito
  /// apertada é melhor ficar parado que teimar.
  void _saltar() {
    for (var tentativa = 0; tentativa < 8; tentativa++) {
      final angulo = _random.nextDouble() * 2 * pi;
      final direcao = Vector2(cos(angulo), sin(angulo));
      if (!direcaoLivre(direcao, segundos: _segundosDoSalto)) continue;

      add(
        MoveByEffect(
          direcao * speed * _segundosDoSalto,
          EffectController(duration: 0.35, curve: Curves.easeOutQuad),
        ),
      );
      return;
    }
  }
  @override
  void death() {
    unlockCreature();
    super.death();
  }
}
