import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import 'package:creatures_rogue/game/components/creatures/creature_progress.dart';
import 'package:creatures_rogue/game/components/player/player.dart';
import 'package:creatures_rogue/l10n/creature_i18n.dart';
import 'creatures/ave_eletrica_boss_enemy.dart';
import 'creatures/ave_neutro_boss_enemy.dart';
import 'creatures/bomba_fogo_boss_enemy.dart';
import 'creatures/cao_neutro_boss_enemy.dart';
import 'creatures/gato_neutro_boss_enemy.dart';
import 'creatures/peixe_neutro_boss_enemy.dart';
import 'creatures/caranguejo_ermitao_boss_enemy.dart';
import 'creatures/cobra_agua_boss_enemy.dart';
import 'creatures/cogumelo_planta_boss_enemy.dart';
import 'creatures/olho_eletrico_boss_enemy.dart';
import 'creatures/roda_fogo_boss_enemy.dart';
import 'creatures/sereia_agua_boss_enemy.dart';
import 'creatures/grilo_eletrico_boss_enemy.dart';
import 'creatures/leao_eletrico_boss_enemy.dart';
import 'creatures/ourico_eletrico_boss_enemy.dart';
import 'creatures/pinguim_agua_boss_enemy.dart';
import 'creatures/roedor_fogo_boss_enemy.dart';
import 'creatures/sapo_agua_boss_enemy.dart';
import 'creatures/slime_planta_boss_enemy.dart';
import 'creatures/tartaruga_planta_boss_enemy.dart';
import 'creatures/toco_planta_boss_enemy.dart';
import 'creatures/tornado_fogo_boss_enemy.dart';
import 'creatures/tubarao_agua_boss_enemy.dart';
import 'creatures/urso_planta_boss_enemy.dart';
import 'enemy.dart';

typedef BossBuilder = Enemy Function(Vector2 position, Player playerTarget);

class BossOption {
  /// Criatura que este boss libera pra jogar quando é derrotado.
  final String creatureId;

  final BossBuilder builder;

  const BossOption({required this.creatureId, required this.builder});

  /// Nome mostrado na barra de vida e no reveal. Derivado da criatura em vez de
  /// guardado aqui: os nomes das criaturas ainda estão sendo definidos, e
  /// duplicar faria a barra do boss divergir do resto do jogo.
  String nome(BuildContext context) =>
      creatureName(context, creatureId).toUpperCase();
}

