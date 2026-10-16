import 'package:creatures_rogue/game/components/creatures/abilities/brado_evo.dart';
import 'package:creatures_rogue/game/components/enemies/creatures/roda_fogo_enemy.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/choque_eletrico_evo.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/deixar_bomba_evo.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/disparada_congelante.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/disparada_veloz_evo.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/esquiva_tornado_evo.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/jato_aquatico_evo.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/jogada_de_corpo_evo.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/mega_soco_evo.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/soco_flamejante_evo.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/tiro_de_gelo.dart';
import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/choque_eletrico.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/cuspe_venenoso.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/deixar_bomba.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/disparada_veloz.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/tiro_de_gelo_evo.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/disparada_congelante_evo.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/cuspe_venenoso_evo.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/explosao_venenosa_evo.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/ericar_evo.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/escudo_de_espinhos_evo.dart';
import 'package:creatures_rogue/game/components/creatures/passives/roda_de_fogo.dart';
import 'package:creatures_rogue/game/components/creatures/passives/faro_do_predador.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/esquiva_bomba.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/esquiva_tornado.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/explosao_venenosa.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/soco_flamejante.dart';
import 'abilities/esporo_errante.dart';
import 'abilities/esporo_errante_evo.dart';
import 'abilities/casulo_de_esporos.dart';
import 'abilities/casulo_de_esporos_evo.dart';
import 'package:creatures_rogue/game/components/enemies/creatures/cogumelo_planta_enemy.dart';
import 'abilities/arranhao.dart';
import 'abilities/baforada_de_cinzas_evo.dart';
import 'abilities/recolher_no_casco_evo.dart';
import 'abilities/folhas_navalha_evo.dart';
import 'abilities/enraizar_evo.dart';
import 'abilities/mordida_evo.dart';
import 'abilities/mergulho_e_estouro_evo.dart';
import 'abilities/estocada_relampago_evo.dart';
import 'abilities/investida_da_lanca_evo.dart';
import 'abilities/baforada_de_cinzas.dart';
import 'abilities/bicada_rapida.dart';
import 'abilities/bico_eletrico.dart';
import 'abilities/bico_eletrico_evo.dart';
import 'abilities/bola_dagua_evo.dart';
import 'abilities/bolha_protetora.dart';
import 'abilities/bolha_protetora_evo.dart';
import 'abilities/brado.dart';
import 'abilities/casco_fechado.dart';
import 'abilities/casco_fechado_evo.dart';
import 'abilities/corrente_estatica.dart';
import 'abilities/corrente_estatica_evo.dart';
import 'abilities/cuspe_de_semente_evo.dart';
import 'abilities/disparada_flamejante_evo.dart';
import 'abilities/cuspe_de_semente.dart';
import 'abilities/disparada_flamejante.dart';
import 'abilities/escamas_escorregadias.dart';
import 'abilities/latido_feroz.dart';
import 'abilities/mordida_certeira.dart';
import 'abilities/rabanada.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/rabanada_evo.dart';
import 'package:creatures_rogue/game/components/creatures/abilities/escamas_espelhadas.dart';
import 'abilities/rajada_de_brasa_evo.dart';
import 'abilities/salto_felino.dart';
import 'abilities/voo_alto.dart';
import 'abilities/voo_alto_evo.dart';
import 'abilities/bicada_rapida_evo.dart';
import 'abilities/mordida_certeira_evo.dart';
import 'abilities/latido_feroz_evo.dart';
import 'abilities/arranhao_evo.dart';
import 'abilities/salto_felino_evo.dart';
import 'abilities/enraizar.dart';
import 'abilities/ericar.dart';
import 'abilities/escudo_de_espinhos.dart';
import 'abilities/folhas_navalha.dart';
import 'abilities/estocada_relampago.dart';
import 'abilities/investida_da_lanca.dart';
import 'abilities/jato_aquatico.dart';
import 'abilities/bola_dagua.dart';
import 'abilities/jogada_de_corpo.dart';
import 'abilities/mega_soco.dart';
import 'abilities/mergulho_e_estouro.dart';
import 'abilities/mordida.dart';
import 'abilities/rajada_de_brasa.dart';
import 'abilities/recolher_no_casco.dart';
import 'base_stats.dart';
import 'creature_data.dart';
import 'creature_type.dart';
/*import '//passives/rastro_flamejante.dart';
import '//passives/casco_reflexivo.dart';
import '//passives/bolha_autonoma.dart';
import '//passives/corrente_reflexa.dart';
import '//passives/tornado_residual.dart';
import '//passives/salto_aquatico.dart';
import '//passives/brado_reflexo.dart';
import '//passives/reflexo_eletrico.dart';
import '//passives/bomba_na_esquiva.dart';
import '//passives/pecoenha_reflexiva.dart';
import '//passives/rastro_congelante.dart';
import '//passives/retaliacao_eletrica.dart';
import '//passives/fumaca_ao_lacar.dart';
import '//passives/raizes_do_laco.dart';
import '//passives/investida_predatoria.dart';
import '//passives/golpe_de_lanca.dart';
*/
import '../effects/movement_animator.dart';
import '../enemies/creatures/ave_eletrica_enemy.dart';
import '../enemies/creatures/ave_neutro_enemy.dart';
import '../enemies/creatures/bomba_fogo_enemy.dart';
import '../enemies/creatures/cao_neutro_enemy.dart';
import '../enemies/creatures/gato_neutro_enemy.dart';
import '../enemies/creatures/peixe_neutro_enemy.dart';
import '../enemies/creatures/caranguejo_ermitao_enemy.dart';
import '../enemies/creatures/cobra_agua_enemy.dart';
import '../enemies/creatures/grilo_eletrico_enemy.dart';
import '../enemies/creatures/leao_eletrico_enemy.dart';
import '../enemies/creatures/ourico_eletrico_enemy.dart';
import '../enemies/creatures/pinguim_agua_enemy.dart';
import '../enemies/creatures/roedor_fogo_enemy.dart';
import '../enemies/creatures/sapo_agua_enemy.dart';
import '../enemies/creatures/slime_planta_enemy.dart';
import '../enemies/creatures/tartaruga_planta_enemy.dart';
import '../enemies/creatures/toco_planta_enemy.dart';
import '../enemies/creatures/tornado_fogo_enemy.dart';
import '../enemies/creatures/tubarao_agua_enemy.dart';
import '../enemies/creatures/urso_planta_enemy.dart';
import '../enemies/creatures/sereia_agua_enemy.dart';
import '../enemies/creatures/olho_eletrico_enemy.dart';
import 'abilities/raio_ocular.dart';
import 'abilities/piscar.dart';
import 'abilities/tentaculada.dart';
import 'abilities/redemoinho_de_tentaculos.dart';
import 'abilities/esguicho_de_tinta.dart';
import 'abilities/cortina_de_tinta.dart';

