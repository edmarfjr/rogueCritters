import 'package:creatures_rogue/game/components/effects/sprite_effect.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/components/creatures/passives/roda_de_fogo.dart';

import 'package:creatures_rogue/game/components/creatures/creature_data.dart';
import 'package:creatures_rogue/game/components/creatures/creature_progress.dart';
import 'package:creatures_rogue/game/components/creatures/creature_type.dart';
import 'package:creatures_rogue/game/components/effects/efeitos_temporarios.dart';
import 'package:creatures_rogue/game/components/player/player.dart';
import 'package:creatures_rogue/game/creatures_rogue_game.dart';
import 'dart:math';

import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/effects/aura_pulse_effect.dart';
import 'package:creatures_rogue/game/components/effects/corrente_visual.dart';
import 'package:creatures_rogue/game/components/effects/dot.dart';
import 'package:creatures_rogue/game/components/enemies/enemy.dart';
import 'package:creatures_rogue/game/components/map/dungeon_generator.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import 'package:creatures_rogue/game/components/projeteis/orbit_projectile.dart';
import 'package:creatures_rogue/game/components/projeteis/projectile.dart';
import 'package:creatures_rogue/game/components/items/coin_pickup.dart';
import 'package:creatures_rogue/game/components/items/heart_half_pickup.dart';
import 'package:creatures_rogue/game/components/items/xp_pickup.dart';
import 'package:creatures_rogue/game/components/map/obstacle.dart';
import 'package:creatures_rogue/game/components/effects/text_effect.dart';
import 'package:creatures_rogue/game/components/items/collectible.dart';
import 'package:creatures_rogue/game/components/items/item_descritor.dart';
import 'package:creatures_rogue/game/components/items/power_up_item.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';
import 'package:flame/components.dart';

/// Item que reage a um EVENTO, em oposição ao [PowerUpType], que só soma num
/// stat na hora da coleta.
///
/// Por que não reaproveitar `Passive` (`creatures/passive.dart`, hoje toda
/// comentada): `Passive` pertence ao `CreatureData`, então troca junto com a
/// criatura ativa. Item pertence ao JOGADOR e persiste na troca — é a mesma
/// distinção que fez `bonusHpItens` existir. Ganchos parecidos, dono
/// diferente; juntar os dois faria o item herdar a regra errada.
///
/// Instâncias são `const` e vivem em [ItemEfeitoRegistry.todos], igual a
/// `Ability`: o item não guarda estado nenhum, quem guarda é o `Player`.
abstract class ItemEfeito implements ItemDescritor {
  const ItemEfeito();

  /// Chave estável do save. NUNCA renomear depois de publicado.
  @override
  String get id;

  @override
  String get spritePath;
  @override
  Color get cor1;
  @override
  Color get cor2;
  @override
  String nome(BuildContext context);
  @override
  String descricao(BuildContext context);

  /// Este efeito pode aparecer em pedestal e loja? `false` = só se ganha por
  /// outra via (as passivas de aposentadoria), mas continua registrado em
  /// [ItemEfeitoRegistry.todos] — é `porId` que reconstrói `player.itens` no
  /// carregamento do save, e um registro separado faria eles desaparecerem ao
  /// recarregar.
  bool get sorteavel => true;

  /// ANTES de qualquer escudo: dispara sempre que o jogador TENTA tomar dano,
  /// mesmo que o golpe seja inteiramente absorvido.
  ///
  /// Separado de [aoTomarDano] de propósito — aquele só roda quando o dano
  /// chega no HP de verdade. Efeito de retaliação quer o primeiro; efeito que
  /// reage a ferimento quer o segundo.
  void aoTentarTomarDano(Player player, double amount) {}

  /// Toda esquiva, com a direção já resolvida.
  void aoEsquivar(Player player, Vector2 direcao) {}

  /// Depois do dano ser resolvido (tipo, redução e escudo já aplicados), e só
  /// se ele realmente passou do escudo e chegou no HP.
  void aoTomarDano(Player player, double danoFinal, CreatureType tipoAtacante) {}

  /// Quando o escudo passivo (a barra derivada da defesa) vai de >0 pra 0.
  /// NÃO dispara pela bolha de habilidade (`shieldHits`) — são dois sistemas
  /// independentes, e a bolha estoura com frequência muito diferente.
  void aoQuebrarEscudo(Player player) {}

  /// Depois da troca, com o `Player` já mutado: [entra] é `player.creatureData`.
  void aoTrocarCriatura(Player player, CreatureData sai, CreatureData entra) {}

  /// Uma criatura entrou no grupo pela PRIMEIRA vez nesta run — trocar de
  /// volta pra uma que já passou por lá não dispara de novo.
  ///
  /// Diferente de [aoTrocarCriatura], que fala de quem está no comando agora:
  /// este é sobre o elenco. Quem chama é
  /// `CreaturesRogueGame._registrarCriaturaUsada`, o único lugar que sabe o
  /// que é novidade.
  void aoUsarCriaturaNova(Player player, CreatureData criatura) {}

  /// O golpe saiu crítico. [alvo] é quem levou — o único gancho que recebe o
  /// inimigo, porque é o único disparado de dentro do `Enemy.takeDamage`.
  void aoCritar(Player player, Enemy alvo) {}

  /// Este item gasta `Player.cargasDeSala`?
  ///
  /// Serve pra duas coisas: a Hud só desenha o contador de cargas quando
  /// alguém as usa, e o `Player` só as ACUMULA nesse caso — senão, achar um
  /// item de carga no quinto andar viria com todas as salas já andadas de
  /// presente.
  bool get usaCargasDeSala => false;

  /// O jogador usou a habilidade do botão B, QUALQUER que seja o tipo dela.
  ///
  /// Dispara junto com [aoEsquivar] e [aoUsarDefesa], não no lugar deles: uma
  /// esquiva chama este E aquele. É o gancho pra efeito que não se importa com
  /// o tipo da habilidade — e é o único que vale pra todas as 34 criaturas,
  /// já que cada uma tem só um tipo de botão B.
  void aoUsarAbility2(Player player) {}

  /// O jogador usou a habilidade DEFENSIVA (`AbilityTipo.defesa`).
  ///
  /// Irmão do [aoEsquivar], que cobre `AbilityTipo.esquiva`: os dois saem do
  /// mesmo `Player.dispararAbility2`, cada um no seu ramo de tipo. Não existe
  /// gancho pra `AbilityTipo.ataque` porque ninguém precisou até agora.
  void aoUsarDefesa(Player player) {}

  /// O jogador MATOU [alvo]. Irmão do [aoCritar]: os dois recebem o inimigo, e
  /// os dois saem de dentro do próprio `Enemy` — este do `death`, aquele do
  /// `takeDamage`.
  ///
  /// Dispara uma única vez por inimigo, garantido pela trava `Enemy._morto`:
  /// dois golpes no mesmo quadro chamavam `death()` duas vezes.
  ///
  /// Roda ANTES do inimigo sair da árvore, então `alvo.position` e
  /// `alvo.parent` ainda valem — é por onde um item faz nascer algo no lugar
  /// da morte.
  void aoMatarInimigo(Player player, Enemy alvo) {}

  /// Uma [Rock] foi quebrada por uma explosão. Roda ANTES dos drops dela e
  /// antes de ela sair da árvore, então `pedra.position` e `pedra.parent`
  /// ainda valem.
  ///
  /// Quem dispara é a própria `Rock.blowUp`, que busca o jogador pelo jogo —
  /// nem a pedra nem a `ExplosionHitbox` que a quebrou têm referência pra ele.
  void aoQuebrarPedra(Player player, Rock pedra) {}

  /// O golpe ERROU pela evasão (ver `Player.takeDamage`).
  ///
  /// Irmão do [aoTomarDano], e o oposto dele: um dispara quando o golpe entra,
  /// o outro quando ele passa raspando. Roda DEPOIS do dado, então quem
  /// reage aqui tem certeza de que a criatura escapou.
  ///
  /// Não recebe o atacante porque `takeDamage` não o conhece — chega só o
  /// tipo do golpe. Quem precisar bater de volta mira o inimigo mais próximo,
  /// como a `Sentinela` já faz.
  void aoEvadir(Player player) {}

  /// A vida da criatura ativa acabou de chegar a zero, e ela ainda NÃO saiu de
  /// campo. Devolver `true` segura o golpe: o `Player` refaz a vida em 1 e o
  /// game over não acontece.
  ///
  /// Único gancho com retorno. É o que permite ao item decidir — e o `Player`
  /// para no primeiro que aceitar, então dois itens de salvamento não gastam
  /// os dois recursos no mesmo golpe.
  bool aoCairEmCombate(Player player) => false;

  /// Anula o golpe inteiro? Consultado depois da evasão e ANTES do escudo:
  /// devolver `true` faz o golpe não acontecer — nem escudo, nem vida.
  bool anulaGolpe(Player player) => false;

  /// O golpe tirou vida de verdade (passou de evasão, anulação e escudo).
  /// [dano] é o quanto a vida caiu.
  void aoPerderVida(Player player, double dano) {}

  /// Ajusta o dano de um golpe do jogador num inimigo, depois do crítico e
  /// antes de a vida cair. Devolve o dano novo — sem mexer, o mesmo [dano].
  double ajustarGolpe(Player player, Enemy alvo, double dano) => dano;

  void aoAtualizar(Player player, double dt) {}

  /// O item SAIU do inventário (o Mercador de Trocas levou). Quem deixou
  /// algo no mundo — orbital, bola — limpa aqui; o resto é derivado e some
  /// sozinho no quadro seguinte.
  void aoPerder(Player player) {}
}

class ItemEfeitoRegistry {
  static const List<ItemEfeito> todos = [
    // --- Passivas de aposentadoria: `sorteavel` false, ver `ItemEfeito`. ---
    RastroFlamejante(),
    CascoReflexivo(),
    BolhaAutonoma(),
    CorrenteReflexa(),
    TornadoResidual(),
    BombaNaEsquiva(),
    SaltoAquatico(),
    BradoReflexo(),
    ReflexoEletrico(),
    ImpetoArdente(),
    PeconhaReflexiva(),
    RetaliacaoEletrica(),
    RastroCongelante(),
    PenaDeVoo(),
    EscamasGuardadas(),
    FumacaResidual(),
    EsporosLatentes(),
    EcoDoLatido(),
    PontaDaLanca(),
    SeteVidas(),
    RaizProfunda(),
    FaroDeSangue(),
    Camuflagem(),
    Piscadela(),
    Revezamento(),
    CascaInstavel(),
    Estilhaco(),
    PeleDeCinzas(),
    Couraca(),
    Desesperado(),
    CapsulaFurada(),
    DiarioDeCampo(),
    EloDoGrupo(),
    Imposto(),
    PedraElemental(CreatureType.fogo),
    PedraElemental(CreatureType.agua),
    PedraElemental(CreatureType.planta),
    PedraElemental(CreatureType.eletrico),
    Sentinela(),
    Recarga(),
    Repulsao(),
    SegundoFolego(),
    Frenesi(),
    PresaDoCampeao(),
    BauDoTesouro(),
    CascaDeOvo(),
    Prisma(),
    Ninhada(),
    Espolio(),
    VeioRico(),
    PeDeCabra(),
    Jejum(),
    Coleira(),
    Ressonancia(),
    Miragem(),
    Aparar(),
    PeDeCoelho(),
    Esgotamento(),
    GatilhoFrio(),
    SangueFrio(),
    Bussola(),
    Cofrinho(),
    Cupom(),
    Reposicao(),
    Agulha(),
    PresasDeVampiro(),
    Bencao(),
    RelogioParado(),
    Enxame(),
    Telecinese(),
    Furia(),
    Pureza(),
    Contrato(),
    CoroaInstavel(),
    Heranca(),
    OlhoNoOlho(),
  ];

  static ItemEfeito? porId(String id) {
    for (final item in todos) {
      if (item.id == id) return item;
    }
    return null;
  }
}

/// Troca de criatura dá dano extra por alguns segundos. Faz a troca virar
/// jogada ofensiva, não só botão de pânico quando a vida acaba.
class Revezamento extends ItemEfeito {
  const Revezamento();

  static const double bonusDano = 0.5;
  static const double duracao = 4.0;

  @override
  String get id => 'revezamento';

  @override
  String get spritePath => 'items/revezamento.png';

  @override
  Color get cor1 => const Color(0xFFFFC66D);

  @override
  Color get cor2 => const Color(0xFF8B3E2F);

  @override
  String nome(BuildContext context) => context.l10n.item_revezamento;

  @override
  String descricao(BuildContext context) => context.l10n.item_revezamentoDesc;

  @override
  void aoTrocarCriatura(Player player, CreatureData sai, CreatureData entra) {
    // `dono: jogador` é obrigatório aqui: a própria troca limpa os efeitos da
    // criatura logo antes de chamar este gancho, então um efeito marcado como
    // `criatura` seria varrido no mesmo instante em que nasce.
    //
    // `danoMult` é estático e compartilhado, então soma e subtração TÊM que
    // vir em par — é o CONTRATO do mixin que garante isso, e por isso
    // `aoIniciar` não repete quando o efeito é só renovado.
    player.aplicarEfeito(
      #revezamento,
      duracao,
      dono: EfeitoDono.jogador,
      aoIniciar: () => Player.danoMult += bonusDano,
      aoTerminar: () => Player.danoMult -= bonusDano,
    );
  }
}

/// Levar dano no HP causa uma explosão em volta do jogador. Escala com
/// `defesa`, o stat que fora disso só alimenta o escudo passivo, E com o
/// tamanho do golpe levado.
///
/// O golpe entra na conta pra separar este item da [PeleDeCinzas], que dispara
/// no mesmo gancho e no mesmo raio: aqui o troco é proporcional — arranhão de
/// contato devolve pouco, pancada de boss devolve muito. Com o dano fixo de
/// antes, os dois eram a mesma jogada com dano de tipo diferente.
class CascaInstavel extends ItemEfeito {
  const CascaInstavel();

  /// Multiplica `danoFinal * defesa`. Mantido em 1,5 de propósito: com a
  /// `defesa` 1 de quase todo o elenco e um golpe comum de 1, o estouro sai
  /// exatamente no valor fixo de antes — o que muda é o topo, não a média.
  static const double coefDano = 5.0;

  @override
  String get id => 'cascaInstavel';
  @override
  String get spritePath => 'items/cascoQuebrado.png';
  @override
  Color get cor1 => Palette.pumpkin;
  @override
  Color get cor2 => Palette.burgundy;
  @override
  String nome(BuildContext context) => context.l10n.item_cascaInstavel;
  @override
  String descricao(BuildContext context) =>
      context.l10n.item_cascaInstavelDesc;

  @override
  void aoTomarDano(Player player, double danoFinal, CreatureType tipoAtacante) {
    player.parent?.add(
      ExplosionHitbox(
        position: player.position.clone(),
        dmg: danoFinal * player.creatureData.stats.defesa * coefDano,
        tipo: player.creatureData.tipo,
        cor2: Palette.laranja,
      ),
    );
  }
}

/// O escudo passivo chegando a zero estoura em projéteis radiais. Transforma
/// perder o escudo em algo que o jogador quer que aconteça de vez em quando.
class Estilhaco extends ItemEfeito {
  const Estilhaco();

  static const int qtdProjeteis = 8;
  static const double coefDano = 1.5;

  @override
  String get id => 'estilhaco';
  @override
  String get spritePath => 'items/escudoQuebr.png';
  @override
  Color get cor1 => Palette.azul;
  @override
  Color get cor2 => Palette.azulEsc;
  @override
  String nome(BuildContext context) => context.l10n.item_estilhaco;
  @override
  String descricao(BuildContext context) => context.l10n.item_estilhacoDesc;

