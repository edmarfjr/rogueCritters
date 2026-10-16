import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import '../enemy.dart';

/// Urso de Planta Boss — "Patriarca da Floresta": mesmo avanço lento e sem
/// parar da normal, com a mesma pancada de prepara-e-solta. É o mais lento do
/// elenco, então kitar é ainda mais fácil que com o Tornado — precisa do
/// mesmo remédio (fura distância), só que pesado em vez de veloz.
///
/// Fase 2 (≤50%): entra o **salto-pancada** — um pulo curto, ainda telegrafado,
/// que cobre bem mais chão que um passo normal e aterrissa com onda maior.
/// Continua tendo a pancada de perto no meio tempo; o salto é um golpe extra
/// na rotação, não substitui o resto.
class UrsoPlantaBossEnemy extends Enemy{
  static const double _vidaInicial = 300.0; // 4x a normal (100)
  static const double _alcancePancada = 30.0;
  static const double _preparoPancada = 0.6;
  static const double _empurraoPancada = 60.0;
  static const double _danoPancadaFase1 = 6.0;
  static const double _danoPancadaFase2 = 8.0;
  static const double _recuperacaoFase1 = 1.2;
  static const double _recuperacaoFase2 = 0.9;

  /// Distância a partir da qual o salto é cogitado — só entra quando o
  /// jogador já saiu do alcance normal da pancada.
  static const double _leapGatilho = 40.0;
  static const double _leapTelegraph = 0.45;
  static const double _leapDuracao = 0.35;
  static const double _leapDistancia = 70.0;
  static const double _leapAltura = 24.0;
  static const double _leapCooldown = 3.0;
  static const double _leapDano = 10.0;
  static const double _leapEmpurrao = 70.0;
  static const double _leapRecuperacao = 0.5;

  double _preparoTimer = 0.0;
  double _recuperacaoTimer = 0.0;
  bool _preparando = false;
  bool _faseDois = false;

  bool _leapTelegrafando = false;
  bool _leapEmAndamento = false;
  bool _leapRecuperando = false;
  double _leapTimer = 0.0;
  double _leapCooldownTimer = _leapCooldown; // pronto desde o começo
  Vector2 _leapDirecao = Vector2.zero();

  UrsoPlantaBossEnemy({
    required super.position,
    required super.playerTarget,
  }) : super(
         creature: CreatureRegistry.ursoPlantaEvo,
         speed: 14.0, // continua o mais lento — a solução é o salto, não a perna
         health: _vidaInicial,
         dmg: 2,
         size: Vector2(48, 48),        // dobro do padrão (16x16)
         hitboxSize: Vector2(30, 32),  // dobro do hitbox normal (15, 16)
         isPushable: false,
       );

  double get _danoPancada => _faseDois ? _danoPancadaFase2 : _danoPancadaFase1;
  double get _recuperacao => _faseDois ? _recuperacaoFase2 : _recuperacaoFase1;

  @override
  void movimento(double dt) {
    if (!_faseDois && health <= _vidaInicial / 2) _faseDois = true;

    _leapCooldownTimer += dt;

    // Pousou do salto: fica exposto, janela de contra-ataque maior que a da
    // pancada normal — o golpe custou mais, a punição também.
    if (_leapRecuperando) {
      _leapTimer -= dt;
      animateMovement(dt, isMoving: false);
      if (_leapTimer <= 0) _leapRecuperando = false;
      return;
    }

    // No ar: cobre a distância do salto com um arco visual em Y.
    if (_leapEmAndamento) {
      _leapTimer += dt;
      final progresso = (_leapTimer / _leapDuracao).clamp(0.0, 1.0);
      final zOffset = 4 * _leapAltura * progresso * (1 - progresso);
      visual.position.y = size.y / 2 - zOffset;
      position += _leapDirecao * (_leapDistancia / _leapDuracao) * dt;

      if (_leapTimer >= _leapDuracao) {
        _leapEmAndamento = false;
        visual.position.y = size.y / 2;
        _leapRecuperando = true;
        _leapTimer = _leapRecuperacao;
        _baterChao();
      }
      return;
    }

    // Aviso do salto: agacha mais forte que a pancada normal — golpe maior,
    // tell maior.
    if (_leapTelegrafando) {
      _leapTimer += dt;
      final flip = visual.scale.x.isNegative ? -1.0 : 1.0;
      final progresso = (_leapTimer / _leapTelegraph).clamp(0.0, 1.0);
      visual.scale = Vector2((1.0 + progresso * 0.2) * flip, 1.0 - progresso * 0.25);

      if (_leapTimer >= _leapTelegraph) {
        _leapTelegrafando = false;
        _leapEmAndamento = true;
        _leapTimer = 0.0;
        visual.scale = Vector2(flip, 1.0);
        _leapDirecao = (alvoPosicao - absolutePosition).normalized();
      }
      return;
    }

    // Recuperação pós-pancada: fica exposto, igual à normal.
    if (_recuperacaoTimer > 0) {
      _recuperacaoTimer -= dt;
      animateMovement(dt, isMoving: false);
      return;
    }

    if (_preparando) {
      _preparoTimer += dt;

      final flip = visual.scale.x.isNegative ? -1.0 : 1.0;
      final progresso = (_preparoTimer / _preparoPancada).clamp(0.0, 1.0);
      visual.scale = Vector2((1.0 + progresso * 0.25) * flip, 1.0 - progresso * 0.2);

      if (_preparoTimer >= _preparoPancada) {
        _preparando = false;
        _preparoTimer = 0.0;
        _recuperacaoTimer = _recuperacao;
        visual.scale = Vector2(flip, 1.0);
        _descerPancada();
      }
      return;
    }

    final distancia = (alvoPosicao - absolutePosition).length;

    // Anti-kite: só na fase 2, só quando já fugiu do alcance da pancada, só
    // com o salto fora de cooldown.
    if (_faseDois && distancia > _leapGatilho && _leapCooldownTimer >= _leapCooldown) {
      _leapTelegrafando = true;
      _leapTimer = 0.0;
      _leapCooldownTimer = 0.0;
      spawnAlerta(duracao: _leapTelegraph);
      return;
    }

    if (distancia <= _alcancePancada) {
      _preparando = true;
      _preparoTimer = 0.0;
      return;
    }

    updateChaseMovement(dt);
  }

  void _descerPancada() {
    parent?.add(ExplosionHitbox(
      position: position.clone(),
      isEnemy: true, // sem isso a explosão não machuca o jogador
      origem: creature,
      dono: this,
      dmg: _danoPancada,
      knockback: _empurraoPancada,
      size: Vector2(50, 50),
      cor1: CreatureRegistry.ursoPlanta.corClara,
      cor2: CreatureRegistry.ursoPlanta.corEscura,
    ));
  }

  void _baterChao() {
    parent?.add(ExplosionHitbox(
      position: position.clone(),
      isEnemy: true,
      origem: creature,
      dono: this,
      dmg: _leapDano,
      knockback: _leapEmpurrao,
      size: Vector2(64, 64),
      cor1: CreatureRegistry.ursoPlanta.corClara,
      cor2: CreatureRegistry.ursoPlanta.corEscura,
    ));
  }

  @override
  void death() {
    unlockCreature();
    super.death();
  }
}