class CreatureRegistry {
  static final CreatureData roedorFogo = CreatureData(
    id: 'roedor_fogo',
    nome: 'Torchmin',
    spritePath: 'actors/ratFogo.png',
    tipo: CreatureType.fogo,
    corClara: Palette.pumpkin,
    corEscura: Palette.vermelho,
    stats: BaseStats(maxHp: 4, speed: 70, defesa: 1, ataque: 3),
    ability1: RajadaDeBrasa(),
    ability2: DisparadaFlamejante(),
    moveAnim: MovementAnimation.caminhada,
    hitboxSize: Vector2(8, 10),
    enemyBuilder: (pos, plr) =>
        RoedorFogoEnemy(position: pos, playerTarget: plr),
    //passive: RastroFlamejante(),
    evoluir: () => roedorFogoEvo,
  );

  /// Forma evoluída de [roedorFogo] (ver `PIVOT_EVOLUCAO`) — mesmo `id`, mesmo
  /// `ability1`: só sprite e `ability2` mudam, então o retrato do banco e o
  /// filtro de "criatura já no grupo" da recruta selvagem continuam
  /// funcionando sem saber que evolução existe.
  static final CreatureData roedorFogoEvo = CreatureData(
    id: 'roedor_fogo',
    nome: 'Torchmin',
    spritePath: 'actors/ratFogoEvo.png',
    tipo: CreatureType.fogo,
    corClara: Palette.pumpkin,
    corEscura: Palette.vermelho,
    stats: BaseStats(maxHp: 6, speed: 70, defesa: 1, ataque: 3),
    ability1: RajadaDeBrasaEvo(),
    ability2: DisparadaFlamejanteEvo(),
    moveAnim: MovementAnimation.caminhada,
    hitboxSize: Vector2(8, 10),
    enemyBuilder: (pos, plr) =>
        RoedorFogoEnemy(position: pos, playerTarget: plr),
  );

  static final CreatureData tartarugaPlanta = CreatureData(
    id: 'tartaruga_planta',
    nome: 'Turtrent',
    spritePath: 'actors/tartPlanta.png',
    tipo: CreatureType.planta,
    corClara: Palette.verde,
    corEscura: Palette.marrom,
    stats: BaseStats(maxHp: 4, speed: 50, defesa: 1, ataque: 3),
    ability1: CuspeDeSemente(),
    ability2: CascoFechado(),
    moveAnim: MovementAnimation.arrastar,
    hitboxSize: Vector2(14, 14),
    enemyBuilder: (pos, plr) =>
        TartarugaPlantaEnemy(position: pos, playerTarget: plr),
    //passive: CascoReflexivo(),
    evoluir: () => tartarugaPlantaEvo,
  );

  static final CreatureData tartarugaPlantaEvo = CreatureData(
    id: 'tartaruga_planta',
    nome: 'Turtrent',
    spritePath: 'actors/tartPlantaEvo.png',
    tipo: CreatureType.planta,
    corClara: Palette.verde,
    corEscura: Palette.marrom,
    stats: BaseStats(maxHp: 4, speed: 50, defesa: 2, ataque: 3),
    ability1: CuspeDeSementeEvo(),
    ability2: CascoFechadoEvo(),
    moveAnim: MovementAnimation.arrastar,
    hitboxSize: Vector2(14, 14),
    enemyBuilder: (pos, plr) =>
        TartarugaPlantaEnemy(position: pos, playerTarget: plr),
  );

  static final CreatureData sapoAgua = CreatureData(
    id: 'sapo_agua',
    nome: 'Frowago',
    spritePath: 'actors/sapoAgua.png',
    tipo: CreatureType.agua,
    corClara: Palette.azul,
    corEscura: Palette.indigo,
    stats: BaseStats(maxHp: 4, speed: 70, defesa: 1, ataque: 2),
    ability1: BolaDagua(),
    ability2: BolhaProtetora(),
    moveAnim: MovementAnimation.saltitar,
    hitboxSize: Vector2(12, 10),
    enemyBuilder: (pos, plr) => SapoAguaEnemy(position: pos, playerTarget: plr),
    //passive: BolhaAutonoma(),
    evoluir: () => sapoAguaEvo,
  );

  static final CreatureData sapoAguaEvo = CreatureData(
    id: 'sapo_agua',
    nome: 'Frowago',
    spritePath: 'actors/sapoAguaEvo.png',
    tipo: CreatureType.agua,
    corClara: Palette.azul,
    corEscura: Palette.indigo,
    stats: BaseStats(maxHp: 6, speed: 70, defesa: 1, ataque: 2),
    ability1: BolaDaguaEvo(),
    ability2: BolhaProtetoraEvo(),
    moveAnim: MovementAnimation.saltitar,
    hitboxSize: Vector2(12, 10),
    enemyBuilder: (pos, plr) => SapoAguaEnemy(position: pos, playerTarget: plr),
  );

  static final CreatureData aveEletrica = CreatureData(
    id: 'ave_eletrica',
    nome: 'Garibirb',
    spritePath: 'actors/aveEletric.png',
    tipo: CreatureType.eletrico,
    corClara: Palette.amarelo,
    corEscura: Palette.pumpkin,
    stats: BaseStats(maxHp: 4, speed: 80, defesa: 1, ataque: 1, critBonus: 5, tempoAteMaxima: 0.4, tempoAteParar: 0.4),
    ability1: BicoEletrico(),
    ability2: CorrenteEstatica(),
    moveAnim: MovementAnimation.flutuar,
    hitboxSize: Vector2(9, 11),
    enemyBuilder: (pos, plr) =>
        AveEletricaEnemy(position: pos, playerTarget: plr),
    //passive: CorrenteReflexa(),
    evoluir: () => aveEletricaEvo,
  );