  @override
  void aoQuebrarEscudo(Player player) {
    final dano = player.creatureData.stats.ataque * coefDano;
    for (int i = 0; i < qtdProjeteis; i++) {
      final ang = (pi * 2 / qtdProjeteis) * i;
      player.parent?.add(
        Projectile(
          owner: player,
          position: player.position.clone(),
          direction: Vector2(cos(ang), sin(ang)),
          //speed: 70,
          lifeTime: 1.0,
          dmg: dano,
          sprPath: 'projeteis/proj2.png',
          cor1: Palette.azul,
          cor2: Palette.branco,
          tipo: player.creatureData.tipo,
          radius: 3,
        ),
      );
    }
  }
}

/// Queima continuamente quem estiver perto. Premia jogar no aperto, o oposto
/// do que o resto do kit defensivo pede.
///
/// AURA, e não contra-ataque: antes disparava em `aoTomarDano`, o MESMO gancho
/// e o MESMO raio da [CascaInstavel], e as duas eram a mesma jogada. Mais que
/// isso, "premia jogar no aperto" não era o que ela fazia — ela premiava levar
/// dano, que é outra coisa. Agora o gatilho é a proximidade, então ficar no
/// meio do bolo basta.
///
/// A cadência sai de um efeito temporário com `EfeitoStack.ignora`, mesmo
/// truque da passiva `RodaDeFogoEvo`: reaplicar não faz nada enquanto vale, o
/// `aoIniciar` queima na hora de armar e o quadro seguinte rearma quando
/// expira. É o jeito de ter tique periódico sem guardar cronômetro, que um
/// [ItemEfeito] `const` não pode.
///
/// O tique roda SEM checar se há inimigo por perto, de propósito: o pulso do
/// anel (ver `AuraPulseEffect`) é o que mostra o alcance, e ele precisa
/// aparecer antes de o inimigo chegar pra o jogador poder se posicionar. O
/// custo é varrer a lista de inimigos uma vez a cada [intervalo] em sala
/// vazia, o que não aparece em lugar nenhum.
class PeleDeCinzas extends ItemEfeito {
  const PeleDeCinzas();

  static const double alcance = 24.0;

  /// Segundos entre uma queimada e a próxima.
  ///
  /// Folgado porque a queimadura NÃO acumula (`Dot.criar`: `acumula: false`,
  /// teto de 3 tiques de 2 de dano a cada 0,67s). Reaplicar só recarrega o que
  /// falta, então um intervalo curto manteria o inimigo encostado queimando
  /// sem parar — com 2 tiques a cada 2s o teto é 2 de dano por segundo, e
  /// esse é o número pra mexer se ficar fraco ou forte demais.
  static const double intervalo = 0.6;
  static const int ticks = 1;

  @override
  String get id => 'peleDeCinzas';
  @override
  String get spritePath => 'items/peleFogo.png';
  @override
  Color get cor1 => Palette.laranja;
  @override
  Color get cor2 => Palette.vermelho;
  @override
  String nome(BuildContext context) => context.l10n.item_peleDeCinzas;
  @override
  String descricao(BuildContext context) => context.l10n.item_peleDeCinzasDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    player.aplicarEfeito(
      #peleDeCinzasAura,
      intervalo,
      stack: EfeitoStack.ignora,
      // `aoIniciar`, não `aoTerminar`: pulsa e queima no instante em que o
      // efeito arma. No `aoTerminar` o primeiro pulso só sairia [intervalo]
      // depois, e a aura leria como desligada até lá.
      aoIniciar: () => _queimarPerto(player),
    );
  }

  void _queimarPerto(Player player) {
    // Anel com o [alcance] de verdade, não um número visual escolhido à parte:
    // a aura acertava sem dizer onde começava e onde acabava.
    player.parent?.add(
      AuraPulseEffect(
        position: player.position.clone(),
        raio: alcance,
        cor1: Palette.pumpkin,
        cor2: Palette.vermelho,
      ),
    );

    final inimigos =
        player.parent?.children.whereType<Enemy>() ?? const <Enemy>[];
    for (final inimigo in inimigos) {
      if (inimigo.position.distanceTo(player.position) <= alcance) {
        inimigo.applyDot(DotKind.queimadura, ticks);
      }
    }
  }
}

/// Escudo cheio dá dano extra. Par de [Desesperado]: os dois no mesmo run
/// puxam pra lados opostos, que é o ponto.
///
/// O efeito é reaplicado a cada quadro com duração curta em vez de ligado e
/// desligado na mão: [ItemEfeito] é `const` e não pode guardar "já apliquei",
/// e o contrato do mixin garante que `aoTerminar` roda exatamente uma vez
/// quando a renovação para. O custo é o bônus sumir [janela] depois de a
/// condição deixar de valer, não no mesmo quadro.
class Couraca extends ItemEfeito {
  const Couraca();

  static const double bonusDano = 0.25;
  static const double janela = 0.2;

  @override
  String get id => 'couraca';
  @override
  String get spritePath => 'items/armor.png';
  @override
  Color get cor1 => Palette.indigo;
  @override
  Color get cor2 => Palette.azulEsc;
  @override
  String nome(BuildContext context) => context.l10n.item_couraca;
  @override
  String descricao(BuildContext context) => context.l10n.item_couracaDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    if (player.shieldMax <= 0 || player.shield < player.shieldMax) return;
    player.aplicarEfeito(
      #couraca,
      janela,
      dono: EfeitoDono.jogador,
      aoIniciar: () => Player.danoMult += bonusDano,
      aoTerminar: () => Player.danoMult -= bonusDano,
    );
  }
}

/// Sem escudo nenhum: mais velocidade e mais cadência. Par de [Couraca].
class Desesperado extends ItemEfeito {
  const Desesperado();

  static const double bonusVel = 0.25;
  static const double fatorCadencia = 0.8;
  static const double janela = 0.2;

  @override
  String get id => 'desesperado';
  @override
  String get spritePath => 'items/desespero.png';
  @override
  Color get cor1 => Palette.verde;
  @override
  Color get cor2 => Palette.verdeEsc;
  @override
  String nome(BuildContext context) => context.l10n.item_desesperado;
  @override
  String descricao(BuildContext context) => context.l10n.item_desesperadoDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    if (player.shield > 0) return;
    player.aplicarEfeito(
      #desesperado,
      janela,
      dono: EfeitoDono.jogador,
      aoIniciar: () {
        player.velMult += bonusVel;
        player.cdMult *= fatorCadencia;
      },
      aoTerminar: () {
        player.velMult -= bonusVel;
        player.cdMult /= fatorCadencia;
      },
    );
  }
}

/// A criatura que SAI deixa uma poça do elemento dela no chão. Dá um motivo
/// pra trocar fora de emergência, e o efeito muda conforme o grupo.
class CapsulaFurada extends ItemEfeito {
  const CapsulaFurada();

  static const double coefDano = 1.6;
  static const double duracao = 4.0;

  /// Quanto a poça de ÁGUA atrasa quem pisou. Curto de propósito e bem menor
  /// que [duracao]: a poça reaplica a cada tique de reacerto do `Projectile`,
  /// então quem FICA dentro dela segue atrasado, e quem só atravessa leva
  /// pouco.
  static const double lentidaoDuracao = 1.5;

  static const double lentidaoFator = 0.5;

  /// Atordoamento da poça ELÉTRICA. Bem mais curto que a lentidão porque
  /// atordoar para o inimigo de vez, enquanto a lentidão só o atrasa.
  static const double atordoamento = 0.6;

  @override
  // `id` CONTINUA 'legado', apesar do nome novo: ele é chave de save, e um
  // save gravado antes desta renomeação reconstrói `player.itens` por
  // `ItemEfeitoRegistry.porId`. Trocar aqui faria o item sumir da mochila de
  // quem estava no meio de uma run.
  @override
  String get id => 'legado';
  @override
  String get spritePath => 'items/capsula.png';
  @override
  Color get cor1 => Palette.verde;
  @override
  Color get cor2 => Palette.roxoEsc;
  @override
  String nome(BuildContext context) => context.l10n.item_capsulaFurada;
  @override
  String descricao(BuildContext context) =>
      context.l10n.item_capsulaFuradaDesc;

  @override
  void aoTrocarCriatura(Player player, CreatureData sai, CreatureData entra) {
    // Cada elemento deixa uma poça diferente. Fogo e planta já tinham DoT;
    // água e elétrico eram só dano cru, e agora carregam status.
    //
    // Elétrico ATORDOA. Descarga elétrica parando o inimigo no lugar é o
    // vocabulário já estabelecido do jogo — ver `RetaliacaoEletrica`,
    // `CorrenteReflexa` e o `retaliaStunDuration` do Escudo de Espinhos.
    // Cegueira tem outro dono no jogo (fumaça e desorientação), e usá-la aqui
    // quebraria a associação que o jogador já aprendeu.
    final (sprite, dot, lentidao, stun) = switch (sai.tipo) {
      CreatureType.fogo => (
        'projeteis/fogo.png',
        DotKind.queimadura,
        0.0,
        0.0,
      ),
      CreatureType.planta => ('projeteis/folha.png', DotKind.veneno, 0.0, 0.0),
      CreatureType.agua => (
        'projeteis/bolha.png',
        null,
        lentidaoDuracao,
        0.0,
      ),
      CreatureType.eletrico => (
        'projeteis/raio.png',
        null,
        0.0,
        atordoamento,
      ),
      CreatureType.neutro => ('projeteis/nuvem.png', null, 0.0, 0.0),
    };

    
    for(var i=-1;i<=1;i++){
      for(var j=-1;j<=1;j++){
      player.parent?.add(
        Projectile(
          owner: player,
          position: player.position.clone() + Vector2(i*16,j*16),
          direction: Vector2.zero(),
          speed: 0,
          lifeTime: duracao,
          dmg: sai.stats.ataque * coefDano,
          sprPath: sprite,
          cor1: sai.corClara,
          cor2: sai.corEscura,
          tipo: sai.tipo,
          radius: 8,
          atravessa: 100,
          dotKind: dot,
          dotTicks: 4,
          lentidaoDuracao: lentidao,
          lentidaoFator: lentidaoFator,
          stunDuration: stun,
        ),
      );
    }
    }
    
  }
}

// ---------------------------------------------------------------------------
// Passivas de aposentadoria (ver [PassivasAposentadoria]). Vêm das classes em
// `creatures/passives/`, que nasceram como `Passive` — ligadas ao
// `CreatureData` e portanto mortas na troca de criatura. Aqui elas são do
// JOGADOR e permanentes, que é o que a aposentadoria exige: a criatura vai
// embora e o bônus fica.
//
// `sorteavel => false` nas seis: não aparecem em pedestal nem em loja.
//
// `spritePath` e cores existem só pra satisfazer a interface — nenhuma delas
// chega a ser instanciada como coletável.
// ---------------------------------------------------------------------------

/// Roedor de Fogo. Toda esquiva termina numa explosão de fogo no ponto de
/// chegada.
class RastroFlamejante extends ItemEfeito {
  const RastroFlamejante({this.coef = 0.5});

  final double coef;

  @override
  bool get sorteavel => false;
  @override
  String get id => 'rastroFlamejante';
  @override
  String get spritePath => 'actors/ratFogo.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_rastroFlamejante;
  @override
  String descricao(BuildContext context) =>
      context.l10n.passiva_rastroFlamejanteDesc;

  @override
  void aoUsarAbility2(Player player) {
    final dano = player.creatureData.stats.ataque * coef;
    // No FIM da esquiva, não no início: a explosão marca onde ele chegou.
    // Efeito temporário em vez do `Future.delayed` que a `Passive` usava —
    // este respeita pausa e é limpo na troca de criatura.
    player.aplicarEfeito(
      #rastroFlamejante,
      player.dodgeIframeDuration,
      aoTerminar: () => player.parent?.add(
        ExplosionHitbox(
          position: player.position.clone(),
          dmg: dano,
          cor2: Palette.laranja,
          tipo: player.creatureData.tipo,
          dotKind: DotKind.queimadura,
          dotTicks: 5,
        ),
      ),
    );
  }
}

/// Tartaruga de Planta. Durante os i-frames da esquiva, reflete projéteis.
class CascoReflexivo extends ItemEfeito {
  const CascoReflexivo();

  @override
  bool get sorteavel => false;
  @override
  String get id => 'cascoReflexivo';
  @override
  String get spritePath => 'actors/tartPlanta.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_cascoReflexivo;
  @override
  String descricao(BuildContext context) =>
      context.l10n.passiva_cascoReflexivoDesc;

  @override
  void aoUsarAbility2(Player player) {
    // Alguém já está refletindo? Então o dono do campo é outro, e o
    // `aoTerminar` daqui desligaria a reflexão DELE no meio: Casco
    // Fechado e Recolher no Casco duram bem mais que esta janela, e
    // antes da migração nunca coincidiam — aquelas são de defesa, e
    // este gancho só pegava esquiva.
    if (player.refleteProjetil) return;
    player.aplicarEfeito(
      #cascoReflexivo,
      player.dodgeIframeDuration,
      aoIniciar: () => player.refleteProjetil = true,
      aoTerminar: () => player.refleteProjetil = false,
    );
  }
}

/// Sapo de Água. Sem apanhar por um tempo, forma sozinho um escudo de um
/// golpe.
class BolhaAutonoma extends ItemEfeito {
  const BolhaAutonoma({this.tempoParaFormar = 5.0});

  final double tempoParaFormar;

  @override
  bool get sorteavel => false;
  @override
  String get id => 'bolhaAutonoma';
  @override
  String get spritePath => 'actors/sapoAgua.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_bolhaAutonoma;
  @override
  String descricao(BuildContext context) =>
      context.l10n.passiva_bolhaAutonomaDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    if (player.shieldHits > 0) return;
    if (player.tempoSemApanhar < tempoParaFormar) return;
    player.adicionarEscudoPermanente(1);
  }
}

/// Ave Elétrica. Todo golpe que o jogador TENTA tomar solta uma descarga
/// atordoante em volta — inclusive os que o escudo come.
class CorrenteReflexa extends ItemEfeito {
  const CorrenteReflexa({this.coef = 1.0, this.duracaoStun = 1.5});

  final double coef;
  final double duracaoStun;

  @override
  bool get sorteavel => false;
  @override
  String get id => 'correnteReflexa';
  @override
  String get spritePath => 'actors/aveEletric.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_correnteReflexa;
  @override
  String descricao(BuildContext context) =>
      context.l10n.passiva_correnteReflexaDesc;

  @override
  void aoTentarTomarDano(Player player, double amount) {
    player.parent?.add(
      ExplosionHitbox(
        position: player.position.clone(),
        dmg: player.creatureData.stats.ataque * coef,
        stunDuration: duracaoStun,
        cor1: Palette.amarelo,
        cor2: Palette.laranja,
      ),
    );
  }
}

/// Tornado de Fogo. Toda esquiva deixa um tornado no ponto de partida.
class TornadoResidual extends ItemEfeito {
  const TornadoResidual({this.coef = 0.5});

  final double coef;

  @override
  bool get sorteavel => false;
  @override
  String get id => 'tornadoResidual';
  @override
  String get spritePath => 'actors/furacFogo.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_tornadoResidual;
  @override
  String descricao(BuildContext context) =>
      context.l10n.passiva_tornadoResidualDesc;

  @override
  void aoUsarAbility2(Player player) {
    // Mesmo vetor que o `aoEsquivar` recebia: é o que o
    // `dispararAbility2` passa pros dois ganchos.
    final direcao = player.lockedAb2Direction;
    player.parent?.add(
      Projectile(
        owner: player,
        position: player.position.clone(),
        direction: direcao,
        movimento: ProjetilMovimento.espiral,
        speed: 10,
        velAngular: 4.0,
        lifeTime: 3,
        dmg: player.creatureData.stats.ataque * coef,
        sprPath: 'projeteis/tornado.png',
        cor1: Palette.vermelho,
        cor2: Palette.laranja,
        tipo: player.creatureData.tipo,
        radius: 8,
        atravessa: 10,
      ),
    );
  }
}

/// Bomba de Fogo. Toda esquiva larga uma bomba pra trás, se houver estoque.
class BombaNaEsquiva extends ItemEfeito {
  const BombaNaEsquiva();

