import 'dart:async';
import 'package:creatures_rogue/l10n/creature_i18n.dart';
import 'package:creatures_rogue/game/components/creatures/ability_user.dart';
import 'package:creatures_rogue/game/components/effects/efeitos_temporarios.dart';
import 'package:creatures_rogue/game/components/effects/text_effect.dart';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/camera.dart';
import 'package:creatures_rogue/game/components/effects/camera_tremor.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
//import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
//import 'package:flutter/painting.dart';
import 'package:flutter/services.dart'
    show LogicalKeyboardKey, KeyDownEvent, HapticFeedback;
import 'package:flame/input.dart';
import 'package:creatures_rogue/game/audio/game_audio.dart';
import 'package:creatures_rogue/game/audio/game_music.dart';
import 'package:creatures_rogue/game/components/core/ui_theme.dart';
import 'package:creatures_rogue/game/components/UI/gameboy_bezel.dart';
import 'package:creatures_rogue/game/audio/sfx.dart';
import 'package:creatures_rogue/game/components/UI/ability_button.dart';
import 'package:creatures_rogue/game/components/UI/ability_button_sprites.dart';
import 'package:creatures_rogue/game/components/UI/ability_icons.dart';
import 'package:creatures_rogue/game/components/UI/pause_button_sprite.dart';
import 'package:creatures_rogue/game/components/effects/companion_recall_effect.dart';
import 'package:creatures_rogue/game/components/effects/companion_revive_effect.dart';
import 'package:creatures_rogue/game/components/UI/consumable_slot_button.dart';
import 'package:creatures_rogue/game/components/UI/pointer_tracker.dart';
import 'package:creatures_rogue/game/components/UI/blind_overlay.dart';
import 'package:creatures_rogue/game/components/UI/boss_health_bar.dart';
import 'package:creatures_rogue/game/components/UI/dynamic_joystick_component.dart';
import 'package:creatures_rogue/game/components/UI/dpad_indicator.dart';
import 'package:creatures_rogue/game/components/UI/hud.dart';
import 'package:creatures_rogue/game/components/enemies/boss_registry.dart';
import 'package:creatures_rogue/game/components/enemies/enemy.dart';
import 'package:creatures_rogue/game/components/UI/minimap_hud.dart';
import 'package:creatures_rogue/game/components/UI/level_transition_overlay.dart';
//import 'package:creatures_rogue/game/components/enemies/enemy.dart';
import 'package:creatures_rogue/game/components/creatures/ability.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/creatures/creature_data.dart';
import 'package:creatures_rogue/game/components/creatures/creature_type.dart';
import 'package:creatures_rogue/game/components/creatures/wild_creature_npc.dart';
import 'package:creatures_rogue/game/components/items/consumable_item.dart';
import 'package:creatures_rogue/game/components/map/dungeon_generator.dart';
import 'package:creatures_rogue/game/components/map/room_component.dart';
import 'package:creatures_rogue/game/components/map/evento.dart';
import 'package:creatures_rogue/game/components/creatures/afinidade.dart';
import 'package:creatures_rogue/game/anuncios.dart';
import 'package:creatures_rogue/game/components/projeteis/projectile.dart';
import 'package:creatures_rogue/game/components/effects/aura_pulse_effect.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/utils/palette_swapper.dart';
import 'package:creatures_rogue/game/game_settings.dart';
import 'package:creatures_rogue/game/components/creatures/creature_progress.dart';
import 'package:creatures_rogue/game/run_save.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';
import 'components/player/player.dart';
import 'package:creatures_rogue/game/components/items/item_efeito.dart';
import 'package:creatures_rogue/game/components/items/power_up_item.dart';

/// Como o jogador aciona as duas habilidades. Os dois caminhos convivem no
/// código; quem escolhe é `CreaturesRogueGame.controlScheme`, ajustado pelo
/// seletor da tela de configurações e persistido por `GameSettings`.
enum ControlScheme {
  /// Dois botões A/B no canto inferior direito. Ver [AbilityButton].
  botoes,

  /// Sem botão de habilidade 2: um toque rápido e parado na metade direita da
  /// tela dispara ela. Arrastar essa mesma metade continua mirando, como
  /// sempre — quem separa os dois é o `onToqueRapido` do
  /// `DynamicJoystickComponent`, que só chama de volta se o dedo saiu em até
  /// 250ms sem passar do `kTouchSlop`.
  gestos;

  /// Nome curto pro seletor.
  String rotulo(BuildContext context) => switch (this) {
    ControlScheme.botoes => context.l10n.settings_controleBotoes,
    ControlScheme.gestos => context.l10n.settings_controleGestos,
  };

  /// Uma linha explicando o esquema, porque nenhum dos dois é óbvio de
  /// adivinhar só pelo nome.
  String descricao(BuildContext context) => switch (this) {
    ControlScheme.botoes => context.l10n.settings_controleBotoesDesc,
    ControlScheme.gestos => context.l10n.settings_controleGestosDesc,
  };
}