  static final CreatureData aveEletricaEvo = CreatureData(
    id: 'ave_eletrica',
    nome: 'Garibirb',
    spritePath: 'actors/aveEletricEvo.png',
    tipo: CreatureType.eletrico,
    corClara: Palette.amarelo,
    corEscura: Palette.pumpkin,
    stats: BaseStats(maxHp: 6, speed: 80, defesa: 1, ataque: 1),
    ability1: BicoEletricoEvo(),
    ability2: CorrenteEstaticaEvo(),
    moveAnim: MovementAnimation.flutuar,
    hitboxSize: Vector2(9, 11),
    enemyBuilder: (pos, plr) =>
        AveEletricaEnemy(position: pos, playerTarget: plr),
  );

  static final CreatureData tornadoFogo = CreatureData(
    id: 'tornado_fogo',
    nome: 'Flamenado',
    spritePath: 'actors/furacFogo.png',
    tipo: CreatureType.fogo,
    corClara: Palette.vermelho,
    corEscura: Palette.roxoEsc,
    stats: BaseStats(maxHp: 4, speed: 70, defesa: 1, ataque: 4),
    ability1: SocoFlamejante(),
    ability2: EsquivaTornado(),
    moveAnim: MovementAnimation.flutuar,
    hitboxSize: Vector2(8, 10),
    enemyBuilder: (pos, plr) =>
        TornadoFogoEnemy(position: pos, playerTarget: plr),
    evoluir: () => tornadoFogoEvo,
  );

  static final CreatureData tornadoFogoEvo = CreatureData(
    id: 'tornado_fogo',
    nome: 'Flamenado',
    spritePath: 'actors/furacFogoEvo.png',
    tipo: CreatureType.fogo,
    corClara: Palette.vermelho,
    corEscura: Palette.roxoEsc,
    stats: BaseStats(maxHp: 6, speed: 70, defesa: 1, ataque: 4),
    ability1: SocoFlamejanteEvo(),
    ability2: EsquivaTornadoEvo(),
    moveAnim: MovementAnimation.flutuar,
    hitboxSize: Vector2(8, 10),
    enemyBuilder: (pos, plr) =>
        TornadoFogoEnemy(position: pos, playerTarget: plr),
    //passive: TornadoResidual(),
  );

  static final CreatureData cobraAgua = CreatureData(
    id: 'cobra_agua',
    nome: 'Seadracon',
    spritePath: 'actors/cobraAgua.png',
    tipo: CreatureType.agua,
    corClara: Palette.azul,
    corEscura: Palette.pumpkin,
    stats: BaseStats(maxHp: 4, speed: 50, defesa: 1, ataque: 4),
    ability1: JatoAquatico(),
    ability2: JogadaDeCorpo(),
    moveAnim: MovementAnimation.arrastar,
    hitboxSize: Vector2(9, 14),
    enemyBuilder: (pos, plr) =>
        CobraAguaEnemy(position: pos, playerTarget: plr),
    evoluir: () => cobraAguaEvo,
  );

  static final CreatureData cobraAguaEvo = CreatureData(
    id: 'cobra_agua',
    nome: 'Seadracon',
    spritePath: 'actors/cobraAguaEvo.png',
    tipo: CreatureType.agua,
    corClara: Palette.azul,
    corEscura: Palette.pumpkin,
    stats: BaseStats(maxHp: 6, speed: 50, defesa: 1, ataque: 4),
    ability1: JatoAquaticoEvo(),
    ability2: JogadaDeCorpoEvo(),
    moveAnim: MovementAnimation.arrastar,
    hitboxSize: Vector2(14, 14),
    enemyBuilder: (pos, plr) =>
        CobraAguaEnemy(position: pos, playerTarget: plr),
  );

  static final CreatureData ursoPlanta = CreatureData(
    id: 'urso_planta',
    nome: 'Panjoin',
    spritePath: 'actors/ursoPlanta.png',
    tipo: CreatureType.planta,
    corClara: Palette.bege,
    corEscura: Palette.forest,
    stats: BaseStats(maxHp: 4, speed: 50, defesa: 1, ataque: 4),
    ability1: MegaSoco(),
    ability2: Brado(),
    moveAnim: MovementAnimation.caminhada,
    hitboxSize: Vector2(15, 16),
    enemyBuilder: (pos, plr) =>
        UrsoPlantaEnemy(position: pos, playerTarget: plr),
    evoluir: () => ursoPlantaEvo,
  );

  static final CreatureData ursoPlantaEvo = CreatureData(
    id: 'urso_planta',
    nome: 'Panjoin',
    spritePath: 'actors/ursoPlantaEvo.png',
    tipo: CreatureType.planta,
    corClara: Palette.verde,
    corEscura: Palette.marrom,
    stats: BaseStats(maxHp: 6, speed: 50, defesa: 1, ataque: 4),
    ability1: MegaSocoEvo(),
    ability2: BradoEvo(),
    moveAnim: MovementAnimation.arrastar,
    hitboxSize: Vector2(14, 14),
    enemyBuilder: (pos, plr) =>
        UrsoPlantaEnemy(position: pos, playerTarget: plr),
  );

  static final CreatureData griloEletrico = CreatureData(
    id: 'grilo_eletrico',
    nome: 'Hicrick',
    spritePath: 'actors/griloEletric.png',
    tipo: CreatureType.eletrico,
    corClara: Palette.laranja,
    corEscura: Palette.marrom,
    stats: BaseStats(maxHp: 4, speed: 80, defesa: 1, ataque: 4),
    ability1: ChoqueEletrico(),
    ability2: DisparadaVeloz(),
    moveAnim: MovementAnimation.saltitar,
    hitboxSize: Vector2(8, 10),
    enemyBuilder: (pos, plr) =>
        GriloEletricoEnemy(position: pos, playerTarget: plr),
    evoluir: () => griloEletricoEvo,
  );