  @override
  bool get sorteavel => false;
  @override
  String get id => 'bombaNaEsquiva';
  @override
  String get spritePath => 'actors/bombaFogo.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_bombaNaEsquiva;
  @override
  String descricao(BuildContext context) =>
      context.l10n.passiva_bombaNaEsquivaDesc;

  @override
  void aoUsarAbility2(Player player) {
    // Mesmo vetor que o `aoEsquivar` recebia: é o que o
    // `dispararAbility2` passa pros dois ganchos.
    final direcao = player.lockedAb2Direction;
    player.placeBomb(-direcao);
  }
}

/// Cobra de Água. A esquiva termina num respingo que empurra quem está perto.
class SaltoAquatico extends ItemEfeito {
  const SaltoAquatico({this.coef = 0.4});

  final double coef;

  @override
  bool get sorteavel => false;
  @override
  String get id => 'saltoAquatico';
  @override
  String get spritePath => 'actors/cobraAgua.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_saltoAquatico;
  @override
  String descricao(BuildContext context) =>
      context.l10n.passiva_saltoAquaticoDesc;

  @override
  void aoUsarAbility2(Player player) {
    final dano = player.creatureData.stats.ataque * coef;
    player.aplicarEfeito(
      #saltoAquatico,
      player.dodgeIframeDuration,
      aoTerminar: () => player.parent?.add(
        ExplosionHitbox(
          position: player.position.clone(),
          dmg: dano,
          knockback: 30,
          size: Vector2(28, 28),
          cor1: Palette.azul,
          cor2: Palette.royal,
          tipo: player.creatureData.tipo,
        ),
      ),
    );
  }
}

/// Urso de Planta. Todo golpe que o jogador TENTA tomar empurra tudo em volta
/// pra longe — o eco da habilidade `Brado` dele.
class BradoReflexo extends ItemEfeito {
  const BradoReflexo({this.coef = 0.25, this.empurrao = 100});

  final double coef;
  final double empurrao;

  @override
  bool get sorteavel => false;
  @override
  String get id => 'bradoReflexo';
  @override
  String get spritePath => 'actors/ursoPlanta.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_bradoReflexo;
  @override
  String descricao(BuildContext context) =>
      context.l10n.passiva_bradoReflexoDesc;

  @override
  void aoTentarTomarDano(Player player, double amount) {
    player.parent?.add(
      ExplosionHitbox(
        position: player.position.clone(),
        dmg: player.creatureData.stats.ataque * coef,
        knockback: empurrao,
        size: Vector2(48, 48),
        tipo: player.creatureData.tipo,
      ),
    );
  }
}

/// Grilo Elétrico. A esquiva recarrega bem mais rápido, mas percorre menos
/// distância.
///
/// Única das passivas que não é gancho de evento: são dois multiplicadores
/// permanentes. Reafirmados todo quadro em [aoAtualizar], por ATRIBUIÇÃO e não
/// multiplicação — assim não há par de aplicar/desfazer pra manter, o efeito
/// volta sozinho depois de um `trocarCriatura` (que zera estado de combate) e
/// sobrevive ao carregamento do save sem precisar de um gancho "ao ganhar".
class ReflexoEletrico extends ItemEfeito {
  const ReflexoEletrico({this.multCooldown = 0.6, this.multDistancia = 0.8});

  final double multCooldown;
  final double multDistancia;

  @override
  bool get sorteavel => false;
  @override
  String get id => 'reflexoEletrico';
  @override
  String get spritePath => 'actors/griloEletric.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_reflexoEletrico;
  @override
  String descricao(BuildContext context) =>
      context.l10n.passiva_reflexoEletricoDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    player.dodgeCdMult = multCooldown;
    player.dodgeDistMult = multDistancia;
  }
}

/// Roda de Fogo. Na velocidade máxima, o corpo do jogador machuca quem
/// encostar e o empurra, e fica imune ao dano de contato — a assinatura da
/// criatura virando permanente. Sem a imunidade a passiva não se pagava: pra
/// causar o dano de contato era preciso encostar, e encostar custava vida.
///
/// Escreve em `Player.danoDeContato`, `empurraoDeContato` e `imuneAContato`,
/// os mesmos campos que a passiva de criatura
/// [RodaDeFogo] usa. Os dois convivem: os itens rodam ANTES de
/// `creatureData.passive` no `Player.update`, então jogando DE Roda de Fogo o
/// valor da criatura vence (é maior). Com qualquer outra criatura, vale este.
class ImpetoArdente extends ItemEfeito {
  const ImpetoArdente({
    this.limiarVelocidade = 0.9,
    this.coefDano = 0.6,
    this.empurrao = 90.0,
  });

  /// Fração de `Player.maxSpeed` a partir da qual conta como máxima. Mais
  /// exigente que o da criatura (0,75): aqui não há o freio de ter que jogar
  /// sem habilidade 1 pra compensar.
  final double limiarVelocidade;

  final double coefDano;

  /// Mesmo empurrão do atropelamento da Roda de Fogo (ver `RodaDeFogo`).
  final double empurrao;

  @override
  bool get sorteavel => false;
  @override
  String get id => 'impetoArdente';
  @override
  String get spritePath => 'actors/rodaFogo.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_impetoArdente;
  @override
  String descricao(BuildContext context) =>
      context.l10n.passiva_impetoArdenteDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    final maxima = player.maxSpeed;
    final naMaxima =
        maxima > 0 && player.velocity.length >= maxima * limiarVelocidade;

    // Atribui nos DOIS casos. Zerar é obrigatório: com uma criatura que não
    // tem passiva, ninguém mais escreve neste campo, e sem o `else` o dano de
    // contato ficaria ligado pra sempre depois da primeira vez que o jogador
    // encostasse na velocidade máxima.
    //
    // Não atropela a Roda de Fogo porque a passiva da criatura roda DEPOIS
    // dos itens no `Player.update` e reescreve o campo com a palavra final.
    player.danoDeContato = naMaxima
        ? player.creatureData.stats.ataque * coefDano
        : 0.0;
    player.empurraoDeContato = naMaxima ? empurrao : 0.0;
    player.imuneAContato = naMaxima;
    // Mesmo rastro de vultos da Roda: o jogador precisa ver quando o corpo
    // virou arma.
    if (naMaxima) RodaDeFogo.rastroDeVelocidade(player);
  }
}

/// Slime de Planta. Levar dano solta uma nuvem de veneno em volta — quem te
/// encostou sai envenenado.
///
/// `aoTentarTomarDano` não recebe QUEM atacou, então o veneno sai como área em
/// volta do jogador em vez de ir no agressor. Na prática dá no mesmo: quem
/// acabou de te acertar está encostado em você.
class PeconhaReflexiva extends ItemEfeito {
  const PeconhaReflexiva({this.coef = 0.3, this.dotTicks = 4});

  final double coef;
  final int dotTicks;

  @override
  bool get sorteavel => false;
  @override
  String get id => 'peconhaReflexiva';
  @override
  String get spritePath => 'actors/slimePlanta.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_peconhaReflexiva;
  @override
  String descricao(BuildContext context) =>
      context.l10n.passiva_peconhaReflexivaDesc;

  @override
  void aoTentarTomarDano(Player player, double amount) {
    player.parent?.add(
      ExplosionHitbox(
        position: player.position.clone(),
        dmg: player.creatureData.stats.ataque * coef,
        size: Vector2(32, 32),
        cor1: Palette.verde,
        cor2: Palette.verdeEsc,
        tipo: player.creatureData.tipo,
        dotKind: DotKind.veneno,
        dotTicks: dotTicks,
      ),
    );
  }
}

/// Ouriço Elétrico. Levar dano solta uma descarga que atordoa em volta.
///
/// Primo da `CorrenteReflexa` (Ave Elétrica), e de propósito: a diferença é
/// que esta troca alcance por atordoamento mais longo, que é o jogo do Ouriço
/// — ele é lento e precisa que o inimigo pare, não que se afaste.
class RetaliacaoEletrica extends ItemEfeito {
  const RetaliacaoEletrica({this.coef = 0.5, this.duracaoStun = 2.0});

  final double coef;
  final double duracaoStun;

  @override
  bool get sorteavel => false;
  @override
  String get id => 'retaliacaoEletrica';
  @override
  String get spritePath => 'actors/ouricoEletric.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_retaliacaoEletrica;
  @override
  String descricao(BuildContext context) =>
      context.l10n.passiva_retaliacaoEletricaDesc;

  @override
  void aoTentarTomarDano(Player player, double amount) {
    player.parent?.add(
      ExplosionHitbox(
        position: player.position.clone(),
        dmg: player.creatureData.stats.ataque * coef,
        stunDuration: duracaoStun,
        size: Vector2(24, 24),
        cor1: Palette.amarelo,
        cor2: Palette.laranja,
        tipo: player.creatureData.tipo,
      ),
    );
  }
}

/// Pinguim de Água. Toda esquiva deixa uma poça de gelo no ponto de partida,
/// que lentifica quem passar.
///
/// No ponto de PARTIDA, não no de chegada (ao contrário do `RastroFlamejante`
/// e do `SaltoAquatico`): a poça serve pra atrasar quem está te perseguindo, e
/// pra isso ela tem que ficar atrás.
class RastroCongelante extends ItemEfeito {
  const RastroCongelante({
    this.lentidaoDuracao = 2.5,
    this.lentidaoFator = 0.5,
    this.duracaoPoca = 3.0,
  });

  final double lentidaoDuracao;
  final double lentidaoFator;
  final double duracaoPoca;

  @override
  bool get sorteavel => false;
  @override
  String get id => 'rastroCongelante';
  @override
  String get spritePath => 'actors/pinguimAgua.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_rastroCongelante;
  @override
  String descricao(BuildContext context) =>
      context.l10n.passiva_rastroCongelanteDesc;

  @override
  void aoUsarAbility2(Player player) {
    player.parent?.add(
      Projectile(
        owner: player,
        position: player.position.clone(),
        direction: Vector2.zero(),
        speed: 0,
        dmg: 0,
        kbForce: 0,
        sprPath: 'projeteis/bolaGrande.png',
        cor1: Palette.royal,
        cor2: Palette.azul,
        tipo: player.creatureData.tipo,
        lentidaoDuracao: lentidaoDuracao,
        lentidaoFator: lentidaoFator,
        atravessa: 100,
        size: Vector2(24, 24),
        lifeTime: duracaoPoca,
        radius: 12,
        playSfx: false,
      ),
    );
  }
}

/// Qual passiva cada criatura entrega ao se aposentar.
///
/// Este mapa É a pool de aposentadoria: criatura fora dele não acumula a
/// segunda contagem de XP nem se aposenta, porque não haveria o que entregar.
/// Cresce sozinho conforme novas passivas forem escritas — não existe uma
/// segunda lista pra manter em sincronia.
///
/// Cada criatura NOVA que passa pelo grupo nesta run deixa dano permanente.
///
/// Paga por ROTAÇÃO, e é o único item que faz isso: o resto do acervo premia
/// ficar bom no que você já tem, e este premia experimentar. Combina com a
/// sala da escada (`recrutarCriaturaSelvagem`) e com o consumível MAPA, as
/// duas vias de entrar gente no grupo no meio da run.
///
/// O bônus é concedido UMA vez, no momento em que a criatura entra, e não
/// recalculado por quadro. Isso importa: `Player.danoMult` é estático e vai
/// pro save, então somar aqui é um ganho permanente de verdade, gravado como
/// tal — o oposto das janelas de [Couraca]/[Desesperado], que o
/// `_salvarProgresso` tem que derrubar antes da foto justamente porque NÃO
/// são permanentes.
///
/// A primeira criatura da run não paga: `startRun` registra ela antes de os
/// itens existirem. Na prática o item conta da segunda em diante, o que é o
/// que ele promete.
class DiarioDeCampo extends ItemEfeito {
  const DiarioDeCampo();

  /// Quanto cada criatura nova acrescenta em `Player.danoMult`. Mesma ordem
  /// de grandeza do upgrade de dano do pedestal (0,15), um pouco abaixo
  /// porque este pode repetir até o limite do elenco.
  static const double bonusPorCriatura = 0.10;

  @override
  String get id => 'diarioDeCampo';
  @override
  String get spritePath => 'items/diario.png';
  @override
  Color get cor1 => Palette.bege;
  @override
  Color get cor2 => Palette.marrom;
  @override
  String nome(BuildContext context) => context.l10n.item_diarioDeCampo;
  @override
  String descricao(BuildContext context) =>
      context.l10n.item_diarioDeCampoDesc;

  @override
  void aoUsarCriaturaNova(Player player, CreatureData criatura) {
    Player.danoMult += bonusPorCriatura;
  }
}

/// Cada companheira viva além da que está no comando dá dano.
///
/// Recompensa NÃO perder ninguém — hoje uma criatura caída só tira opções, e
/// nenhum item falava disso. Perder a segunda companheira derruba o bônus na
/// hora, então o item transforma o grupo num número pra proteger.
///
/// Derivado, não permanente: escreve em `Player.danoMultDerivado`, que é
/// reconstruído a cada quadro. Por isso o valor sobe quando alguém é
/// recrutado e desce quando alguém cai, sem nada pra desfazer.
class EloDoGrupo extends ItemEfeito {
  const EloDoGrupo();

  /// Por companheira viva fora da ativa. Com os 3 slots do grupo, o teto é
  /// duas companheiras — ou seja, +0,30 no máximo.
  static const double bonusPorCompanheira = 0.15;

  @override
  String get id => 'eloDoGrupo';
  @override
  String get spritePath => 'items/elos.png';
  @override
  Color get cor1 => Palette.jade;
  @override
  Color get cor2 => Palette.verdeEsc;
  @override
  String nome(BuildContext context) => context.l10n.item_eloDoGrupo;
  @override
  String descricao(BuildContext context) => context.l10n.item_eloDoGrupoDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    final jogo = player.game;
    if (jogo is! CreaturesRogueGame) return;

    // Conta os slots ocupados: `pocketarSlotAtivo` esvazia o slot de quem cai
    // (nada neste jogo revive), então "slot ocupado" já é "criatura viva".
    final vivas = jogo.grupo.where((m) => m != null).length;
    if (vivas <= 1) return;

    Player.danoMultDerivado += (vivas - 1) * bonusPorCompanheira;
  }
}

/// Moeda no bolso dá dano. Gastar na loja enfraquece.
///
/// Põe a loja em tensão com o combate: até agora guardar moeda era só esperar
/// pelo balcão certo, e o custo de comprar era zero. Com este item, cada
/// compra é uma troca de força imediata por um item.
///
/// Derivado a cada quadro em `Player.danoMultDerivado`, então o bônus cai no
/// mesmo instante em que o balcão cobra.
class Imposto extends ItemEfeito {
  const Imposto();

  static const double bonusPorMoeda = 0.02;

  /// Teto de propósito: moeda não tem limite de acúmulo (ver `CoinPickup`,
  /// "não tem teto útil"), e sem travar aqui uma run de acúmulo viraria dano
  /// infinito. 25 moedas batem no teto, e os balcões mais caros da loja
  /// custam 20 — então o teto fica logo acima do que o jogador de fato
  /// carrega.
  static const double bonusMaximo = 0.50;

  @override
  String get id => 'imposto';
  @override
  String get spritePath => 'items/saco.png';
  @override
  Color get cor1 => Palette.amarelo;
  @override
  Color get cor2 => Palette.marrom;
  @override
  String nome(BuildContext context) => context.l10n.item_imposto;
  @override
  String descricao(BuildContext context) => context.l10n.item_impostoDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    Player.danoMultDerivado +=
        (player.coins * bonusPorMoeda).clamp(0.0, bonusMaximo);
  }
}

/// Dano cresce conforme a energia esvazia — os últimos tiros da rajada são os
/// que doem.
///
/// O caminho INVERSO do que parece natural, e de propósito. Energia é o
/// tamanho da rajada (teto 10, regenera 5/s e pausa 0,3s depois de cada tiro,
/// ver `AbilityUser`), então "energia cheia" quer dizer "você ainda não
/// atirou". Um bônus atrelado à energia cheia valeria só no primeiro tiro e
/// sumiria no segundo — premiaria não atirar.
///
/// Atrelado ao esvaziamento, vira decisão: a pausa de regeneração pune quem só
/// martela o botão, então ou você para cedo e mantém a cadência, ou desce até o
/// fundo do pente atrás do dano e engole a espera.
class Esgotamento extends ItemEfeito {
  const Esgotamento();

