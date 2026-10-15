import 'package:flame/components.dart';

import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import '../enemy.dart';

/// Fase da investida. Enquanto `rodando` a direção está TRAVADA — é isso que
/// faz a Roda ser esquivável: o jogador lê a mira no aviso e sai da linha.
enum RodaFase { vagando, mirando, rodando, recuperando }

/// Roda de Fogo como inimiga: vagueia devagar, mira, e se atira em LINHA RETA
/// até bater na parede.
///
/// Espelha o que a criatura jogável faz — ganhar embalo e manter — e é por
/// isso que ela não persegue: perseguição corrige a rota a cada quadro e não
/// teria como ser esquivada. Aqui a direção é escolhida UMA vez, no fim da
/// mira, e depois não muda mais.
///
/// O dano da investida é o dano de contato que o `Player.onCollision` já
/// aplica; esta classe não precisa de hitbox própria pra isso. O que ela
/// acrescenta é o estouro de fogo ao bater na parede, que pune quem tentou
/// ficar entre a Roda e o cenário.
class RodaFogoEnemy extends Enemy {
  /// Só investe se o jogador estiver dentro disso — de longe ela vagueia.
  static const double _alcanceInvestida = 90.0;

  static const double _duracaoMira = 0.45;
  static const double _duracaoMaxRodando = 1.1;
  static const double _duracaoRecuperando = 0.8;

  /// Velocidade da investida. Bem acima da de vagar (que vem de `speed`),
  /// senão a fase travada não se distingue da fase solta.
  static const double _velInvestida = 150.0;

  static const double _danoEstouro = 2.0;

  RodaFase _fase = RodaFase.vagando;
  double _timer = 0.0;
  Vector2 _direcao = Vector2.zero();

  RodaFogoEnemy({required super.position, required super.playerTarget})
    : super(
        creature: CreatureRegistry.rodaFogo,
        speed: 30.0, // só o vagar; a investida usa `_velInvestida`
        health: 14,
        dmg: 1,
      );

  @override
  void movimento(double dt) {
    _timer += dt;

    switch (_fase) {
      case RodaFase.vagando:
        updateWanderMovement(dt);
        final distancia =
            (alvoPosicao - absolutePosition).length;
        if (distancia <= _alcanceInvestida) {
          _entrar(RodaFase.mirando);
          // Aviso com a duração exata da mira: o jogador tem a janela inteira
          // pra sair da linha, não um susto solto.
          spawnAlerta(duracao: _duracaoMira);
        }

      case RodaFase.mirando:
        // Ainda segue o jogador com a mira ATÉ o último instante, e é aí que
        // ela congela — perseguir depois de travar tiraria a esquiva.
        _direcao = (alvoPosicao - absolutePosition)
            .normalized();
        if (_timer >= _duracaoMira) _entrar(RodaFase.rodando);

      case RodaFase.rodando:
        // `direcaoLivre` olha o caminho à frente com a mesma regra de solidez
        // do resto do jogo (`barraMovimento`), então a Roda para na parede em
        // vez de atravessar.
        if (!direcaoLivre(_direcao, segundos: 0.12)) {
          _bater();
          _entrar(RodaFase.recuperando);
          return;
        }
        if (_timer >= _duracaoMaxRodando) {
          _entrar(RodaFase.recuperando);
          return;
        }
        position += _direcao * _velInvestida * dt;
        _virarPraDirecao();

      case RodaFase.recuperando:
        if (_timer >= _duracaoRecuperando) _entrar(RodaFase.vagando);
    }
  }

  void _entrar(RodaFase nova) {
    _fase = nova;
    _timer = 0.0;
  }

  void _virarPraDirecao() {
    if (_direcao.x < 0 && !visual.isFlippedHorizontally) {
      visual.flipHorizontallyAroundCenter();
    } else if (_direcao.x > 0 && visual.isFlippedHorizontally) {
      visual.flipHorizontallyAroundCenter();
    }
  }

  /// Chamado só quando a investida termina contra parede, não quando ela
  /// termina por tempo — bater é que gera o estouro.
  void _bater() {
    parent?.add(
      ExplosionHitbox(
        explosao: true,
        position: position.clone(),
        isEnemy: true,
        origem: creature,
        dono: this,
        dmg: _danoEstouro,
        knockback: 40,
        size: Vector2(24, 24),
        cor1: Palette.laranja,
        cor2: Palette.vermelho,
        tipo: creature?.tipo ?? CreatureRegistry.rodaFogo.tipo,
      ),
    );
  }
}