  static final CreatureData griloEletricoEvo = CreatureData(
    id: 'grilo_eletrico',
    nome: 'Hicrick',
    spritePath: 'actors/griloEletricEvo.png',
    tipo: CreatureType.eletrico,
    corClara: Palette.laranja,
    corEscura: Palette.marrom,
    stats: BaseStats(maxHp: 6, speed: 80, defesa: 1, ataque: 4),
    ability1: ChoqueEletricoEvo(),
    ability2: DisparadaVelozEvo(),
    moveAnim: MovementAnimation.saltitar,
    hitboxSize: Vector2(8, 10),
    enemyBuilder: (pos, plr) =>
        GriloEletricoEnemy(position: pos, playerTarget: plr),
    //passive: ReflexoEletrico(),
  );

  static final CreatureData bombaFogo = CreatureData(
    id: 'bomba_fogo',
    nome: 'Granadin',
    spritePath: 'actors/bombaFogo.png',
    tipo: CreatureType.fogo,
    corClara: Palette.burgundy,
    corEscura: Palette.roxoEsc,
    stats: BaseStats(maxHp: 4, speed: 70, defesa: 1, ataque: 4),
    ability1: DeixarBomba(),
    ability2: EsquivaBomba(),
    moveAnim: MovementAnimation.saltitar,
    hitboxSize: Vector2(8, 10),
    enemyBuilder: (pos, plr) =>
        BombaFogoEnemy(position: pos, playerTarget: plr),
    evoluir: () => bombaFogoEvo,
  );

  static final CreatureData bombaFogoEvo = CreatureData(
    id: 'bomba_fogo',
    nome: 'Granadin',
    spritePath: 'actors/bombaFogoEvo.png',
    tipo: CreatureType.fogo,
    corClara: Palette.burgundy,
    corEscura: Palette.roxoEsc,
    stats: BaseStats(maxHp: 6, speed: 70, defesa: 1, ataque: 4),
    ability1: DeixarBombaEvo(),
    ability2: EsquivaBomba(),
    moveAnim: MovementAnimation.saltitar,
    hitboxSize: Vector2(8, 10),
    enemyBuilder: (pos, plr) =>
        BombaFogoEnemy(position: pos, playerTarget: plr),
    //passive: BombaNaEsquiva(),
  );

  static final CreatureData slimePlanta = CreatureData(
    id: 'slime_planta',
    nome: 'Slimo',
    spritePath: 'actors/slimePlanta.png',
    tipo: CreatureType.planta,
    corClara: Palette.verde,
    corEscura: Palette.forest,
    stats: BaseStats(maxHp: 4, speed: 70, defesa: 1, ataque: 4),
    ability1: CuspeVenenoso(),
    ability2: ExplosaoVenenosa(),
    moveAnim: MovementAnimation.arrastar,
    hitboxSize: Vector2(8, 10),
    enemyBuilder: (pos, plr) =>
        SlimePlantaEnemy(position: pos, playerTarget: plr),
    //passive: PecoenhaReflexiva(),
    evoluir: () => slimePlantaEvo,
  );

  /// Evolução do Slime de Planta. O veneno dele deixa de ser um golpe e passa
  /// a ser terreno: o cuspe se divide e a explosão vira poça duradoura.
  static final CreatureData slimePlantaEvo = CreatureData(
    id: 'slime_planta',
    nome: 'Slimepeste',
    spritePath: 'actors/slimePlantaEvo.png',
    tipo: CreatureType.planta,
    corClara: Palette.verde,
    corEscura: Palette.verdeEsc,
    stats: BaseStats(maxHp: 6, speed: 70, defesa: 1, ataque: 5),
    ability1: CuspeVenenosoEvo(),
    ability2: ExplosaoVenenosaEvo(),
    moveAnim: MovementAnimation.arrastar,
    hitboxSize: Vector2(8, 10),
    enemyBuilder: (pos, plr) =>
        SlimePlantaEnemy(position: pos, playerTarget: plr),
  );

 
  static final CreatureData pinguimAgua = CreatureData(
    id: 'pinguim_agua',
    nome: 'Penpin',
    spritePath: 'actors/pinguimAgua.png',
    tipo: CreatureType.agua,
    corClara: Palette.azul,
    corEscura: Palette.royal,
    stats: BaseStats(maxHp: 4, speed: 70, defesa: 1, ataque: 3),
    ability1: TiroDeGelo(),
    ability2: DisparadaCongelante(),
    moveAnim: MovementAnimation.caminhada,
    hitboxSize: Vector2(8, 14),
    enemyBuilder: (pos, plr) =>
        PinguimAguaEnemy(position: pos, playerTarget: plr),
    //passive: RastroCongelante(),
    evoluir: () => pinguimAguaEvo,
  );

   /// Evolução do Pinguim de Água. Troca alcance por controle: leque de gelo em
  /// vez de um tiro, e o dash congela o caminho inteiro.
  static final CreatureData pinguimAguaEvo = CreatureData(
    id: 'pinguim_agua',
    nome: 'Glacinguim',
    spritePath: 'actors/pinguimAguaEvo.png',
    tipo: CreatureType.agua,
    corClara: Palette.azul,
    corEscura: Palette.royal,
    stats: BaseStats(maxHp: 6, speed: 70, defesa: 1, ataque: 3),
    ability1: TiroDeGeloEvo(),
    ability2: DisparadaCongelanteEvo(),
    moveAnim: MovementAnimation.caminhada,
    hitboxSize: Vector2(8, 14),
    enemyBuilder: (pos, plr) =>
        PinguimAguaEnemy(position: pos, playerTarget: plr),
  );