  /// Dano extra com a energia no zero. No meio do pente rende metade disso —
  /// a escala é linear em cima de `energiaFracao`.
  static const double bonusMaximo = 0.60;

  @override
  String get id => 'esgotamento';
  @override
  String get spritePath => 'items/esgotamento.png';
  @override
  Color get cor1 => Palette.laranja;
  @override
  Color get cor2 => Palette.marrom;
  @override
  String nome(BuildContext context) => context.l10n.item_esgotamento;
  @override
  String descricao(BuildContext context) => context.l10n.item_esgotamentoDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    Player.danoMultDerivado += (1 - player.energiaFracao) * bonusMaximo;
  }
}

/// Crítico atordoa o alvo.
///
/// Transforma crítico de "número maior" em controle: com 5% de chance base ele
/// é raro o bastante pra o atordoamento não trivializar a sala, e a sinergia
/// com o [SangueFrio] — que sobe a chance quando o azar se acumula — é
/// intencional.
class GatilhoFrio extends ItemEfeito {
  const GatilhoFrio();

  static const double duracaoStun = 0.8;

  @override
  String get id => 'gatilhoFrio';
  @override
  String get spritePath => 'items/gatilhoFrio.png';
  @override
  Color get cor1 => Palette.azul;
  @override
  Color get cor2 => Palette.royal;
  @override
  String nome(BuildContext context) => context.l10n.item_gatilhoFrio;
  @override
  String descricao(BuildContext context) => context.l10n.item_gatilhoFrioDesc;

  @override
  void aoCritar(Player player, Enemy alvo) {
    alvo.applyStun(duracaoStun);
  }
}

/// Cada golpe sem crítico aumenta a chance do próximo. O crítico zera a
/// conta.
///
/// Mata a variância, que é o problema real de apostar em crítico numa run
/// curta: com 5% de base, uma sequência de azar significa que o investimento
/// inteiro não rendeu nada. Aqui o azar vira a própria garantia.
///
/// A contagem (`Player.golpesSemCrit`) é mantida onde o sorteio acontece, em
/// `Enemy.takeDamage` — este item só lê. E o bônus sai por
/// `Player.critChanceDerivada`, reconstruído a cada quadro, então ele nunca é
/// gravado no save nem se soma em cima de si mesmo.
class SangueFrio extends ItemEfeito {
  const SangueFrio();

  /// Pontos percentuais por golpe sem crítico.
  static const double porGolpe = 4.0;

  /// Teto do acúmulo. Com a base de 5%, dez golpes sem crítico levam a chance
  /// pra perto de 45% — alto, mas só depois de um azar que valha compensar.
  static const double teto = 40.0;

  @override
  String get id => 'sangueFrio';
  @override
  String get spritePath => 'items/sangueFrio.png';
  @override
  Color get cor1 => Palette.royal;
  @override
  Color get cor2 => Palette.azulEsc;
  @override
  String nome(BuildContext context) => context.l10n.item_sangueFrio;
  @override
  String descricao(BuildContext context) => context.l10n.item_sangueFrioDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    player.critChanceDerivada += (player.golpesSemCrit * porGolpe).clamp(
      0.0,
      teto,
    );
  }
}

/// Sala de tesouro e loja aparecem no minimapa desde a chegada no andar.
///
/// Item permanente, e não consumível como o MAPA: aquele revela uma vez e
/// acaba, este muda o roteiro de toda a run — você escolhe o caminho sabendo
/// onde estão as duas salas que interessam.
///
/// A sala do BOSS fica de fora de propósito: saber onde ele está tira a única
/// tensão que sobra em explorar um andar já limpo.
///
/// Reafirma a cada quadro em vez de marcar uma vez porque a dungeon é gerada
/// de novo a cada andar. São poucas dezenas de escritas de bool por quadro, e
/// um gancho de "entrou num andar novo" só se pagaria com um segundo item
/// desse tipo.
class Bussola extends ItemEfeito {
  const Bussola();

  @override
  String get id => 'bussola';
  @override
  String get spritePath => 'items/bussola.png';
  @override
  Color get cor1 => Palette.laranja;
  @override
  Color get cor2 => Palette.roxoEsc;
  @override
  String nome(BuildContext context) => context.l10n.item_bussola;
  @override
  String descricao(BuildContext context) => context.l10n.item_bussolaDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    final jogo = player.game;
    if (jogo is! CreaturesRogueGame) return;

    for (final sala in jogo.mapData.values) {
      if (sala.type == RoomType.item || sala.type == RoomType.shop) {
        sala.isRevealed = true;
      }
    }
  }
}

/// Pedra elemental: aumenta o dano de UM elemento.
///
/// Uma classe só, parametrizada pelo [tipo], em vez de quatro quase idênticas:
/// a diferença entre a Pedra de Fogo e a de Água é uma cor, um nome e uma
/// chave de mapa. As quatro instâncias ficam em `ItemEfeitoRegistry.todos`.
///
/// Escreve em `Player.danoElementalDerivado`, e não no `danoMultDerivado`:
/// aquele é global e é lido no ponto do acerto, onde não existe informação de
/// elemento. Quem sabe o elemento do golpe é o `Enemy.takeDamage`, e é lá que
/// o mapa é consultado.
///
/// O bônus pega TUDO daquele elemento, inclusive o dano por tempo: um tique de
/// queimadura chega em `takeDamage` com `tipoAtacante: fogo`.
///
/// AVISO DE BALANCEAMENTO: o elemento dos seus golpes vem da criatura ativa
/// (`creatureData.tipo`), que não muda no meio do combate. Então esta pedra é
/// forte com a criatura certa e **peso morto** com as outras — é um item que
/// premia quem monta o grupo em torno de um elemento. Se isso ficar frustrante
/// demais no teste, o conserto é o bônus valer também pro elemento da criatura
/// ATIVA, seja qual for a pedra; mas aí ela deixa de ser uma escolha.
class PedraElemental extends ItemEfeito {
  const PedraElemental(this.tipo);

  final CreatureType tipo;

  /// Quanto o dano daquele elemento sobe. Generoso de propósito: o item só
  /// vale enquanto a criatura ativa for do elemento certo, então um bônus
  /// tímido o deixaria pior que qualquer `+DANO` de pedestal, que vale sempre.
  static const double bonus = 0.30;

  @override
  String get id => 'pedra_${tipo.name}';

  /// Um desenho por elemento. O arquivo do elétrico é `pedraRaio`, e não
  /// `pedraEletrico` como o resto do enum sugeriria — nome do asset, não do
  /// código.
  @override
  String get spritePath => switch (tipo) {
    CreatureType.fogo => 'items/pedraFogo.png',
    CreatureType.agua => 'items/pedraAgua.png',
    CreatureType.planta => 'items/pedraPlanta.png',
    CreatureType.eletrico => 'items/pedraRaio.png',
    CreatureType.neutro => 'items/pedraFogo.png',
  };

  @override
  Color get cor1 => switch (tipo) {
    CreatureType.fogo => Palette.vermelho,
    CreatureType.agua => Palette.azul,
    CreatureType.planta => Palette.verde,
    CreatureType.eletrico => Palette.amarelo,
    CreatureType.neutro => Palette.cinza,
  };

  @override
  Color get cor2 => switch (tipo) {
    CreatureType.fogo => Palette.laranja,
    CreatureType.agua => Palette.royal,
    CreatureType.planta => Palette.verdeEsc,
    CreatureType.eletrico => Palette.marrom,
    CreatureType.neutro => Palette.cinzaEsc,
  };

  /// Nome e descrição por elemento, e não um texto com lacuna: em português
  /// "PEDRA DE FOGO" e "PEDRA ELÉTRICA" não cabem na mesma forma.
  @override
  String nome(BuildContext context) => switch (tipo) {
    CreatureType.fogo => context.l10n.item_pedraFogo,
    CreatureType.agua => context.l10n.item_pedraAgua,
    CreatureType.planta => context.l10n.item_pedraPlanta,
    CreatureType.eletrico => context.l10n.item_pedraEletrico,
    CreatureType.neutro => context.l10n.item_pedraFogo,
  };

  @override
  String descricao(BuildContext context) => switch (tipo) {
    CreatureType.fogo => context.l10n.item_pedraFogoDesc,
    CreatureType.agua => context.l10n.item_pedraAguaDesc,
    CreatureType.planta => context.l10n.item_pedraPlantaDesc,
    CreatureType.eletrico => context.l10n.item_pedraEletricoDesc,
    CreatureType.neutro => context.l10n.item_pedraFogoDesc,
  };

  @override
  void aoAtualizar(Player player, double dt) {
    // Soma, não atribui: duas pedras do mesmo elemento (possível se um dia a
    // pool deixar repetir) acumulam, e o mapa é zerado a cada quadro de
    // qualquer jeito.
    player.danoElementalDerivado[tipo] =
        (player.danoElementalDerivado[tipo] ?? 1.0) + bonus;
  }
}

/// Toda vez que o jogador usa a habilidade do botão B, há chance de algo
/// invisível atacar um inimigo qualquer da sala.
///
/// Vale pra QUALQUER habilidade 2 — defesa, esquiva ou ataque —, e é por isso
/// que o efeito é por CHANCE: amarrado só à defesa, o item seria peso morto
/// nas criaturas cujo botão B é esquiva, que são a maioria.
///
/// Alvo sorteado e não o mais próximo: escolher o mais próximo faria o item
/// premiar quem já estava perto, que é justamente quem menos precisa de ajuda
/// ao se defender. Sorteio também dá pra alcançar quem está atirando de longe.
///
/// Dano do tipo NEUTRO de propósito: sem vantagem nem desvantagem elemental
/// (ver `typeMultiplier`), o item rende igual com qualquer criatura e não vira
/// refém da composição do grupo — o oposto da [PedraElemental], que é uma
/// aposta declarada.
class Sentinela extends ItemEfeito {
  const Sentinela();

  /// Chance por uso do botão B. Não é 100% porque a habilidade 2 tem cooldown
  /// curto em várias criaturas; garantir o golpe transformaria o botão B num
  /// ataque melhor que o A.
  static const double chance = 0.35;

  /// Dano = ataque da criatura x isto. Generoso porque não escala com nada e
  /// só acontece em pouco mais de um a cada três usos.
  static const double coefDano = 1.5;

  @override
  String get id => 'sentinela';
  @override
  String get spritePath => 'items/garrafa.png';
  @override
  Color get cor1 => Palette.indigo;
  @override
  Color get cor2 => Palette.azulEsc;
  @override
  String nome(BuildContext context) => context.l10n.item_sentinela;
  @override
  String descricao(BuildContext context) => context.l10n.item_sentinelaDesc;

  @override
  void aoUsarAbility2(Player player) {
    if (Random().nextDouble() >= chance) return;

    final alvo = _sortearInimigo(player);
    if (alvo == null) return;

    player.parent?.add(
      SpriteEffect(
        position: alvo.position.clone(),
        spritePath: 'effects/summon.png',
        size: Vector2.all(24),
        textureSize: Vector2.all(24),
        corClara: cor1,
        corEscura: cor2,
        corBranco: Palette.branco,
      ),
    );

    alvo.takeDamage(
      player.creatureData.stats.ataque * coefDano,
      tipoAtacante: CreatureType.neutro,
    );
  }

  /// Um inimigo qualquer da sala ATUAL.
  ///
  /// A restrição por sala é a mesma que a mira automática e o item CONGELAR
  /// já usam: todos os inimigos da dungeon existem ao mesmo tempo, então sem
  /// o filtro o golpe acertaria alguém a três salas de distância.
  Enemy? _sortearInimigo(Player player) {
    final sala = player.currentRoom;
    final candidatos = <Enemy>[];

    for (final inimigo in player.parent?.children.whereType<Enemy>() ??
        const <Enemy>[]) {
      if (sala != null &&
          !sala.toAbsoluteRect().contains(
            Offset(inimigo.absolutePosition.x, inimigo.absolutePosition.y),
          )) {
        continue;
      }
      candidatos.add(inimigo);
    }

    if (candidatos.isEmpty) return null;
    return candidatos[Random().nextInt(candidatos.length)];
  }
}

/// Levantar a guarda devolve energia.
///
/// Liga o botão B ao botão A, que hoje não se conversam: a energia é o
/// tamanho da rajada da habilidade 1 (ver `AbilityUser`), e a defesa era tempo
/// parado que não contribuía em nada pro ataque. Com isto, defender no momento
/// certo vira parte do ciclo ofensivo em vez de uma pausa nele.
///
/// Só vale pra criatura de habilidade 2 DEFENSIVA — quem tem esquiva no botão
/// B não tem o que fazer com este item. É o preço de um efeito forte e
/// garantido, sem chance envolvida.
class Recarga extends ItemEfeito {
  const Recarga();

  /// Fração da energia máxima devolvida por uso. Metade é o bastante pra
  /// emendar uma rajada logo depois da defesa, sem tornar a energia irrelevante.
  static const double fracao = 0.5;

  @override
  String get id => 'recarga';
  @override
  String get spritePath => 'items/energyRecover.png';
  @override
  Color get cor1 => Palette.laranja;
  @override
  Color get cor2 => Palette.royal;
  @override
  String nome(BuildContext context) => context.l10n.item_recarga;
  @override
  String descricao(BuildContext context) => context.l10n.item_recargaDesc;

  @override
  void aoUsarDefesa(Player player) {
    player.energia = (player.energia + player.energiaMax * fracao).clamp(
      0.0,
      player.energiaMax,
    );
  }
}

/// Levantar a guarda empurra pra longe quem estiver perto.
///
/// Dano ZERO: a defesa continua sendo defesa, o que muda é que ela passa a
/// COMPRAR ESPAÇO. Resolve o problema de fechar o casco com dois inimigos
/// colados e sair da defesa exatamente onde entrou.
///
/// Mesmo `ExplosionHitbox` de dano zero que o estouro da Bolha Protetora usa —
/// e é por isso que aquele `if (dmg > 0)` do `ExplosionHitbox` importa: sem
/// ele, cada inimigo empurrado ganharia um "0.0" flutuando na cabeça.
class Repulsao extends ItemEfeito {
  const Repulsao();

  static const double empurrao = 110.0;
  static const double raio = 44.0;

  @override
  String get id => 'repulsao';
  @override
  String get spritePath => 'items/repulsao.png';
  @override
  Color get cor1 => Palette.azul;
  @override
  Color get cor2 => Palette.branco;
  @override
  String nome(BuildContext context) => context.l10n.item_repulsao;
  @override
  String descricao(BuildContext context) => context.l10n.item_repulsaoDesc;

  @override
  void aoUsarDefesa(Player player) {
    player.parent?.add(
      ExplosionHitbox(
        position: player.position.clone(),
        dmg: 0,
        knockback: empurrao,
        size: Vector2.all(raio),
        cor1: cor1,
        cor2: cor2,
        tipo: player.creatureData.tipo,
      ),
    );
  }
}

/// Usar a habilidade do botão B cura, gastando cargas ganhas ao explorar.
///
/// Vale pra QUALQUER habilidade 2 — defesa, esquiva ou ataque —, então não
/// depende de a criatura ativa ter o tipo certo, ao contrário da [Recarga] e
/// da [Repulsao].
///
/// O custo é o item inteiro. A primeira versão usava espera em SEGUNDOS, e
/// isso não segurava nada: numa sala já limpa, tempo é de graça: bastava
/// martelar o botão B entre uma sala e outra pra chegar no andar seguinte com
/// a vida cheia, e poção, coração e escudo passivo perdiam a razão de existir.
///
/// Sala nova é um recurso que o jogador NÃO fabrica parado — o andar tem um
/// número fixo delas, e voltar pra uma já andada não conta (ver
/// `Player.cargasDeSala`). Curar passa a custar exploração de verdade.
class SegundoFolego extends ItemEfeito {
  const SegundoFolego();

