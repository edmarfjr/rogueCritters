import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/creatures/ability.dart';
import 'package:creatures_rogue/game/components/effects/ghost_effect.dart';
import 'package:creatures_rogue/game/components/creatures/ability_user.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import 'package:creatures_rogue/game/components/projeteis/projectile.dart';

/// Evolução de [MergulhoEEstouro]: mergulho mais longo e, no ponto de
/// emersão, uma poça que atrasa quem pisar.
///
/// O problema da forma base é o depois: o Tubarão fecha distância, estoura, e
/// fica parado no meio de tudo com a habilidade em recarga. A poça resolve
/// isso sem dar mais dano — quem foi empurrado pelo estouro volta andando na
/// metade da velocidade, o que é exatamente o tempo de que ele precisa.
///
/// A poça é `speed: 0` e `atravessa` alto, o mesmo jeito que as outras áreas
/// de chão do jogo são feitas, e sai sem som: o estouro logo antes já tocou o
/// som de água, e dois no mesmo quadro abafam um ao outro.
class MergulhoEEstouroEvo extends Ability {
  final double distancia;
  final double duracao;
  final double altura;
  final double coef;
  final double empurrao;
  final double duracaoPoca;
  final double lentidaoDuracao;
  final double lentidaoFator;

  const MergulhoEEstouroEvo({
    this.distancia = 65,
    this.duracao = 0.6,
    this.altura = 24,
    this.coef = 1.2,
    this.empurrao = 85,
    this.duracaoPoca = 4.0,
    this.lentidaoDuracao = 2.5,
    this.lentidaoFator = 0.5,
  }) : super(
         nome: 'Mergulho Profundo',
         descricao:
             'Mergulha invulnerável, explode ao emergir e deixa uma poça congelante.',
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
      fatorVelocidade: 2,
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
        user.parent?.add(
          Projectile(
            owner: user,
            position: user.position.clone(),
            direction: Vector2.zero(),
            speed: 0,
            dmg: 0,
            kbForce: 0,
            sprPath: 'projeteis/bolaGrande.png',
            cor1: user.creatureData.corClara,
            cor2: user.creatureData.corEscura,
            tipo: user.creatureData.tipo,
            lentidaoDuracao: lentidaoDuracao,
            lentidaoFator: lentidaoFator,
            atravessa: 100,
            size: Vector2(32, 32),
            lifeTime: duracaoPoca,
            radius: 16,
            playSfx: false,
          ),
        );
      },
    );

  }
}