   static final CreatureData ouricoEletrico = CreatureData(
    id: 'ourico_eletrico',
    nome: 'Jolthog',
    spritePath: 'actors/ouricoEletric.png',
    tipo: CreatureType.eletrico,
    corClara: Palette.amarelo,
    corEscura: Palette.marrom,
    stats: BaseStats(maxHp: 4, speed: 50, defesa: 1, ataque: 3),
    ability1: Ericar(),
    ability2: EscudoDeEspinhos(),
    moveAnim: MovementAnimation.caminhada,
    hitboxSize: Vector2(12, 12),
    enemyBuilder: (pos, plr) =>
        OuricoEletricoEnemy(position: pos, playerTarget: plr),
    //passive: RetaliacaoEletrica(),
    evoluir: () => ouricoEletricoEvo,
  );

/// Evolução do Ouriço Elétrico. Continua o mais lento do elenco de
  /// propósito: o que ele ganha é imobilizar (espinhos que perfuram e
  /// paralisam) e revidar mais forte, não fugir.
  static final CreatureData ouricoEletricoEvo = CreatureData(
    id: 'ourico_eletrico',
    nome: 'Voltari',
    spritePath: 'actors/ouricoEletricEvo.png',
    tipo: CreatureType.eletrico,
    corClara: Palette.amarelo,
    corEscura: Palette.marrom,
    stats: BaseStats(maxHp: 6, speed: 50, defesa: 1, ataque: 4),
    ability1: EricarEvo(),
    ability2: EscudoDeEspinhosEvo(),
    moveAnim: MovementAnimation.caminhada,
    hitboxSize: Vector2(12, 12),
    enemyBuilder: (pos, plr) =>
        OuricoEletricoEnemy(position: pos, playerTarget: plr),
  );

  static final CreatureData caranguejoErmitao = CreatureData(
    id: 'caranguejo_fogo',
    nome: 'Hermiton',
    spritePath: 'actors/caranguejoFogo.png',
    tipo: CreatureType.fogo,
    corClara: Palette.vermelho,
    corEscura: Palette.cinzaEsc,
    stats: BaseStats(maxHp: 4, speed: 50, defesa: 1, ataque: 3),
    ability1: BaforadaDeCinzas(),
    ability2: RecolherNoCasco(),
    moveAnim: MovementAnimation.arrastar,
    hitboxSize: Vector2(14, 12),
    enemyBuilder: (pos, plr) =>
        CaranguejoErmitaoEnemy(position: pos, playerTarget: plr),
    //passive: FumacaAoLacar(),
    evoluir: () => caranguejoErmitaoEvo,
  );

   /// Evolução do Caranguejo Ermitão. O sopro deixa de ser uma linha e vira
  /// área suja; o casco deixa de só aguentar e passa a devolver tiro.
  static final CreatureData caranguejoErmitaoEvo = CreatureData(
    id: 'caranguejo_fogo',
    nome: 'Brasiton',
    spritePath: 'actors/caranguejoFogoEvo.png',
    tipo: CreatureType.fogo,
    corClara: Palette.vermelho,
    corEscura: Palette.cinzaEsc,
    stats: BaseStats(maxHp: 6, speed: 50, defesa: 2, ataque: 4),
    ability1: BaforadaDeCinzasEvo(),
    ability2: RecolherNoCascoEvo(),
    moveAnim: MovementAnimation.arrastar,
    hitboxSize: Vector2(14, 12),
    enemyBuilder: (pos, plr) =>
        CaranguejoErmitaoEnemy(position: pos, playerTarget: plr),
  );

  static final CreatureData tocoPlanta = CreatureData(
    id: 'toco_planta',
    nome: 'Toco de Madeira',
    spritePath: 'actors/tocoPlanta.png',
    tipo: CreatureType.planta,
    corClara: Palette.verdeEsc,
    corEscura: Palette.chocolate,
    stats: BaseStats(maxHp: 4, speed: 50, defesa: 1, ataque: 3),
    ability1: FolhasNavalha(),
    ability2: Enraizar(),
    moveAnim: MovementAnimation.saltitar,
    hitboxSize: Vector2(10, 10),
    enemyBuilder: (pos, plr) =>
        TocoPlantaEnemy(position: pos, playerTarget: plr),
    //passive: RaizesDoLaco(),
    evoluir: () => tocoPlantaEvo,
  );

  /// Evolução do Toco de Madeira. Continua sem sair do lugar — o que ele ganha
  /// é fechar a brecha do anel de folhas e prender quem chega perto.
  static final CreatureData tocoPlantaEvo = CreatureData(
    id: 'toco_planta',
    nome: 'Tronconte',
    spritePath: 'actors/tocoPlantaEvo.png',
    tipo: CreatureType.planta,
    corClara: Palette.verdeEsc,
    corEscura: Palette.chocolate,
    stats: BaseStats(maxHp: 4, speed: 50, defesa: 2, ataque: 4),
    ability1: FolhasNavalhaEvo(),
    ability2: EnraizarEvo(),
    moveAnim: MovementAnimation.saltitar,
    hitboxSize: Vector2(10, 10),
    enemyBuilder: (pos, plr) =>
        TocoPlantaEnemy(position: pos, playerTarget: plr),
  );


  static final CreatureData tubaraoAgua = CreatureData(
    id: 'tubarao_agua',
    nome: 'Tubarão de Água',
    spritePath: 'actors/tubaAgua.png',
    tipo: CreatureType.agua,
    corClara: Palette.azul,
    corEscura: Palette.royal,
    stats: BaseStats(maxHp: 4, speed: 70, defesa: 1, ataque: 5),
    ability1: Mordida(),
    ability2: MergulhoEEstouro(),
    moveAnim: MovementAnimation.caminhada,
    hitboxSize: Vector2(13, 15),
    enemyBuilder: (pos, plr) =>
        TubaraoAguaEnemy(position: pos, playerTarget: plr),
    //passive: InvestidaPredatoria(),
    evoluir: () => tubaraoAguaEvo,
  );

  /// Evolução do Tubarão de Água. Ganha alcance na mordida e, no mergulho,
  /// resolve o problema do depois: a poça segura quem o estouro empurrou.
  static final CreatureData tubaraoAguaEvo = CreatureData(
    id: 'tubarao_agua',
    nome: 'Tubarrasco',
    spritePath: 'actors/tubaAguaEvo.png',
    tipo: CreatureType.agua,
    corClara: Palette.azul,
    corEscura: Palette.royal,
    stats: BaseStats(maxHp: 6, speed: 70, defesa: 1, ataque: 6),
    ability1: MordidaEvo(),
    ability2: MergulhoEEstouroEvo(),
    moveAnim: MovementAnimation.caminhada,
    hitboxSize: Vector2(13, 15),
    enemyBuilder: (pos, plr) =>
        TubaraoAguaEnemy(position: pos, playerTarget: plr),
  );