  /// Cargas por cura. Com uma carga por sala inédita, sai perto de uma cura a
  /// cada três salas novas.
  static const int custoCargas = 3;

  @override
  bool get usaCargasDeSala => true;

  @override
  String get id => 'segundoFolego';
  @override
  String get spritePath => 'items/segundoFolego.png';
  @override
  Color get cor1 => Palette.jade;
  @override
  Color get cor2 => Palette.vermelho;
  @override
  String nome(BuildContext context) => context.l10n.item_segundoFolego;
  @override
  String descricao(BuildContext context) =>
      context.l10n.item_segundoFolegoDesc;

  @override
  void aoUsarAbility2(Player player) {
    if (player.cargasDeSala < custoCargas) return;
    if (!player.heal(1)) return;
    player.parent?.add(
        TextEffect(
          text:player.game.buildContext!.l10n.effect_maisVida(1),
          position: player.position.clone() + Vector2(0, -player.size.y / 2 - 4),
          color: Palette.verde,
        )
      );
    player.gastarCargasDeSala(custoCargas);
  }
}


/// Abates em sequência aceleram a habilidade 1. O contador zera se você
/// passar [janela] segundos sem matar nada.
///
/// Mexe no [Player.cdMultDerivado], que entra tanto no cooldown quanto no
/// CUSTO DE ENERGIA do disparo (ver `Player.dispararAbility1`). Só no
/// cooldown o item quase não se sentiria: em fogo sustentado quem limita a
/// cadência é a energia, não o cooldown.
///
/// [maxPilhas] existe porque cadência sem piso trava o indicador da Hud — o
/// mesmo motivo do `_dodgeCooldownMultFloor` da esquiva.
class Frenesi extends ItemEfeito {
  const Frenesi();

  static const double janela = 3.0;
  static const double porAbate = 0.12;
  static const int maxPilhas = 5;

  @override
  String get id => 'frenesi';
  @override
  String get spritePath => 'items/frenesi.png';
  @override
  Color get cor1 => Palette.vermelho;
  @override
  Color get cor2 => Palette.vermelho;
  @override
  String nome(BuildContext context) => context.l10n.item_frenesi;
  @override
  String descricao(BuildContext context) => context.l10n.item_frenesiDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    // `Player.tempoDesdeAbate` anda sozinho no `update`; aqui só se lê.
    if (player.tempoDesdeAbate > janela) {
      player.abatesSeguidos = 0;
      return;
    }
    final pilhas = player.abatesSeguidos > maxPilhas
        ? maxPilhas
        : player.abatesSeguidos;
    if (pilhas <= 0) return;
    player.cdMultDerivado *= 1.0 - porAbate * pilhas;
  }
}

/// Campeão abatido larga um item de verdade.
///
/// Hoje campeão é risco puro: o dobro de tamanho e 150% de vida por uns dois
/// pontos de XP a mais, então a jogada certa é evitar. Com isto ele vira
/// caça, que era a intenção da mecânica desde o começo.
///
/// Sorteia da pool da run (`sortearItemEfeito` JÁ retira o que devolve, então
/// não sai repetido) e cai num upgrade quando a pool acaba — nunca larga
/// nada.
class PresaDoCampeao extends ItemEfeito {
  const PresaDoCampeao();

  @override
  String get id => 'presaDoCampeao';
  @override
  String get spritePath => 'items/presaCampeao.png';
  @override
  Color get cor1 => Palette.branco;
  @override
  Color get cor2 => Palette.cinzaEsc;
  @override
  String nome(BuildContext context) => context.l10n.item_presaDoCampeao;
  @override
  String descricao(BuildContext context) => context.l10n.item_presaDoCampeaoDesc;

  @override
  void aoMatarInimigo(Player player, Enemy alvo) {
    if (!alvo.ehCampeao) return;

    // `alvo.parent`, e não `player.parent`: os dois são o mundo, mas o do alvo
    // é quem ainda está montado no quadro em que esta linha roda.
    final mundo = alvo.parent;
    if (mundo == null) return;

    final jogo = player.game;
    final item = jogo is CreaturesRogueGame ? jogo.sortearItemEfeito() : null;

    if (item != null) {
      mundo.add(ItemEfeitoPickup(position: alvo.position.clone(), item: item));
      return;
    }

    mundo.add(
      PowerUpItem(
        position: alvo.position.clone(),
        tipo: PowerUpType.values[Random().nextInt(PowerUpType.values.length)],
      ),
    );
  }
}

/// A sala de tesouro passa a nascer com TRÊS pedestais em vez de dois (ver
/// `RoomComponent._spawnTreasure`). Continua levando um só: o item não dá
/// mais prêmio, dá mais opção.
///
/// Não tem gancho nenhum — quem consulta é a sala, na hora de montar. E por
/// isso vale SÓ A PARTIR DO ANDAR SEGUINTE: todas as salas de um andar são
/// criadas de uma vez quando o andar é gerado, então a sala de tesouro do
/// andar em que você achou o item já nasceu com dois.
class BauDoTesouro extends ItemEfeito {
  const BauDoTesouro();

  @override
  String get id => 'bauDoTesouro';
  @override
  String get spritePath => 'items/bauDoTesouro.png';
  @override
  Color get cor1 => Palette.amarelo;
  @override
  Color get cor2 => Palette.marrom;
  @override
  String nome(BuildContext context) => context.l10n.item_bauDoTesouro;
  @override
  String descricao(BuildContext context) => context.l10n.item_bauDoTesouroDesc;
}

/// +[bonusDano] de dano, e o escudo passivo nunca mais enche.
///
/// NÃO é o Desesperado com outra roupa: aquele PREMIA estar sem escudo e
/// devolve o bônus quando a barra volta; este FORÇA a condição pra sempre. Os
/// dois na mesma run são uma build, não uma repetição — e a bolha de
/// habilidade (`shieldHits`) segue funcionando, que é a única defesa que
/// sobra.
class CascaDeOvo extends ItemEfeito {
  const CascaDeOvo();

  static const double bonusDano = 0.5;

  @override
  String get id => 'cascaDeOvo';
  @override
  String get spritePath => 'items/cascaDeOvo.png';
  @override
  Color get cor1 => Palette.bege;
  @override
  Color get cor2 => Palette.laranja;
  @override
  String nome(BuildContext context) => context.l10n.item_cascaDeOvo;
  @override
  String descricao(BuildContext context) => context.l10n.item_cascaDeOvoDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    Player.danoMultDerivado *= 1.0 + bonusDano;
    // A trava vale mais que zerar o valor: a regeneração roda depois deste
    // laço no mesmo `update` (ver `Player.escudoTravado`).
    player.escudoTravado = true;
    if (player.shield > 0) player.shield = 0;
  }
}

/// A desvantagem elemental (o 0,5x da tabela) deixa de existir: todo golpe
/// seu vale pelo menos 1,0x.
///
/// NÃO dá vantagem — o 2,0x continua 2,0x, então trocar de criatura pelo
/// tipo certo segue valendo. O que ele tira é a PUNIÇÃO, que é o que hoje
/// obriga a largar a criatura de que você gosta numa sala inteira do tipo
/// errado.
class Prisma extends ItemEfeito {
  const Prisma();

  @override
  String get id => 'prisma';
  @override
  String get spritePath => 'items/prisma.png';
  @override
  Color get cor1 => Palette.branco;
  @override
  Color get cor2 => Palette.indigo;
  @override
  String nome(BuildContext context) => context.l10n.item_prisma;
  @override
  String descricao(BuildContext context) => context.l10n.item_prismaDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    player.ignoraDesvantagemElemental = true;
  }
}


/// Um filhote orbita o jogador e ATIRA sozinho no inimigo mais próximo, com o
/// ELEMENTO da criatura ativa — troque de criatura e ele troca de cor e de
/// tipo junto.
///
/// Atira, e não machuca por encosto, pra não repetir a [Coleira]. As duas
/// nasceram como "corpo girando que fere quem toca" e a diferença entre elas
/// era só numérica — dano, raio e velocidade angular —, o que é o mesmo item
/// com dois nomes. Agora cada uma tem um verbo: esta cobre o que você NÃO
/// alcança, a Coleira defende o que está colado em você e cobra velocidade por
/// isso. Carregar as duas passa a somar em vez de repetir.
///
/// O orbital é uma subclasse própria, e não um `OrbitProjectile` cru, por uma
/// razão prática: os espinhos do Toco de Madeira também são `OrbitProjectile`,
/// e sem um tipo só dele este item não teria como perguntar "o meu ainda está
/// lá?" sem contar os do Toco junto.
///
/// A vigia é por tique periódico e não por um campo guardando a referência:
/// instância de `ItemEfeito` é `const` e não guarda estado, e um tique que
/// repara sozinho cobre de graça todo jeito de perder o filhote (morte, troca
/// de andar, fim de run).
class Ninhada extends ItemEfeito {
  const Ninhada();

  static const double intervaloVigia = 0.5;
  static const double raio = 20.0;
  static const double velocidadeAngular = 2.2;

  /// Dano do TIRO. O corpo do filhote não fere (ver [NinhoOrbital]).
  static const double coefDano = 0.5;

  static const double intervaloTiro = 1.2;

  /// Até onde ele enxerga alvo. Curto o bastante pra não atirar em inimigo de
  /// outra sala — ele nasce no mundo, não na sala, então a varredura de
  /// inimigos não tem fronteira própria.
  static const double alcance = 72.0;

  static const double velocidadeTiro = 150.0;

  @override
  String get id => 'ninhada';
  @override
  String get spritePath => 'items/ninho.png';
  @override
  Color get cor1 => Palette.bege;
  @override
  Color get cor2 => Palette.marrom;
  @override
  String nome(BuildContext context) => context.l10n.item_ninhada;
  @override
  String descricao(BuildContext context) => context.l10n.item_ninhadaDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    player.aplicarEfeito(
      #ninhadaVigia,
      intervaloVigia,
      stack: EfeitoStack.ignora,
      dono: EfeitoDono.jogador,
      aoIniciar: () => _garantirFilhote(player),
    );
  }

  /// Ao trocar de criatura o filhote velho é descartado; o tique seguinte
  /// devolve um com a cor e o tipo da criatura que entrou.
  @override
  void aoTrocarCriatura(Player player, CreatureData sai, CreatureData entra) {
    for (final f in _filhotes(player)) {
      f.removeFromParent();
    }
  }

  @override
  void aoPerder(Player player) {
    for (final f in _filhotes(player)) {
      f.removeFromParent();
    }
  }

  Iterable<NinhoOrbital> _filhotes(Player player) =>
      player.parent?.children.whereType<NinhoOrbital>() ??
      const <NinhoOrbital>[];

  void _garantirFilhote(Player player) {
    if (_filhotes(player).isNotEmpty) return;
    final criatura = player.creatureData;
    player.parent?.add(
      NinhoOrbital(
        owner: player,
        anguloAtual: 0,
        raio: raio,
        velocidadeAngular: velocidadeAngular,
        danoTiro: criatura.stats.ataque * coefDano,
        intervaloTiro: intervaloTiro,
        alcance: alcance,
        velocidadeTiro: velocidadeTiro,
        tipo: criatura.tipo,
        sprPath: 'actors/bird.png',
        cor1: criatura.corClara,
        cor2: criatura.corEscura,
      ),
    );
  }
}

/// O filhote da [Ninhada]: orbita o dono e dispara sozinho.
///
/// Tipo próprio, e não um `OrbitProjectile` cru, por duas razões. A primeira
/// é a lógica de tiro daqui. A segunda é identificação: os espinhos do Toco de
/// Madeira também são `OrbitProjectile`, e sem um tipo só dele a `Ninhada` não
/// teria como perguntar "o meu ainda está lá?" sem contar os do Toco junto.
///
/// `dmg: 0` de propósito — o corpo do filhote NÃO fere. Quem fere é o tiro.
/// Sem isso ele acumularia os dois papeis e voltaria a ser a Coleira.
class NinhoOrbital extends OrbitProjectile {
  NinhoOrbital({
    required PositionComponent owner,
    required double anguloAtual,
    required double raio,
    required double velocidadeAngular,
    required this.danoTiro,
    required this.intervaloTiro,
    required this.alcance,
    required this.velocidadeTiro,
    CreatureType tipo = CreatureType.neutro,
    String sprPath = 'projeteis/proj1.png',
    Color cor1 = Palette.bege,
    Color cor2 = Palette.marrom,
  }) : super(
         owner: owner,
         anguloAtual: anguloAtual,
         raioOrbita: raio,
         velocidadeAngular: velocidadeAngular,
         dmg: 0,
         tipo: tipo,
         sprPath: sprPath,
         cor1: cor1,
         cor2: cor2,
         atravessaObstaculos: true
       );

  final double danoTiro;
  final double intervaloTiro;
  final double alcance;
  final double velocidadeTiro;

  double _recarga = 0.0;

  @override
  void update(double dt) {
    super.update(dt);

    // Desfaz o giro que o `OrbitProjectile` acabou de aplicar. Aquele
    // `angle = anguloAtual` é certo pros espinhos do Toco de Madeira, que são
    // simetricos e devem rodar; num bicho com cabeça e pé ele deixa o filhote
    // de ponta-cabeça em metade da órbita. Aqui, e não lá no pai, porque os
    // dois usos querem coisas opostas do mesmo canal.
    angle = 0;

    // Vira pro lado pra onde está indo. A órbita é `(cos, sin) * raio`, então
    // o deslocamento é a derivada disso, `(-sin, cos)` — ou seja ele vai pra
    // direita quando `sin` é negativo.
    //
    // `bird.png` nasce olhando pra ESQUERDA (o bico ocupa as primeiras
    // colunas), por isso é o caso da direita que leva o espelho.
    scale.x = sin(anguloAtual) < 0 ? -1.0 : 1.0;

    _recarga -= dt;
    if (_recarga > 0) return;

    final alvo = _alvoMaisProximo();
    if (alvo == null) return;

    // Só recarrega quando ATIRA, não a cada quadro: sem alvo à vista o
    // filhote fica de tocaia e dispara no instante em que alguém entra no
    // alcance, em vez de esperar o relógio virar.
    _recarga = intervaloTiro;

    final delta = alvo.position - position;
    if (delta.length == 0) return;
    parent?.add(
      Projectile(
        owner: owner,
        position: position.clone(),
        direction: delta.normalized(),
        speed: velocidadeTiro,
        dmg: danoTiro,
        sprPath: 'projeteis/proj2.png',
        cor1: cor1,
        cor2: cor2,
        tipo: tipo,
        playSfx: false,
      ),
    );
  }

  Enemy? _alvoMaisProximo() {
    final vizinhos = parent?.children.whereType<Enemy>() ?? const <Enemy>[];
    Enemy? perto;
    var menor = alcance;
    for (final inimigo in vizinhos) {
      if (inimigo.summonTimer > 0) continue;
      final d = inimigo.position.distanceTo(position);
      if (d < menor) {
        menor = d;
        perto = inimigo;
      }
    }
    return perto;
  }
}

/// Quem você mata deixa uma poça do PRÓPRIO elemento: inimigo de fogo vira
/// queimadura no chão, de planta vira veneno.
///
/// Elemento do morto, e não o seu, de propósito: assim a sala vai ficando
/// cheia do tipo que aquele bioma usa, e você escolhe a criatura pensando no
/// que o chão vai virar, não só no que está vivo.
class Espolio extends ItemEfeito {
  const Espolio();

  static const double coefDano = 0.8;
  static const double duracao = 3.5;

  @override
  String get id => 'espolio';
  @override
  String get spritePath => 'items/espolio.png';
  @override
  Color get cor1 => Palette.mauve;
  @override
  Color get cor2 => Palette.roxoEsc;
  @override
  String nome(BuildContext context) => context.l10n.item_espolio;
  @override
  String descricao(BuildContext context) => context.l10n.item_espolioDesc;

