import 'package:creatures_rogue/game/audio/game_music.dart';
import 'package:creatures_rogue/game/audio/ui_sfx.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/core/ui_theme.dart';
import 'package:creatures_rogue/game/components/core/responsive.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/components/creatures/creature_progress.dart';
import 'package:creatures_rogue/game/creatures_rogue_game.dart';
import 'package:creatures_rogue/game/run_save.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/items/item_efeito.dart';
import 'package:creatures_rogue/game/components/items/progressao_itens.dart';
import 'package:creatures_rogue/game/overlays/selecao_widgets.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';

/// Menu principal: os botões de entrada do jogo e o quadro com o estado do
/// save. Logo e nome moram na tela de título ([TitleOverlay]), que só a
/// abertura do app mostra.
class MainMenuOverlay extends StatelessWidget {
  final CreaturesRogueGame game;
  const MainMenuOverlay({super.key, required this.game});

  void _novoJogo(BuildContext context) {
    game.overlays.remove('MainMenu');
    game.overlays.add(
      CreatureProgress.instance.introConcluida ? 'CreatureSelect' : 'Intro',
    );
  }

  /// "NOVO JOGO" por cima de um save existente apaga a partida em
  /// andamento — mesmo padrão de confirmação de `SettingsOverlay._confirmarReset`
  /// (pergunta antes, não executa direto no toque).
  Future<void> _confirmarNovoJogo(BuildContext context) async {
    if (!RunSave.instance.hasSave) {
      _novoJogo(context);
      return;
    }

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: UiTheme.btnCor,
        shape: const BordaDuplaShape(),
        title: Text(
          context.l10n.menu_confirmarNovoJogoTitulo,
          style: const TextStyle(
            color: UiTheme.txtCor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          context.l10n.menu_confirmarNovoJogoMensagem,
          style: const TextStyle(color: UiTheme.txtCor),
        ),
        actions: [
          OutlinedButton(
            onPressed: withBtnSfx(() => Navigator.of(dialogContext).pop(false)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              backgroundColor: UiTheme.btnCor,
              side: BorderSide(color: Palette.preto),
              shape: const BordaDuplaShape(),
            ),
            child: Text(
              context.l10n.settings_confirmarResetNao,
              style: const TextStyle(color: UiTheme.txtCor),
            ),
          ),
          OutlinedButton(
            onPressed: withBtnSfx(() => Navigator.of(dialogContext).pop(true)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              backgroundColor: UiTheme.btnCor,
              side: BorderSide(color: Palette.preto),
              shape: const BordaDuplaShape(),
            ),
            child: Text(
              context.l10n.settings_confirmarResetSim,
              style: const TextStyle(
                color: UiTheme.txtCor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmou != true) return;
    // A run apagada foi jogada: o tempo dela entra no total antes de sumir.
    final tempoSalvo =
        (RunSave.instance.dados?['tempoDeRun'] as num?)?.toDouble() ?? 0.0;
    await CreatureProgress.instance.somarTempoJogado(tempoSalvo);
    await RunSave.instance.apagar();
    if (context.mounted) _novoJogo(context);
  }

  @override
  Widget build(BuildContext context) {
    // A trilha do menu é pedida AQUI, e não em cada lugar que reexibe o menu.
    // São vários caminhos de volta pra cá (título, game over, vitória, pausa,
    // seleção de criatura), e espalhar a chamada por todos é garantir que um
    // deles seja esquecido. `GameMusic.play` não faz nada quando a faixa
    // pedida já é a que está tocando, então rebuild aqui custa uma comparação
    // de string.
    GameMusic.instance.play(GameMusic.menu);

    final retrato = Responsive.ehRetrato(context);
    final botoes = _botoes(context);
    final quadro = _QuadroDeProgresso(game: game);

    return ResponsiveOverlayScaffold(
      background: UiTheme.backgroundMenuCor,
      // Paisagem pede mais largura de referência pras duas colunas, mesmo
      // motivo das configurações.
      maxWidth: retrato ? 480 : 760,
      child: retrato
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [quadro, const SizedBox(height: 20), botoes],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(child: botoes),
                const SizedBox(width: 24),
                Flexible(child: quadro),
              ],
            ),
    );
  }

  Widget _botoes(BuildContext context) {
    final temSave = RunSave.instance.hasSave;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (temSave) ...[
          _botao(
            context.l10n.pause_continuar,
            24,
            withBtnSfx(game.continuarSalva),
          ),
          const SizedBox(height: 10),
        ],
        // Sem save: entra direto (seletor de criaturas, ou a intro antes da
        // primeira run). Com save, confirma antes: escolher "novo jogo" por
        // cima de uma run em andamento apaga ela.
        _botao(
          context.l10n.menu_novoJogo,
          24,
          withBtnSfx(() => _confirmarNovoJogo(context)),
        ),
        const SizedBox(height: 10),
        _botao(
          context.l10n.menu_compendio,
          20,
          withBtnSfx(() {
            game.overlays.remove('MainMenu');
            game.overlays.add('Compendio');
          }),
        ),
        const SizedBox(height: 10),
        _botao(
          context.l10n.menu_manual,
          20,
          withBtnSfx(() {
            game.overlays.remove('MainMenu');
            game.overlays.add('Manual');
          }),
        ),
        const SizedBox(height: 10),
        _botao(
          context.l10n.menu_configuracoes,
          20,
          withBtnSfx(() {
            game.overlays.remove('MainMenu');
            game.settingsReturnOverlay = 'MainMenu';
            game.overlays.add('Settings');
          }),
        ),
      ],
    );
  }