/// Quais bosses existem e qual deles cai na run atual.
///
/// Escopo do projeto: toda criatura tem as três formas (jogável, inimigo comum
/// e boss), então esta lista termina cobrindo o elenco inteiro — sem isso,
/// criatura sem boss ficaria sem via de desbloqueio.
class BossRegistry {
  static final List<List<BossOption>> all = [
    [
      BossOption(
        creatureId: 'tartaruga_planta',
        builder: (pos, plr) =>
            TartarugaPlantaBossEnemy(position: pos, playerTarget: plr),
      ),
      BossOption(
        creatureId: 'ave_eletrica',
        builder: (pos, plr) =>
            AveEletricaBossEnemy(position: pos, playerTarget: plr),
      ),
      BossOption(
        creatureId: 'roedor_fogo',
        builder: (pos, plr) =>
            RoedorFogoBossEnemy(position: pos, playerTarget: plr),
      ),
      BossOption(
        creatureId: 'sapo_agua',
        builder: (pos, plr) =>
            SapoAguaBossEnemy(position: pos, playerTarget: plr),
      ),
    ],
    [
      BossOption(
        creatureId: 'cobra_agua',
        builder: (pos, plr) =>
            CobraAguaBossEnemy(position: pos, playerTarget: plr),
      ),
      BossOption(
        creatureId: 'tornado_fogo',
        builder: (pos, plr) =>
            TornadoFogoBossEnemy(position: pos, playerTarget: plr),
      ),
      BossOption(
        creatureId: 'urso_planta',
        builder: (pos, plr) =>
            UrsoPlantaBossEnemy(position: pos, playerTarget: plr),
      ),
      BossOption(
        creatureId: 'grilo_eletrico',
        builder: (pos, plr) =>
            GriloEletricoBossEnemy(position: pos, playerTarget: plr),
      ),
    ],
    // Dungeon 3 — as criaturas que ganharam evolucao por ultimo.
    [
      BossOption(
        creatureId: 'slime_planta',
        builder: (pos, plr) =>
            SlimePlantaBossEnemy(position: pos, playerTarget: plr),
      ),
      BossOption(
        creatureId: 'ourico_eletrico',
        builder: (pos, plr) =>
            OuricoEletricoBossEnemy(position: pos, playerTarget: plr),
      ),
      BossOption(
        creatureId: 'pinguim_agua',
        builder: (pos, plr) =>
            PinguimAguaBossEnemy(position: pos, playerTarget: plr),
      ),
      BossOption(
        creatureId: 'bomba_fogo',
        builder: (pos, plr) =>
            BombaFogoBossEnemy(position: pos, playerTarget: plr),
      ),
    ],
    // Dungeon 4 — as quatro ultimas criaturas a ganhar evolucao. Mesma regra
    // das pools anteriores: um boss de cada tipo elemental, pra que nenhuma
    // dungeon possa sortear dois do mesmo e deixar um elemento sem via de
    // desbloqueio.
    //
    // Acrescentar esta lista ESTENDE o jogo: `ehUltimaDungeon` compara o andar
    // atual com `BossRegistry.all.length`, entao cada pool nova aumenta o
    // numero de dungeons ate a vitoria.
    [
      BossOption(
        creatureId: 'toco_planta',
        builder: (pos, plr) =>
            TocoPlantaBossEnemy(position: pos, playerTarget: plr),
      ),
      BossOption(
        creatureId: 'leao_eletrico',
        builder: (pos, plr) =>
            LeaoEletricoBossEnemy(position: pos, playerTarget: plr),
      ),
      BossOption(
        creatureId: 'tubarao_agua',
        builder: (pos, plr) =>
            TubaraoAguaBossEnemy(position: pos, playerTarget: plr),
      ),
      BossOption(
        creatureId: 'caranguejo_fogo',
        builder: (pos, plr) =>
            CaranguejoErmitaoBossEnemy(position: pos, playerTarget: plr),
      ),
    ],
    // Dungeon 5 — as quatro criaturas mais novas do elenco, uma por
    // elemento, como nas pools anteriores.
    [
      BossOption(
        creatureId: 'roda_fogo',
        builder: (pos, plr) =>
            RodaFogoBossEnemy(position: pos, playerTarget: plr),
      ),
      BossOption(
        creatureId: 'cogumelo_planta',
        builder: (pos, plr) =>
            CogumeloPlantaBossEnemy(position: pos, playerTarget: plr),
      ),
      BossOption(
        creatureId: 'sereia_agua',
        builder: (pos, plr) =>
            SereiaAguaBossEnemy(position: pos, playerTarget: plr),
      ),
      BossOption(
        creatureId: 'olho_eletrico',
        builder: (pos, plr) =>
            OlhoEletricoBossEnemy(position: pos, playerTarget: plr),
      ),
    ],
    // Dungeon 6, a FINAL: os quatro neutros, que sao a origem do elenco. Nao
    // segue a regra de um boss por elemento das pools anteriores porque os
    // neutros nao tem elemento — e eles so aparecem aqui, inclusive como
    // inimigos comuns (ver `EnemySpawner`).
    //
    // Sendo os mais fracos do elenco, a dificuldade da dungeon vem da chance
    // de campeao elevada em `RoomComponent`, nao das criaturas.
    [
      BossOption(
        creatureId: 'cao_neutro',
        builder: (pos, plr) =>
            CaoNeutroBossEnemy(position: pos, playerTarget: plr),
      ),
      BossOption(
        creatureId: 'gato_neutro',
        builder: (pos, plr) =>
            GatoNeutroBossEnemy(position: pos, playerTarget: plr),
      ),
      BossOption(
        creatureId: 'ave_neutro',
        builder: (pos, plr) =>
            AveNeutroBossEnemy(position: pos, playerTarget: plr),
      ),
      BossOption(
        creatureId: 'peixe_neutro',
        builder: (pos, plr) =>
            PeixeNeutroBossEnemy(position: pos, playerTarget: plr),
      ),
    ],
  ];

  /// Sorteia um boss pra dungeon `dungeon` (1 = primeira lista de [all], 2 =
  /// segunda, e por aí em diante). Dungeons além das cadastradas ciclam de
  /// volta pra lista 0, então a run nunca fica sem boss só por ter passado
  /// da última dungeon definida.
  ///
  /// Prefere boss cuja criatura o jogador AINDA NÃO desbloqueou: o boss é a
  /// via de desbloqueio, e sortear a criatura que ele já tem (a da intro, no
  /// caso mais comum) desperdiça a dungeon. Com a lista inteira já
  /// desbloqueada, volta a sortear entre todos — repetir aí é esperado (ver
  /// `BossRevealOverlay`, que mostra a criatura colorida quando já é dele).
  ///
  /// No GOD MODE todas contam como desbloqueadas (ver
  /// `CreatureProgress.isUnlocked`), então o sorteio cai na lista inteira.
  static BossOption sortear(Random random, int dungeon) {
    final lista = all[(dungeon - 1) % all.length];
    final ineditos = lista
        .where((b) => !CreatureProgress.instance.isUnlocked(b.creatureId))
        .toList();
    final candidatos = ineditos.isEmpty ? lista : ineditos;
    return candidatos[random.nextInt(candidatos.length)];
  }
}