  @override
  void aoMatarInimigo(Player player, Enemy alvo) {
    final morto = alvo.creature;
    if (morto == null) return;
    final mundo = alvo.parent;
    if (mundo == null) return;

    final (sprite, dot) = switch (morto.tipo) {
      CreatureType.fogo => ('projeteis/fogo.png', DotKind.queimadura),
      CreatureType.planta => ('projeteis/folha.png', DotKind.veneno),
      CreatureType.agua => ('projeteis/proj1.png', null),
      CreatureType.eletrico => ('projeteis/raio.png', null),
      CreatureType.neutro => ('projeteis/nuvemP.png', null),
    };

    mundo.add(
      Projectile(
        owner: player,
        position: alvo.position.clone(),
        direction: Vector2.zero(),
        speed: 0,
        lifeTime: duracao,
        dmg: player.creatureData.stats.ataque * coefDano,
        sprPath: sprite,
        cor1: morto.corClara,
        cor2: morto.corEscura,
        tipo: morto.tipo,
        radius: 8,
        atravessa: 100,
        dotKind: dot,
        dotTicks: 3,
        playSfx: false,
      ),
    );
  }
}

/// Toda pedra quebrada larga alguma coisa.
///
/// Sem ele a pedra dá coração ou moeda em 5% das vezes, ou seja: quebrar
/// pedra é quase só limpar o caminho. Com ele o cenário vira recurso, que é
/// um eixo de progressão que o jogo ainda não tinha.
class VeioRico extends ItemEfeito {
  const VeioRico();

  static const int xpExtra = 2;

  @override
  String get id => 'veioRico';
  @override
  String get spritePath => 'items/veioRico.png';
  @override
  Color get cor1 => Palette.amarelo;
  @override
  Color get cor2 => Palette.cinzaEsc;
  @override
  String nome(BuildContext context) => context.l10n.item_veioRico;
  @override
  String descricao(BuildContext context) => context.l10n.item_veioRicoDesc;

  @override
  void aoQuebrarPedra(Player player, Rock pedra) {
    final mundo = pedra.parent;
    if (mundo == null) return;
    final rng = Random();

    mundo.add(CoinPickup(position: pedra.position.clone()));
    for (var i = 0; i < xpExtra; i++) {
      mundo.add(
        XpPickup(
          position:
              pedra.position +
              Vector2(rng.nextDouble() * 16 - 8, rng.nextDouble() * 16 - 8),
        ),
      );
    }
  }
}

/// Pedra quebrada estoura.
///
/// A explosão quebra as pedras vizinhas, que estouram também — a reação em
/// cadeia é INTENCIONAL, e é o que torna uma sala cheia de pedra uma arma. Ela
/// não corre solta: gasta um quadro por elo (o `add` só vale no fim do quadro)
/// e acaba quando as pedras acabam.
///
/// `isEnemy` fica no padrão (false), então o estouro só pega inimigo. Quebrar
/// pedra do seu lado não pode te punir por usar o item.
class PeDeCabra extends ItemEfeito {
  const PeDeCabra();

  static const double coefDano = 1.2;
  static const double raio = 34.0;

  @override
  String get id => 'peDeCabra';
  @override
  String get spritePath => 'items/peDeCabra.png';
  @override
  Color get cor1 => Palette.cinza;
  @override
  Color get cor2 => Palette.marrom;
  @override
  String nome(BuildContext context) => context.l10n.item_peDeCabra;
  @override
  String descricao(BuildContext context) => context.l10n.item_peDeCabraDesc;

  @override
  void aoQuebrarPedra(Player player, Rock pedra) {
    pedra.parent?.add(
      ExplosionHitbox(
        position: pedra.position.clone(),
        dmg: player.creatureData.stats.ataque * coefDano,
        knockback: 60,
        size: Vector2.all(raio),
        tipo: player.creatureData.tipo,
        cor1: Palette.cinza,
        cor2: Palette.marrom,
      ),
    );
  }
}

/// Você não cura mais. Em troca, o dano cresce a cada andar sobrevivido.
///
/// O bônus sai do andar e não de um tempo corrido porque é o andar que mede o
/// que você pagou: cada um foi atravessado sem nenhum coração. E a cura
/// recusada devolve `false` em `Player.heal`, então o coração FICA no chão em
/// vez de sumir — se depois você largar o Jejum, ele ainda está lá.
class Jejum extends ItemEfeito {
  const Jejum();

  static const double bonusPorAndar = 0.15;

  @override
  String get id => 'jejum';
  @override
  String get spritePath => 'items/jejum.png';
  @override
  Color get cor1 => Palette.marrom;
  @override
  Color get cor2 => Palette.chocolate;
  @override
  String nome(BuildContext context) => context.l10n.item_jejum;
  @override
  String descricao(BuildContext context) => context.l10n.item_jejumDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    player.curaBloqueada = true;
    final jogo = player.game;
    final andar = jogo is CreaturesRogueGame ? jogo.currentFloor : 1;
    Player.danoMultDerivado *= 1.0 + bonusPorAndar * (andar - 1);
  }
}

/// Uma bola de ferro presa a você por uma corrente: gira devagar, machuca
/// forte quem encosta, e cobra velocidade.
///
/// É o oposto da [Ninhada] de propósito — aquela é pequena, rápida, elemental
/// e de graça; esta é pesada, lenta, neutra e cobra. Duas órbitas que jogam
/// diferente valem mais que duas parecidas.
///
/// O custo entra pelo [Player.velMultDerivado], canal reconstruído todo
/// quadro. Um `velMult -= x` pareado com um `+= x` no fim seria a receita de
/// virar permanente no dia em que o par se desequilibrasse.
class Coleira extends ItemEfeito {
  const Coleira();

  static const double intervaloVigia = 0.5;
  static const double raio = 36.0;
  static const double velocidadeAngular = 1.1;
  static const double coefDano = 2.0;
  static const double custoVelocidade = 0.15;

  @override
  String get id => 'coleira';
  @override
  String get spritePath => 'items/coleira.png';
  @override
  Color get cor1 => Palette.indigo;
  @override
  Color get cor2 => Palette.cinzaEsc;
  @override
  String nome(BuildContext context) => context.l10n.item_coleira;
  @override
  String descricao(BuildContext context) => context.l10n.item_coleiraDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    player.velMultDerivado *= 1.0 - custoVelocidade;
    player.aplicarEfeito(
      #coleiraVigia,
      intervaloVigia,
      stack: EfeitoStack.ignora,
      dono: EfeitoDono.jogador,
      aoIniciar: () => _garantirBola(player),
    );
  }

  @override
  void aoPerder(Player player) {
    for (final bola
        in player.parent?.children.whereType<BolaCorrente>().toList() ??
            const <BolaCorrente>[]) {
      bola.removeFromParent();
    }
  }

  void _garantirBola(Player player) {
    final existentes =
        player.parent?.children.whereType<BolaCorrente>() ??
        const <BolaCorrente>[];
    if (existentes.isNotEmpty) return;
    final bola = BolaCorrente(
      owner: player,
      anguloAtual: pi,
      raioOrbita: raio,
      velocidadeAngular: velocidadeAngular,
      dmg: player.creatureData.stats.ataque * coefDano,
      atravessaObstaculos: true,
    );
    player.parent?.add(bola);
    // Irmã da bola, não filha — ver `CorrenteVisual`. Ela se remove sozinha
    // quando a bola sai da árvore, então o par nasce e morre junto sem
    // ninguém precisar lembrar de limpar.
    player.parent?.add(CorrenteVisual(dono: player, bola: bola));
  }
}

/// A bola da [Coleira]. Tipo próprio pelo mesmo motivo do [NinhoOrbital].
class BolaCorrente extends OrbitProjectile {
  BolaCorrente({
    required super.owner,
    required super.anguloAtual,
    required super.raioOrbita,
    required super.velocidadeAngular,
    super.dmg,
    super.atravessaObstaculos,
    super.radius = 8,
  }) : super(
         sprPath: 'projeteis/ballChain.png',
         cor1: Palette.cinza,
         cor2: Palette.indigo,
       );
}

/// Matar com VANTAGEM elemental devolve energia.
///
/// Premia trocar de criatura pelo motivo certo, que é o que a tabela de tipos
/// existe pra ensinar e o que o jogo hoje quase não recompensa — a vantagem
/// só faz o inimigo morrer mais rápido, e morrer mais rápido não devolve nada.
///
/// A conta usa o tipo da criatura ATIVA, e não o do golpe que matou: o
/// [aoMatarInimigo] não carrega o golpe, e "matei com a criatura certa" é de
/// qualquer forma a leitura que o item promete.
class Ressonancia extends ItemEfeito {
  const Ressonancia();

  static const double energiaDevolvida = 2.5;

  @override
  String get id => 'ressonancia';
  @override
  String get spritePath => 'items/ressonancia.png';
  @override
  Color get cor1 => Palette.cinza;
  @override
  Color get cor2 => Palette.cinzaEsc;
  @override
  String nome(BuildContext context) => context.l10n.item_ressonancia;
  @override
  String descricao(BuildContext context) => context.l10n.item_ressonanciaDesc;

  @override
  void aoMatarInimigo(Player player, Enemy alvo) {
    final morto = alvo.creature;
    if (morto == null) return;
    if (typeMultiplier(player.creatureData.tipo, morto.tipo) <= 1.0) return;

    player.energia = (player.energia + energiaDevolvida).clamp(
      0.0,
      player.energiaMax,
    );
    player.parent?.add(
      TextEffect.dano(
        energiaDevolvida,
        position: player.position.clone() + Vector2(0, -player.size.y / 2 - 4),
        color: Palette.azul,
      ),
    );
  }
}


/// Cinzas EXATOS que o `PaletteSwapper` procura no sprite. Passar eles como
/// substituição é uma troca IDENTIDADE: o desenho sai exatamente como está no
/// arquivo.
///
/// É assim que as passivas de aposentadoria usam o sprite da própria criatura
/// sem a cor dela: cinza é o que sobra de uma criatura que saiu de campo, e
/// serve de marca de família — item colorido é achado, item cinza é lembrança.
const Color cinzaMarcadorClaro = Color(0xFFA9A9A9);
const Color cinzaMarcadorEscuro = Color(0xFF545454);

/// Paassarin (`ave_neutro`). Eco do Vôo Alto: todo botão B estende a janela de
/// invulnerabilidade.
///
/// SOMA ao que sobrou em vez de pedir um valor fixo: `grantInvulnerability`
/// fica com o maior dos dois, então pedir 0,4s durante uma esquiva de 0,6s
/// não faria nada. Assim o bônus se sente igual nas duas famílias de botão B.
class PenaDeVoo extends ItemEfeito {
  const PenaDeVoo();

  static const double bonus = 0.4;

  @override
  String get id => 'penaDeVoo';
  @override
  bool get sorteavel => false;
  @override
  String get spritePath => 'actors/aveNeutro.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_penaDeVoo;
  @override
  String descricao(BuildContext context) => context.l10n.passiva_penaDeVooDesc;

  @override
  void aoUsarAbility2(Player player) {
    player.grantInvulnerability(player.invulnerabilidadeRestante + bonus);
  }
}

/// layfishy (`peixe_neutro`). Eco das Escamas Escorregadias: todo botão B dá
/// imunidade a STATUS.
///
/// Par de propósito com a [PenaDeVoo], e o par ensina a diferença que o jogo
/// faz: aquela bloqueia DANO (`grantInvulnerability`), esta bloqueia CONDIÇÃO
/// — lentidão, cegueira e empurrão (`grantStatusImmunity`). Carregar as duas
/// é o que torna a distinção visível.
class EscamasGuardadas extends ItemEfeito {
  const EscamasGuardadas();

  static const double duracao = 2.0;

  @override
  String get id => 'escamasGuardadas';
  @override
  bool get sorteavel => false;
  @override
  String get spritePath => 'actors/peixeNeutro.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_escamasGuardadas;
  @override
  String descricao(BuildContext context) =>
      context.l10n.passiva_escamasGuardadasDesc;

  @override
  void aoUsarAbility2(Player player) {
    player.grantStatusImmunity(duracao);
  }
}

/// Hermiton (`caranguejo_fogo`). Eco do Recolher no Casco: todo botão B deixa
/// uma fumaça que cega e atrasa quem entra nela.
///
/// Não é clone do `RastroFlamejante`: aquele explode e queima, este não causa
/// dano nenhum. Um limpa, o outro atrapalha.
class FumacaResidual extends ItemEfeito {
  const FumacaResidual();

  static const double duracao = 4.0;
  static const double cegueira = 1.5;
  static const double lentidaoDuracao = 2.0;
  static const double lentidaoFator = 0.6;

  @override
  String get id => 'fumacaResidual';
  @override
  bool get sorteavel => false;
  @override
  String get spritePath => 'actors/caranguejoFogo.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_fumacaResidual;
  @override
  String descricao(BuildContext context) =>
      context.l10n.passiva_fumacaResidualDesc;

  @override
  void aoUsarAbility2(Player player) {
    player.parent?.add(
      Projectile(
        owner: player,
        position: player.position.clone(),
        direction: Vector2.zero(),
        speed: 0,
        dmg: 0,
        kbForce: 0,
        sprPath: 'projeteis/nuvem.png',
        cor1: Palette.cinza,
        cor2: Palette.cinzaEsc,
        tipo: player.creatureData.tipo,
        cegoDuracao: cegueira,
        lentidaoDuracao: lentidaoDuracao,
        lentidaoFator: lentidaoFator,
        atravessa: 100,
        size: Vector2(24, 24),
        lifeTime: duracao,
        radius: 12,
        playSfx: false,
      ),
    );
  }
}

/// Esporim (`cogumelo_planta`). Eco do Casulo de Esporos: quando a barra de
/// escudo zera, ela arrebenta numa nuvem de veneno.
///
/// É o casulo estourando, e o gancho [aoQuebrarEscudo] quase não tinha dono —
/// só o Estilhaço. Dispara pela barra passiva, não pela bolha de habilidade:
/// são dois sistemas, e a bolha estoura com frequência muito diferente.
class EsporosLatentes extends ItemEfeito {
  const EsporosLatentes();

  static const double coef = 0.6;
  static const double alcance = 26.0;
  static const int ticks = 4;

  @override
  String get id => 'esporosLatentes';
  @override
  bool get sorteavel => false;
  @override
  String get spritePath => 'actors/coguPlanta.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_esporosLatentes;
  @override
  String descricao(BuildContext context) =>
      context.l10n.passiva_esporosLatentesDesc;

  @override
  void aoQuebrarEscudo(Player player) {
    player.parent?.add(
      AuraPulseEffect(
        position: player.position.clone(),
        raio: alcance,
        cor1: Palette.verde,
        cor2: Palette.verdeEsc,
      ),
    );
    // Laço direto nos inimigos em vez de uma `ExplosionHitbox`: aquela quebra
    // pedra (ver `ExplosionHitbox`), e com o `Pé de Cabra` na mochila cada
    // escudo quebrado viraria uma reação em cadeia pela sala.
    final inimigos =
        player.parent?.children.whereType<Enemy>() ?? const <Enemy>[];
    for (final inimigo in inimigos) {
      if (inimigo.position.distanceTo(player.position) > alcance) continue;
      inimigo.takeDamage(
        player.creatureData.stats.ataque * coef,
        tipoAtacante: CreatureType.planta,
      );
      inimigo.applyDot(DotKind.veneno, ticks);
    }
  }
}

/// Doguin (`cao_neutro`). Eco do Latido Feroz: cada abate solta um latido que
/// atrasa quem estiver perto.
///
/// Não é clone do `BradoReflexo` (urso), que EMPURRA ao apanhar: aqui é
/// lentidão, e ao matar. Gatilho e efeito diferentes.
class EcoDoLatido extends ItemEfeito {
  const EcoDoLatido();

  static const double alcance = 40.0;
  static const double duracao = 2.0;
  static const double fator = 0.5;