  Widget _botao(String texto, double fonte, VoidCallback? onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: UiTheme.btnCor,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        elevation: 0,
        shape: const BordaDuplaShape(),
      ),
      onPressed: onPressed,
      child: Text(
        texto,
        style: TextStyle(fontSize: fonte, color: UiTheme.txtCor),
      ),
    );
  }
}

/// Estado do save: o progresso geral sempre, e a run salva quando existe —
/// assim o CONTINUAR mostra o que vai retomar antes do toque.
///
/// Os números são o que o jogador conquistou DE FATO: criaturas e itens não
/// passam pelo atalho do god mode, que libera tudo só pra testar.
class _QuadroDeProgresso extends StatelessWidget {
  final CreaturesRogueGame game;

  const _QuadroDeProgresso({required this.game});

  /// `1h 05m`, ou só `12m` abaixo de uma hora.
  static String _horas(double segundos) {
    final minutos = segundos ~/ 60;
    final h = minutos ~/ 60;
    final m = minutos % 60;
    return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final progresso = CreatureProgress.instance;
    final dados = RunSave.instance.dados;

    final totalCriaturas = CreatureRegistry.all.length;
    final criaturas = progresso.desbloqueadasEntre(
      CreatureRegistry.all.map((c) => c.id),
    );
    final sorteaveis = ItemEfeitoRegistry.todos.where((i) => i.sorteavel);
    final nivel = progresso.nivelProgressao;
    final itens = sorteaveis
        .where((i) => !ProgressaoItens.bloqueado(i, nivel))
        .length;
    final tempoRunSalva = (dados?['tempoDeRun'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: UiTheme.quadroFundoCor,
        border: BordaDupla(cor: Palette.preto, espessura: 3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _rotulo(l.menu_progresso),
          const SizedBox(height: 6),
          _linha(l.menu_criaturas, '$criaturas / $totalCriaturas'),
          _linha(l.menu_itens, '${itens-16} / ${sorteaveis.length - 16}'),
          _linha(l.menu_vitorias, '${progresso.vitorias}'),
          // O total soma a run salva por fora: ela só entra no acumulado
          // quando acaba (ver `CreatureProgress.tempoTotal`).
          _linha(
            l.menu_tempoTotal,
            _horas(progresso.tempoTotal + tempoRunSalva),
          ),
          if (dados != null) ...[
            const SizedBox(height: 12),
            _rotulo(l.menu_runSalva),
            const SizedBox(height: 6),
            _runSalva(context, dados, tempoRunSalva),
          ],
        ],
      ),
    );
  }

  Widget _runSalva(
    BuildContext context,
    Map<String, dynamic> dados,
    double tempo,
  ) {
    final l = context.l10n;
    final criatura = game.criaturaDaRunSalva();
    return Row(
      children: [
        if (criatura != null) ...[
          SpriteUi(
            caminho: criatura.spritePath,
            tamanho: Vector2(32, 32),
            cor1: criatura.corClara,
            cor2: criatura.corEscura,
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.resumo_dungeon(dados['dungeon'] as int, dados['andar'] as int),
                style: const TextStyle(color: UiTheme.txtCor, fontSize: 14),
              ),
              Text(
                l.victory_tempo(CreaturesRogueGame.formatarTempo(tempo)),
                style: const TextStyle(color: UiTheme.txtCor, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rotulo(String texto) => Text(
    texto,
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: UiTheme.txtCor,
      fontSize: 12,
      letterSpacing: 3,
    ),
  );

  Widget _linha(String rotulo, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(
      children: [
        Expanded(
          child: Text(
            rotulo,
            style: const TextStyle(color: UiTheme.txtCor, fontSize: 14),
          ),
        ),
        Text(
          valor,
          style: const TextStyle(
            color: UiTheme.txtCor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
