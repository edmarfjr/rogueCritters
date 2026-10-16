import 'package:creatures_rogue/game/components/creatures/creature_type.dart';

/// Efeitos sonoros do jogo. Cada valor mapeia pra um arquivo em
/// `assets/sounds/sfx/` (ver `GameAudio._paths`) — adicionar um som novo é só
/// acrescentar aqui e no mapa.
enum Sfx {
  dash,
  retorno,
  liberar,
  enemyDie,
  btn,
  stairs,
  die,
  hit,
  fogo,
  agua,
  raio,
  veneno,
  defesa,
  tiro,
  pick,
  use,

  /// O JOGADOR perdeu vida — diferente do [hit], que é o inimigo apanhando.
  dano,
  critico,
  escudoQuebra,
  esquiva,

  /// Bipe de vida no fim, repetido pelo `Player` enquanto durar.
  vidaBaixa,

  /// Ataque de criatura neutra (ver [CreatureTypeSfx]).
  golpe,

  moeda,

  /// Toca em toda cura que de fato sobe a vida (ver `Player.heal`).
  cura,

  /// Item, upgrade ou compra na loja: o jingle de conquista.
  item,
  salaLimpa,
  salaTranca,
  semDinheiro,

  /// O chefe aparece na cutscene.
  bossEntrada,
  evolucao,

  /// Um inimigo ACABOU de ser atordoado (não toca enquanto já estava).
  atordoado,

  /// Tentou a habilidade 1 sem energia.
  energiaVazia,

  /// Menu: escolher numa lista/aba ([cursor]) e sair de uma tela ([voltar]).
  /// Confirmar continua sendo o [btn].
  cursor,
  voltar,

  /// Explosões de habilidade, uma por elemento (ver [CreatureTypeSfx]).
  explosao,
  explosaoFogo,
  explosaoAgua,
  explosaoRaio,
  explosaoVeneno,

  bossDerrotado,

  /// Um campeão terminou de surgir (ver `Enemy.promoverACampeao`).
  campeao,

  /// O escudo passivo ganhou uma carga de volta.
  escudoRecarga,
}

/// Som de ataque elemental de cada [CreatureType] — usado nos pontos onde o
/// dano de fato sai (`ExplosionHitbox`/`Projectile`), não em cada `Ability`
/// individualmente.
extension CreatureTypeSfx on CreatureType {
  Sfx? get attackSfx => switch (this) {
        CreatureType.fogo => Sfx.fogo,
        CreatureType.agua => Sfx.agua,
        CreatureType.eletrico => Sfx.raio,
        CreatureType.planta => Sfx.veneno,
        CreatureType.neutro => Sfx.golpe,
      };

  /// Som da explosão de cada elemento — `ExplosionHitbox` com `explosao`
  /// ligado toca este no lugar do [attackSfx].
  Sfx get explosaoSfx => switch (this) {
        CreatureType.fogo => Sfx.explosaoFogo,
        CreatureType.agua => Sfx.explosaoAgua,
        CreatureType.eletrico => Sfx.explosaoRaio,
        CreatureType.planta => Sfx.explosaoVeneno,
        CreatureType.neutro => Sfx.explosao,
      };
}