  static final CreatureData leaoEletrico = CreatureData(
    id: 'leao_eletrico',
    nome: 'Leão Elétrico',
    spritePath: 'actors/gatoEletrico.png',
    tipo: CreatureType.eletrico,
    corClara: Palette.laranja,
    corEscura: Palette.burgundy,
    stats: BaseStats(maxHp: 4, speed: 50, defesa: 1, ataque: 4),
    ability1: EstocadaRelampago(),
    ability2: InvestidaDaLanca(),
    moveAnim: MovementAnimation.caminhada,
    hitboxSize: Vector2(10, 15),
    enemyBuilder: (pos, plr) =>
        LeaoEletricoEnemy(position: pos, playerTarget: plr),
    //passive: GolpeDeLanca(),
    evoluir: () => leaoEletricoEvo,
  );

  
  /// Evolução do Leão Elétrico. Segue sendo o de LONGE do elenco elétrico:
  /// três linhas em vez de uma, e a investida agora prende onde termina.
  static final CreatureData leaoEletricoEvo = CreatureData(
    id: 'leao_eletrico',
    nome: 'Leontrovão',
    spritePath: 'actors/gatoEletricoEvo.png',
    tipo: CreatureType.eletrico,
    corClara: Palette.laranja,
    corEscura: Palette.burgundy,
    stats: BaseStats(maxHp: 6, speed: 50, defesa: 1, ataque: 5),
    ability1: EstocadaRelampagoEvo(),
    ability2: InvestidaDaLancaEvo(),
    moveAnim: MovementAnimation.caminhada,
    hitboxSize: Vector2(10, 15),
    enemyBuilder: (pos, plr) =>
        LeaoEletricoEnemy(position: pos, playerTarget: plr),
  );

  static final CreatureData caoNeutro = CreatureData(
    id: 'cao_neutro',
    nome: 'Doguin',
    spritePath: 'actors/caoNeutro.png',
    tipo: CreatureType.neutro,
    corClara: Palette.marrom,
    corEscura: Palette.chocolate,
    stats: BaseStats(maxHp: 4, speed: 70, defesa: 1, ataque: 3),
    ability1: MordidaCerteira(),
    ability2: LatidoFeroz(),
    moveAnim: MovementAnimation.caminhada,
    hitboxSize: Vector2(10, 12),
    enemyBuilder: (pos, plr) =>
        CaoNeutroEnemy(position: pos, playerTarget: plr),
    evoluir: () => caoNeutroEvo,
  );

  /// Forma evoluída de [caoNeutro]. O `critBonus` NÃO é enfeite: ele é quem
  /// dimensiona a [FaroDoPredador], que cura no crítico — ver a conta na doc
  /// daquela passiva.
  static final CreatureData caoNeutroEvo = CreatureData(
    id: 'cao_neutro',
    nome: 'Doguin',
    spritePath: 'actors/caoNeutroEvo.png',
    tipo: CreatureType.neutro,
    corClara: Palette.marrom,
    corEscura: Palette.chocolate,
    stats: BaseStats(
      maxHp: 6,
      speed: 70,
      defesa: 1,
      ataque: 3,
      critBonus: 10,
    ),
    ability1: MordidaCerteiraEvo(),
    ability2: LatidoFerozEvo(),
    passive: FaroDoPredador(),
    moveAnim: MovementAnimation.caminhada,
    hitboxSize: Vector2(10, 12),
    enemyBuilder: (pos, plr) =>
        CaoNeutroEnemy(position: pos, playerTarget: plr),
  );

  static final CreatureData gatoNeutro = CreatureData(
    id: 'gato_neutro',
    nome: 'Meao',
    spritePath: 'actors/gatoNeutro.png',
    tipo: CreatureType.neutro,
    corClara: Palette.cinza,
    corEscura: Palette.cinzaEsc,
    stats: BaseStats(maxHp: 4, speed: 50, defesa: 1, ataque: 2),
    ability1: Arranhao(),
    ability2: SaltoFelino(),
    moveAnim: MovementAnimation.saltitar,
    hitboxSize: Vector2(8, 9),
    enemyBuilder: (pos, plr) =>
        GatoNeutroEnemy(position: pos, playerTarget: plr),
    evoluir: () => gatoNeutroEvo,
  );

  /// Forma evoluída de [gatoNeutro]. As três partes do Bote Felino atacam a
  /// mesma fraqueza: ele é o mais lento do elenco jogável.
  static final CreatureData gatoNeutroEvo = CreatureData(
    id: 'gato_neutro',
    nome: 'Meao',
    spritePath: 'actors/gatoNeutroEvo.png',
    tipo: CreatureType.neutro,
    corClara: Palette.cinza,
    corEscura: Palette.cinzaEsc,
    stats: BaseStats(maxHp: 6, speed: 50, defesa: 1, ataque: 3),
    ability1: ArranhaoEvo(),
    ability2: SaltoFelinoEvo(),
    moveAnim: MovementAnimation.saltitar,
    hitboxSize: Vector2(8, 9),
    enemyBuilder: (pos, plr) =>
        GatoNeutroEnemy(position: pos, playerTarget: plr),
  );

  static final CreatureData aveNeutro = CreatureData(
    id: 'ave_neutro',
    nome: 'paassarin',
    spritePath: 'actors/aveNeutro.png',
    tipo: CreatureType.neutro,
    corClara: Palette.picotronBege,
    corEscura: Palette.chocolate,
    stats: BaseStats(maxHp: 4, speed: 70, defesa: 1, ataque: 1),
    ability1: BicadaRapida(),
    ability2: VooAlto(),
    moveAnim: MovementAnimation.flutuar,
    hitboxSize: Vector2(8, 10),
    enemyBuilder: (pos, plr) =>
        AveNeutroEnemy(position: pos, playerTarget: plr),
    evoluir: () => aveNeutroEvo,
  );

