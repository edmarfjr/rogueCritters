import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/creatures/ability.dart';
import 'package:creatures_rogue/game/components/creatures/ability_user.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';

/// Tubarão de Água — botão B. O Tubarão se enfia no chão e nada por baixo
/// dele: continua respondendo ao controle, mais rápido, atravessando pedra e
/// armadilha, e volta à superfície depois de [duracao] segundos com uma
/// explosão no ponto em que emergiu.
///
/// Não é mais um salto com destino travado no inimigo mais próximo. O salto
/// antigo decidia tudo no instante do toque — para onde ir e onde a explosão
/// cairia — e o jogador só assistia aos 0,6s seguintes. Aqui a explosão sai
/// onde ele PARAR, então os dois segundos embaixo da terra são a habilidade,
/// não a animação dela: dá pra entrar num canto, cortar a sala por dentro de
/// uma parede de pedras e sair no meio do grupo.
///
/// O que ele atravessa e o que não atravessa está em `Player.submerso`, e a
/// divisão é a que o cenário já sugere: pedra é chão sólido acima da cabeça
/// dele, e passa; buraco é o chão acabando, e barra. Parede e porta trancada
/// também barram — uma sala fechada precisa continuar fechada.
///
/// Dano da explosão = ataque da criatura × [coef] — ver BaseStats.
class MergulhoEEstouro extends Ability {
  /// Quanto tempo o Tubarão fica embaixo da terra. É o número de ajuste
  /// principal da habilidade: é a janela inteira de invulnerabilidade.
  final double duracao;

  /// Multiplicador da velocidade máxima enquanto enterrado.
  final double fatorVelocidade;

  final double coef;
  final double empurrao;
  

  const MergulhoEEstouro({
    this.duracao = 2.0,
    this.fatorVelocidade = 1.5,
    this.coef = 1.0,
    this.empurrao = 70,
  }) : super(
         nome: 'Mergulho e Estouro',
         descricao:
             'Mergulha no chão, se movendo mais rápido e explode ao emergir.',
         cooldown: 3.5,
         tipo: AbilityTipo.esquiva,
       );

  @override
  void execute(AbilityUser user, Vector2 dir) {
    // Dano e tipo são lidos AGORA, não lá dentro do `aoEmergir`:
    // `trocarCriatura` muta esta mesma instância de `Player`, então ler
    // `user.creatureData` dois segundos depois poderia dar a criatura errada.
    user.grantInvulnerability(duracao+0.3);
    final dano = user.creatureData.stats.ataque * coef;
    final tipo = user.creatureData.tipo;

    // `dir` é ignorado de propósito: a mira travada no inimigo mais próximo
    // servia ao salto de destino fixo. Agora quem dirige é o analógico de
    // movimento, quadro a quadro.
    user.submergir(
      duracao: duracao,
      fatorVelocidade: fatorVelocidade,
      aoEmergir: () {
        user.parent?.add(
          ExplosionHitbox(
            explosao: true,
            position: user.position.clone(),
            dmg: dano,
            knockback: empurrao,
            size: Vector2(36, 36),
            tipo: tipo,
          ),
        );
      },
    );
  }
}
