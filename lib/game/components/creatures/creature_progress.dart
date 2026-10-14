import 'package:shared_preferences/shared_preferences.dart';

import 'package:creatures_rogue/game/components/items/item_efeito.dart';
import 'package:creatures_rogue/game/components/items/progressao_itens.dart';
import 'package:creatures_rogue/game/game_settings.dart';

/// Progresso de desbloqueio das criaturas: quais estão liberadas pra jogar, e
/// quantas mortes já foram acumuladas de cada uma (contagem que mais pra
/// frente aciona o boss de cada criatura — ver brainstorm de desbloqueio).
///
/// Um único carregamento no início do app (`load()`, chamado em `main()`);
/// toda mudança depois grava direto no SharedPreferences.
class CreatureProgress {
  CreatureProgress._();
  static final CreatureProgress instance = CreatureProgress._();

  static const _unlockedKey = 'creatures_rogue.unlocked_ids';
  static const _killCountPrefix = 'creatures_rogue.kills.';
  static const _introKey = 'creatures_rogue.intro_concluida';
  static const _vitoriasKey = 'creatures_rogue.vitorias_ids';
  static const _xpProgressaoKey = 'creatures_rogue.xp_progressao';
  static const _vitoriasContagemKey = 'creatures_rogue.vitorias_contagem';
  static const _tempoTotalKey = 'creatures_rogue.tempo_total';
  static const _herancaKey = 'creatures_rogue.heranca';
  static const _itensColetadosKey = 'creatures_rogue.itens_coletados';
  static const _itensVistosKey = 'creatures_rogue.itens_vistos';
  static const _evolucoesKey = 'creatures_rogue.evolucoes_vistas';

  /// Ninguém começa liberado: a primeira criatura vem da escolha no fim da
  /// intro (ver `IntroOverlay`), e é a única jogável na primeira run. A lista
  /// com 10 ids que morava aqui era atalho de teste.
  static const List<String> defaultUnlocked = [];

  late final SharedPreferences _prefs;
  Set<String> _unlockedIds = {};
  Set<String> _vitoriasIds = {};