  /// Forma evoluída de [aveNeutro] — mesmo `id`, mesmo nome: só sprite,
  /// vida e as duas habilidades mudam.
  static final CreatureData aveNeutroEvo = CreatureData(
    id: 'ave_neutro',
    nome: 'paassarin',
    spritePath: 'actors/aveNeutroEvo.png',
    tipo: CreatureType.neutro,
    corClara: Palette.picotronBege,
    corEscura: Palette.chocolate,
    stats: BaseStats(maxHp: 6, speed: 70, defesa: 1, ataque: 1),
    ability1: BicadaRapidaEvo(),
    ability2: VooAltoEvo(),
    moveAnim: MovementAnimation.flutuar,
    hitboxSize: Vector2(8, 10),
    enemyBuilder: (pos, plr) =>
        AveNeutroEnemy(position: pos, playerTarget: plr),
  );

  static final CreatureData peixeNeutro = CreatureData(
    id: 'peixe_neutro',
    nome: 'layfishy',
    spritePath: 'actors/peixeNeutro.png',
    tipo: CreatureType.neutro,
    corClara: Palette.salmon,
    corEscura: Palette.coral,
    stats: BaseStats(maxHp: 4, speed: 50, defesa: 1, ataque: 3),
    ability1: Rabanada(),
    ability2: EscamasEscorregadias(),
    moveAnim: MovementAnimation.arrastar,
    hitboxSize: Vector2(10, 8),
    enemyBuilder: (pos, plr) =>
        PeixeNeutroEnemy(position: pos, playerTarget: plr),
    evoluir: () => peixeNeutroEvo,
  );

  /// Forma evoluída de [peixeNeutro] — mesmo `id`, mesmo nome. Ataque fica em
  /// 3: a Rabanada Dupla já soma um segundo golpe, e subir o ataque junto
  /// dobraria o ganho.
  static final CreatureData peixeNeutroEvo = CreatureData(
    id: 'peixe_neutro',
    nome: 'layfishy',
    spritePath: 'actors/peixeNeutroEvo.png',
    tipo: CreatureType.neutro,
    corClara: Palette.salmon,
    corEscura: Palette.coral,
    stats: BaseStats(maxHp: 6, speed: 50, defesa: 1, ataque: 3),
    ability1: RabanadaEvo(),
    ability2: EscamasEspelhadas(),
    moveAnim: MovementAnimation.arrastar,
    hitboxSize: Vector2(10, 8),
    enemyBuilder: (pos, plr) =>
        PeixeNeutroEnemy(position: pos, playerTarget: plr),
  );

   /// Sem habilidade 1 de proposito: a passiva [RodaDeFogo] ocupa o lugar dela
  /// (ver `CreatureData.ability1`). `acceleration` e `friction` baixos porque
  /// o jogo dela e ganhar embalo e manter — acelerar rapido tornaria a
  /// invulnerabilidade trivial de ligar.
  static final CreatureData rodaFogo = CreatureData(
    id: 'roda_fogo',
    nome: 'Pyrowheel',
    spritePath: 'actors/rodaFogo.png',
    tipo: CreatureType.fogo,
    corClara: Palette.vermelho,
    corEscura: Palette.roxoEsc,
    stats: BaseStats(
      maxHp: 4,
      speed: 90,
      // Rampa longa de proposito: a passiva `RodaDeFogo` so liga na
      // velocidade maxima, e com os 0,3s padrao ligar seria trivial. Freia
      // devagar pelo mesmo motivo tematico — e uma roda, ela carrega inercia.
      tempoAteMaxima: 0.6,
      tempoAteParar: 0.8,
      defesa: 1,
      ataque: 4,
    ),
    ability2: DisparadaVeloz(),
    passive: RodaDeFogo(),
    moveAnim: MovementAnimation.saltitar,
    hitboxSize: Vector2(10, 10),
    evoluir: () => rodaFogoEvo,
    enemyBuilder: (pos, plr) =>
        RodaFogoEnemy(position: pos, playerTarget: plr),
  );

  /// Evolucao da Roda de Fogo. Segue sem habilidade 1 — a passiva evoluida
  /// ([RodaDeFogoEvo]) e que cresce, ganhando o rastro de fogo.
  static final CreatureData rodaFogoEvo = CreatureData(
    id: 'roda_fogo',
    nome: 'Pyrowheel',
    spritePath: 'actors/rodaFogoEvo.png',
    tipo: CreatureType.fogo,
    corClara: Palette.vermelho,
    corEscura: Palette.roxoEsc,
    stats: BaseStats(
      maxHp: 6,
      speed: 90,
      // Mesmo tempo da forma base: a evolucao ganha no rastro de fogo, nao
      // em ficar mais facil de acelerar.
      tempoAteMaxima: 0.6,
      tempoAteParar: 0.8,
      defesa: 1,
      ataque: 5,
    ),
    ability2: DisparadaVelozEvo(),
    passive: RodaDeFogoEvo(),
    moveAnim: MovementAnimation.saltitar,
    hitboxSize: Vector2(10, 10),
    enemyBuilder: (pos, plr) =>
        RodaFogoEnemy(position: pos, playerTarget: plr),
  );


  /// Zapeye — olho elétrico de longe. O botão A segura um raio contínuo que
  /// atordoa quem fica nele; o botão B é o único teleporte do elenco.
  static final CreatureData olhoEletrico = CreatureData(
    id: 'olho_eletrico',
    nome: 'Zapeye',
    spritePath: 'actors/olhoEletrico.png',
    tipo: CreatureType.eletrico,
    corClara: Palette.cinza,
    corEscura: Palette.indigo,
    stats: BaseStats(maxHp: 4, speed: 70, defesa: 1, ataque: 3),
    ability1: RaioOcular(),
    ability2: Piscar(),
    moveAnim: MovementAnimation.flutuar,
    hitboxSize: Vector2(10, 10),
    enemyBuilder: (pos, plr) =>
        OlhoEletricoEnemy(position: pos, playerTarget: plr),
    evoluir: () => olhoEletricoEvo,
  );