class CreaturesRogueGame extends FlameGame
    with HasCollisionDetection, HasKeyboardHandlerComponents {
  // O Mundo onde o mapa, inimigos e jogador existirão
  late final World dungeonWorld;

  // A câmera que vai renderizar o mundo na resolução do Game Boy
  late final CameraComponent gameCamera;

  /// Sacudida da câmera no dano (ver `Player.takeDamage`). Filha da própria
  /// câmera pra nascer e morrer junto com ela.
  late final CameraTremor tremorCamera;

  // `onGameResize` pode disparar antes do `onLoad` terminar (e montar
  // `gameCamera`) — sem essa trava, `_reposicionarVidro` explodiria com
  // LateInitializationError no primeiro resize.
  bool _camaraPronta = false;

  // Joystick de movimento. Não há mais joystick de mira: a mira das
  // habilidades é sempre a última direção de movimento do jogador.
  late final DynamicJoystickComponent moveJoystick;

  /// Analógico direito — direção travada (4 eixos) = habilidade 1. Ver
  /// `Player.aimJoystick`/`Player._direcaoAtaqueTravada`.
  late final DynamicJoystickComponent aimJoystick;

  /// Posição de todos os dedos na tela. Os botões de habilidade consultam isso
  /// pra se ativarem quando um dedo desliza para dentro deles, e não só quando
  /// um toque nasce ali (ver AbilityButton).
  late final PointerTracker pointerTracker;

  late Player player;

  /// Grupo de até três criaturas — a ativa (quem o `Player` está sendo agora)
  /// mais o banco (ver PIVOT_CONTROLE_DIRETO.md §2.3). Slot 0 é sempre a
  /// criatura escolhida na seleção; 1 e 2 ficam vazios (`null`) até a
  /// criatura selvagem da sala da escada preencher (ver [_buildWildCreature]).
  static const int maxCompanions = 3;

  /// Qual slot é a criatura que o `Player` está sendo agora. Os outros dois
  /// estão sempre no banco (`grupo[i]!.noBanco == true`), vazios, ou
  /// curando ainda abaixo do piso de disponibilidade.
  int companionAtivoIndex = 0;

  /// Os slots do grupo — `null` é slot vazio. Sobrevive à troca (o `Player`
  /// muta pra virar outra criatura, não recria componente nenhum). É o que a
  /// Hud usa pra desenhar o retrato de cada slot, e o que
  /// [_trocarParaSlot]/[pocketarSlotAtivo] usam pra saber quem está esperando
  /// no banco. Ver [MembroGrupo] pro que cada campo guarda.
  final List<MembroGrupo?> grupo = List<MembroGrupo?>.filled(
    maxCompanions,
    null,
  );

  /// Sem cura passiva no banco (pedido do usuário) — a vida de um slot só
  /// muda quando ele está ativo levando dano, ou quando `trocarCriatura`
  /// restaura a vida salva ao entrar em campo. Um slot no banco fica
  /// congelado na vida com que saiu até o jogador trocar pra ele de novo.
  final Random _wildRandom = Random();

  /// Disponível = tem dono e ainda tem vida — sem cura passiva, "abaixo de um
  /// piso" não existe mais: ou a criatura está viva (qualquer vida > 0) e
  /// pode entrar, ou já bateu 0 e só volta se algo restaurar a vida dela
  /// (nada faz isso hoje).
  bool slotDisponivel(int slot) {
    final membro = grupo[slot];
    if (membro == null || !membro.noBanco) return false;
    return membro.vida > 0;
  }

  /// Próximo slot vivo da lista, na ordem 0/1/2 (pulando a ativa) — troca
  /// automática ao desmaiar (ver [pocketarSlotAtivo]) usa o primeiro que
  /// achar, não o "mais saudável" ou qualquer outro critério.
  int? _primeiroSlotDisponivel() {
    for (int i = 0; i < maxCompanions; i++) {
      if (i != companionAtivoIndex && slotDisponivel(i)) return i;
    }
    return null;
  }

  /// Toque num retrato do banco (ver [onTapCompanionSlot]): a ativa atual
  /// entra no banco com a vida que tinha NA HORA, e [slot] assume — sem
  /// recriar componente nenhum, `Player.trocarCriatura` muta a instância que
  /// já existe.
  void _trocarParaSlot(int slot) {
    final destino = grupo[slot];
    if (destino == null) return;
    // Trocar no meio de um mergulho (ver `Player.submergir`) entregaria o
    // estado de enterrado — invulnerabilidade inclusa — pra uma criatura que
    // não tem a habilidade, e a explosão de emersão sairia com o dano
    // guardado da anterior. Só a troca por morte é que precisa passar de
    // qualquer jeito, e ela não pode acontecer aqui: enterrado não apanha.
    if (player.submerso) return;

    grupo[companionAtivoIndex] = MembroGrupo(
      criatura: player.creatureData,
      vida: player.currentHealth,
      xp: player.xp,
      evoluida: player.evoluida,
    );

    destino.noBanco = false;
    companionAtivoIndex = slot;

    GameAudio.instance.play(Sfx.liberar);
    player.trocarCriatura(
      destino.criatura,
      vidaSalva: destino.vida,
      xpSalvo: destino.xp,
      evoluidaSalva: destino.evoluida,
    );
    // A criatura que entra não pode apanhar no mesmo instante da troca: sem
    // esta janela, trocar pra escapar de um golpe já no ar não salvava nada.
    player.grantInvulnerability(invencivelAoTrocar);
    dungeonWorld.add(CompanionReviveEffect(position: player.position.clone()));
  }

  /// Segundos de invencibilidade ao trocar de criatura manualmente.
  static const double invencivelAoTrocar = 0.3;

  /// Toque em qualquer retrato do grupo — ver `Hud`/`CompanionPortraitIndicator`.
  /// Tocar o retrato já ativo não faz nada (sem postura pra ciclar). Tocar um
  /// slot vazio, ou uma criatura já derrotada (vida 0, sem cura passiva pra
  /// trazer de volta), também não.
  /// Itens com gatilho que AINDA podem aparecer nesta run.
  ///
  /// Sai da pool quando um pedestal OFERECE o item, não quando o jogador o
  /// pega: um item deixado pra trás na sala já foi a chance dele. Consumíveis
  /// e power-ups de stat não passam por aqui de propósito — eles repetem à
  /// vontade, porque empilhar +dano de novo é um upgrade válido, enquanto ter
  /// dois Estilhaço dispararia o mesmo gancho duas vezes.
  final List<ItemEfeito> poolItens = [];

  /// Criaturas que ainda podem se aposentar nesta run. Sai da lista quando uma
  /// se aposenta — a mesma criatura não entrega a passiva duas vezes.
  ///
  /// Semeada das chaves de [PassivasAposentadoria.porCriatura], que é a única
  /// fonte de "quem tem passiva": criatura sem passiva mapeada nunca entra.
  final List<String> poolAposentadoria = [];

  /// Tira um item da pool e devolve, ou `null` se a run já viu todos — nesse
  /// caso o pedestal cai de volta em consumível/power-up. Usado por quem
  /// ENTREGA o item na hora (pedestal): a oferta e a retirada são o mesmo ato.
  ItemEfeito? sortearItemEfeito() {
    if (poolItens.isEmpty) return null;
    return poolItens.removeAt(_poolRandom.nextInt(poolItens.length));
  }

  /// Escolhe um item da pool SEM tirar — pra quem expõe uma oferta que pode
  /// não se concretizar (a loja: o jogador pode não ter moeda). Quem espia
  /// precisa chamar [consumirItemEfeito] na hora que a oferta virar entrega.
  ItemEfeito? espiarItemEfeito() {
    if (poolItens.isEmpty) return null;
    return poolItens[_poolRandom.nextInt(poolItens.length)];
  }

  /// Tira [item] da pool. Devolve false se ele já não estava lá — o que
  /// significa que outra fonte (um pedestal) entregou o mesmo item enquanto a
  /// loja ainda o exibia. Nesse caso a venda deve ser RECUSADA: dois do mesmo
  /// item na lista disparariam o gancho duas vezes por evento.
  bool consumirItemEfeito(ItemEfeito item) => poolItens.remove(item);

  final Random _poolRandom = Random();

  /// Só a troca MANUAL respeita o cooldown. A troca forçada por desmaio
  /// (`pocketarSlotAtivo`) ignora: ali não há escolha, e travá-la deixaria o
  /// jogador sem criatura em campo.
  static const double trocaCooldownPadrao = 3.0;
  double trocaCooldown = 0.0;

  /// Recarga cheia da troca agora: a padrão, ou metade com a Diversidade
  /// (ver `Afinidade`).
  double get trocaCooldownMax =>
      afinidade.diversidade
          ? trocaCooldownPadrao * Afinidade.fatorTrocaDiversidade
          : trocaCooldownPadrao;

  /// Recarga com que a última troca começou — a fração da Hud mede contra
  /// ela, e não contra o [trocaCooldownMax] de agora, que muda se o grupo
  /// mudar no meio da recarga.
  double _trocaCooldownInicial = trocaCooldownPadrao;

  /// 0 = pronto pra trocar, 1 = acabou de trocar. Pra indicador da Hud.
  double get trocaCooldownFraction =>
      (trocaCooldown / _trocaCooldownInicial).clamp(0.0, 1.0);

  /// Afinidade elemental do grupo inteiro (ver `Afinidade`).
  Afinidade get afinidade =>
      Afinidade.de(grupo.nonNulls.map((m) => m.criatura.tipo));

  /// Vai pra próxima criatura VIVA da lista, em laço. Usada pelo botão de
  /// troca e pelo toque duplo — o toque num retrato específico continua sendo
  /// [onTapCompanionSlot].
  ///
  /// `slotDisponivel` já exclui a criatura ativa (ela não está "no bolso"),
  /// então o laço nunca escolhe quem já está em campo.
  void trocarParaProximaCriatura() {
    if (!_runStarted) return;
    if (trocaCooldown > 0) return;

    for (int i = 1; i < maxCompanions; i++) {
      final slot = (companionAtivoIndex + i) % maxCompanions;
      if (slotDisponivel(slot)) {
        trocaCooldown = _trocaCooldownInicial = trocaCooldownMax;
        _trocarParaSlot(slot);
        return;
      }
    }
  }

  void onTapCompanionSlot(int slot) {
    if (slot == companionAtivoIndex) return;
    if (trocaCooldown > 0) return;
    if (slotDisponivel(slot)) {
      trocaCooldown = _trocaCooldownInicial = trocaCooldownMax;
      _trocarParaSlot(slot);
    }
  }

  /// A ativa bateu 0 de vida em combate (chamado por `Player.takeDamage`):
  /// vai pro banco com vida 0 e o jogo troca sozinho pro primeiro slot
  /// disponível. Sem ninguém disponível, é Game Over — mesmo grupo esgotado
  /// que o modelo antigo tratava como "a criatura morreu".
  /// A criatura ativa encheu a SEGUNDA barra de XP: ela deixa o grupo de vez e
  /// o jogador fica com a passiva dela (ver [PassivasAposentadoria]).
  ///
  /// Abre a cerimônia () e para aí — ver
  /// [dismissAposentadoria] pra o que acontece quando ela fecha.
  void aposentarSlotAtivo() {
    final passiva = PassivasAposentadoria.de(player.creatureData.id);
    // Sem passiva mapeada não há aposentadoria — `Player.ganharXp` já nem
    // acumula nesse caso, então isto é rede de segurança contra um mapa
    // editado no meio da run.
    if (passiva == null) {
      return;
    }

    // Só abre a cerimônia. Nada de estado muda aqui: entregar o prêmio e
    // tirar a criatura do grupo é papel de `dismissAposentadoria`, no toque de
    // continuar, pra que o texto do prêmio e a eventual tela de fim venham
    // DEPOIS da animação.
    aposentadoriaCriatura = player.creatureData;
    aposentadoriaPassiva = passiva;
    pauseEngine();
    overlays.add('Retirement');
  }

  /// A ativa bateu 0 de vida: SAI do grupo, não fica "estacionada" com vida 0
  /// no banco — o slot fica livre de novo, do mesmo jeito que antes de
  /// alguém entrar nele (o item MAPA ou a sala da escada podem preencher com
  /// outra criatura). Derrotada é derrotada; nada neste jogo revive.
  ///
  /// [porMorte] separa quem zerou a vida de quem foi APOSENTADO
  /// (`aposentarSlotAtivo`), porque na ponta em que o grupo acaba os dois
  /// terminam aqui e a cena precisa ser diferente: quem morre é lançado no ar
  /// (ver `Player.iniciarMorte`), quem se aposenta continua sendo recolhido.
  void pocketarSlotAtivo({bool porMorte = true}) {
    grupo[companionAtivoIndex] = null;

    final proximo = _primeiroSlotDisponivel();

    if (proximo == null && porMorte) {
      // Última criatura caída: sem cerimônia de recolher, que leria como
      // "voltou pro grupo" justo quando não há mais grupo. `Sfx.die` estava
      // declarado e com o .wav no disco desde sempre, sem nenhum tocador.
      GameAudio.instance.play(Sfx.die);
      derrotadoPor = player.ultimaOrigemDeDano;
      derrotadoPorArmadilha = player.ultimoDanoPorArmadilha;
      _handleGameOver(comAnimacaoDeMorte: true);
      return;
    }

    GameAudio.instance.play(Sfx.retorno);
    dungeonWorld.add(
      CompanionRecallEffect(
        position: player.position.clone(),
        trainerPosition: () => player.position,
      ),
    );

    if (proximo == null) {
      _handleGameOver();
      return;
    }

    final membro = grupo[proximo]!;
    membro.noBanco = false;
    companionAtivoIndex = proximo;
    player.trocarCriatura(
      membro.criatura,
      vidaSalva: membro.vida,
      xpSalvo: membro.xp,
      evoluidaSalva: membro.evoluida,
    );
    dungeonWorld.add(CompanionReviveEffect(position: player.position.clone()));
  }

  /// Ids de toda criatura já OFERECIDA na sala da escada nesta run, escolhida
  /// ou não. A oferta seguinte não repete nenhuma: quem recusou uma criatura
  /// (ou pulou a sala) vê outras da próxima vez. Só quando não sobra nenhuma
  /// inédita é que as já vistas voltam a valer.
  final Set<String> criaturasOferecidas = {};

  /// Distância de cada criatura da oferta até o centro dela.
  static const double _afastamentoOferta = 24.0;

  /// Oferta de criaturas selvagens da sala da escada (andares pares, ver
  /// PIVOT_CONTROLE_DIRETO.md §5) — passado como `wildCreatureBuilder` pra
  /// `RoomComponent`, mesmo padrão que `bossBuilder`/`isBossFloor` já usa.
  ///
  /// DUAS criaturas, lado a lado, e o jogador leva só uma: recrutar uma faz a
  /// outra sumir (ver `WildCreatureNpc.irmas`) — mesma escolha excludente da
  /// sala de tesouro. Uma só quando não sobra outra candidata; nenhuma sem
  /// slot livre no grupo.
  List<WildCreatureNpc> _buildWildCreatures(Vector2 centro) {
    final slotVazio = grupo.indexWhere((m) => m == null);
    if (slotVazio == -1) return const [];

    final possiveis = CreatureRegistry.all
        .where(
          (c) =>
              !grupo.any((m) => m?.criatura.id == c.id) &&
              c.evoluir != null &&
              // Neutros só existem na dungeon final (ver `EnemySpawner`), e
              // recrutá-los na escada furaria essa regra.
              c.tipo != CreatureType.neutro,
        )
        .toList();
    final ineditas = possiveis
        .where((c) => !criaturasOferecidas.contains(c.id))
        .toList();
    final candidatas = ineditas.isEmpty ? possiveis : ineditas;
    candidatas.shuffle(_wildRandom);
    final escolhidas = candidatas.take(2).toList();
    criaturasOferecidas.addAll(escolhidas.map((c) => c.id));

    final npcs = [
      for (var i = 0; i < escolhidas.length; i++)
        WildCreatureNpc(
          // Com duas, uma de cada lado do centro; sozinha, no centro.
          position: escolhidas.length == 1
              ? centro.clone()
              : centro +
                    Vector2(
                      i == 0 ? -_afastamentoOferta : _afastamentoOferta,
                      0,
                    ),
          creatureData: escolhidas[i],
        ),
    ];
    for (final npc in npcs) {
      npc.irmas.addAll(npcs.where((outra) => outra != npc));
    }
    return npcs;
  }

  /// Evento cuja janela está aberta (ver `EventoOverlay`).
  EventoNpc? eventoAberto;

  /// Encostou num evento: pausa e abre a janela dele. Mesma trava da ficha
  /// da criatura selvagem contra os dois hitboxes do jogador.
  void abrirEvento(EventoNpc evento) {
    if (overlays.isActive('Evento')) return;
    eventoAberto = evento;
    pauseEngine();
    overlays.add('Evento');
  }

  void fecharEvento() {
    overlays.remove('Evento');
    final evento = eventoAberto;
    eventoAberto = null;
    resumeEngine();
    evento?.fechado();
  }

  /// Eventos que ainda não saíram nesta run. Esvaziou, recomeça.
  final List<EventoTipo> _eventosRestantes = [];

  /// Sorteia o evento de uma sala de evento, sem repetir na run. A
  /// `criaturaFerida` sorteia também a criatura; sem nenhuma disponível,
  /// o evento vira `termas`.
  ({EventoTipo tipo, CreatureData? criatura}) sortearEvento() {
    if (_eventosRestantes.isEmpty) _eventosRestantes.addAll(EventoTipo.values);
    final tipo = _eventosRestantes.removeAt(
      _poolRandom.nextInt(_eventosRestantes.length),
    );
    if (tipo != EventoTipo.criaturaFerida) return (tipo: tipo, criatura: null);
    final criatura = _sortearCriaturaFerida();
    if (criatura == null) return (tipo: EventoTipo.termas, criatura: null);
    return (tipo: tipo, criatura: criatura);
  }

  /// Criatura cuja passiva de aposentadoria ainda não saiu, e que não está
  /// no grupo — a dela o jogador ainda pode ganhar aposentando.
  CreatureData? _sortearCriaturaFerida() {
    final candidatas = CreatureRegistry.all
        .where(
          (c) =>
              poolAposentadoria.contains(c.id) &&
              !grupo.any((m) => m?.criatura.id == c.id),
        )
        .toList();
    if (candidatas.isEmpty) return null;
    return candidatas[_poolRandom.nextInt(candidatas.length)];
  }

  /// Entrega a passiva de aposentadoria de [criatura] sem aposentar ninguém
  /// (a `criaturaFerida`). Devolve a passiva, ou null se não houver.
  ItemEfeito? entregarPassivaDe(CreatureData criatura) {
    final passiva = PassivasAposentadoria.de(criatura.id);
    if (passiva == null) return null;
    if (!player.itens.any((i) => i.id == passiva.id)) {
      player.ganharItem(passiva);
    }
    poolAposentadoria.remove(criatura.id);
    return passiva;
  }

  /// Vida cheia pra todo o grupo, banco incluído — inclusive quem desmaiou.
  /// Respeita o `Jejum` como toda cura: com ele, ninguém se recupera.
  void curarGrupoInteiro() {
    if (player.curaBloqueada) return;
    player.heal(player.maxHealth.ceil());
    for (final membro in grupo) {
      if (membro == null || !membro.noBanco) continue;
      membro.vida = membro.criatura.stats.maxHp;
    }
  }

  /// Criatura selvagem cuja ficha está aberta (ver `WildCreatureInfoOverlay`).
  WildCreatureNpc? npcEmAnalise;

  /// Encostou numa criatura selvagem: pausa e abre a ficha dela. Ignora se a
  /// ficha já está aberta — os dois hitboxes do jogador chegam a disparar o
  /// toque no mesmo quadro.
  void abrirInfoCriaturaSelvagem(WildCreatureNpc npc) {
    if (overlays.isActive('WildCreatureInfo')) return;
    npcEmAnalise = npc;
    pauseEngine();
    overlays.add('WildCreatureInfo');
  }

  /// Fecha a ficha. [escolher] recruta a criatura (e some com as irmãs da
  /// oferta); sem ele, ela fica onde está.
  void fecharInfoCriaturaSelvagem({required bool escolher}) {
    overlays.remove('WildCreatureInfo');
    final npc = npcEmAnalise;
    npcEmAnalise = null;
    resumeEngine();
    if (npc == null) return;
    if (escolher) {
      npc.recrutar();
    } else {
      npc.recusada();
    }
  }

  /// Chamado por `WildCreatureNpc` quando o jogador escolhe a criatura. Entra no
  /// banco com vida cheia — o jogador troca pra ela quando quiser, pelo
  /// retrato. Devolve `false` só em caso de corrida rara (grupo já se
  /// preencheu entre a sala nascer e o toque acontecer).
  bool recrutarCriaturaSelvagem(CreatureData creature) {
    final slotVazio = grupo.indexWhere((m) => m == null);
    if (slotVazio == -1) return false;

    grupo[slotVazio] = MembroGrupo(
      criatura: creature,
      vida: creature.stats.maxHp,
    );
    _registrarCriaturaUsada(creature);
    return true;
  }

  bool _runStarted = false;

  /// Trava de reentrada do Game Over — zerada em `startRun`, que é o único
  /// caminho de volta pro jogo.
  bool _gameOverEmCurso = false;
  Vector2 currentRoomIndex = Vector2.zero();

  final VoidCallback? onGameOver;

  ControlScheme _controlScheme;

  /// Esquema de controle montado agora. Atribuir troca os componentes de
  /// controle na hora — dá pra alternar nas configurações e ver o efeito na
  /// run seguinte sem reiniciar o app. Gravar em disco é papel de
  /// `GameSettings`, não deste setter (que é síncrono).
  ControlScheme get controlScheme => _controlScheme;

  set controlScheme(ControlScheme scheme) {
    if (scheme == _controlScheme) return;
    _controlScheme = scheme;
    // Antes do onLoad não há o que remontar: o próprio onLoad monta.
    if (isLoaded) _setupAbilityControls();
  }

  /// Overlay pra reabrir quando o jogador sai de 'Settings' — a tela é
  /// compartilhada entre o menu principal e o menu de pausa (ver
  /// [PauseMenuOverlay] e [MainMenuOverlay]), então o "VOLTAR" precisa saber
  /// pra qual dos dois voltar. Quem abre 'Settings' escreve aqui antes.
  String settingsReturnOverlay = 'MainMenu';

  int currentLevel = 1;

  /// Inimigos derrotados nesta run, pro resumo de Game Over/vitória. Contado
  /// em `Enemy.death`, que já tem guarda contra morrer duas vezes.
  int abatesDaRun = 0;

  /// Bosses derrotados nesta run — contado em `Enemy.death`, pro XP de
  /// progressão.
  int bossesDaRun = 0;

  /// XP de progressão de ANTES desta run e o que ela rendeu, gravados no
  /// instante em que a run acaba (ver [_premiarProgressao]). A barra do
  /// resumo anima de um pro outro.
  int xpProgressaoAntes = 0;
  int xpProgressaoGanho = 0;

  /// Quem derrubou a ÚLTIMA criatura do grupo — ver [pocketarSlotAtivo].
  /// Nulo quando a run acabou sem morte (aposentando a última) ou quando o
  /// golpe não tinha origem conhecida; o resumo então omite a linha.
  CreatureData? derrotadoPor;
  bool derrotadoPorArmadilha = false;
  int numFloors = 5;
  int currentFloor = 1;

  /// Segundos de jogo desta run. Cresce no [update], que nao roda com o motor
  /// pausado — logo tempo de menu, de cerimonia e de tela de boss nao conta.
  double tempoDeRun = 0.0;

  /// MM:SS, pro menu de pausa e pra tela de vitoria. Minutos nao estouram em
  /// 60: uma run de 75 minutos mostra 75:00, nao 15:00.
  String get tempoDeRunFormatado => formatarTempo(tempoDeRun);

  /// `mm:ss` — também usado pelo menu pra mostrar o tempo da run salva.
  static String formatarTempo(double segundos) {
    final total = segundos.floor();
    final mm = (total ~/ 60).toString().padLeft(2, '0');
    final ss = (total % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  /// Criatura ativa da run salva, na forma em que foi salva — pro menu
  /// mostrar quem vai voltar ao CONTINUAR. Nula sem save.
  CreatureData? criaturaDaRunSalva() {
    final dados = RunSave.instance.dados;
    if (dados == null) return null;
    final grupo = (dados['grupo'] as List).cast<Map<String, dynamic>>();
    final slot = grupo[dados['ativo'] as int];
    final id = slot['id'] as String?;
    if (id == null) return null;
    return _formaSalva(id, slot['evoluida'] as bool);
  }

  /// Ids de toda criatura que passou pelo grupo nesta run, na ordem em que
  /// entraram. Nao e o mesmo que [grupo]: aquele perde a criatura
  /// que morreu ou se aposentou, e a tela de vitoria quer o elenco inteiro.
  final List<String> criaturasUsadas = [];

  void _registrarCriaturaUsada(CreatureData criatura) {
    if (criaturasUsadas.contains(criatura.id)) return;
    criaturasUsadas.add(criatura.id);

    // Único lugar do jogo que sabe "esta criatura é nova nesta run", então é
    // daqui que sai o gancho. Ordem importa no carregamento: `startRun`
    // registra a criatura ANTES de `_aplicarSave` repor `player.itens`, então
    // a lista está vazia aqui e um save carregado não paga o bônus de novo em
    // cima do que já está gravado no `danoMult`.
    for (final item in player.itens) {
      item.aoUsarCriaturaNova(player, criatura);
    }
  }

  /// A dungeon atual e a ultima? Criterio: nao existe pool de boss para a
  /// proxima (ver [BossRegistry.all]). Assim, acrescentar uma pool nova ao
  /// registro estende o jogo sem tocar em mais nada.
  bool get ehUltimaDungeon => currentLevel >= BossRegistry.all.length;

  /// Salas geradas no PRIMEIRO andar de uma dungeon.
  static const int salasNoPrimeiroAndar = 10;

  /// Quantas salas o andar atual tem: [salasNoPrimeiroAndar] no primeiro,
  /// mais uma por andar avançado.
  ///
  /// Não existe reset por dungeon aqui porque não precisa: `currentFloor` já
  /// volta a 1 quando uma dungeon nova começa (ver `_avancarAndar`), então a
  /// contagem reinicia em 10 sozinha. Um reset separado seria uma segunda
  /// fonte de verdade pra mesma coisa.
  int get salasDoAndar => salasNoPrimeiroAndar + (currentFloor - 1);

  /// De quantos em quantos andares aparece um boss. 5 combina com os 5 temas
  /// de `DungeonTheme.levelThemes` (um por andar do ciclo). **Baixe pra 2
  /// enquanto estiver ajustando um boss** — senão cada teste custa uma run
  /// inteira.
  static const int andaresPorBoss = 5;

  /// Boss da dungeon ATUAL — resorteado toda vez que uma dungeon nova começa
  /// (ver `nextLevel`), não só uma vez no início da run. Revelado com
  /// antecedência (`BossRevealOverlay`) assim que o andar 1 da dungeon nova
  /// carrega, pra dar tempo de saber o que espera no andar final.
  BossOption? runBoss;

  /// Criatura antes/depois da evolução em andamento (ver PIVOT_EVOLUCAO) —
  /// só usado pra `EvolutionOverlay` desenhar as duas formas. `null` quando
  /// não há tela de evolução aberta.
  CreatureData? evolucaoBase;
  CreatureData? evolucaoNova;

  /// Criatura e prêmio da aposentadoria em andamento — só pra
  /// `RetirementOverlay` desenhar. `null` quando não há cerimônia aberta.
  CreatureData? aposentadoriaCriatura;
  ItemEfeito? aposentadoriaPassiva;

  /// Chamado por `Player._evoluir()` assim que a troca de dados já
  /// aconteceu (o jogador já É a forma evoluída por baixo) — esta tela é só
  /// a cerimônia visual por cima, pausando o jogo até o toque de continuar.
  void mostrarEvolucao(CreatureData base, CreatureData nova) {
    evolucaoBase = base;
    evolucaoNova = nova;
    pauseEngine();
    overlays.add('Evolution');
  }

  /// Toque de continuar da `RetirementOverlay`. É AQUI que o estado muda, não
  /// na abertura da cerimônia: o prêmio é entregue, a criatura sai do grupo e,
  /// se ela era a última viva, o Game Over dispara — tudo depois da animação,
  /// como a cena pede.
  void dismissAposentadoria() {
    final criatura = aposentadoriaCriatura;
    final passiva = aposentadoriaPassiva;
    aposentadoriaCriatura = null;
    aposentadoriaPassiva = null;
    overlays.remove('Retirement');
    resumeEngine();

    if (criatura == null || passiva == null) {
      return;
    }

    // Duplicata não empilha, mas a criatura sai do grupo de qualquer jeito: a
    // barra encheu, a despedida acontece. Só não há prêmio novo.
    if (!player.itens.any((i) => i.id == passiva.id)) {
      player.ganharItem(passiva);
    }
    poolAposentadoria.remove(criatura.id);

    final contexto = buildContext;
    if (contexto != null) {
      player.parent?.add(
        TextEffect(
          text: contexto.l10n.effect_aposentou(
            creatureName(contexto, criatura.id).toUpperCase(),
            passiva.nome(contexto),
          ),
          position: player.position.clone() + Vector2(0, -14),
          color: Palette.amarelo,
          duration: 2.5,
        ),
      );
    }

    // Libera o slot, troca pra próxima viva e chama Game Over se não houver
    // nenhuma — comportamento aceito pra aposentar a última criatura.
    // `porMorte: false`: aposentar a última encerra a run, mas não é morte, e
    // a animação de morte não deve tocar.
    pocketarSlotAtivo(porMorte: false);
  }

  /// Chamado pelo botão "CONTINUAR" da `EvolutionOverlay`.
  void dismissEvolucao() {
    overlays.remove('Evolution');
    evolucaoBase = null;
    evolucaoNova = null;
    resumeEngine();
  }

  final Random _bossRandom = Random();

  bool get isBossFloor => currentFloor % andaresPorBoss == 0;

  @override
  Color backgroundColor() => GameSettings.instance.controlesNaTela
      ? UiTheme.screenBackground
      // Sem controles na tela a faixa que sobra ao redor da área de jogo não
      // é mais o "plástico" de um aparelho portátil — é só a moldura de uma
      // janela. Preto some, cinza vira borda à toa.
      : Palette.cinza;

  Map loadedRooms = {};

  late Map<String, RoomData> mapData;
  late MinimapHud minimapHud;

  double freezeTmr = 0;
  double freezeTime = 0.5;

  CreaturesRogueGame({
    this.onGameOver,
    ControlScheme controlScheme = ControlScheme.botoes,
  }) : _controlScheme = controlScheme;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    //debugMode = true;

    // 1. Inicializa o Mundo
    dungeonWorld = World();
    add(dungeonWorld); // Adiciona o mundo ao jogo

    pointerTracker = PointerTracker();
    add(pointerTracker);

    // Os três ícones de habilidade ficam em memória antes dos controles: os
    // botões nascem aqui, sem jogador ainda, e escolhem o ícone na hora de
    // desenhar conforme a criatura da run.
    await AbilityIcons.carregar();
    await AbilityButtonSprites.carregar();
    await PauseButtonSprite.carregar();

    _setupJoysticks();
    _setupAbilityControls();

    // Pré-processa a paleta dos sprites que aparecem em pleno combate.
    // Sem isso, o PRIMEIRO tiro / explosão / morte de inimigo gerava uma
    // textura nova em tempo de execução (travadinha na hora do disparo).
    await _preloadCombatSprites();

    // Mesmo tratamento pros efeitos sonoros: `main.dart` já disparou isto
    // sem esperar (só pra começar cedo, antes do GameWidget existir), mas o
    // jogo em si só é dado como carregado depois que os sons também
    // estiverem prontos — `preload()` é "single-flight", então não recarrega
    // nada, só espera terminar.
    await GameAudio.instance.preload();

    // 2. Configura a Câmera (Resolução Fixa: 160 x 144). Não depende do
    // jogador, então já pode ser montada aqui — a run em si só começa
    // quando o jogador escolhe uma criatura no CreatureSelectOverlay.
    gameCamera = CameraComponent.withFixedResolution(
      width: RoomComponent.roomWidth,
      height: RoomComponent.roomHeight,
      world: dungeonWorld,
    );
    gameCamera.viewfinder.position = Vector2(
      RoomComponent.roomWidth / 2,
      RoomComponent.roomHeight / 2,
    );
    // `await`: o `onLoad` do viewport (que ele mesmo dispara ao montar) faz
    // o auto-centralizado padrão do Flame — sem esperar aqui, nosso
    // `_reposicionarVidro` rodava ANTES desse `onLoad` e era sobrescrito por
    // ele assim que a câmera terminasse de montar, e o jogo carregava direto
    // no modo RETRATO já com o vidro errado (só um resize de verdade depois
    // corrigia).
    await add(gameCamera);
    tremorCamera = CameraTremor(gameCamera.viewfinder);
    gameCamera.add(tremorCamera);
    add(GameboyBezel(camera: gameCamera));

    _camaraPronta = true;
    _reflowControles(size);
    // Depois do `_reflowControles`: e ele quem decide o tipo de viewport, e no
    // desktop os slots viram FILHOS do viewport (ver `_setupInventorySlots`).
    _setupInventorySlots();

    pauseEngine();
  }

  /// Começa uma run nova com a criatura escolhida no seletor. Pode ser
  /// chamado mais de uma vez: voltar ao menu e escolher outra criatura
  /// derruba a run anterior (jogador e dungeon) e monta tudo de novo.
  ///
  /// [save] é o atalho pra "CONTINUAR" (ver `continuarSalva`): quando não é
  /// nulo, [creature] já veio pré-resolvida pelo chamador na forma certa
  /// (evoluída ou não — ver `_formaSalva`), então o `Player` já nasce com o
  /// visual correto sem precisar remontar depois. `save` então só
  /// sobrescreve stats/andar/dungeon/grupo por cima, e pula a tela de
  /// "BossReveal" (o boss já foi revelado antes de salvar).
  void startRun(CreatureData creature, {Map<String, dynamic>? save}) {
    // Varredura explícita por tipo além do loop genérico abaixo: encontramos
    // um caso (Game Over → "Menu Principal") em que dois `startRun` corriam
    // em sequência com o motor pausado, e o `Player` da run anterior
    // sobrevivia — o joystick é uma instância única compartilhada por todo
    // `Player`, então dois montados ao mesmo tempo se moviam juntos.
    grupo.fillRange(0, maxCompanions, null);
    companionAtivoIndex = 0;
    tempoDeRun = 0.0;
    abatesDaRun = 0;
    bossesDaRun = 0;
    derrotadoPor = null;
    derrotadoPorArmadilha = false;
    reviveuNestaRun = false;
    criaturasUsadas.clear();
    criaturasOferecidas.clear();
    _eventosRestantes.clear();
    poolItens
      ..clear()
      //  filtra as passivas de aposentadoria: elas moram no mesmo
      // registro (pra  reconstruir o save), mas não podem cair num
      // pedestal.
      ..addAll(
        ItemEfeitoRegistry.todos.where(
          (i) => i.sorteavel && CreatureProgress.instance.itemLiberado(i),
        ),
      );
    poolAposentadoria
      ..clear()
      ..addAll(PassivasAposentadoria.porCriatura.keys);
    trocaCooldown = 0.0;
    dungeonWorld.children.whereType<Player>().toList().forEach(
      (p) => p.removeFromParent(),
    );

    for (final child in dungeonWorld.children.toList()) {
      child.removeFromParent();
    }
    loadedRooms.clear();

    player = Player(
      moveJoystick: moveJoystick,
      aimJoystick: aimJoystick,
      creatureData: creature,
    );
    _runStarted = true;
    _gameOverEmCurso = false;
    player.position = Vector2(
      RoomComponent.roomWidth / 2,
      RoomComponent.centerY,
    );
    dungeonWorld.add(player);

    // Vida 0 no slot ativo de propósito: a vida de quem está em campo mora no
    // `player`, e o slot só recebe a dele quando ela for pro banco.
    grupo[0] = MembroGrupo(criatura: creature, noBanco: false, vida: 0.0);
    _registrarCriaturaUsada(creature);

    if (save != null) {
      _aplicarSave(save);
    } else {
      // Run nova: volta pro primeiro andar e sorteia o boss que espera no
      // andar final desta run.
      currentLevel = 1;
      currentFloor = 1;
      runBoss = BossRegistry.sortear(_bossRandom, currentLevel);
      _receberHeranca();
    }

    // Depois do save ser aplicado / do andar ser zerado acima: `salasDoAndar`
    // lê `currentFloor`, então a ordem importa.
    final generator = DungeonGenerator(
      maxRooms: salasDoAndar,
      // Mesmo `isBossFloor` que decide o `bossBuilder` logo abaixo: a sala
      // final nasce como BOSS no andar de boss e como ESCADA nos outros.
      comBoss: isBossFloor,
    );
    mapData = generator.generate();

    // Percorre todos os dados de salas criados pelo algoritmo
    for (var roomData in mapData.values) {
      // Cria o componente visual e o adiciona ao mundo
      final room = RoomComponent(
        roomData,
        player: player,
        dungeon: currentLevel,
        floor: currentFloor,
        bossBuilder: isBossFloor ? _buildRunBoss : null,
        wildCreatureBuilder: currentFloor % 2 == 0 ? _buildWildCreatures : null,
      );
      loadedRooms['${roomData.x},${roomData.y}'] = room;
      dungeonWorld.add(room);
    }

    currentRoomIndex = Vector2.zero();
    // Antes de escrever na câmera: um tremor em curso venceria esta linha
    // todo quadro e depois restauraria a posição ANTIGA (ver
    // `CameraTremor.parar`).
    tremorCamera.parar();
    gameCamera.viewfinder.position = Vector2(
      RoomComponent.roomWidth / 2,
      RoomComponent.roomHeight / 2,
    );

    // Remove HUD/minimapa de uma run anterior, se houver, antes de recriar.
    gameCamera.viewport.children.whereType<Hud>().toList().forEach(
      (h) => h.removeFromParent(),
    );
    gameCamera.viewport.children.whereType<MinimapHud>().toList().forEach(
      (m) => m.removeFromParent(),
    );
    // Barra de boss de uma run anterior: o boss dela já foi removido junto com
    // o mundo, mas a barra vive na viewport e sobraria órfã.
    gameCamera.viewport.children.whereType<BossHealthBar>().toList().forEach(
      (b) => b.removeFromParent(),
    );
    gameCamera.viewport.children.whereType<BlindOverlay>().toList().forEach(
      (c) => c.removeFromParent(),
    );

    final hud = Hud(
      game: this,
      player: player,
      companionCreatureAt: (slot) => grupo[slot]?.criatura,
      companionPocketFractionAt: (slot) => companionPocketFraction(slot),
      trocaFraction: () => trocaCooldownFraction,
      isCompanionAtivo: (slot) => slot == companionAtivoIndex,
      onTapCompanionSlot: onTapCompanionSlot,
    );
    gameCamera.viewport.add(hud);

    gameCamera.viewport.add(BlindOverlay(player: player, camera: gameCamera));

    minimapHud = MinimapHud(
      mapData: mapData,
      getCurrentLogicalRoom: () {
        return Vector2(
          currentRoomIndex.x + dungeonGridOrigin,
          currentRoomIndex.y + dungeonGridOrigin,
        );
      },
      position: Vector2(RoomComponent.roomWidth - 1, 1),
    );
    gameCamera.viewport.add(minimapHud);

    overlays.remove('CreatureSelect');
    overlays.remove('MainMenu');
    GameMusic.instance.play(GameMusic.run);

    // Boss pendente nesta run: mostra quem espera no andar final antes de
    // liberar o jogo. Motor continua pausado até `dismissBossReveal`. Numa
    // run continuada o boss já foi revelado antes de salvar — não mostra de
    // novo.
    if (save == null && runBoss != null) {
      overlays.add('BossReveal');
    } else {
      overlays.add('Hud');
      resumeEngine();
    }

    unawaited(_salvarAposMontarAndar());
  }

  /// Chamado pelo botão "CONTINUAR" do menu principal. Reconstrói a run a
  /// partir do save (ver `RunSave`) e entra direto no jogo, sem passar pelo
  /// seletor de criaturas.
  /// Fecha a tela de título e abre o menu. O toque (ou tecla) que chega aqui
  /// é o primeiro gesto do jogador — no navegador, é só depois dele que o
  /// áudio é liberado, e o menu pede a música ao abrir.
  void sairDoTitulo() {
    if (!overlays.isActive('Title')) return;
    overlays.remove('Title');
    overlays.add('MainMenu');
  }

  void continuarSalva() {
    final dados = RunSave.instance.dados;
    if (dados == null) return; // botão não deveria nem aparecer sem save

    final grupo = (dados['grupo'] as List).cast<Map<String, dynamic>>();
    final ativoIdx = dados['ativo'] as int;
    final ativoSlot = grupo[ativoIdx];
    final creature = _formaSalva(
      ativoSlot['id'] as String,
      ativoSlot['evoluida'] as bool,
    );

    startRun(creature, save: dados);
  }

  /// Forma (evoluída ou base) da criatura de id [baseId] — usado ao
  /// restaurar um save, que só guarda o id BASE (ver
  /// `CreatureRegistry.baseDe`) mais a flag [evoluida].
  CreatureData _formaSalva(String baseId, bool evoluida) {
    final base = CreatureRegistry.byId(baseId);
    if (!evoluida) return base;
    return base.evoluir?.call() ?? base;
  }

  /// Acha o `BossOption` de id [creatureId] na lista da dungeon [dungeon].
  /// Se as listas de `BossRegistry` mudarem entre um save antigo e a versão
  /// atual do jogo (comum em desenvolvimento) e o id sumir, sorteia um novo
  /// em vez de travar o carregamento.
  BossOption _acharBoss(String creatureId, int dungeon) {
    final lista = BossRegistry.all[(dungeon - 1) % BossRegistry.all.length];
    return lista.firstWhere(
      (b) => b.creatureId == creatureId,
      orElse: () => BossRegistry.sortear(_bossRandom, dungeon),
    );
  }

  /// Aplica por cima do estado recém-montado por `startRun` os dados de um
  /// save (ver `RunSave`/`_serializarRun`). `player.creatureData` já
  /// chegou aqui na forma certa (quem chamou — `continuarSalva` — já
  /// resolveu isso), então só falta stats, andar/dungeon/boss e o resto do
  /// grupo.
  void _aplicarSave(Map<String, dynamic> dados) {
    currentLevel = dados['dungeon'] as int;
    currentFloor = dados['andar'] as int;
    // Save anterior a estes dois campos: cronometro volta do zero e o elenco
    // fica vazio. Nada quebra, so a tela de vitoria mostraria menos.
    tempoDeRun = (dados['tempoDeRun'] as num?)?.toDouble() ?? 0.0;
    abatesDaRun = (dados['abates'] as num?)?.toInt() ?? 0;
    reviveuNestaRun = dados['reviveu'] as bool? ?? false;
    bossesDaRun = (dados['bosses'] as num?)?.toInt() ?? 0;
    // Save anterior a este campo: sem histórico, qualquer criatura pode vir.
    criaturasOferecidas
      ..clear()
      ..addAll(
        ((dados['criaturasOferecidas'] as List?) ?? const []).cast<String>(),
      );
    criaturasUsadas
      ..clear()
      ..addAll(
        ((dados['criaturasUsadas'] as List?) ?? const []).cast<String>(),
      );

    final bossId = dados['bossId'] as String?;
    runBoss = bossId == null ? null : _acharBoss(bossId, currentLevel);

    companionAtivoIndex = dados['ativo'] as int;

    final grupoSalvo = (dados['grupo'] as List).cast<Map<String, dynamic>>();
    for (int i = 0; i < maxCompanions; i++) {
      final slot = grupoSalvo[i];
      final id = slot['id'] as String?;
      final evoluida = slot['evoluida'] as bool;
      grupo[i] = id == null
          ? null
          : MembroGrupo(
              criatura: _formaSalva(id, evoluida),
              noBanco: slot['pocketed'] as bool,
              vida: (slot['vida'] as num).toDouble(),
              xp: (slot['xp'] as num).toDouble(),
              evoluida: evoluida,
            );
    }
    // O slot ativo nunca fica marcado como "no banco" — mesma invariante de
    // `startRun`/`_trocarParaSlot`.
    final ativo = grupo[companionAtivoIndex];
    ativo?.noBanco = false;

    player.xp = ativo?.xp ?? 0.0;
    player.evoluida = ativo?.evoluida ?? false;

    final j = dados['jogador'] as Map<String, dynamic>;
    player.maxHealth = (j['maxHealth'] as num).toDouble();
    player.currentHealth = (j['vida'] as num).toDouble();
    player.shieldMax = (j['shieldMax'] as num).toDouble();
    player.shield = (j['shield'] as num).toDouble();
    // Save antigo (anterior ao bônus de item) não tem as chaves: cai em 0, que
    // é o mesmo que "nenhum upgrade de HP/escudo pego" — o total salvo acima
    // continua valendo, só não se recompõe na próxima troca daquela run.
    player.bonusHpItens = (j['bonusHp'] as num?)?.toDouble() ?? 0.0;
    player.bonusShieldItens = (j['bonusShield'] as num?)?.toDouble() ?? 0.0;
    // Save anterior a esta pool: assume que nenhuma criatura se aposentou
    // ainda, que e o unico palpite possivel.
    final aposentadoriaSalva = dados['poolAposentadoria'] as List?;
    poolAposentadoria
      ..clear()
      ..addAll(
        aposentadoriaSalva == null
            ? PassivasAposentadoria.porCriatura.keys
            : aposentadoriaSalva.cast<String>(),
      );

    final poolSalva = dados['poolItens'] as List?;
    poolItens
      ..clear()
      ..addAll(
        poolSalva == null
            // Save anterior à pool: o que a run já ofereceu se perdeu, então
            // o melhor palpite é "tudo menos o que o jogador está carregando".
            //
            // Com o mesmo `.where(sorteavel)` do `startRun`: sem ele, carregar
            // um save antigo enchia a pool também com as passivas de
            // aposentadoria, que moram no mesmo registro só pra reconstruir o
            // save — e aí elas apareciam em pedestal e na loja.
            ? ItemEfeitoRegistry.todos.where(
                (i) => i.sorteavel && CreatureProgress.instance.itemLiberado(i),
              )
            : poolSalva.cast<String>().map(ItemEfeitoRegistry.porId).nonNulls,
      );

    player.itens
      ..clear()
      ..addAll(
        ((j['itens'] as List?) ?? const [])
            .cast<String>()
            .map(ItemEfeitoRegistry.porId)
            .nonNulls,
      );
    poolItens.removeWhere((i) => player.itens.any((p) => p.id == i.id));
    // A run salva pode vir de antes do compêndio: o que ela carrega entra
    // nele agora.
    for (final item in player.itens) {
      unawaited(CreatureProgress.instance.registrarItemColetado(item.id));
    }
    player.velMult = (j['velMult'] as num).toDouble();
    player.cdMult = (j['cdMult'] as num).toDouble();
    Player.danoMult = (j['danoMult'] as num).toDouble();
    // Save anterior aos upgrades de energia: cai no padrão da criatura.
    player.energiaMax =
        (j['energiaMax'] as num?)?.toDouble() ?? energiaMaxPadrao;
    player.energiaRegen =
        (j['energiaRegen'] as num?)?.toDouble() ?? energiaRegenPorSegundo;
    // Idem pro upgrade de regeneração de escudo.
    player.shieldRegenInterval =
        (j['shieldRegenInterval'] as num?)?.toDouble() ??
        Player.shieldRegenIntervalPadrao;
    // Save anterior ao historico de upgrades: a lista fica vazia. Os stats
    // ja estao aplicados (vieram gravados um a um logo acima), so nao ha como
    // saber retroativamente QUAIS upgrades produziram eles.
    player.upgradesPegos
      ..clear()
      ..addAll(
        ((j['upgrades'] as List?) ?? const []).cast<String>().map(
          (n) => PowerUpType.values.byName(n),
        ),
      );
    // Save anterior às cargas de sala: começa zerado. Perder as cargas ao
    // continuar seria injusto, mas o contrário (ganhar) seria explorável, e
    // zero é o lado seguro.
    player.cargasDeSala = (j['cargasDeSala'] as int?) ?? 0;
    // Save anterior ao upgrade de evasão: cai em zero, que é o mesmo que
    // "nunca peguei nenhum".
    player.bonusEvasaoItens = (j['bonusEvasao'] as num?)?.toDouble() ?? 0.0;
    player.critChance = (j['critChance'] as num).toDouble();
    player.critMult = (j['critMult'] as num).toDouble();
    player.bombsAmount = j['bombs'] as int;
    player.coins = j['coins'] as int;
    final slotsSalvos = (j['slots'] as List).cast<String?>();
    for (int i = 0; i < player.slots.length; i++) {
      final nome = slotsSalvos[i];
      player.slots[i] = nome == null
          ? null
          : ConsumableType.values.byName(nome);
    }
  }

  /// Serializa a run atual pro formato que `RunSave` grava — ver
  /// `_aplicarSave` pro caminho inverso.
  Map<String, dynamic> _serializarRun() {
    // O slot ativo só é sincronizado de volta pro array em
    // `_trocarParaSlot` (ver comentário lá) — salvar no meio de uma
    // criatura ativa (o caso comum) pegaria dado velho sem isto.
    final ativo = grupo[companionAtivoIndex] ??= MembroGrupo(
      criatura: player.creatureData,
      noBanco: false,
      vida: 0.0,
    );
    ativo
      ..criatura = player.creatureData
      ..evoluida = player.evoluida
      ..xp = player.xp;

    String? baseId(MembroGrupo? m) {
      if (m == null) return null;
      return m.evoluida
          ? CreatureRegistry.baseDe(m.criatura).id
          : m.criatura.id;
    }

    return {
      'dungeon': currentLevel,
      'andar': currentFloor,
      'poolItens': poolItens.map((i) => i.id).toList(),
      'tempoDeRun': tempoDeRun,
      'abates': abatesDaRun,
      'reviveu': reviveuNestaRun,
      'bosses': bossesDaRun,
      'criaturasUsadas': List<String>.from(criaturasUsadas),
      'criaturasOferecidas': criaturasOferecidas.toList(),
      'poolAposentadoria': List<String>.from(poolAposentadoria),
      'bossId': runBoss?.creatureId,
      'ativo': companionAtivoIndex,
      'grupo': [
        // Chaves e valores de slot vazio iguais aos de antes de `MembroGrupo`
        // existir, pra save antigo e novo serem o mesmo formato.
        for (final m in grupo)
          {
            'id': baseId(m),
            'evoluida': m?.evoluida ?? false,
            'pocketed': m?.noBanco ?? false,
            'vida': m?.vida ?? 0.0,
            'xp': m?.xp ?? 0.0,
          },
      ],
      'jogador': {
        'maxHealth': player.maxHealth,
        'vida': player.currentHealth,
        'shieldMax': player.shieldMax,
        'shield': player.shield,
        'bonusHp': player.bonusHpItens,
        'bonusShield': player.bonusShieldItens,
        'itens': player.itens.map((i) => i.id).toList(),
        'upgrades': player.upgradesPegos.map((u) => u.name).toList(),
        'cargasDeSala': player.cargasDeSala,
        'velMult': player.velMult,
        'cdMult': player.cdMult,
        'danoMult': Player.danoMult,
        'energiaMax': player.energiaMax,
        'energiaRegen': player.energiaRegen,
        'shieldRegenInterval': player.shieldRegenInterval,
        'bonusEvasao': player.bonusEvasaoItens,
        'critChance': player.critChance,
        'critMult': player.critMult,
        'bombs': player.bombsAmount,
        'coins': player.coins,
        'slots': player.slots.map((s) => s?.name).toList(),
      },
    };
  }

  /// Chamado a cada andar novo (ver `startRun`/`nextLevel`) — fire-and-forget
  /// de propósito: nada na run trava esperando o disco gravar.
  ///
  /// Derruba os efeitos do JOGADOR antes de tirar a foto, e isso não é
  /// faxina: `_serializarRun` grava `danoMult`, `velMult` e `cdMult`, e
  /// [Couraca]/[Desesperado] somam neles por janelas reafirmadas a cada
  /// quadro. Salvar com uma janela aberta gravava o bônus como se fosse
  /// permanente — e como isso acontece a cada andar, o valor COMPOUNDAVA a
  /// cada transição feita com escudo cheio (ou vazio, no caso do
  /// [Desesperado]).
  ///
  /// `limparEfeitos` roda o `aoTerminar` de cada um (ver o CONTRATO de
  /// `EfeitosTemporarios`), então os valores-base vão pro disco e os itens
  /// rearmam no quadro seguinte se a condição deles ainda valer. O preço é o
  /// [Revezamento] perder o resto da janela dele quando a foto cai no meio
  /// dela — janela de segundos, contra um bônus que ficava pra sempre.
  /// Salva só depois que TODAS as salas do andar terminaram de montar.
  ///
  /// As salas nascem com `add`, mas o `onLoad` delas — onde os pedestais
  /// sorteiam itens da pool e a sala da escada sorteia as criaturas — só roda
  /// no quadro seguinte. Salvando antes, o save guardava a pool e o histórico
  /// de criaturas de ANTES desses sorteios, e continuar a run recriava o andar
  /// oferecendo as mesmas coisas de novo. Com o motor pausado (tela de VS do
  /// boss), a montagem espera ele voltar, e o save junto.
  Future<void> _salvarAposMontarAndar() async {
    await Future.wait([
      for (final sala in loadedRooms.values.whereType<RoomComponent>())
        sala.loaded,
    ]);
    if (!_runStarted || _gameOverEmCurso) return;
    await _salvarProgresso();
  }

  Future<void> _salvarProgresso() {
    player.limparEfeitos(dono: EfeitoDono.jogador);
    return RunSave.instance.salvar(_serializarRun());
  }

  /// Chamado pelo botão "ENTRAR" do `BossRevealOverlay`.
  void dismissBossReveal() {
    overlays.remove('BossReveal');
    overlays.add('Hud');
    resumeEngine();
  }

  /// Constrói o boss da run e pendura a barra de vida na viewport. Passado
  /// como `bossBuilder` pra sala de boss, que decide QUANDO chamar (quando o
  /// jogador entra). Null quando não há boss pendente — a sala então spawna
  /// inimigos comuns.
  Enemy? _buildRunBoss(Vector2 position) {
    final option = runBoss;
    if (option == null) return null;

    final boss = option.builder(position, player);
    boss.ehBoss = true;
    // Aqui, e não no `BossReveal`: o reveal acontece no começo do andar, e o
    // jogador ainda tem a masmorra inteira pela frente. Este método só roda
    // quando ele ABRE a porta da sala do boss.
    GameMusic.instance.play(GameMusic.boss);
    // A barra se auto-remove quando o boss sai do mundo, então é só somar.
    gameCamera.viewport.add(
      BossHealthBar(boss: boss, nome: option.nome(buildContext!)),
    );
    return boss;
  }

  /// ATALHO DE TESTE (F1): joga um boss na frente do jogador sem precisar
  /// chegar no andar final. Sempre o primeiro do registry, pra ser
  /// determinístico durante o ajuste de números.
  void _spawnTestBoss() {
    if (!_runStarted) return;

    final option =
        BossRegistry.all[(currentLevel - 1) % BossRegistry.all.length].first;
    final boss = option.builder(player.position + Vector2(0, -40), player);
    boss.ehBoss = true;
    GameMusic.instance.play(GameMusic.boss);
    dungeonWorld.add(boss);
    gameCamera.viewport.add(
      BossHealthBar(boss: boss, nome: option.nome(buildContext!)),
    );
  }

  /// App foi pra segundo plano (ligação, botão home, troca de app). O Flame
  /// já para o motor sozinho, mas o RETOMA sozinho na volta — e o jogador
  /// cairia no meio do combate sem saber onde estava. Com a run rolando,
  /// abre o menu de pausa: aí a volta espera um toque.
  ///
  /// Só quando o motor estava rodando: com ele já parado, alguma janela
  /// (evolução, evento, ficha da criatura) está aberta e segura o jogo.
  @override
  void lifecycleStateChange(AppLifecycleState state) {
    final estavaRodando = !paused;
    super.lifecycleStateChange(state);
    final saiu = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (!saiu || !estavaRodando || !_runStarted) return;
    if (!overlays.isActive('Hud') || overlays.isActive('PauseMenu')) return;
    // `pauseEngine` daqui desarma o "retomar na volta" do Flame.
    pauseEngine();
    overlays.add('PauseMenu');
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    // <-- MUDOU AQUI
    // Tela de título: qualquer tecla avança. Tratado aqui, no teclado do
    // jogo, e não com um `Focus` no overlay — tirar o foco do `GameWidget`
    // deixaria os controles da run sem teclado depois.
    if (event is KeyDownEvent && overlays.isActive('Title')) {
      sairDoTitulo();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f1) {
      _spawnTestBoss();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      if (!overlays.isActive('MainMenu') &&
          !overlays.isActive('Title') &&
          !overlays.isActive('WildCreatureInfo')) {
        if (overlays.isActive('PauseMenu')) {
          overlays.remove('PauseMenu');
          resumeEngine();
        } else {
          pauseEngine();
          overlays.add('PauseMenu');
        }
      }
      return KeyEventResult.handled;
    }
    return super.onKeyEvent(event, keysPressed);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _reflowControles(size);
  }

  /// PAISAGEM: vidro da câmera intocado — a resolução fixa (ver `onLoad`) já
  /// centraliza sozinha, é o comportamento de sempre. Slots do inventário na
  /// faixa do topo (`ConsumableSlotButton.alturaFaixa`).
  ///
  /// RETRATO: a área de jogo fica presa no TOPO da tela, sobrando uma banda
  /// embaixo pro rodapé de controles (`DynamicJoystickComponent.alturaBanda`
  /// — mesma conta, reservada sozinha pelo joystick via seu próprio
  /// `onGameResize`) e os slots do inventário migram pro topo dessa banda —
  /// nada fica em cima da área de jogo (ver `HudOverlay`, que faz o mesmo
  /// pro botão de pausa, um widget do Flutter fora da árvore do Flame).
  ///
  /// Chamado de três lugares — `onLoad` (montagem), `onGameResize` (resize
  /// de verdade) e `update` (rede de segurança, ver comentário lá): o
  /// `onLoad`/`onGameResize` de um `FixedResolutionViewport` roda seu PRÓPRIO
  /// auto-centralizado ao montar, então depender de um cálculo único feito
  /// cedo demais (antes do tamanho final da janela estar disponível em todas
  /// as plataformas) deixava o vidro preso num tamanho errado sem gerar
  /// nenhum resize de verdade depois pra corrigir.
  void _reflowControles(Vector2 canvasSize) {
    if (!_camaraPronta) return;

    // Sem controles na tela não há banda pra reservar: a área de jogo usa a
    // janela inteira, em pé ou deitada. O ramo de RETRATO abaixo encolhe o
    // vidro da câmera pra abrir espaço pro rodapé de controles, e rodá-lo no
    // desktop deixaria uma faixa vazia embaixo do jogo.
    final semControles = !GameSettings.instance.controlesNaTela;
    final retrato =
        !semControles && DynamicJoystickComponent.retrato(canvasSize);
    double slotsTop = 10;

    _reposicionarCentrosFixos(canvasSize, retrato || semControles);
    _ajustarVidro(canvasSize);

    if (retrato) {
      final alturaBanda = DynamicJoystickComponent.alturaBanda(canvasSize);
      final ladoVidro = min(canvasSize.x, canvasSize.y - alturaBanda);
      final vidroLeft = (canvasSize.x - ladoVidro) / 2;

      // NÃO usar `viewport.size = ...` direto: esse setter aciona
      // `onViewportResize()`, que pro tipo de viewport da câmera
      // (`FixedAspectRatioViewport`, por trás do `withFixedResolution`)
      // recalcula a máscara de recorte num referencial CENTRALIZADO
      // (-metade a +metade). O caminho normal de resize
      // (`onGameResize`/`_handleResize`, disparado sozinho pelo Flame num
      // resize de verdade) usa um referencial no CANTO SUPERIOR ESQUERDO (0
      // a tamanho) — os dois divergem, e via `size =` só metade do vidro
      // (o quadrante que sobra da interseção dos dois referenciais) ficava
      // visível. `onGameResize` chama `_handleResize` por dentro, então é o
      // jeito de forçar o tamanho certo sem cair nesse descompasso.
      gameCamera.viewport.onGameResize(Vector2.all(ladoVidro));
      // 16px pra baixo, a pedido — não presa exatamente na borda superior.
      gameCamera.viewport.position = Vector2(vidroLeft, 48);
      slotsTop = canvasSize.y - alturaBanda + 58;

      // Botão da habilidade 2: em PAISAGEM ele usa `margin` (ver
      // `_setupActionButtons`), que se autoajusta sozinho no resize — não
      // mexe aqui. Em RETRATO esse mesmo margin (5px da borda inferior da
      // tela cheia) deixava o botão colado bem embaixo da banda de
      // controle, baixo demais pro polegar alcançar direito — sobrescreve
      // com uma posição própria, centralizada na altura da banda.
      final botao = _ability2Button;
      if (botao != null) {
        const margemBorda = 5.0;
        botao.position = Vector2(
          canvasSize.x - margemBorda - botao.size.x,
          (canvasSize.y - alturaBanda) + (alturaBanda - botao.size.y) / 3,
        );

        // O de troca acompanha, logo acima — em RETRATO o `margin` sofre o
        // mesmo problema do de habilidade 2 (ver acima), então também precisa
        // de posição própria.
        final troca = _trocaButton;
        if (troca != null) {
          troca.position = Vector2(
            botao.position.x,
            botao.position.y - troca.size.y - 8,
          );
        }
      }
    }

    const margem = 8.0;
    const gap = 8.0;
    final raio = _isDesktop ? 32.0 : 32.0;
    final larguraSlot = raio * 2;

    // Sem controles na tela os slots mudam de canto. No celular eles ficam no
    // topo, longe dos polegares, que e onde o resto dos controles mora. No
    // desktop nao ha polegar nem banda de controle, e o canto inferior direito
    // e o unico que fica vazio — o topo tem a Hud (vida, andar, moedas,
    // minimapa) e o rodape esquerdo tem a barra de XP.
    if (semControles) {
      // Coordenadas de SALA, não de tela: aqui os slots são filhos do viewport
      // (ver `_setupInventorySlots`), então quem escala eles é a mesma
      // transformação que escala o jogo.
      const margemSala = 4.0;
      const gapSala = 3.0;
      final ladoSala = _raioSlotNaSala * 2;
      final quantidade = _slotButtons.length;
      final larguraTotal = quantidade * ladoSala + (quantidade - 1) * gapSala;
      final esquerda = RoomComponent.roomWidth - margemSala - larguraTotal;
      final topo = RoomComponent.roomHeight - margemSala - ladoSala;
      for (var i = 0; i < quantidade; i++) {
        _slotButtons[i].position = Vector2(
          esquerda + i * (ladoSala + gapSala),
          topo,
        );
      }
      return;
    }

    for (var i = 0; i < _slotButtons.length; i++) {
      _slotButtons[i].position = Vector2(
        margem + i * (larguraSlot + gap),
        slotsTop,
      );
    }
  }

  /// Garante que o vidro da câmera é o de RESOLUÇÃO FIXA.
  ///
  /// Existiu aqui uma versão esticada, que ocupava a janela inteira deformando
  /// os pixels — foi testada e descartada: pixel art esticada fica ruim. A
  /// proporção 160x144 volta a ser preservada, e a faixa que sobra é pintada
  /// de preto no desktop (ver `backgroundColor`).
  void _ajustarVidro(Vector2 canvasSize) {
    if (gameCamera.viewport is FixedResolutionViewport) return;
    gameCamera.viewport = FixedResolutionViewport(
      resolution: Vector2(RoomComponent.roomWidth, RoomComponent.roomHeight),
    );
    gameCamera.viewport.onGameResize(canvasSize);
  }

  /// Onde o joystick FIXO (ver `GameSettings.joysticksFixos`) fica em cada
  /// orientação.
  ///
  /// RETRATO devolve pra regra do próprio componente: ali a área de captura já
  /// É a banda do rodapé, livre de sobreposição, e o meio dela serve.
  ///
  /// PAISAGEM precisa deste cálculo. A área de captura de cada joystick é
  /// METADE DA TELA, e o meio dela cai embaixo do vidro da câmera — que em
  /// paisagem é centralizado e ocupa a altura inteira, sobrando só duas
  /// tarjas nas laterais. O centro então vai pro meio da TARJA, não da
  /// metade da tela.
  ///
  /// A largura do vidro é recalculada aqui com a mesma conta do
  /// `withFixedResolution` (escala pelo eixo mais apertado) em vez de lida do
  /// `gameCamera.viewport`: aquele objeto mistura dois referenciais
  /// diferentes de posição (ver o comentário do `viewport.onGameResize` logo
  /// acima), e depender dele aqui só reintroduziria aquela confusão.
  void _reposicionarCentrosFixos(Vector2 canvasSize, bool retrato) {
    if (retrato) {
      moveJoystick.centroFixoExterno = null;
      aimJoystick.centroFixoExterno = null;
      return;
    }

    final escala = min(
      canvasSize.x / RoomComponent.roomWidth,
      canvasSize.y / RoomComponent.roomHeight,
    );
    final larguraVidro = RoomComponent.roomWidth * escala;
    final tarja = (canvasSize.x - larguraVidro) / 2;

    // Tarja estreita demais pra caber o indicador: melhor deixar a regra
    // padrão agir do que empurrar o controle pra um canto onde ele fica
    // cortado pela borda da tela.
    if (tarja < _tarjaMinimaParaCentroFixo) {
      moveJoystick.centroFixoExterno = null;
      aimJoystick.centroFixoExterno = null;
      return;
    }

    final alturaCentro = moveJoystick.size.y * _fracaoAlturaCentroPaisagem;

    // Esquerdo: área começa em x=0 e a tarja esquerda está livre, então o
    // meio dela serve.
    moveJoystick.centroFixoExterno = Vector2(tarja / 2, alturaCentro);

    // Direito: NÃO no meio da tarja. Os botões de habilidade 2 e de troca
    // moram colados na borda DIREITA da tela (posicionados por `margin`, ver
    // `_setupActionButtons`), e o indicador centralizado encostava por baixo
    // deles. Empurrando o centro pra dentro — na direção da área de jogo — o
    // controle continua na tarja, continua baixo (que é onde o polegar
    // descansa) e larga o canto pros botões.
    //
    // A conta sai da borda direita da TELA: `canvasSize.x - tarja * fração`
    // é o centro em coordenadas de tela, e o `- canvasSize.x / 2` vira
    // coordenada local, já que a área deste joystick começa na metade.
    aimJoystick.centroFixoExterno = Vector2(
      canvasSize.x - tarja * _fracaoCentroDireitoNaTarja - canvasSize.x / 2,
      alturaCentro,
    );
  }

  /// Largura mínima de tarja lateral pra valer a pena prender o joystick nela
  /// — o indicador tem 168px de lado (ver `_setupJoysticks`).
  static const double _tarjaMinimaParaCentroFixo = 180.0;

  /// Mesma fração que o componente usa em paisagem; repetida aqui porque o
  /// centro externo substitui a regra dele por inteiro.
  static const double _fracaoAlturaCentroPaisagem = 0.72;

  /// Quão fundo na tarja direita o analógico de mira fica, medido a partir da
  /// borda direita da tela. 0,5 seria o meio; mais que isso o empurra pra
  /// dentro, longe dos botões de ação que ocupam o canto.
  static const double _fracaoCentroDireitoNaTarja = 0.7;

  /// Pré-processa toda combinação caminho+cores que o jogo pode desenhar em
  /// pleno jogo, pra que a PRIMEIRA vez que ela aparecer (primeiro inimigo
  /// de uma espécie nova numa sala, primeira captura de uma criatura nova,
  /// primeiro tiro de uma habilidade) não trave gerando a textura na hora.
  /// `PaletteSwapper` já cacheia por caminho+cores (ver `_keyFor`); isto só
  /// garante que o cache já está quente ANTES da run começar.
  ///
  /// Três blocos:
  /// 1. Sprites genéricos (tiros/itens padrão, sem depender de criatura).
  /// 2. Combinações fixas: os 5 ícones de condição, o alerta de ataque
  ///    (`Enemy.spawnAlerta`), e as habilidades/passivas cuja arte usa
  ///    cor de uma criatura específica só (`Ericar` é sempre a cor do
  ///    Ouriço, por exemplo) — não dá pra derivar isso do `CreatureRegistry`
  ///    genericamente, porque `Ability`/`Passive` não expõem sprite/cor como
  ///    dado; precisa ser mantido à mão quando a arte de uma habilidade
  ///    mudar (ver comentário de cada entrada).
  /// 3. Um laço sobre as 16 criaturas do registro: cada uma aparece em até
  ///    três formas visuais distintas (companion — sem `whiteReplacement`;
  ///    inimigo/boss e escudo passivo do treinador — com
  ///    `whiteReplacement: Palette.branco`), e as três precisam do próprio
  ///    cache, mesmo caminho+cores gerando chaves diferentes por causa do
  ///    branco. Autossuficiente: uma 17ª criatura no registry já entra
  ///    sozinha, sem editar esta função.
  Future<void> _preloadCombatSprites() async {
    final warmUps = <Future<ui.Image>>[
      // Tiro do player (Projectile padrão)
      PaletteSwapper.createSwappedImage(
        imagePath: 'projeteis/tiro.png',
        lightGrayReplacement: Palette.azul,
        darkGrayReplacement: Palette.verdeEsc,
      ),
      // Tiro dos inimigos (Enemy.bltImg padrão)
      PaletteSwapper.createSwappedImage(
        imagePath: 'projeteis/tiro2.png',
        lightGrayReplacement: Palette.vermelho,
        darkGrayReplacement: Palette.laranja,
      ),
      // Bomba
      PaletteSwapper.createSwappedImage(
        imagePath: 'projeteis/bomb.png',
        lightGrayReplacement: Palette.indigo,
        darkGrayReplacement: Palette.azulEsc,
      ),
      // Efeito de morte de inimigo
      PaletteSwapper.createSwappedImage(
        imagePath: 'effects/enemy_death.png',
        lightGrayReplacement: Palette.indigo,
        darkGrayReplacement: Palette.cinzaEsc,
        whiteReplacement: Palette.branco,
      ),
      // Drops de vida
      PaletteSwapper.createSwappedImage(
        imagePath: 'items/heartHalf.png',
        lightGrayReplacement: Palette.vermelho,
        darkGrayReplacement: Palette.roxoEsc,
      ),
      // Drop de bomba
      PaletteSwapper.createSwappedImage(
        imagePath: 'items/bomb.png',
        lightGrayReplacement: Palette.indigo,
        darkGrayReplacement: Palette.azulEsc,
      ),
      // Bolha das habilidades defensivas (Bolha Protetora, Casco Fechado)
      PaletteSwapper.createSwappedImage(
        imagePath: 'projeteis/bolha.png',
        lightGrayReplacement: Palette.azul,
        darkGrayReplacement: Palette.azulEsc,
        whiteReplacement: Palette.branco,
      ),

      // --- Ícones de condição (ConditionIcons) — 5 combinações fixas,
      // iguais pra qualquer inimigo. Sem preload, o primeiro inimigo
      // atordoado/envenenado/queimado/lento/cego da run travava um pouco.
      PaletteSwapper.createSwappedImage(
        imagePath: 'effects/stun.png',
        lightGrayReplacement: Palette.cinza,
        darkGrayReplacement: Palette.laranja,
        whiteReplacement: Palette.branco,
      ),
      PaletteSwapper.createSwappedImage(
        imagePath: 'effects/poison.png',
        lightGrayReplacement: Palette.verde,
        darkGrayReplacement: Palette.amarelo,
        whiteReplacement: Palette.branco,
      ),
      PaletteSwapper.createSwappedImage(
        imagePath: 'effects/fogo.png',
        lightGrayReplacement: Palette.laranja,
        darkGrayReplacement: Palette.vermelho,
        whiteReplacement: Palette.branco,
      ),
      PaletteSwapper.createSwappedImage(
        imagePath: 'effects/lento.png',
        lightGrayReplacement: Palette.azul,
        darkGrayReplacement: Palette.indigo,
        whiteReplacement: Palette.branco,
      ),
      PaletteSwapper.createSwappedImage(
        imagePath: 'effects/cego.png',
        lightGrayReplacement: Palette.cinza,
        darkGrayReplacement: Palette.cinzaEsc,
        whiteReplacement: Palette.branco,
      ),
      // Os três que faltavam do conjunto do `ConditionIcons`. Ele carrega os
      // OITO ícones no `onLoad` de CADA inimigo, então quem não está aqui é
      // processado no primeiro inimigo da run, em pleno jogo. As cores
      // precisam bater exatamente com as de lá — elas entram na chave do
      // cache, e uma cor diferente aquece uma entrada que ninguém usa.
      PaletteSwapper.createSwappedImage(
        imagePath: 'effects/chain.png',
        lightGrayReplacement: Palette.cinza,
        darkGrayReplacement: Palette.indigo,
        whiteReplacement: Palette.branco,
      ),
      PaletteSwapper.createSwappedImage(
        imagePath: 'effects/fear.png',
        lightGrayReplacement: Palette.cinza,
        darkGrayReplacement: Palette.azulEsc,
        whiteReplacement: Palette.branco,
      ),
      PaletteSwapper.createSwappedImage(
        imagePath: 'effects/espelho.png',
        lightGrayReplacement: Palette.branco,
        darkGrayReplacement: Palette.azul,
        whiteReplacement: Palette.branco,
      ),
      // Alerta antes do inimigo atacar (Enemy.spawnAlerta)
      PaletteSwapper.createSwappedImage(
        imagePath: 'effects/exclamacao.png',
        lightGrayReplacement: Palette.indigo,
        darkGrayReplacement: Palette.vermelho,
        whiteReplacement: Palette.branco,
      ),

      // --- Projéteis de habilidade/passiva com cor fixa (não derivada de
      // `creatureData` na hora do disparo). Mantido à mão — ver comentário
      // do método.
      // Roedor de Fogo — RajadaDeBrasa
      PaletteSwapper.createSwappedImage(
        imagePath: 'projeteis/fogo2.png',
        lightGrayReplacement: Palette.vermelho,
        darkGrayReplacement: Palette.laranja,
      ),
      // Tartaruga de Planta / Slime de Planta — CuspeDeSemente / CuspeVenenoso
      PaletteSwapper.createSwappedImage(
        imagePath: 'projeteis/proj1.png',
        lightGrayReplacement: Palette.verde,
        darkGrayReplacement: Palette.verdeEsc,
      ),
      // Sapo de Água — BolaDagua
      PaletteSwapper.createSwappedImage(
        imagePath: 'projeteis/proj1.png',
        lightGrayReplacement: Palette.azul,
        darkGrayReplacement: Palette.azulEsc,
      ),
      // Ave Elétrica — BicoEletrico
      PaletteSwapper.createSwappedImage(
        imagePath: 'projeteis/proj2.png',
        lightGrayReplacement: Palette.amarelo,
        darkGrayReplacement: Palette.laranja,
      ),
      // Tornado de Fogo — SocoFlamejante
      PaletteSwapper.createSwappedImage(
        imagePath: 'projeteis/soco.png',
        lightGrayReplacement: Palette.vermelho,
        darkGrayReplacement: Palette.roxoEsc,
      ),
      // Cobra de Água — JatoAquatico
      PaletteSwapper.createSwappedImage(
        imagePath: 'projeteis/proj1.png',
        lightGrayReplacement: Palette.azul,
        darkGrayReplacement: Palette.royal,
      ),
      // Grilo Elétrico — ChoqueEletrico
      PaletteSwapper.createSwappedImage(
        imagePath: 'projeteis/raio.png',
        lightGrayReplacement: Palette.amarelo,
        darkGrayReplacement: Palette.laranja,
      ),
      // Pinguim de Água — TiroDeGelo
      PaletteSwapper.createSwappedImage(
        imagePath: 'projeteis/proj1.png',
        lightGrayReplacement: Palette.azul,
        darkGrayReplacement: Palette.indigo,
      ),
      // Toco de Madeira — FolhasNavalha
      PaletteSwapper.createSwappedImage(
        imagePath: 'projeteis/folha.png',
        lightGrayReplacement: Palette.verde,
        darkGrayReplacement: Palette.verdeEsc,
      ),
      // Tornado de Fogo — TornadoResidual (passiva)
      PaletteSwapper.createSwappedImage(
        imagePath: 'projeteis/tornado.png',
        lightGrayReplacement: Palette.vermelho,
        darkGrayReplacement: Palette.laranja,
      ),
      // Slime de Planta — PecoenhaReflexiva (passiva)
      PaletteSwapper.createSwappedImage(
        imagePath: 'projeteis/bolaGrande.png',
        lightGrayReplacement: Palette.verde,
        darkGrayReplacement: Palette.verdeEsc,
      ),

      // --- Habilidades/passivas cuja arte usa a cor da PRÓPRIA criatura
      // (`user.creatureData.corClara/corEscura` no código da habilidade) —
      // a combinação abaixo é a cor real de quem usa cada uma, não um valor
      // genérico.
      // Ouriço Elétrico — Ericar
      PaletteSwapper.createSwappedImage(
        imagePath: 'projeteis/raio.png',
        lightGrayReplacement: CreatureRegistry.ouricoEletrico.corClara,
        darkGrayReplacement: CreatureRegistry.ouricoEletrico.corEscura,
      ),
      // Caranguejo Ermitão de Fogo — BaforadaDeCinzas
      PaletteSwapper.createSwappedImage(
        imagePath: 'projeteis/nuvemP.png',
        lightGrayReplacement: CreatureRegistry.caranguejoErmitao.corClara,
        darkGrayReplacement: CreatureRegistry.caranguejoErmitao.corEscura,
      ),
      // Caranguejo Ermitão de Fogo — FumacaAoLacar (passiva)
      PaletteSwapper.createSwappedImage(
        imagePath: 'projeteis/nuvem.png',
        lightGrayReplacement: CreatureRegistry.caranguejoErmitao.corClara,
        darkGrayReplacement: CreatureRegistry.caranguejoErmitao.corEscura,
      ),
      // Leão Elétrico — EstocadaRelampago
      PaletteSwapper.createSwappedImage(
        imagePath: 'projeteis/proj2.png',
        lightGrayReplacement: CreatureRegistry.leaoEletrico.corClara,
        darkGrayReplacement: CreatureRegistry.leaoEletrico.corEscura,
      ),
    ];

    // --- Uma vez por criatura do registro: as três formas visuais que ela
    // pode assumir em jogo (ver doc do método).
    for (final c in CreatureRegistry.all) {
      // Inimigo comum/boss (Enemy.onLoad) e escudo passivo do treinador
      // (Player.onLoad) — as duas usam `whiteReplacement: Palette.branco`,
      // então compartilham exatamente esta chave de cache.
      warmUps.add(
        PaletteSwapper.createSwappedImage(
          imagePath: c.spritePath,
          lightGrayReplacement: c.corClara,
          darkGrayReplacement: c.corEscura,
          whiteReplacement: Palette.branco,
        ),
      );
      warmUps.add(
        PaletteSwapper.createSwappedImage(
          imagePath: 'projeteis/bolha.png',
          lightGrayReplacement: c.corClara,
          darkGrayReplacement: c.corEscura,
          whiteReplacement: Palette.branco,
        ),
      );
      // Sprite do próprio `Player` (ver `Player._montarVisualEHitbox`) — sem
      // `whiteReplacement`, chave diferente da forma inimigo/escudo acima.
      // Cobre tanto a criatura inicial (slot 0) quanto qualquer troca em
      // pleno jogo pra uma espécie ainda não vista na run (recrutada na sala
      // da escada, ver PIVOT_CONTROLE_DIRETO.md §5) — sem isso, a PRIMEIRA
      // troca pra uma criatura nova geraria a textura em pleno combate.
      warmUps.add(
        PaletteSwapper.createSwappedImage(
          imagePath: c.spritePath,
          lightGrayReplacement: c.corClara,
          darkGrayReplacement: c.corEscura,
        ),
      );
    }

    // Formas evoluídas (ver PIVOT_EVOLUCAO): só a forma `Player` — uma
    // evolução nunca aparece como inimigo/boss nem escudo passivo de outra
    // criatura, só substitui o sprite da ativa em pleno jogo. Sem isso, a
    // PRIMEIRA evolução da run geraria a textura em pleno combate.
    for (final evoluida in [
      CreatureRegistry.roedorFogoEvo,
      CreatureRegistry.tartarugaPlantaEvo,
      CreatureRegistry.sapoAguaEvo,
      CreatureRegistry.aveEletricaEvo,
    ]) {
      warmUps.add(
        PaletteSwapper.createSwappedImage(
          imagePath: evoluida.spritePath,
          lightGrayReplacement: evoluida.corClara,
          darkGrayReplacement: evoluida.corEscura,
        ),
      );
    }

    await PaletteSwapper.warmUp(warmUps);
  }

  /// Desktop usa mouse, não polegar: não precisa do piso de 48dp do Material.
  /// Os controles ficam menores lá pra não dominar uma janela pequena.
  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  /// Derruba e remonta TODO o aparato de controle — usado quando o jogador
  /// liga ou desliga os controles de tela nas configuracoes, no meio da run.
  ///
  /// Os joysticks sao recriados, e nao so remontados, porque o `Player` guarda
  /// a referencia dos dois: recriar exigiria mexer no jogador tambem. Por isso
  /// aqui e remocao e (re)adicao das MESMAS instancias.
  void remontarControles() {
    final mostrar = GameSettings.instance.controlesNaTela;

    moveJoystick.removeFromParent();
    aimJoystick.removeFromParent();
    for (final indicador in children.whereType<DPadIndicator>().toList()) {
      indicador.removeFromParent();
    }
    if (mostrar) {
      add(moveJoystick);
      add(aimJoystick);
      _adicionarIndicadores();
    }

    _setupAbilityControls();
    _reflowControles(size);
    // Depois do reflow: o viewport ja trocou de tipo, e e nele que os slots
    // do desktop moram.
    _setupInventorySlots();
  }

  void _setupJoysticks() {
    final scale = _isDesktop ? 0.75 : 1.0;

    // Joystick Esquerdo (Movimento). A mira sumiu: a mira das habilidades
    // agora é sempre a última direção de movimento (ver Player.lockedFireDirection).
    //
    // Sem manípulo/fundo próprios (knob/background nulos): o feedback visual
    // do movimento é o `DPadIndicator` montado logo abaixo, não um manípulo
    // que nasce embaixo do dedo. A área de captura (arrasto, metade
    // esquerda da tela) continua igual.
    moveJoystick = DynamicJoystickComponent(
      knobRadius: 60 * scale,
      spawnAreaSize: Vector2(size.x / 2, size.y),
    );

    // Joystick Direito (Ataque): a direção que ele é empurrado É a
    // habilidade 1, travada nos 4 eixos cardeais (ver
    // `Player._direcaoAtaqueTravada`) — twin-stick, não mira automática.
    // Metade DIREITA da tela (`ladoDireito: true`), senão sobreporia a
    // área de captura do joystick de movimento. Mesmo tratamento do
    // movimento: sem manípulo/fundo próprios, o `DPadIndicator` (com
    // `ui/apad.png`) montado abaixo é o feedback visual.
    aimJoystick = DynamicJoystickComponent(
      knobRadius: 60 * scale,
      spawnAreaSize: Vector2(size.x / 2, size.y),
      ladoDireito: true,
    );

    // No DESKTOP os dois são construídos mas NÃO montados. Construídos porque
    // o `Player` recebe os dois no construtor e lê `relativeDelta` todo
    // quadro; não montados porque isso já resolve tudo de uma vez —
    // `relativeDelta` devolve zero enquanto não há arrasto ativo, e
    // componente fora da árvore não recebe evento nenhum, então o jogador cai
    // direto no teclado. De quebra somem as duas áreas de captura que cobrem
    // meia tela cada e engoliriam o arrasto do mouse.
    if (!GameSettings.instance.controlesNaTela) return;

    // Adicionamos os joysticks DIRETAMENTE ao jogo, e não ao World.
    // Isso garante que eles sejam tratados como HUD (Interface) e
    // não sofram o zoom/escala da resolução de 160x144.
    add(moveJoystick);
    add(aimJoystick);

    _adicionarIndicadores();
  }

  /// Indicadores dos dois D-pads (ver doc da classe): cada um nasce onde o
  /// dedo toca dentro da área do respectivo joystick, e fica ali depois
  /// que solta.
  void _adicionarIndicadores() {
    add(
      DPadIndicator(
        posicao: () => moveJoystick.centroIndicador,
        direcao: () => moveJoystick.relativeDelta,
        spritePath: 'ui/dpad.png',
        cor1: UiTheme.dpadCor1,
        cor2: UiTheme.dpadCor2,
        tamanho: 168,
      ),
    );
    add(
      DPadIndicator(
        posicao: () => aimJoystick.centroIndicador,
        direcao: () => aimJoystick.relativeDelta,
        spritePath: 'ui/apad.png',
        cor1: UiTheme.apadCor1,
        cor2: UiTheme.apadCor2,
        tamanho: 168,
      ),
    );
  }

  /// Componentes de controle montados pelo esquema atual, guardados pra poder
  /// desmontar na troca. Uma lista própria, e não uma varredura por tipo em
  /// `children`, porque `add` do Flame é diferido: um componente adicionado e
  /// trocado no mesmo frame ainda não apareceria em `children`.
  final List<Component> _abilityControls = [];

  /// Referência direta ao botão da habilidade 2, além de estar em
  /// `_abilityControls` — pra `_reflowControles` poder reposicioná-lo em
  /// RETRATO sem precisar de `whereType` a cada frame.
  AbilityButton? _ability2Button;

  /// Botão de troca de criatura, montado só no esquema de BOTÕES — em GESTOS
  /// quem troca é o toque duplo.
  AbilityButton? _trocaButton;

  /// (Re)monta o esquema de controle escolhido. Idempotente: derruba o que o
  /// esquema anterior tinha posto antes de montar o novo, então serve tanto pro
  /// onLoad quanto pra troca em runtime.
  ///
  /// A habilidade 1 fica fora dos dois esquemas: ela é o analógico direito
  /// (`aimJoystick`), montado sempre em `_setupJoysticks`. O que muda entre
  /// BOTÕES e GESTOS é só como a habilidade 2 é disparada.
  ///
  /// GESTOS não monta componente nenhum — só pendura um callback no analógico
  /// direito, que já recebe todo ponteiro daquela metade da tela. Arrastar
  /// segue mirando; um toque curto e parado vira a habilidade 2.
  ///
  /// Roda depois de `_setupJoysticks` (ver `onLoad`), então `aimJoystick`
  /// sempre existe aqui.
  void _setupAbilityControls() {
    for (final control in _abilityControls) {
      control.removeFromParent();
    }
    _abilityControls.clear();
    _ability2Button = null;
    _trocaButton = null;
    aimJoystick.onToqueRapido = null;
    aimJoystick.onToqueMantido = null;

    // Desktop joga no teclado (ver `Player.onKeyEvent`): nenhum botão de ação
    // é montado, e os ganchos de gesto ficam nulos — o analógico direito que
    // os dispararia nem está na árvore.
    if (!GameSettings.instance.controlesNaTela) return;

    switch (_controlScheme) {
      case ControlScheme.botoes:
        _setupActionButtons();
      case ControlScheme.gestos:
        // `dispararAbility2()` direto, e não a flag `touchHoldAbility2`: a
        // flag é lida uma vez por frame pra sustentar o botão segurado, e um
        // toque não tem duração pra sustentar nada — ligar e desligar dentro
        // do mesmo frame poderia nunca ser visto pelo `update`.
        //
        // A vibração vem ANTES e fora do `if`, igual ao botão
        // (`AbilityButton._refreshPressed`): lá ela responde ao toque, não ao
        // disparo, então acontece mesmo em cooldown ou sem energia. Manter o
        // mesmo critério é o que faz os dois esquemas darem o mesmo retorno
        // ao dedo — senão o modo gestos ficaria mudo justo quando o jogador
        // aperta repetido esperando a habilidade voltar.
        aimJoystick.onToqueRapido = () {
          HapticFeedback.lightImpact();
          if (_runStarted) player.dispararAbility2();
        };
        // Trocar de criatura é SEGURAR o dedo parado, não tocar duas vezes.
        // Com o toque duplo, a habilidade 2 saía junto: o toque rápido
        // dispara nos dois toques, e adiar o primeiro pra ver se vinha um
        // segundo custava ~250ms em TODO ataque, o que se sentia como
        // travamento. Segurar separa os dois gestos sem atrasar nenhum — o
        // `DynamicJoystickComponent` não chama o toque rápido quando o toque
        // já virou mantido.
        aimJoystick.onToqueMantido = () {
          HapticFeedback.lightImpact();
          trocarParaProximaCriatura();
        };
    }

    addAll(_abilityControls);
  }

  // APOSENTADO — comentado, não apagado (ver doc de `_setupAbilityControls`).
  // Metade direita da tela como área de gesto, sem botão desenhado: toque
  // parado e mantido = habilidade A; arrastar pra cima = habilidade B;
  // arrastar pra baixo = esquiva. Deixou de fazer sentido quando a
  // habilidade 1 virou o analógico direito (não tem mais "segurar"/"tocar"
  // pra configurar) — corpo comentado porque `player.touchHoldAbility1` foi
  // removido junto.
  //
  // void _setupGestureControls() {
  //   _abilityControls.add(
  //     GestureActionArea(
  //       onAbility1HoldChanged: (active) {
  //         if (_runStarted) player.touchHoldAbility1 = active;
  //       },
  //       onAbility2: () {
  //         if (_runStarted) player.dispararAbility2();
  //       },
  //       onDodge: () {
  //         if (_runStarted) player.dodge();
  //       },
  //     ),
  //   );
  // }

  /// Os dois botões dos slots, guardados pra poder reposicionar em
  /// PAISAGEM x RETRATO (ver `_reflowControles`) — a mesma razão de
  /// `_abilityControls` existir como lista: `add` do Flame é diferido.
  final List<ConsumableSlotButton> _slotButtons = [];

  /// Os dois slots de item de uso único. Montados uma única vez, fora de
  /// [_abilityControls]: eles não dependem do esquema de controle e não podem
  /// ser derrubados quando o jogador troca de esquema nas configurações.
  ///
  /// Posição real fica por conta de `_reflowControles` (muda com a
  /// orientação da tela).
  /// Raio do slot quando ele mora DENTRO da sala (desktop), em unidades de
  /// sala. A sala tem 160x144, então 9 dá um quadrado de 18 — mesma ordem de
  /// grandeza de um sprite de criatura.
  static const double _raioSlotNaSala = 9.0;

  /// (Re)monta os dois slots. Chamado de novo quando o jogador liga ou desliga
  /// os controles de tela, porque o PAI e o TAMANHO deles mudam junto.
  ///
  /// No celular são filhos do jogo, em pixels de tela, fora da área jogável.
  /// No desktop são filhos do VIEWPORT, em unidades de sala, desenhados por
  /// cima do jogo — a única forma de aparecerem ali, já que o
  /// `CameraComponent` nasce com `priority: 0x7fffffff` e cobre qualquer
  /// componente de raiz.
  void _setupInventorySlots() {
    for (final slot in _slotButtons) {
      slot.removeFromParent();
    }
    _slotButtons.clear();

    final naSala = !GameSettings.instance.controlesNaTela;

    for (int i = 0; i < 2; i++) {
      final slot = ConsumableSlotButton(
        radius: naSala ? _raioSlotNaSala : 32.0,
        // Índice capturado por valor no loop: cada slot lê o seu.
        conteudo: () => _runStarted ? player.slots[i] : null,
        onUsar: () {
          if (_runStarted) player.useSlot(i);
        },
      );
      _slotButtons.add(slot);
      if (naSala) {
        gameCamera.viewport.add(slot);
      } else {
        add(slot);
      }
    }
  }

  void _setupActionButtons() {
    // Só a habilidade 2 tem botão agora — a 1 é o analógico direito
    // (`aimJoystick`, twin-stick de eixos travados, montado sempre em
    // `_setupJoysticks`, fora daqui). Botão da habilidade A e o de esquiva
    // ficam comentados abaixo, não apagados.
    //
    // Raio 50 (100dp de diâmetro) no mobile é o piso de alvo de toque do
    // Material — com 18 (36dp) o botão ficava menor que o mínimo recomendado.
    final buttonRadius = (_isDesktop ? 48.0 : 48.0);
    const double edgeMarginX = 5;
    const double edgeMarginY = 5;

    // Habilidade B (segunda habilidade) — canto inferior ESQUERDO da tela,
    // a pedido do usuário. Segurar dispara enquanto o cooldown permitir,
    // mesmo padrão do teclado (`Player._keyboardHoldAbility2`, tecla espaço).
    _ability2Button = AbilityButton(
      radius: buttonRadius,
      quadro: (pressionado) {
        final tipo = _runStarted
            ? player.creatureData.ability2.tipo
            : AbilityTipo.ataque;
        return pressionado
            ? AbilityButtonSprites.pressionado(tipo)
            : AbilityButtonSprites.neutro(tipo);
      },
      pointerTracker: pointerTracker,
      margin: EdgeInsets.only(right: edgeMarginX, bottom: edgeMarginY),
      onPressedChanged: (pressed) {
        if (_runStarted) player.touchHoldAbility2 = pressed;
      },
    );
    _abilityControls.add(_ability2Button!);

    // Acima do botão de habilidade 2, com uma folga — mesmo canto, pra não
    // disputar espaço com o analógico direito do outro lado.
    const double folga = 8;
    _trocaButton = AbilityButton(
      radius: buttonRadius * 0.75,
      quadro: (pressionado) => pressionado
          ? AbilityButtonSprites.trocaPressionado
          : AbilityButtonSprites.trocaNeutro,
      pointerTracker: pointerTracker,
      margin: EdgeInsets.only(
        right: edgeMarginX,
        bottom: edgeMarginY + buttonRadius * 2 + folga,
      ),
      // Botão de ação instantânea: age na borda de descida (ao soltar) e
      // ignora o segurar, senão manter o dedo trocaria a criatura a cada
      // quadro. `_trocarParaProximaCriatura` ainda respeita o cooldown.
      onPressedChanged: (pressed) {
        if (pressed) trocarParaProximaCriatura();
      },
    );
    _abilityControls.add(_trocaButton!);

    // APOSENTADO — comentado, não apagado. Habilidade A por botão: virou o
    // analógico direito (`aimJoystick`). `marginRightB`/`marginRightA`
    // dependiam de `gap`, que só existia pra essas margens — se
    // reativar, recalcule.
    // const double gap = 10;
    // final double marginRightA = edgeMarginX;
    // final double marginRightB = edgeMarginX + buttonRadius * 2 + gap;
    // final double marginBottomC = edgeMarginY + buttonRadius * 2 + gap;
    // _abilityControls.add(
    //   AbilityButton(
    //     radius: buttonRadius,
    //     tipo: () => _runStarted
    //         ? player.creatureData.ability1.tipo
    //         : AbilityTipo.ataque,
    //     baseColor: Palette.cinza.withAlpha(255),
    //     pressedColor: Palette.cinza.withAlpha(140),
    //     pointerTracker: pointerTracker,
    //     margin: EdgeInsets.only(right: marginRightB, bottom: edgeMarginY),
    //     onPressedChanged: (pressed) {
    //       if (_runStarted) player.touchHoldAbility1 = pressed;
    //     },
    //   ),
    // );

    // Esquiva pessoal, não uma habilidade de criatura — ver `Player.dodge`.
    // Sem cooldown desenhado aqui (a barra própria da esquiva vive embaixo
    // do sprite do jogador, ver `Player.render`). Já estava comentada antes
    // desta mudança.
    // _abilityControls.add(
    //   AbilityButton(
    //     radius: buttonRadius,
    //     tipo: () => AbilityTipo.esquiva,
    //     baseColor: Palette.cinza.withAlpha(255),
    //     pressedColor: Palette.cinza.withAlpha(140),
    //     pointerTracker: pointerTracker,
    //     margin: EdgeInsets.only(right: marginRightA, bottom: marginBottomC),
    //     onPressedChanged: (pressed) {
    //       if (pressed) player.dodge();
    //     },
    //   ),
    // );
  }

  @override
  void update(double dt) {
    if (freezeTmr > 0) {
      freezeTmr -= dt;
      return;
    }
    super.update(dt);
    if (_runStarted) tempoDeRun += dt;
    if (trocaCooldown > 0) trocaCooldown -= dt;
    _checkCameraTransition();
    // Rede de segurança pro layout RETRATO x PAISAGEM (ver doc de
    // `_reflowControles`): reafirma a cada frame, não só no resize — barato
    // (poucas contas) e cobre qualquer plataforma/ordem de montagem em que
    // `onGameResize` não disparasse de novo com o tamanho final da janela.
    _reflowControles(size);
  }

  /// Fração de vida FALTANDO no banco (0 = vida cheia, 1 = zerada) — mesma
  /// convenção visual que `AbilityCooldownIndicator` usa (cinza cheio =
  /// "não pronto"). Sem cura passiva, esse valor é estático: só muda quando
  /// a criatura entra/sai do banco, não com o tempo. Fora do banco, 0 — nada
  /// pra desenhar.
  double companionPocketFraction(int slot) {
    final membro = grupo[slot];
    if (membro == null || !membro.noBanco) return 0.0;
    final maxHp = membro.criatura.stats.maxHp;
    if (maxHp <= 0) return 0.0;
    return (1 - membro.vida / maxHp).clamp(0.0, 1.0);
  }

  /// Chamado pela `Stairs` ao encostar no jogador. Só encena a animação —
  /// quem realmente troca o andar é o `aoFechar` de [LevelTransitionOverlay],
  /// disparado no instante em que a tela fica 100% preta.
  void startLevelTransition() {
    player.naoMove = true;
    gameCamera.viewport.add(
      LevelTransitionOverlay(
        player: player,
        camera: gameCamera,
        aoFechar: nextLevel,
      ),
    );
  }

  // NOVO MÉTODO: Limpa e recria a fase!
  void nextLevel() {
    // 1. LIMPEZA TOTAL (O "faxineiro")
    // Remove salas velhas, tiros perdidos, itens no chão... tudo, MENOS o
    // jogador (que precisa atravessar de andar) — o grupo inteiro é só dado
    // (`grupo`), não componente montado, então não há mais nada
    // além do `Player` pra preservar aqui.
    GameAudio.instance.play(Sfx.stairs);
    for (var child in dungeonWorld.children) {
      if (child != player) {
        child.removeFromParent();
      }
    }
    loadedRooms.clear();

    // 2. AVANÇA O ANDAR
    // Sem isso o contador ficava travado em 1 pra sempre — e como o tema da
    // sala vem de `getThemeForLevel`, os outros 4 temas nunca apareciam.

    currentFloor++;

    // Só troca de dungeon (e resorteia o boss dela) quando o andar estoura
    // o ciclo — dentro da mesma dungeon o boss já sorteado continua valendo
    // até o andar final dela.
    final novaDungeon = currentFloor > numFloors;
    if (novaDungeon) {
      // Sem pool de boss pra proxima dungeon: acabou o jogo. Checado ANTES do
      // `currentLevel++` de propósito — depois de incrementar, `sortear`
      // daria a volta no `%` e reusaria a primeira pool, e o jogador jogaria
      // a dungeon 1 de novo achando que era nova.
      if (ehUltimaDungeon) {
        _handleVitoria();
        return;
      }

      currentLevel++;
      currentFloor = 1;
      runBoss = BossRegistry.sortear(_bossRandom, currentLevel);
    }

    // Andar novo, fôlego novo: a passiva do Meao volta a poder salvar uma vez.
    player.seteVidasUsada = false;

    // 3. GERAÇÃO DE NOVO MAPA
    final generator = DungeonGenerator(
      maxRooms: salasDoAndar,
      // Mesmo `isBossFloor` que decide o `bossBuilder` logo abaixo: a sala
      // final nasce como BOSS no andar de boss e como ESCADA nos outros.
      comBoss: isBossFloor,
    );
    mapData = generator.generate();

    for (var roomData in mapData.values) {
      final room = RoomComponent(
        roomData,
        player: player,
        dungeon: currentLevel,
        floor: currentFloor,
        bossBuilder: isBossFloor ? _buildRunBoss : null,
        wildCreatureBuilder: currentFloor % 2 == 0 ? _buildWildCreatures : null,
      );
      loadedRooms['${roomData.x},${roomData.y}'] = room;
      dungeonWorld.add(room);
    }

    // 3. REPOSICIONAMENTO DO JOGADOR E CÂMERA
    // Volta o jogador para o centro lógico da fase (Sala Inicial)
    player.position = Vector2(
      RoomComponent.roomWidth / 2,
      RoomComponent.centerY,
    );
    currentRoomIndex = Vector2.zero();

    // Dá um "corte seco" na câmera de volta para o início
    tremorCamera.parar();
    gameCamera.viewfinder.position = Vector2(
      RoomComponent.roomWidth / 2,
      RoomComponent.roomHeight / 2,
    );

    // 4. ATUALIZA O MINIMAPA
    // Entrega o novo mapa para a HUD e limpa o contorno antigo
    minimapHud.mapData = mapData;

    // Dungeon nova: revela o boss dela antes de liberar o jogo de novo —
    // mesma cerimônia de `startRun`. Motor pausado aqui também segura a
    // `LevelTransitionOverlay` no frame preto (`_fechou`), então o círculo
    // só reabre depois que o jogador confirma em `dismissBossReveal`.
    if (novaDungeon) {
      pauseEngine();
      overlays.add('BossReveal');
    }

    unawaited(_salvarAposMontarAndar());

    player.naoMove = false;
  }

  /// Chamado pelo `Player.onDeath` quando a vida chega a zero. Congela o jogo
  /// e troca a Hud pela tela de Game Over — as ações de RESTART/MENU dela já
  /// esperam o motor pausado (ver comentário em game_over_overlay.dart).
  ///
  /// Apaga o save aqui: roguelike é permadeath, e morrer é o único jeito de
  /// zerar a run em si (RESTART logo em seguida começa uma run NOVA, que já
  /// grava o save dela própria).
  /// Zerou o jogo: passou do andar final da ULTIMA dungeon (ver
  /// [ehUltimaDungeon]). Mesma mecanica do Game Over — tira a Hud, pausa e
  /// apaga o save —, porque em ambos a run terminou e nao ha pra onde
  /// continuar.
  /// Gasta a marca da `Heranca`: a run nova começa com um item da pool, já
  /// no inventário, e o nome dele sobe acima do jogador.
  void _receberHeranca() {
    if (!CreatureProgress.instance.herancaPendente) return;
    unawaited(CreatureProgress.instance.marcarHeranca(false));
    final item = sortearItemEfeito();
    if (item == null) return;
    player.ganharItem(item);
    dungeonWorld.add(
      TextEffect(
        text: buildContext!.l10n.effect_heranca(item.nome(buildContext!)),
        position: player.position.clone() + Vector2(0, -player.size.y / 2 - 4),
        color: Palette.amarelo,
      ),
    );
  }

  /// XP de progressão desta run: andar alcançado pesa mais, boss e vitória
  /// dão bônus, abate vale pouco (a quantidade de inimigos já cresce com o
  /// andar, então pesar abate contaria o progresso duas vezes). Moeda fica de
  /// fora de propósito: contar o saldo puniria gastar na loja.
  int _xpDaRun({required bool vitoria}) {
    final andares = (currentLevel - 1) * numFloors + currentFloor;
    return andares * 10 + bossesDaRun * 30 + abatesDaRun + (vitoria ? 100 : 0);
  }

  /// Grava o XP da run ANTES de qualquer animação: fechar o app no meio da
  /// barra enchendo não pode custar o XP. A tela só reproduz o que já está
  /// salvo. GOD MODE não rende XP — é cheat de teste.
  void _premiarProgressao({required bool vitoria}) {
    xpProgressaoAntes = CreatureProgress.instance.xpProgressao;
    xpProgressaoGanho = GameSettings.instance.godMode
        ? 0
        : _xpDaRun(vitoria: vitoria);
    unawaited(CreatureProgress.instance.ganharXpProgressao(xpProgressaoGanho));
    // Tempo jogado conta mesmo em god mode: é tempo de jogo, não conquista.
    unawaited(CreatureProgress.instance.somarTempoJogado(tempoDeRun));
  }

  void _handleVitoria() {
    // `nextLevel` já fez `currentFloor++` antes de perceber que era a última
    // dungeon, então aqui o andar está um além do último. Sem voltar, o
    // resumo da vitória mostraria um andar que não existe. Seguro mexer: o
    // save é apagado logo abaixo e `startRun` zera o andar.
    currentFloor = numFloors;
    _premiarProgressao(vitoria: true);
    // Toda criatura que passou pelo grupo ganha a marca, inclusive as que
    // caíram ou se aposentaram no caminho — mesmo critério do elenco que a
    // tela de vitória mostra. Vitória em GOD MODE não conta: é cheat de
    // teste, e a marca registra o que o jogador conquistou.
    if (!GameSettings.instance.godMode) {
      unawaited(CreatureProgress.instance.registrarVitoria(criaturasUsadas));
    }
    overlays.remove('Hud');
    overlays.add('Victory');
    GameMusic.instance.play(GameMusic.vitoria);
    pauseEngine();
    unawaited(RunSave.instance.apagar());
  }

  /// Com [comAnimacaoDeMorte], a tela de Game Over espera a cena de morte do
  /// jogador terminar (ver `Player.iniciarMorte`) — o motor NÃO pode ser
  /// pausado antes, senão a animação não recebe quadro nenhum.
  void _handleGameOver({bool comAnimacaoDeMorte = false}) {
    // O corpo em cena continua no mundo e com o motor rodando; sem esta
    // guarda, um segundo caminho de Game Over no meio da animação empilharia
    // outra tela.
    if (_gameOverEmCurso) return;
    _gameOverEmCurso = true;

    overlays.remove('Hud');
    // A run fecha JÁ, mesmo com o reviver em oferta: save apagado, XP e
    // tempo gravados, Herança marcada. Assim fechar o app na tela de reviver
    // é morte de verdade, sem XP perdido. Reviver desfaz isto (ver
    // [_reviver]).
    unawaited(RunSave.instance.apagar());
    _premiarProgressao(vitoria: false);
    if (player.itens.any((i) => i is Heranca)) {
      unawaited(CreatureProgress.instance.marcarHeranca(true));
    }
    // Aqui, e não em `_mostrarGameOver`: a faixa entra junto com a cena de
    // morte, que é quando a run acabou de fato. RESTART volta pra trilha da
    // run sozinho — `startRun` toca `GameMusic.run`.
    GameMusic.instance.play(GameMusic.gameOver);

    // O reviver só vale pra quem MORREU em combate (com cena de morte) — o
    // grupo esvaziado por aposentadoria não tem quem trazer de volta.
    final depois = comAnimacaoDeMorte && !reviveuNestaRun
        ? _oferecerReviver
        : _mostrarGameOver;
    if (!comAnimacaoDeMorte) {
      depois();
      return;
    }
    player.iniciarMorte(aoTerminar: depois);
  }

  // ------------------------------------------------------------ reviver

  /// Já usou o reviver nesta run (ver [reviverComAnuncio]). Vai pro save.
  bool reviveuNestaRun = false;

  /// Invencibilidade ao reviver, e raio do empurrão nos inimigos em volta.
  static const double invencivelAoReviver = 2.0;
  static const double raioEmpurraoReviver = 48.0;

  void _oferecerReviver() {
    overlays.add('Reviver');
    pauseEngine();
  }

  /// DESISTIR na oferta: segue pro game over de sempre.
  void recusarReviver() {
    overlays.remove('Reviver');
    _mostrarGameOver();
  }

  /// Mostra o anúncio e revive se ele foi visto até o fim. Devolve se
  /// reviveu — a tela de oferta usa pra avisar quando não.
  Future<bool> reviverComAnuncio() async {
    if (reviveuNestaRun) return false;
    final ganhou = await Anuncios.instance.mostrarRecompensado();
    if (!ganhou) return false;
    _reviver();
    return true;
  }

  /// A última criatura volta com a vida cheia, onde caiu. Desfaz o fim de
  /// run que [_handleGameOver] já tinha gravado e salva a run de novo.
  void _reviver() {
    overlays.remove('Reviver');
    reviveuNestaRun = true;
    _gameOverEmCurso = false;

    unawaited(
      CreatureProgress.instance.estornarFimDeRun(
        xp: xpProgressaoGanho,
        tempo: tempoDeRun,
      ),
    );
    if (player.itens.any((i) => i is Heranca)) {
      unawaited(CreatureProgress.instance.marcarHeranca(false));
    }

    // A ativa mora no `player`; o slot dela volta a existir com vida 0, como
    // no começo da run (ver `startRun`).
    grupo[companionAtivoIndex] = MembroGrupo(
      criatura: player.creatureData,
      noBanco: false,
      vida: 0.0,
      xp: player.xp,
      evoluida: player.evoluida,
    );
    derrotadoPor = null;
    derrotadoPorArmadilha = false;
    player.reviver(invencibilidade: invencivelAoReviver);

    // Respiro: some o que já vinha no ar, e quem estava colado é empurrado.
    for (final p in dungeonWorld.children.whereType<Projectile>().toList()) {
      if (p.isEnemy) p.removeFromParent();
    }
    for (final e in dungeonWorld.children.whereType<Enemy>()) {
      if (e.position.distanceTo(player.position) < raioEmpurraoReviver) {
        e.applyKnockback(player.position, 120);
      }
    }
    dungeonWorld.add(
      AuraPulseEffect(
        position: player.position.clone(),
        raio: raioEmpurraoReviver,
        cor1: Palette.amarelo,
        cor2: Palette.branco,
      ),
    );
    GameAudio.instance.play(Sfx.liberar);

    final temBoss = dungeonWorld.children.whereType<Enemy>().any(
      (e) => e.ehBoss && e.health > 0,
    );
    GameMusic.instance.play(temBoss ? GameMusic.boss : GameMusic.run);
    overlays.add('Hud');
    resumeEngine();
    unawaited(_salvarProgresso());
  }

  void _mostrarGameOver() {
    overlays.add('GameOver');
    pauseEngine();
    onGameOver?.call();
  }

  /// Reseta a run inteira, não só o jogador: `startRun` já limpa todo mundo
  /// (inimigos incluídos) e gera uma dungeon nova do zero, então reaproveita
  /// ele em vez de tentar remendar o estado da run anterior.
  void resetGame() {
    freezeTmr = 0;
    startRun(player.creatureData);
  }

  /// Empurra o jogador de volta pro interior da sala trancada. Trabalha na
  /// hitbox dos pés, a mesma que as paredes bloqueiam, e usa a espessura de
  /// parede (16px) como borda — exceto em cima, que soma também a faixa
  /// reservada pra HUD (`RoomComponent.topoHud`, sem parede/colisão nenhuma),
  /// senão esta função empurrava o jogador só até essa faixa vazia, atrás da
  /// HUD, em vez de até a parede/porta de verdade.
  void _prendeJogadorNaSala(
    double roomLeft,
    double roomTop,
    double roomRight,
    double roomBottom,
  ) {
    const double parede = 16.0;
    final double paredeTopo = RoomComponent.topoHud + parede;
    final pes = player.physicsHitbox.toAbsoluteRect();

    double dx = 0;
    double dy = 0;

    if (pes.left < roomLeft + parede) {
      dx = (roomLeft + parede) - pes.left;
    } else if (pes.right > roomRight - parede) {
      dx = (roomRight - parede) - pes.right;
    }

    if (pes.top < roomTop + paredeTopo) {
      dy = (roomTop + paredeTopo) - pes.top;
    } else if (pes.bottom > roomBottom - parede) {
      dy = (roomBottom - parede) - pes.bottom;
    }

    if (dx == 0 && dy == 0) return;

    player.position += Vector2(dx, dy);
    if (dx != 0) player.velocity.x = 0;
    if (dy != 0) player.velocity.y = 0;
  }

  void _checkCameraTransition() {
    // `physicsHitbox` só existe depois do onLoad do jogador (que espera as
    // trocas de paleta); até lá não há o que checar.
    if (!player.isLoaded) return;

    // Sem essa guarda, uma transição já em andamento (`player.naoMove`,
    // câmera ainda no `MoveToEffect` de 0.4s) não impedia esta função de
    // rodar de novo todo frame e achar `currentRoomIndex` de novo do lado
    // errado da fronteira (empurrão de parede/obstáculo perto da porta, ou
    // qualquer reposicionamento no meio do pan) — cada chamada empilhava
    // outro `MoveToEffect` competindo com o anterior e trocava
    // `currentRoomIndex` de novo, e de novo, sem nunca assentar: minimapa
    // alternando entre as duas salas, jogador travado sem controle porque
    // `naoMove` nunca volta a `false` de vez. Uma transição por vez, ponto.
    if (player.naoMove) return;

    final double roomWidth = RoomComponent.roomWidth;
    final double roomHeight = RoomComponent.roomHeight;
    final double threshold = 8.0;

    double roomLeft = currentRoomIndex.x * roomWidth;
    double roomRight = roomLeft + roomWidth;
    double roomTop = currentRoomIndex.y * roomHeight;
    double roomBottom = roomTop + roomHeight;

    int newRoomX = currentRoomIndex.x.toInt();
    int newRoomY = currentRoomIndex.y.toInt();
    bool transitioned = false;

    // Sala trancada não deixa passar, ponto: nem troca de sala, nem sair pela
    // borda. Recusar só a troca não bastava — o jogador continuava andando
    // pra fora com a câmera parada, porque a resolução de colisão empurra
    // pelo lado MAIS PERTO: quem afunda mais da metade dos 16px da parede é
    // cuspido pro lado de fora em vez de voltar pra dentro. Com a sala
    // trancada a regra é dura, então prendemos os pés no interior dela.
    final salaAtual =
        loadedRooms['${currentRoomIndex.x.toInt() + dungeonGridOrigin},${currentRoomIndex.y.toInt() + dungeonGridOrigin}'];
    if (salaAtual != null && salaAtual.isLocked) {
      _prendeJogadorNaSala(roomLeft, roomTop, roomRight, roomBottom);
      return;
    }

    // O gatilho lê a hitbox de física (os pés), não `player.position`. Eram
    // duas referências diferentes: a porta bloqueia os pés, mas a troca de
    // sala olhava o centro do componente, que fica `hitboxSize.y / 2` acima
    // dos pés. Em criaturas altas sobrava só ~3px entre "a porta empurra" e
    // "a sala troca", e qualquer frame mais longo pulava essa margem — o
    // jogador atravessava a porta trancada. Com os pés dos dois lados da
    // conta, a folga vira 8px fixos pra qualquer criatura.
    final pes = player.physicsHitbox.toAbsoluteRect();

    if (pes.right > roomRight - threshold) {
      newRoomX++;
      transitioned = true;
    } else if (pes.left < roomLeft + threshold) {
      newRoomX--;
      transitioned = true;
    } else if (pes.bottom > roomBottom - threshold) {
      newRoomY++;
      transitioned = true;
    } else if (pes.top < roomTop + threshold) {
      newRoomY--;
      transitioned = true;
    }

    if (transitioned) {
      player.naoMove = true;

      // Empurrão derivado da borda TRASEIRA do `physicsHitbox`, não uma
      // constante fixa. A constante (22px) só levava o CENTRO do jogador pra
      // além da fronteira — a borda de trás (a que importa: é ela que o
      // próximo `_checkCameraTransition` compara contra o threshold da sala
      // nova) ficava a `hitboxSize.x` de distância além disso. Toda criatura
      // com hitbox largo o bastante (>6px, ou seja, qualquer uma) reentrava
      // no threshold assim que o congelamento acabava e revertia a troca —
      // o jogador ficava entrando e saindo da mesma porta sem fim. Só não
      // aparecia numa sala nova porque `onPlayerEnter` tranca a sala e
      // `_prendeJogadorNaSala` mascara o ping-pong; numa sala já limpa
      // (`isLocked` nunca liga) o bug ficava visível.
      const double margem = 4.0;

      // Por onde o jogador ENTRA na sala nova é o lado oposto ao sentido em
      // que ele andou: indo pra direita, ele surge na porta ESQUERDA da sala
      // seguinte. Calculado aqui porque `currentRoomIndex` é sobrescrito
      // logo abaixo e a informação se perde.
      final LadoSala ladoEntrada;
      if (newRoomX > currentRoomIndex.x) {
        ladoEntrada = LadoSala.esquerda;
      } else if (newRoomX < currentRoomIndex.x) {
        ladoEntrada = LadoSala.direita;
      } else if (newRoomY > currentRoomIndex.y) {
        ladoEntrada = LadoSala.topo;
      } else {
        ladoEntrada = LadoSala.baixo;
      }

      if (newRoomX > currentRoomIndex.x) {
        player.position.x += (roomRight + threshold + margem) - pes.left;
      } else if (newRoomX < currentRoomIndex.x) {
        player.position.x -= pes.right - (roomLeft - threshold - margem);
      } else if (newRoomY > currentRoomIndex.y) {
        // Entrando pela porta de CIMA da sala nova: a sala nova reserva
        // `RoomComponent.topoHud` (16px) no topo pra HUD, sem parede nem
        // piso ali (ver RoomComponent) — pousar só `threshold+margem` além
        // da borda (como antes) deixava o jogador dentro dessa faixa vazia,
        // atrás da HUD, sem colisão nenhuma pra empurrá-lo pra fora. Soma
        // `topoHud` pra pousar depois da faixa, no mesmo lugar relativo
        // (dentro da linha da parede/porta) que já pousava antes.
        player.position.y +=
            (roomBottom + RoomComponent.topoHud + threshold + margem) - pes.top;
      } else if (newRoomY < currentRoomIndex.y) {
        player.position.y -= pes.bottom - (roomTop - threshold - margem);
      }

      currentRoomIndex = Vector2(newRoomX.toDouble(), newRoomY.toDouble());

      int logicalX = newRoomX + dungeonGridOrigin;
      int logicalY = newRoomY + dungeonGridOrigin;
      loadedRooms['$logicalX,$logicalY']?.onPlayerEnter(ladoEntrada);

      Vector2 newCameraPosition = Vector2(
        (newRoomX * roomWidth) + (roomWidth / 2),
        (newRoomY * roomHeight) + (roomHeight / 2),
      );

      // O tremor escreve na mesma `viewfinder.position` que este efeito, e
      // venceria todo quadro — a câmera ficaria presa na sala de onde o
      // jogador saiu até o tremor acabar.
      tremorCamera.parar();
      gameCamera.viewfinder.add(
        MoveToEffect(
          newCameraPosition,
          EffectController(duration: 0.4, curve: Curves.easeInOut),
          onComplete: () {
            player.naoMove = false;
            freezeTmr = freezeTime;
          },
        ),
      );
    }
  }
}

/// Um slot ocupado do grupo. Junta o que antes eram cinco listas paralelas
/// indexadas pelo mesmo slot (criatura, banco, vida, XP, evolução), em que
/// limpar ou preencher um slot exigia lembrar de mexer nas cinco — agora slot
/// vazio é só `null`.
///
/// [vida], [xp] e [evoluida] só valem pra quem está NO BANCO: a criatura em
/// campo guarda esses três no `Player`, e o slot dela recebe os valores
/// quando ela volta pro banco (`_trocarParaSlot`) ou no save.
class MembroGrupo {
  CreatureData criatura;

  /// `true` pra todo slot que não é a ativa agora. Um slot vai pro banco por
  /// dois motivos: o jogador trocou de ativa (ver `_trocarParaSlot`) ou a
  /// ativa bateu 0 de vida (ver `pocketarSlotAtivo`). Gravado como
  /// `pocketed` no save, nome do sistema de bolso original.
  bool noBanco;

  /// Vida salva — sem cura passiva no banco, fica congelada na vida com que
  /// a criatura saiu até ela voltar a campo.
  double vida;

  double xp;
  bool evoluida;

  MembroGrupo({
    required this.criatura,
    required this.vida,
    this.noBanco = true,
    this.xp = 0.0,
    this.evoluida = false,
  });
}