  /// Registros do compêndio (ver `CompendioOverlay`), por id.
  Set<String> _itensColetados = {};
  Set<String> _itensVistos = {};
  Set<String> _evolucoes = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    _prefs = await SharedPreferences.getInstance();
    _unlockedIds = (_prefs.getStringList(_unlockedKey) ?? defaultUnlocked).toSet();
    _vitoriasIds = (_prefs.getStringList(_vitoriasKey) ?? const []).toSet();
    _itensColetados =
        (_prefs.getStringList(_itensColetadosKey) ?? const []).toSet();
    _itensVistos = (_prefs.getStringList(_itensVistosKey) ?? const []).toSet();
    _evolucoes = (_prefs.getStringList(_evolucoesKey) ?? const []).toSet();
    _loaded = true;
  }

  /// Esta criatura está liberada pra jogar?
  ///
  /// O GOD MODE libera TODAS. É cheat de teste, igual às outras duas metades
  /// dele (`Player.takeDamage` ignora dano, `Enemy.takeDamage` mata de um
  /// golpe): sem isto, testar uma criatura específica exigia derrotar o boss
  /// dela antes, e as de andar alto eram praticamente inalcançáveis.
  ///
  /// Mente na LEITURA, nunca na escrita: [_unlockedIds] continua intacto, e
  /// desligar o god mode devolve a lista real de quem o jogador de fato
  /// desbloqueou.
  ///
  /// Aqui, e não na tela de seleção, porque este é o funil por onde as três
  /// leituras passam — a lista, o cadeado de cada linha e a silhueta do VS.
  /// Espalhar a condição pelos três era garantir que um deles fosse esquecido.
  bool isUnlocked(String creatureId) =>
      GameSettings.instance.godMode || _unlockedIds.contains(creatureId);

  /// A intro (diálogo + escolha da criatura inicial) já foi concluída alguma
  /// vez. Enquanto for falso, "NOVO JOGO" leva pra intro em vez do seletor.
  bool get introConcluida => _prefs.getBool(_introKey) ?? false;

  /// Fecha a intro liberando a criatura escolhida. Uma chamada só de
  /// propósito: se a flag e o unlock fossem gravados em momentos diferentes,
  /// o app morto no meio deixaria zero criatura liberada E nenhuma intro pra
  /// liberar uma — e o seletor abriria com uma criatura travada selecionada.
  Future<void> concluirIntro(String starterId) async {
    _unlockedIds.add(starterId);
    await _prefs.setStringList(_unlockedKey, _unlockedIds.toList());
    await _prefs.setBool(_introKey, true);
  }

  /// Desfaz a intro e os desbloqueios (as contagens de morte por criatura
  /// continuam). Existe pra dar pra ver a intro de novo sem reinstalar o app
  /// — sem isso ela aparece uma vez na vida do aparelho.
  Future<void> resetIntro() async {
    _unlockedIds = defaultUnlocked.toSet();
    _vitoriasIds = {};
    await _prefs.setStringList(_unlockedKey, _unlockedIds.toList());
    await _prefs.setStringList(_vitoriasKey, const []);
    await _prefs.setInt(_xpProgressaoKey, 0);
    await _prefs.setInt(_vitoriasContagemKey, 0);
    await _prefs.setDouble(_tempoTotalKey, 0.0);
    await _prefs.remove(_herancaKey);
    _itensColetados = {};
    _itensVistos = {};
    _evolucoes = {};
    await _prefs.remove(_itensColetadosKey);
    await _prefs.remove(_itensVistosKey);
    await _prefs.remove(_evolucoesKey);
    await _prefs.setBool(_introKey, false);
  }

  /// Marca de conclusão: esta criatura já participou de uma run vencida?
  /// Indexado pelo `id`, que a forma evoluída compartilha com a base — vencer
  /// evoluída conta pra mesma criatura.
  ///
  /// Sem o atalho do GOD MODE que o [isUnlocked] tem: a marca existe pra
  /// registrar o que o jogador fez, e mentir nela apagaria o sentido.
  bool venceuCom(String creatureId) => _vitoriasIds.contains(creatureId);

  /// Grava a marca de todas as [creatureIds] de uma vez, numa escrita só.
  Future<void> registrarVitoria(Iterable<String> creatureIds) async {
    // A contagem de vitórias anda junto das marcas: as duas são "o que o
    // jogador conquistou", e quem chama já filtrou o god mode.
    await _prefs.setInt(_vitoriasContagemKey, vitorias + 1);
    final antes = _vitoriasIds.length;
    _vitoriasIds.addAll(creatureIds);
    if (_vitoriasIds.length == antes) return;
    await _prefs.setStringList(_vitoriasKey, _vitoriasIds.toList());
  }

  /// XP de progressão acumulado em todas as runs. Só o total é salvo: o
  /// nível e os itens liberados saem dele (ver [ProgressaoItens]), então
  /// editar a lista de desbloqueio nunca deixa o save inconsistente.
  int get xpProgressao => _prefs.getInt(_xpProgressaoKey) ?? 0;

  /// Runs vencidas fora do god mode — ver [registrarVitoria].
  int get vitorias => _prefs.getInt(_vitoriasContagemKey) ?? 0;

  /// Segundos jogados em runs que já ACABARAM (morte, vitória, ou run salva
  /// apagada por "novo jogo"). A run salva em andamento não está aqui: quem
  /// mostra o total soma o tempo dela por fora, senão ele contaria duas
  /// vezes quando a run acabasse.
  double get tempoTotal => _prefs.getDouble(_tempoTotalKey) ?? 0.0;

  Future<void> somarTempoJogado(double segundos) async {
    if (segundos <= 0) return;
    await _prefs.setDouble(_tempoTotalKey, tempoTotal + segundos);
  }

  /// Criaturas que o jogador desbloqueou DE FATO — sem o atalho do god mode
  /// que o [isUnlocked] tem, porque isto é placar, não permissão.
  int desbloqueadasEntre(Iterable<String> ids) =>
      ids.where(_unlockedIds.contains).length;

  int get nivelProgressao => ProgressaoItens.nivelPara(xpProgressao);

  // ---------------------------------------------------------- compêndio
  //
  // Sem o atalho do god mode na leitura, como [venceuCom]: é registro do que
  // o jogador fez. E o god mode também não ESCREVE aqui — com ele todo item
  // cai na run, e uma sessão de teste encheria o compêndio de mentira.

  /// Já matou esta criatura ou já jogou com ela (desbloqueio real).
  bool criaturaVista(String creatureId) =>
      _unlockedIds.contains(creatureId) || killCount(creatureId) > 0;

  bool itemColetado(String itemId) => _itensColetados.contains(itemId);

  /// Apareceu num pedestal ou na loja com o jogador na sala. Coletado conta
  /// como visto.
  bool itemVisto(String itemId) =>
      _itensVistos.contains(itemId) || _itensColetados.contains(itemId);

  /// Esta criatura já evoluiu alguma vez nas mãos do jogador.
  bool evolucaoVista(String creatureId) => _evolucoes.contains(creatureId);

  Future<void> registrarItemColetado(String itemId) =>
      _registrar(_itensColetados, _itensColetadosKey, itemId);

  Future<void> registrarItemVisto(String itemId) =>
      _registrar(_itensVistos, _itensVistosKey, itemId);

  Future<void> registrarEvolucao(String creatureId) =>
      _registrar(_evolucoes, _evolucoesKey, creatureId);

  Future<void> _registrar(Set<String> registro, String chave, String id) async {
    if (GameSettings.instance.godMode || !registro.add(id)) return;
    await _prefs.setStringList(chave, registro.toList());
  }

  /// A run passada morreu com a `Heranca`: a próxima começa com um item.
  bool get herancaPendente => _prefs.getBool(_herancaKey) ?? false;

  Future<void> marcarHeranca(bool pendente) =>
      _prefs.setBool(_herancaKey, pendente);

  Future<void> ganharXpProgressao(int xp) async {
    if (xp <= 0) return;
    await _prefs.setInt(_xpProgressaoKey, xpProgressao + xp);
  }

  /// O item pode cair nesta run? GOD MODE libera todos, pelo mesmo motivo de
  /// [isUnlocked]: é cheat de teste, e mente só na leitura.
  bool itemLiberado(ItemEfeito item) =>
      GameSettings.instance.godMode ||
      !ProgressaoItens.bloqueado(item, nivelProgressao);

  Future<void> unlock(String creatureId) async {
    if (_unlockedIds.add(creatureId)) {
      await _prefs.setStringList(_unlockedKey, _unlockedIds.toList());
    }
  }

  int killCount(String creatureId) => _prefs.getInt('$_killCountPrefix$creatureId') ?? 0;

  /// Chamado quando um inimigo dessa criatura morre. Retorna a contagem nova
  /// (ainda sem gatilho de boss — isso entra quando o sistema de boss existir).
  Future<int> incrementKill(String creatureId) async {
    final novo = killCount(creatureId) + 1;
    await _prefs.setInt('$_killCountPrefix$creatureId', novo);
    return novo;
  }
}