  @override
  String get id => 'ecoDoLatido';
  @override
  bool get sorteavel => false;
  @override
  String get spritePath => 'actors/caoNeutro.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_ecoDoLatido;
  @override
  String descricao(BuildContext context) =>
      context.l10n.passiva_ecoDoLatidoDesc;

  @override
  void aoMatarInimigo(Player player, Enemy alvo) {
    player.parent?.add(
      AuraPulseEffect(
        position: player.position.clone(),
        raio: alcance,
        cor1: Palette.bege,
        cor2: Palette.marrom,
      ),
    );
    // Mesma razão do `EsporosLatentes` pra não usar `ExplosionHitbox`: ela
    // quebra pedra, e isto aqui dispara a cada abate.
    final inimigos =
        player.parent?.children.whereType<Enemy>() ?? const <Enemy>[];
    for (final inimigo in inimigos) {
      if (inimigo.position.distanceTo(player.position) > alcance) continue;
      inimigo.applyLentidao(duracao, fator: fator);
    }
  }
}

/// Leão Elétrico (`leao_eletrico`). Eco da Investida da Lança: o crítico
/// dispara uma lança que atravessa.
///
/// O estrangulador de 0,3s NÃO é zelo: a lança acerta, o `Enemy.takeDamage`
/// rola crítico de novo, e o [aoCritar] dispara outra lança. Com `atravessa`
/// alto e o Sangue Frio empurrando a chance pra cima, isso vira um laço que
/// só para quando a sala esvazia. Tique de veneno e queimadura também passam
/// pelo `takeDamage` e também rolam crítico, então nem "só golpe direto"
/// resolveria.
class PontaDaLanca extends ItemEfeito {
  const PontaDaLanca();

  static const double coef = 0.7;
  static const double velocidade = 170;
  static const double estrangulador = 0.3;

  @override
  String get id => 'pontaDaLanca';
  @override
  bool get sorteavel => false;
  @override
  String get spritePath => 'actors/gatoEletrico.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_pontaDaLanca;
  @override
  String descricao(BuildContext context) =>
      context.l10n.passiva_pontaDaLancaDesc;

  @override
  void aoCritar(Player player, Enemy alvo) {
    player.aplicarEfeito(
      #pontaDaLanca,
      estrangulador,
      stack: EfeitoStack.ignora,
      dono: EfeitoDono.jogador,
      aoIniciar: () => _lancar(player, alvo),
    );
  }

  void _lancar(Player player, Enemy alvo) {
    final delta = alvo.position - player.position;
    if (delta.length == 0) return;
    final frente = delta.normalized();
    player.parent?.add(
      Projectile(
        owner: player,
        position: player.position.clone() + frente * player.size.x / 2,
        direction: frente,
        speed: velocidade,
        dmg: player.creatureData.stats.ataque * coef,
        atravessa: 3,
        sprPath: 'projeteis/proj2.png',
        cor1: Palette.amarelo,
        cor2: Palette.laranja,
        tipo: player.creatureData.tipo,
      ),
    );
  }
}

/// Meao (`gato_neutro`). Um golpe letal por ANDAR deixa você com 1 de vida em
/// vez de tirar a criatura de campo.
///
/// É a única rede de segurança contra morte do jogo. Por andar, e não por
/// sala nem por run: por sala salvaria demais, por run quase nunca apareceria.
class SeteVidas extends ItemEfeito {
  const SeteVidas();

  @override
  String get id => 'seteVidas';
  @override
  bool get sorteavel => false;
  @override
  String get spritePath => 'actors/gatoNeutro.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_seteVidas;
  @override
  String descricao(BuildContext context) => context.l10n.passiva_seteVidasDesc;

  @override
  bool aoCairEmCombate(Player player) {
    if (player.seteVidasUsada) return false;
    player.seteVidasUsada = true;
    player.grantInvulnerability(1.0);
    player.parent?.add(
      AuraPulseEffect(
        position: player.position.clone(),
        raio: 20,
        cor1: Palette.branco,
        cor2: Palette.cinza,
      ),
    );
    return true;
  }
}

/// Toco de Madeira (`toco_planta`). Eco do Enraizar: ficar parado crava raízes
/// e reduz o dano recebido.
///
/// Único efeito do jogo que premia NÃO se mexer. A conta sai de
/// `Player.tempoParado`, que mede DESLOCAMENTO e não `velocity` — ver a doc
/// daquele campo pra saber por quê.
class RaizProfunda extends ItemEfeito {
  const RaizProfunda();

  /// Quanto tempo parado até a redução começar a subir.
  static const double carencia = 1.0;

  /// Quanto tempo parado até o máximo.
  static const double ateOMaximo = 3.0;

  static const double reducaoMax = 0.4;

  @override
  String get id => 'raizProfunda';
  @override
  bool get sorteavel => false;
  @override
  String get spritePath => 'actors/tocoPlanta.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_raizProfunda;
  @override
  String descricao(BuildContext context) =>
      context.l10n.passiva_raizProfundaDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    final parado = player.tempoParado - carencia;
    if (parado <= 0) return;
    final fracao = (parado / (ateOMaximo - carencia)).clamp(0.0, 1.0);
    player.reducaoDanoDerivada += reducaoMax * fracao;
  }
}

/// Tubarão de Água (`tubarao_agua`). Faro de sangue: mais dano contra inimigo
/// com menos da metade da vida.
///
/// Dano de execução é um eixo que nenhum outro item tem. Vale contra boss e
/// campeão também, que é onde a metade final da barra custa mais caro.
/// Calamarin (`sereia_agua`). Eco do molusco que some no cenário: ficar
/// parado por [espera] segundos garante crítico no PRÓXIMO golpe.
///
/// Um só: o crítico gasta a camuflagem, e ela só rearma depois de o jogador
/// se mexer e parar de novo. Sem isso, plantar o pé e atacar daria crítico
/// em todo golpe — virava torre, não emboscada.
///
/// `tempoParado` mede deslocamento, não `velocity` (ver a doc dele), então
/// atacar parado não desarma; andar desarma.
/// Zapeye (`olho_eletrico`). Eco do teleporte: todo botão B, de qualquer
/// criatura, faz todos os inimigos perderem o jogador de vista por
/// [duracao] segundos.
///
/// Usa a cegueira de inimigo, que agora mira a última posição vista: eles
/// atacam o ponto de onde o jogador SAIU — e tiro às cegas acerta os outros.
/// Cega no ponto de partida (`Player.posicaoAntesDaHab2`), e não no atual,
/// porque este gancho roda depois da habilidade e um teleporte já moveu o
/// jogador.
class Piscadela extends ItemEfeito {
  const Piscadela();

  static const double duracao = 0.8;

  @override
  String get id => 'piscadela';
  @override
  bool get sorteavel => false;
  @override
  String get spritePath => 'actors/olhoEletrico.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_piscadela;
  @override
  String descricao(BuildContext context) =>
      context.l10n.passiva_piscadelaDesc;

  @override
  void aoUsarAbility2(Player player) {
    final inimigos =
        player.parent?.children.whereType<Enemy>() ?? const <Enemy>[];
    for (final inimigo in inimigos) {
      inimigo.applyCego(duracao, vista: player.posicaoAntesDaHab2);
    }
  }
}

class Camuflagem extends ItemEfeito {
  const Camuflagem();

  static const double espera = 1.5;

  @override
  String get id => 'camuflagem';
  @override
  bool get sorteavel => false;
  @override
  String get spritePath => 'actors/sereiaAgua.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_camuflagem;
  @override
  String descricao(BuildContext context) =>
      context.l10n.passiva_camuflagemDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    if (player.tempoParado <= 0) player.camuflagemGasta = false;
    if (player.camuflagemGasta || player.tempoParado < espera) return;
    // 100 pontos percentuais: crítico certo, qualquer que seja a base.
    player.critChanceDerivada += 100;
  }

  @override
  void aoCritar(Player player, Enemy alvo) {
    if (player.tempoParado >= espera) player.camuflagemGasta = true;
  }
}

class FaroDeSangue extends ItemEfeito {
  const FaroDeSangue();

  static const double bonus = 0.35;

  @override
  String get id => 'faroDeSangue';
  @override
  bool get sorteavel => false;
  @override
  String get spritePath => 'actors/tubaAgua.png';
  @override
  Color get cor1 => cinzaMarcadorClaro;
  @override
  Color get cor2 => cinzaMarcadorEscuro;
  @override
  String nome(BuildContext context) => context.l10n.passiva_faroDeSangue;
  @override
  String descricao(BuildContext context) =>
      context.l10n.passiva_faroDeSangueDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    player.bonusAlvoFerido += bonus;
  }
}


/// Cada golpe que você escapa deixa você mais escorregadio; tomar dano zera
/// tudo.
///
/// O verbo é EMBALO: a evasão deixa de ser um número fixo e vira uma coisa
/// que se constrói e se perde. Quem está numa boa sequência pensa duas vezes
/// antes de entrar numa troca de golpes — que é exatamente a decisão que um
/// item de evasão deveria provocar.
class Miragem extends ItemEfeito {
  const Miragem();

  static const double porEsquiva = 6.0;
  static const int maxPilhas = 4;

  @override
  String get id => 'miragem';
  @override
  String get spritePath => 'items/miragem.png';
  @override
  Color get cor1 => Palette.cinza;
  @override
  Color get cor2 => Palette.indigo;
  @override
  String nome(BuildContext context) => context.l10n.item_miragem;
  @override
  String descricao(BuildContext context) => context.l10n.item_miragemDesc;

  @override
  void aoEvadir(Player player) {
    if (player.pilhasMiragem < maxPilhas) player.pilhasMiragem++;
  }

  /// Zera no golpe que ENTRA. Aqui, e não no `aoTentarTomarDano`: aquele
  /// dispara também no golpe que o escudo come, e perder o embalo inteiro por
  /// um golpe que a bolha absorveu seria punir duas vezes.
  @override
  void aoTomarDano(Player player, double danoFinal, CreatureType tipoAtacante) {
    player.pilhasMiragem = 0;
  }

  @override
  void aoAtualizar(Player player, double dt) {
    player.evasaoDerivada += porEsquiva * player.pilhasMiragem;
  }
}

/// Aparar o golpe revida no inimigo mais próximo.
///
/// O verbo é CONTRAGOLPE: a evasão deixa de ser só defesa e vira a abertura
/// do seu ataque. Transforma o 5% que todo mundo tem de graça em algo que
/// vale a pena procurar.
class Aparar extends ItemEfeito {
  const Aparar();

  static const double coefDano = 1.5;
  static const double alcance = 64.0;

  @override
  String get id => 'aparar';
  @override
  String get spritePath => 'items/parry.png';
  // `cinza`, e não `branco`: o sprite já usa o BRANCO FIXO do `PaletteSwapper`
  // por conta própria, e uma `cor1` branca se dissolveria nele.
  @override
  Color get cor1 => Palette.cinza;
  @override
  Color get cor2 => Palette.indigo;
  @override
  String nome(BuildContext context) => context.l10n.item_aparar;
  @override
  String descricao(BuildContext context) => context.l10n.item_apararDesc;

  @override
  void aoEvadir(Player player) {
    final inimigos =
        player.parent?.children.whereType<Enemy>() ?? const <Enemy>[];
    Enemy? alvo;
    var menor = alcance;
    for (final inimigo in inimigos) {
      if (inimigo.summonTimer > 0) continue;
      final d = inimigo.position.distanceTo(player.position);
      if (d < menor) {
        menor = d;
        alvo = inimigo;
      }
    }
    if (alvo == null) return;

    player.parent?.add(
      SpriteEffect(
        position: alvo.position.clone(),
        size: Vector2(16, 16),
        corClara: Palette.branco,
        corEscura: Palette.azulEsc,
        corBranco: Palette.branco,
        spritePath: 'effects/stun.png',
        textureSize: Vector2(16, 16),
        stepTime: 0.12,
      ),
    );
    alvo.takeDamage(
      player.creatureData.stats.ataque * coefDano,
      tipoAtacante: player.creatureData.tipo,
    );
  }
}

/// Com a vida no fim, a evasão dobra.
///
/// O verbo é VIRADA: não dá nada enquanto você está bem, e muito quando você
/// está por um fio. É a cara oposta do `Couraça`, que premia andar com o
/// escudo cheio — os dois juntos nunca ligam ao mesmo tempo, e isso é de
/// propósito: um cobre o começo da briga, o outro o fim.
class PeDeCoelho extends ItemEfeito {
  const PeDeCoelho();

  /// Fração da vida abaixo da qual o bônus liga.
  static const double limiar = 0.34;

  @override
  String get id => 'peDeCoelho';
  @override
  String get spritePath => 'items/peCoelho.png';
  @override
  Color get cor1 => Palette.bege;
  @override
  Color get cor2 => Palette.marrom;
  @override
  String nome(BuildContext context) => context.l10n.item_peDeCoelho;
  @override
  String descricao(BuildContext context) => context.l10n.item_peDeCoelhoDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    if (player.currentHealth > player.maxHealth * limiar) return;
    // DOBRA o que já existe em vez de somar um valor fixo: assim ele escala
    // junto com a Miragem e com o upgrade, e continua valendo a pena no fim
    // de uma run em que a evasão já subiu.
    player.evasaoDerivada += player.evasaoTotal;
  }
}

class PassivasAposentadoria {
  static const Map<String, ItemEfeito> porCriatura = {
    'roedor_fogo': RastroFlamejante(),
    'tartaruga_planta': CascoReflexivo(),
    'sapo_agua': BolhaAutonoma(),
    'ave_eletrica': CorrenteReflexa(),
    'tornado_fogo': TornadoResidual(),
    'bomba_fogo': BombaNaEsquiva(),
    'cobra_agua': SaltoAquatico(),
    'urso_planta': BradoReflexo(),
    'grilo_eletrico': ReflexoEletrico(),
    'roda_fogo': ImpetoArdente(),
    'slime_planta': PeconhaReflexiva(),
    'ourico_eletrico': RetaliacaoEletrica(),
    'pinguim_agua': RastroCongelante(),
    'ave_neutro': PenaDeVoo(),
    'peixe_neutro': EscamasGuardadas(),
    'caranguejo_fogo': FumacaResidual(),
    'cogumelo_planta': EsporosLatentes(),
    'cao_neutro': EcoDoLatido(),
    'leao_eletrico': PontaDaLanca(),
    'gato_neutro': SeteVidas(),
    'toco_planta': RaizProfunda(),
    'tubarao_agua': FaroDeSangue(),
    'sereia_agua': Camuflagem(),
    'olho_eletrico': Piscadela(),
  };

  static ItemEfeito? de(String creatureId) => porCriatura[creatureId];
}

/// Marca [item] como visto no compêndio quando o jogador está na mesma sala
/// que [quem]. Pela sala, e não pela criação: o andar inteiro nasce de uma
/// vez, e os pedestais das salas ainda não andadas contariam como vistos.
/// Devolve true quando registrou — quem chama para de perguntar.
bool registrarSeVisto(PositionComponent quem, ItemEfeito item) {
  final jogo = quem.findGame();
  if (jogo is! CreaturesRogueGame) return false;
  final sala = jogo.player.currentRoom;
  if (sala == null || !sala.containsPoint(quem.absolutePosition)) return false;
  CreatureProgress.instance.registrarItemVisto(item.id);
  return true;
}

/// Coletável do pedestal que entrega um [ItemEfeito]. Não pega duas vezes o
/// mesmo item: um segundo `Revezamento` na lista dispararia o gancho duas
/// vezes por troca, dobrando o bônus sem o balanceamento ter dito isso.
class ItemEfeitoPickup extends Collectible {
  final ItemEfeito item;

  ItemEfeitoPickup({required super.position, required this.item})
    : super(
        spritePath: item.spritePath,
        cor1: item.cor1,
        cor2: item.cor2,
      );

  @override
  String? nomeExibido(BuildContext context) => item.nome(context);

  bool _visto = false;

  @override
  void update(double dt) {
    super.update(dt);
    if (!_visto) _visto = registrarSeVisto(this, item);
  }