  /// Evolução do Zapeye (Zaptron). O raio cresce com o foco e o teleporte
  /// deixa um clarão atordoante pra trás.
  static final CreatureData olhoEletricoEvo = CreatureData(
    id: 'olho_eletrico',
    nome: 'Zaptron',
    spritePath: 'actors/olhoEletricoEvo.png',
    tipo: CreatureType.eletrico,
    corClara: Palette.cinza,
    corEscura: Palette.indigo,
    stats: BaseStats(maxHp: 6, speed: 70, defesa: 1, ataque: 3),
    ability1: RaioConcentrado(),
    ability2: PiscarFulminante(),
    moveAnim: MovementAnimation.flutuar,
    hitboxSize: Vector2(10, 10),
    enemyBuilder: (pos, plr) =>
        OlhoEletricoEnemy(position: pos, playerTarget: plr),
  );

  /// Calamarin (nome provisório) — molusco de água de corpo a corpo. O botão A
  /// varre um arco com o tentáculo; o botão B esquiva soltando tinta que cega.
  /// Id `sereia_agua` fixo: é chave de save, e não muda quando o nome mudar.
  static final CreatureData sereiaAgua = CreatureData(
    id: 'sereia_agua',
    nome: 'Calamarin',
    spritePath: 'actors/sereiaAgua.png',
    tipo: CreatureType.agua,
    corClara: Palette.azul,
    corEscura: Palette.mauve,
    stats: BaseStats(maxHp: 4, speed: 70, defesa: 1, ataque: 3),
    ability1: Tentaculada(),
    ability2: EsguichoDeTinta(),
    moveAnim: MovementAnimation.saltitar,
    hitboxSize: Vector2(10, 10),
    enemyBuilder: (pos, plr) =>
        SereiaAguaEnemy(position: pos, playerTarget: plr),
    evoluir: () => sereiaAguaEvo,
  );

  /// Evolução do Calamarin (Kalamarok, provisório). O tentáculo passa a girar
  /// em volta e a tinta vira cortina contra tiro.
  static final CreatureData sereiaAguaEvo = CreatureData(
    id: 'sereia_agua',
    nome: 'Kalamarok',
    spritePath: 'actors/sereiaAguaEvo.png',
    tipo: CreatureType.agua,
    corClara: Palette.azul,
    corEscura: Palette.mauve,
    stats: BaseStats(maxHp: 6, speed: 70, defesa: 1, ataque: 3),
    ability1: RedemoinhoDeTentaculos(),
    ability2: CortinaDeTinta(),
    moveAnim: MovementAnimation.saltitar,
    hitboxSize: Vector2(10, 10),
    enemyBuilder: (pos, plr) =>
        SereiaAguaEnemy(position: pos, playerTarget: plr),
  );

  /// Cogumelo de Planta. Não mira: o esporo do botão A vai pro lado que o
  /// jogador está indo, e para quando ele para — arma de condução, não de
  /// pontaria. O botão B converte o golpe absorvido em nuvem no chão.
  static final CreatureData cogumeloPlanta = CreatureData(
    id: 'cogumelo_planta',
    nome: 'Esporim',
    spritePath: 'actors/coguPlanta.png',
    tipo: CreatureType.planta,
    corClara: Palette.picotronBege,
    corEscura: Palette.rosa,
    stats: BaseStats(maxHp: 4, speed: 50, defesa: 1, ataque: 4),
    ability1: EsporoErrante(),
    ability2: CasuloDeEsporos(),
    moveAnim: MovementAnimation.saltitar,
    hitboxSize: Vector2(10, 12),
    enemyBuilder: (pos, plr) =>
        CogumeloPlantaEnemy(position: pos, playerTarget: plr),
    evoluir: () => cogumeloPlantaEvo,
  );

  /// Evolução do Cogumelo de Planta. O que ela resolve é ACERTO, não dano: o
  /// esporo não mira, e conduzir um só até um alvo que anda exige adivinhar a
  /// rota dele. Três lado a lado perdoam o erro sem tirar a condução.
  static final CreatureData cogumeloPlantaEvo = CreatureData(
    id: 'cogumelo_planta',
    nome: 'Esporugo',
    spritePath: 'actors/coguPlantaEvo.png',
    tipo: CreatureType.planta,
    corClara: Palette.picotronBege,
    corEscura: Palette.roxoEsc,
    stats: BaseStats(maxHp: 6, speed: 50, defesa: 1, ataque: 5),
    ability1: EsporoErranteEvo(),
    ability2: CasuloDeEsporosEvo(),
    moveAnim: MovementAnimation.saltitar,
    hitboxSize: Vector2(12, 14),
    enemyBuilder: (pos, plr) =>
        CogumeloPlantaEnemy(position: pos, playerTarget: plr),
  );

  static final List<CreatureData> all = [
    roedorFogo,
    tartarugaPlanta,
    sapoAgua,
    aveEletrica,
    tornadoFogo,
    cobraAgua,
    ursoPlanta,
    griloEletrico,
    rodaFogo,
    bombaFogo,
    slimePlanta,
    pinguimAgua,
    ouricoEletrico,
    caranguejoErmitao,
    tocoPlanta,
    tubaraoAgua,
    leaoEletrico,
    cogumeloPlanta,
    sereiaAgua,
    olhoEletrico,
    caoNeutro,
    gatoNeutro,
    aveNeutro,
    peixeNeutro,
  ];

  static CreatureData byId(String id) => all.firstWhere((c) => c.id == id);

  /// Acha o registro BASE (o que está em `all`) cuja evolução é [evoluida] —
  /// necessário porque `all`/`byId` só indexam formas base; uma forma
  /// evoluída (produzida pelo closure `evoluir`) não tem `id` cadastrado
  /// ali. Usado ao salvar/restaurar uma run: só o id base é persistido, e
  /// isto devolve ele a partir da instância evoluída em mãos.
  ///
  /// `orElse` devolve [evoluida] mesma: nunca deveria faltar, mas travar o
  /// save por causa disso é pior que salvar um id levemente errado.
  static CreatureData baseDe(CreatureData evoluida) {
    return all.firstWhere(
      (base) => base.evoluir?.call().id == evoluida.id,
      orElse: () => evoluida,
    );
  }
}
