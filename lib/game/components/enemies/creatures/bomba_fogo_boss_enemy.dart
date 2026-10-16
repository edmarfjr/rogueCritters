import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import '../enemy.dart';
import 'bomba_fogo_enemy.dart';

/// Boss "Rei Bomba" — protótipo da fórmula de boss: dobro de tamanho, paleta
/// própria (dourado/vermelho em vez de bege/roxo) e troca de fase aos 50% de
/// vida.
///
/// Diferença central em relação à Bomba de Fogo normal: pra ela, explodir é
/// morrer — é kamikaze. Pro boss, explodir é um ATAQUE que ele repete a vida
/// toda. O ciclo é perseguir → acender pavio (exclamação avisa) → explodir →
/// ficar exposto durante a recuperação → perseguir de novo. A recuperação é a
/// janela em que você bate nele de graça, mesma linguagem do Urso de Planta.
class BombaFogoBossEnemy extends Enemy{
  static const double _vidaInicial = 200; // 4x a Bomba normal (24)

  /// Maior que o da versão normal (20): o corpo é o dobro, o perigo acompanha.
  static const double _alcanceGatilho = 30.0;

  // Fase 1 / fase 2 (abaixo de 50% de vida). A fase 2 não dá mais dano só por
  // dar: ela encurta o aviso E a punição, então errar sai mais caro.
  static const double _pavioFase1 = 0.6;
  static const double _pavioFase2 = 0.35;
  static const double _recuperacaoFase1 = 1.4;
  static const double _recuperacaoFase2 = 0.9;
  static const double _danoFase1 = 4.0;
  static const double _danoFase2 = 6.0;

  static const double _empurrao = 50.0;
  static const double _raioExplosao = 48.0;

  /// Explosão final, quando a vida acaba de verdade.
  static const double _danoMorte = 9.0;
  static const double _raioMorte = 64.0;
  static const int _minisNaMorte = 3;

  /// Teto de mini-bombas que a fase 2 pode deixar na arena ao longo da luta.
  /// Sem isso, uma luta longa entope a sala.
  static const int _maxMinisFase2 = 4;

  double _pavioTimer = 0.0;
  double _recuperacaoTimer = 0.0;
  bool _acendeu = false;
  bool _faseDois = false;
  bool _explodiuNaMorte = false;
  int _minisSpawnados = 0;

  BombaFogoBossEnemy({
    required super.position,
    required super.playerTarget,
  }) : super(
         creature: CreatureRegistry.bombaFogoEvo,
         corClara: Palette.burgundy,
         corEscura: Palette.roxoEsc,
         speed: 34.0, // mais lento que a normal (40): o tamanho já pressiona
         health: _vidaInicial,
         dmg: 2,
         size: Vector2(32, 32),        // dobro do padrão (16x16)
         hitboxSize: Vector2(16, 20),  // dobro do hitbox da Bomba (8, 10)
         isPushable: false,
       );

  double get _pavio => _faseDois ? _pavioFase2 : _pavioFase1;
  double get _recuperacao => _faseDois ? _recuperacaoFase2 : _recuperacaoFase1;
  double get _dano => _faseDois ? _danoFase2 : _danoFase1;

  @override
  void movimento(double dt) {
    if (!_faseDois && health <= _vidaInicial / 2) _faseDois = true;

    // Acabou de explodir: fica parado e exposto. É aqui que você revida.
    if (_recuperacaoTimer > 0) {
      _recuperacaoTimer -= dt;
      animateMovement(dt, isMoving: false);
      return;
    }

    // Pavio aceso: travado no lugar, contando. Dá pra sair do raio.
    if (_acendeu) {
      _pavioTimer += dt;
      animateMovement(dt, isMoving: false);

      if (_pavioTimer >= _pavio) {
        _acendeu = false;
        _pavioTimer = 0.0;
        _recuperacaoTimer = _recuperacao;
        _explodir(dano: _dano, raio: _raioExplosao);

        // Fase 2: cada explosão cospe uma mini-bomba, até o teto. É o que
        // faz a segunda metade escalar de verdade, não só doer mais.
        if (_faseDois && _minisSpawnados < _maxMinisFase2) {
          _minisSpawnados++;
          parent?.add(BombaFogoEnemy(
            position: position.clone() + Vector2(0, 12),
            playerTarget: playerTarget,
          ));
        }
      }
      return;
    }

    final distancia = (alvoPosicao - absolutePosition).length;
    if (distancia <= _alcanceGatilho) {
      _acendeu = true;
      _pavioTimer = 0.0;
      spawnAlerta(duracao: _pavio);
      return;
    }

    updateChaseMovement(dt);
  }

  void _explodir({required double dano, required double raio}) {
    parent?.add(ExplosionHitbox(
      explosao: true,
      position: position.clone(),
      isEnemy: true, // isEnemy true = machuca o Player e NÃO machuca inimigos
      origem: creature,
      dono: this,
      dmg: dano,
      knockback: _empurrao,
      size: Vector2.all(raio),
      cor1: Palette.amarelo,
      cor2: Palette.vermelho,
    ));
  }

  /// Só é chamado quando a vida chega a zero — o pavio não mata mais.
  @override
  void death() {
    if (!_explodiuNaMorte) {
      _explodiuNaMorte = true;
      _explodir(dano: _danoMorte, raio: _raioMorte);

      // Última cartada: mesmo morto, deixa perseguidores pra trás.
      for (int i = 0; i < _minisNaMorte; i++) {
        parent?.add(BombaFogoEnemy(
          position: position.clone() + Vector2((i - 1) * 16.0, 0),
          playerTarget: playerTarget,
        ));
      }

      // Recompensa: derrotar o boss libera a criatura pra jogar.
      unlockCreature();
    }
    super.death();
  }
}