  @override
  bool onCollect(Player player) {
    if (player.itens.any((i) => i.id == item.id)) return false;
    player.ganharItem(item);
    player.parent?.add(
      TextEffect(
        // Descrição, não nome: o nome já está escrito acima do sprite no chão
        // (ver `Collectible.nomeExibido`), então repeti-lo na coleta não
        // informa nada. O que o jogador ainda não sabe é o que o item FAZ.
        text: item.descricao(player.game.buildContext!),
        position: player.position.clone() + Vector2(0, -player.size.y / 2 - 4),
        color: Palette.amarelo,
      ),
    );
    return true;
  }
}

// ===========================================================================
// Lote inspirado em The Binding of Isaac. Todos funcionam com qualquer
// criatura e qualquer grupo: nenhum depende do tipo de ataque.
// ===========================================================================

/// Levar dano faz cair moedas (Piggy Bank). Só quando a vida cai de verdade:
/// golpe evadido, anulado ou comido pelo escudo não paga nada.
class Cofrinho extends ItemEfeito {
  const Cofrinho();

  static const int moedas = 2;

  @override
  String get id => 'cofrinho';
  @override
  String get spritePath => 'items/pigBank.png';
  @override
  Color get cor1 => Palette.rosa;
  @override
  Color get cor2 => Palette.mauve;
  @override
  String nome(BuildContext context) => context.l10n.item_cofrinho;
  @override
  String descricao(BuildContext context) => context.l10n.item_cofrinhoDesc;

  @override
  void aoPerderVida(Player player, double dano) {
    final rng = Random();
    for (var i = 0; i < moedas; i++) {
      player.parent?.add(
        CoinPickup(
          position: player.position +
              Vector2(rng.nextDouble() * 24 - 12, rng.nextDouble() * 24 - 12),
        ),
      );
    }
  }
}

/// Loja pela metade do preço (Steam Sale), arredondando pra cima.
class Cupom extends ItemEfeito {
  const Cupom();

  @override
  String get id => 'cupom';
  @override
  String get spritePath => 'items/cupon.png';
  @override
  Color get cor1 => Palette.verde;
  @override
  Color get cor2 => Palette.verdeEsc;
  @override
  String nome(BuildContext context) => context.l10n.item_cupom;
  @override
  String descricao(BuildContext context) => context.l10n.item_cupomDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    player.fatorPrecoLoja *= 0.5;
  }
}

/// O balcão da loja repõe outro produto depois de cada compra (Restock).
class Reposicao extends ItemEfeito {
  const Reposicao();

  @override
  String get id => 'reposicao';
  @override
  String get spritePath => 'items/restock.png';
  @override
  Color get cor1 => Palette.marrom;
  @override
  Color get cor2 => Palette.burgundy;
  @override
  String nome(BuildContext context) => context.l10n.item_reposicao;
  @override
  String descricao(BuildContext context) => context.l10n.item_reposicaoDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    player.lojaRepoe = true;
  }
}

/// Chance de abater na hora um inimigo comum (Euthanasia). Boss fica de fora:
/// um golpe de sorte encerrando a luta do andar tiraria o sentido dela.
class Agulha extends ItemEfeito {
  const Agulha();

  static const double chance = 0.03;

  @override
  String get id => 'agulha';
  @override
  String get spritePath => 'items/seringa.png';
  @override
  Color get cor1 => Palette.cinza;
  @override
  Color get cor2 => Palette.indigo;
  @override
  String nome(BuildContext context) => context.l10n.item_agulha;
  @override
  String descricao(BuildContext context) => context.l10n.item_agulhaDesc;

  @override
  double ajustarGolpe(Player player, Enemy alvo, double dano) {
    if (alvo.ehBoss || Random().nextDouble() >= chance) return dano;
    return max(dano, alvo.health);
  }
}

/// A cada [abates] abates, cura meio coração (Charm of the Vampire). É o único
/// item que cura por abate.
class PresasDeVampiro extends ItemEfeito {
  const PresasDeVampiro();

  static const int abates = 12;

  @override
  String get id => 'presasDeVampiro';
  @override
  String get spritePath => 'items/fangs.png';
  @override
  Color get cor1 => Palette.vermelho;
  @override
  Color get cor2 => Palette.burgundy;
  @override
  String nome(BuildContext context) => context.l10n.item_presasDeVampiro;
  @override
  String descricao(BuildContext context) =>
      context.l10n.item_presasDeVampiroDesc;

  @override
  void aoMatarInimigo(Player player, Enemy inimigo) {
    player.abatesParaVampiro++;
    if (player.abatesParaVampiro < abates) return;
    player.abatesParaVampiro = 0;
    player.heal(1);
  }
}

/// O primeiro golpe recebido em cada sala é anulado (Holy Mantle). Diferente
/// do escudo, que regenera com o tempo: aqui a carga é uma por sala, e volta
/// ao entrar em outra.
class Bencao extends ItemEfeito {
  const Bencao();

  @override
  String get id => 'bencao';
  @override
  String get spritePath => 'items/bible.png';
  @override
  Color get cor1 => Palette.marrom;
  @override
  Color get cor2 => Palette.amarelo;
  @override
  String nome(BuildContext context) => context.l10n.item_bencao;
  @override
  String descricao(BuildContext context) => context.l10n.item_bencaoDesc;

  @override
  bool anulaGolpe(Player player) {
    final sala = player.currentRoom;
    if (sala == null || player.salaDaBencaoGasta == sala) return false;
    player.salaDaBencaoGasta = sala;
    return true;
  }
}

/// Todos os inimigos vivem 20% mais devagar (Stopwatch) — andam, pulam e
/// atacam mais devagar, porque o tempo deles inteiro é escalado (ver
/// `Enemy.update`). Os tiros que eles já soltaram voam na velocidade normal.
class RelogioParado extends ItemEfeito {
  const RelogioParado();

  @override
  String get id => 'relogioParado';
  @override
  String get spritePath => 'items/clock.png';
  @override
  Color get cor1 => Palette.amarelo;
  @override
  Color get cor2 => Palette.azulEsc;
  @override
  String nome(BuildContext context) => context.l10n.item_relogioParado;
  @override
  String descricao(BuildContext context) =>
      context.l10n.item_relogioParadoDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    player.tempoInimigos *= 0.8;
  }
}

/// Levar dano solta [bichos] bichinhos que perseguem o inimigo mais próximo e
/// estouram nele (Infestation). São projéteis guiados, sem tipo.
class Enxame extends ItemEfeito {
  const Enxame();

  static const int bichos = 2;

  @override
  String get id => 'enxame';
  @override
  String get spritePath => 'items/hive.png';
  @override
  Color get cor1 => Palette.laranja;
  @override
  Color get cor2 => Palette.marrom;
  @override
  String nome(BuildContext context) => context.l10n.item_enxame;
  @override
  String descricao(BuildContext context) => context.l10n.item_enxameDesc;

  @override
  void aoPerderVida(Player player, double dano) {
    final rng = Random();
    for (var i = 0; i < bichos; i++) {
      final angulo = rng.nextDouble() * 2 * pi;
      player.parent?.add(
        Projectile(
          owner: player,
          position: player.position.clone(),
          direction: Vector2(cos(angulo), sin(angulo)),
          speed: 70,
          guiamento: 6.0,
          dmg: player.creatureData.stats.ataque * 0.6,
          lifeTime: 3.0,
          radius: 3,
          size: Vector2.all(8),
          sprPath: 'projeteis/bug.png',
          cor1: cor1,
          cor2: cor2,
          tipo: CreatureType.neutro,
          playSfx: false,
        ),
      );
    }
  }
}

/// Seus projéteis curvam rumo ao inimigo mais próximo (Spoon Bender). Curva
/// moderada: corrige a mira de longe, e quase não mexe nos golpes de perto,
/// que somem antes de dar tempo de virar.
class Telecinese extends ItemEfeito {
  const Telecinese();

  @override
  String get id => 'telecinese';
  @override
  String get spritePath => 'items/spoon.png';
  @override
  Color get cor1 => Palette.cinza;
  @override
  Color get cor2 => Palette.indigo;
  @override
  String nome(BuildContext context) => context.l10n.item_telecinese;
  @override
  String descricao(BuildContext context) => context.l10n.item_telecineseDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    if (player.guiamentoTiros < 4.0) player.guiamentoTiros = 4.0;
  }
}

/// Cada golpe recebido aumenta o dano até sair da sala (Bloody Lust) — conta
/// todo golpe que chega, mesmo evadido, anulado ou comido pelo escudo. Os
/// i-frames depois de cada golpe já seguram o ritmo da contagem.
/// Teto em [teto]: sem ele, uma sala de boss longa viraria dano infinito.
/// Oposto da `Pureza`, que premia NÃO apanhar.
class Furia extends ItemEfeito {
  const Furia();

  static const double porGolpe = 0.15;
  static const double teto = 0.60;

  @override
  String get id => 'furia';
  @override
  String get spritePath => 'items/raiva.png';
  @override
  Color get cor1 => Palette.vermelho;
  @override
  Color get cor2 => Palette.burgundy;
  @override
  String nome(BuildContext context) => context.l10n.item_furia;
  @override
  String descricao(BuildContext context) => context.l10n.item_furiaDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    final sala = player.currentRoom;
    if (sala != null && sala != player.salaDaFuria) {
      player.salaDaFuria = sala;
      player.golpesDaFuria = 0;
    }
    Player.danoMultDerivado *=
        1.0 + min(porGolpe * player.golpesDaFuria, teto);
  }

  @override
  void aoTentarTomarDano(Player player, double amount) {
    player.golpesDaFuria++;
    player.parent?.add(
      AuraPulseEffect(
        position: player.position.clone(),
        raio: 14,
        cor1: cor1,
        cor2: cor2,
      ),
    );
  }
}

/// Ao entrar numa sala, ganha um bônus sorteado — dano, velocidade ou
/// cadência — até perder vida (Purity). Um pulso da cor do bônus diz qual
/// está valendo. Sumiu, só volta na próxima sala.
class Pureza extends ItemEfeito {
  const Pureza();

  /// Cor de cada bônus, na ordem do índice `Player.bonusDaPureza`:
  /// 0 = dano, 1 = velocidade, 2 = cadência.
  static const List<Color> bonus = [
    Palette.vermelho,
    Palette.azul,
    Palette.amarelo,
  ];

  static const double intervaloPulso = 1.0;

  @override
  String get id => 'pureza';
  @override
  String get spritePath => 'items/pureza.png';
  @override
  Color get cor1 => Palette.branco;
  @override
  Color get cor2 => Palette.azul;
  @override
  String nome(BuildContext context) => context.l10n.item_pureza;
  @override
  String descricao(BuildContext context) => context.l10n.item_purezaDesc;

  @override
  void aoAtualizar(Player player, double dt) {
    final sala = player.currentRoom;
    if (sala != null && sala != player.salaDaPureza) {
      player.salaDaPureza = sala;
      player.bonusDaPureza = Random().nextInt(bonus.length);
      player.pulsoDaPureza = 0.0;
    }

    switch (player.bonusDaPureza) {
      case 0:
        Player.danoMultDerivado *= 1.25;
      case 1:
        player.velMultDerivado *= 1.2;
      case 2:
        player.cdMultDerivado *= 0.8;
      default:
        return;
    }

    player.pulsoDaPureza -= dt;
    if (player.pulsoDaPureza > 0) return;
    player.pulsoDaPureza = intervaloPulso;
    final cor = bonus[player.bonusDaPureza];
    player.parent?.add(
      AuraPulseEffect(
        position: player.position.clone(),
        raio: 12,
        cor1: cor,
        cor2: cor,
        duracao: 0.4,
      ),
    );
  }

  @override
  void aoPerderVida(Player player, double dano) {
    player.bonusDaPureza = -1;
  }
}

/// Salas de combate nascem com mais inimigos, e cada um pode largar moeda
/// ou meio coração (Contract from Below). Os extras são somados em
/// `RoomComponent._spawnEnemies`, com teto em [extrasMax] pra não lotar as
/// salas pequenas. Sala de boss e ondas do desafio ficam de fora.
class Contrato extends ItemEfeito {
  const Contrato();

  static const int extrasMax = 3;
  static const double chanceMoeda = 0.20;
  static const double chanceCoracao = 0.05;

  @override
  String get id => 'contrato';
  @override
  String get spritePath => 'items/contrato.png';
  @override
  Color get cor1 => Palette.vermelho;
  @override
  Color get cor2 => Palette.preto;
  @override
  String nome(BuildContext context) => context.l10n.item_contrato;
  @override
  String descricao(BuildContext context) => context.l10n.item_contratoDesc;

  @override
  void aoMatarInimigo(Player player, Enemy alvo) {
    if (alvo.ehBoss) return;
    final sorte = Random().nextDouble();
    if (sorte < chanceCoracao) {
      alvo.parent?.add(HeartHalfPickup(position: alvo.position.clone()));
    } else if (sorte < chanceCoracao + chanceMoeda) {
      alvo.parent?.add(CoinPickup(position: alvo.position.clone()));
    }
  }
}

/// O item de cada pedestal de item se alterna entre [opcoes] ofertas a cada
/// `PedestalComponent.intervaloCoroa` segundos; leva o que estiver lá na
/// hora do toque (Glitched Crown). As alternativas são tiradas da pool junto
/// com a oferta principal (ver `PedestalComponent.sortearOferta`), então as
/// recusadas não voltam. Vale do andar SEGUINTE em diante, pelo mesmo motivo
/// do `BauDoTesouro`: os pedestais nascem junto com o andar.
class CoroaInstavel extends ItemEfeito {
  const CoroaInstavel();

  static const int opcoes = 3;

  @override
  String get id => 'coroaInstavel';
  @override
  String get spritePath => 'items/coroa.png';
  @override
  Color get cor1 => Palette.amarelo;
  @override
  Color get cor2 => Palette.laranja;
  @override
  String nome(BuildContext context) => context.l10n.item_coroaInstavel;
  @override
  String descricao(BuildContext context) =>
      context.l10n.item_coroaInstavelDesc;
}

/// Morrer com este item faz a PRÓXIMA run começar com um item sorteado
/// (Eden's Blessing). Não tem gancho: o fim de run grava a marca
/// (`CreaturesRogueGame._handleGameOver`) e o começo da seguinte a gasta
/// (`CreaturesRogueGame.startRun`). Vitória não conta — a herança é consolo.
class Heranca extends ItemEfeito {
  const Heranca();

  @override
  String get id => 'heranca';
  @override
  String get spritePath => 'items/heranca.png';
  @override
  Color get cor1 => Palette.marrom;
  @override
  Color get cor2 => Palette.amarelo;
  @override
  String nome(BuildContext context) => context.l10n.item_heranca;
  @override
  String descricao(BuildContext context) => context.l10n.item_herancaDesc;
}

/// Mais dano de perto, menos de longe (Proptosis). Medido pela distância
/// entre o jogador e o alvo NA HORA do golpe, não pelo voo do projétil: vale
/// igual pra tiro, explosão e golpe corpo a corpo.
class OlhoNoOlho extends ItemEfeito {
  const OlhoNoOlho();

  /// Até aqui, bônus cheio.
  static const double perto = 24.0;

  /// Daqui em diante, penalidade cheia.
  static const double longe = 96.0;

  static const double fatorPerto = 1.4;
  static const double fatorLonge = 0.75;

  @override
  String get id => 'olhoNoOlho';
  @override
  String get spritePath => 'items/olho.png';
  @override
  Color get cor1 => Palette.branco;
  @override
  Color get cor2 => Palette.vermelho;
  @override
  String nome(BuildContext context) => context.l10n.item_olhoNoOlho;
  @override
  String descricao(BuildContext context) => context.l10n.item_olhoNoOlhoDesc;

  @override
  double ajustarGolpe(Player player, Enemy alvo, double dano) {
    final d = player.position.distanceTo(alvo.position);
    final t = ((d - perto) / (longe - perto)).clamp(0.0, 1.0);
    return dano * (fatorPerto + (fatorLonge - fatorPerto) * t);
  }
}
