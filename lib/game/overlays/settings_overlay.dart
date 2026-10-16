import 'package:creatures_rogue/game/paleta_tela.dart';
import 'package:creatures_rogue/game/audio/ui_sfx.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/core/ui_theme.dart';
import 'package:creatures_rogue/game/components/core/responsive.dart';
import 'package:creatures_rogue/game/run_save.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/components/creatures/creature_progress.dart';
import 'package:creatures_rogue/game/creatures_rogue_game.dart';
import 'package:creatures_rogue/game/game_settings.dart';
import 'package:creatures_rogue/l10n/gen/app_localizations.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';

class SettingsOverlay extends StatefulWidget {
  final CreaturesRogueGame game;
  const SettingsOverlay({super.key, required this.game});

  @override
  State<SettingsOverlay> createState() => _SettingsOverlayState();
}

/// Stateful por causa do seletor de controle: trocar o esquema já vale no jogo
/// na hora (o setter de `controlScheme` remonta os componentes), mas a tela
/// precisa se redesenhar pra mostrar qual está escolhido.
///
/// A escolha é gravada em disco por [GameSettings], então sobrevive ao
/// fechamento do app.
class _SettingsOverlayState extends State<SettingsOverlay> {
  bool _resetado = false;

  Future<void> _resetar() async {
    await CreatureProgress.instance.resetIntro();
    await RunSave.instance.apagar();
    if (mounted) setState(() => _resetado = true);
  }

  /// Não dá pra desfazer (apaga criaturas liberadas + intro), então confirma
  /// antes — mesmo padrão de qualquer ação destrutiva: pergunta, não executa
  /// direto no toque do botão.
  Future<void> _confirmarReset() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: UiTheme.btnCor,
        shape: const BordaDuplaShape(),
        title: Text(
          context.l10n.settings_confirmarResetTitulo,
          style: const TextStyle(
            color: UiTheme.txtCor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          context.l10n.settings_confirmarResetMensagem,
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

    if (confirmou == true) await _resetar();
  }

  /// O setter de `controlScheme` no jogo remonta os controles na hora, então
  /// a troca vale já na run em andamento; `GameSettings` só cuida do disco.
  Future<void> _escolher(ControlScheme scheme) async {
    widget.game.controlScheme = scheme;
    await GameSettings.instance.setControlScheme(scheme);
    if (mounted) setState(() {});
  }

  // Sem `setState` aqui: `GameSettings.setLocale` já muda `localeNotifier`,
  // que reconstrói o `MaterialApp` inteiro (ver `main.dart`) — esta tela é
  // descendente dele, então reconstrói sozinha já com o idioma novo.
  void _escolherIdioma(Locale? locale) {
    GameSettings.instance.setLocale(locale);
  }

  Future<void> _escolherPaleta(PaletaTela paleta) async {
    await GameSettings.instance.setPaleta(paleta);
    if (mounted) setState(() {});
  }

  Future<void> _alternarSom(bool valor) async {
    await GameSettings.instance.setSoundEnabled(valor);
    if (mounted) setState(() {});
  }

  Future<void> _alternarMusica(bool valor) async {
    await GameSettings.instance.setMusicEnabled(valor);
    if (mounted) setState(() {});
  }

  /// Sem `await` no caminho do arraste: o `Slider` dispara `onChanged` a cada
  /// passo, e esperar a gravação em disco a cada pixel travaria o dedo. O
  /// `setState` redesenha com o valor novo na hora; a persistência alcança
  /// depois.
  void _mudarVolumeSom(double valor) {
    GameSettings.instance.setSoundVolume(valor);
    setState(() {});
  }

  void _mudarVolumeMusica(double valor) {
    GameSettings.instance.setMusicVolume(valor);
    setState(() {});
  }

  /// Rótulo, barra e porcentagem. Largura fixa porque ele mora num `Wrap`
  /// junto dos interruptores: sem teto, o `Slider` tenta ocupar a linha
  /// inteira e empurra todo o resto pra baixo.
  Widget _seletorVolume({
    required String rotulo,
    required double valor,
    required bool ativo,
    required ValueChanged<double> onChanged,
  }) {
    // Claro quando ativo, como o resto do texto; apagado quando o som ou a
    // música estão desligados.
    final cor = ativo ? UiTheme.txtCor : Palette.indigo;
    // `maxWidth`, e não `width` cravada: este seletor mora numa linha junto do
    // rótulo e do interruptor, e em paisagem cada coluna tem pouco mais de
    // 400px. Com largura fixa a linha inteira passava da coluna por um fio —
    // o overflow de 1px. Com teto, ele encolhe até caber.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 290),
      // SEM `mainAxisSize.min` aqui: `min` manda a Row encolher pro tamanho
      // dos filhos, e o `Expanded` logo abaixo manda ela ocupar tudo. Das duas
      // ordens contrárias sobra um arredondamento de meio pixel — era o
      // "RIGHT OVERFLOWED BY 1.0 PIXELS". Com `Expanded` em cena, o padrão
      // (`max`) é o correto.
      child: Row(
        children: [
          // Caixa de rótulo só quando há rótulo: quem chama hoje passa string
          // vazia (o nome já vem do texto ao lado do interruptor), e reservar
          // 64px pra nada era espremer o seletor à toa.
          if (rotulo.isNotEmpty)
            SizedBox(
              width: 64,
              child: Text(
                rotulo,
                style: TextStyle(color: cor, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Expanded(
            child: Slider(
              value: valor,
              activeColor: cor,
              inactiveColor: UiTheme.btnCor,
              thumbColor: cor,
              // Dez passos, do mudo ao máximo: volume é ajuste grosso, e um
              // seletor contínuo só daria trabalho de acertar a mesma casa
              // decimal de novo depois.
              divisions: 10,
              onChanged: ativo ? onChanged : null,
            ),
          ),
          SizedBox(
            width: 38,
            // `FittedBox` porque "100%" é mais largo que "40%", e a caixa é
            // fixa: sem ele, o valor cheio estoura justo quando o jogador
            // arrasta até o fim.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '${(valor * 100).round()}%',
                style: TextStyle(color: cor, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _alternarGodMode(bool valor) async {
    await GameSettings.instance.setGodMode(valor);
    if (mounted) setState(() {});
  }

  Future<void> _alternarJoysticksFixos(bool valor) async {
    await GameSettings.instance.setJoysticksFixos(valor);
    if (mounted) setState(() {});
  }

  /// Remonta os controles do jogo alem de gravar a preferencia: ligar ou
  /// desligar isto muda o que esta montado na arvore do Flame, e sem o
  /// `_setupControles` a troca so apareceria na proxima abertura do app.
  // Desligado da tela por enquanto; mantido pra voltar.
  // ignore: unused_element
  Future<void> _alternarControlesNaTela(bool valor) async {
    await GameSettings.instance.setControlesNaTela(valor);
    widget.game.remontarControles();
    if (mounted) setState(() {});
  }

  @override
  /// Em RETRATO as seções se empilham, como sempre foi. Em PAISAGEM elas se
  /// dividem em duas colunas: controle de um lado, idioma e áudio do outro.
  ///
  /// O motivo é altura, não estética. O cartão inteiro vive num
  /// `FittedBox(scaleDown)` do `ResponsiveOverlayScaffold`, então numa janela
  /// baixa (celular deitado) a coluna única não estourava — ela ENCOLHIA, e
  /// tudo ficava pequeno demais pra tocar. Duas colunas cortam a altura quase
  /// pela metade e o cartão volta ao tamanho natural.
  ///
  /// Título e botões finais ficam FORA da divisão, atravessando as duas
  /// colunas: são a entrada e a saída da tela, e reparti-los daria duas telas
  /// em vez de uma.
  @override
  Widget build(BuildContext context) {
    final retrato = Responsive.ehRetrato(context);

    return ResponsiveOverlayScaffold(
      background: UiTheme.backgroundMenuCor,
      // Paisagem pede mais largura de referência — com os 480 do padrão, duas
      // colunas nasceriam com 240 cada e o `FittedBox` encolheria tudo de novo,
      // desfazendo o ganho.
      maxWidth: retrato ? 480 : 860,
      // Tudo dentro de um quadro, como os outros painéis: o texto do menu
      // (`txtCor`) é claro, e direto sobre o fundo claro da tela não tinha
      // contraste. No `quadroFundoCor` ele lê.
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: UiTheme.quadroFundoCor,
          border: BordaDupla(cor: Palette.preto, espessura: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.settings_titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: UiTheme.txtCor,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            if (retrato)
              ..._secaoControle(context)
            else
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _secaoControle(context),
                      ),
                    ),
                    const VerticalDivider(
                      color: Palette.preto,
                      thickness: 2,
                      width: 24,
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ..._secaoIdioma(context),
                          ..._secaoPaleta(context),
                          ..._secaoAudio(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (retrato) ...[
              ..._secaoIdioma(context),
              ..._secaoPaleta(context),
              ..._secaoAudio(context),
            ],
            const SizedBox(height: 4),
            ..._botoesFinais(context),
          ],
        ),
      ),
    );
  }

  Widget _rotuloSecao(String texto) => Text(
    texto,
    style: const TextStyle(
      color: UiTheme.txtCor,
      fontSize: 16,
      letterSpacing: 3,
      fontWeight: FontWeight.bold,
    ),
  );

  /// Linha de interruptor: rótulo à esquerda, chave à direita.
  ///
  /// Os três interruptores soltos que existiam aqui (joysticks fixos, god
  /// mode) estavam jogados direto na `Column` de fora, sem linha própria — o
  /// rótulo caía numa linha e a chave na seguinte. Dentro de duas colunas isso
  /// ficaria ainda mais torto.
  Widget _linhaSwitch(String rotulo, bool valor, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          rotulo,
          style: const TextStyle(color: UiTheme.txtCor, fontSize: 14),
        ),
        Switch(
          value: valor,
          activeThumbColor: UiTheme.txtCor,
          activeTrackColor: UiTheme.btnCor,
          inactiveThumbColor: Palette.indigo,
          inactiveTrackColor: Palette.cinzaEsc,
          trackOutlineColor: const WidgetStatePropertyAll(Palette.preto),
          onChanged: onChanged,
        ),
      ],
    );
  }

  List<Widget> _secaoControle(BuildContext context) {
    final atual = widget.game.controlScheme;
    return [
      _rotuloSecao(context.l10n.settings_controle),
      const SizedBox(height: 4),
      // `Wrap`, não `Row`: numa janela estreita, dois botões de controle (cada
      // um com padding horizontal de 24px mais o rótulo) não cabem lado a
      // lado — `Wrap` quebra pra segunda linha em vez de estourar.
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final scheme in ControlScheme.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  backgroundColor: scheme == atual
                      ? UiTheme.btnCorAtivo
                      : UiTheme.btnCor,
                  side: const BorderSide(color: Palette.preto),
                  shape: const BordaDuplaShape(),
                ),
                onPressed: withBtnSfx(
                  scheme == atual ? null : () => _escolher(scheme),
                ),
                child: Text(
                  scheme.rotulo(context),
                  style: TextStyle(
                    fontSize: 16,
                    color: scheme == atual ? Palette.branco : UiTheme.txtCor,
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 5),
      SizedBox(
        width: Responsive.largura(context, 420),
        child: Text(
          atual.descricao(context),
          textAlign: TextAlign.center,
          style: const TextStyle(color: UiTheme.txtCor, fontSize: 13),
        ),
      ),
      _linhaSwitch(
        context.l10n.settings_joysticksFixos,
        GameSettings.instance.joysticksFixos,
        _alternarJoysticksFixos,
      ),
    ];
  }

  List<Widget> _secaoIdioma(BuildContext context) {
    return [
      const SizedBox(height: 4),
      _rotuloSecao(context.l10n.settings_idioma),
      const SizedBox(height: 4),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final MapEntry(key: locale, value: rotulo) in {
            null: context.l10n.settings_idiomaSistema,
            for (final loc in AppLocalizations.supportedLocales)
              loc: loc.languageCode.toUpperCase(),
          }.entries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  backgroundColor: locale == GameSettings.instance.locale
                      ? UiTheme.btnCorAtivo
                      : UiTheme.btnCor,
                  side: const BorderSide(color: Palette.preto),
                  shape: const BordaDuplaShape(),
                ),
                onPressed: withBtnSfx(
                  locale == GameSettings.instance.locale
                      ? null
                      : () => _escolherIdioma(locale),
                ),
                child: Text(
                  rotulo,
                  style: TextStyle(
                    fontSize: 16,
                    color: locale == GameSettings.instance.locale
                        ? Palette.branco
                        : UiTheme.txtCor,
                  ),
                ),
              ),
            ),
        ],
      ),
    ];
  }

  /// Mesmo formato do idioma: um botão por opção, a ativa em destaque.
  List<Widget> _secaoPaleta(BuildContext context) {
    final atual = GameSettings.instance.paletaNotifier.value;
    return [
      const SizedBox(height: 4),
      _rotuloSecao(context.l10n.settings_paleta),
      const SizedBox(height: 4),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final paleta in PaletaTela.values)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                backgroundColor: paleta == atual
                    ? UiTheme.btnCorAtivo
                    : UiTheme.btnCor,
                side: const BorderSide(color: Palette.preto),
                shape: const BordaDuplaShape(),
              ),
              onPressed: withBtnSfx(
                paleta == atual ? null : () => _escolherPaleta(paleta),
              ),
              child: Text(
                paleta.nome(context),
                style: TextStyle(
                  fontSize: 14,
                  color: paleta == atual ? Palette.branco : UiTheme.txtCor,
                ),
              ),
            ),
        ],
      ),
    ];
  }

  List<Widget> _secaoAudio(BuildContext context) {
    return [
      const SizedBox(height: 4),
      _rotuloSecao(context.l10n.settings_audio),
      const SizedBox(height: 2),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          Text(
            context.l10n.settings_som,
            style: const TextStyle(color: UiTheme.txtCor, fontSize: 14),
          ),
          Switch(
            value: GameSettings.instance.soundEnabled,
            activeThumbColor: UiTheme.txtCor,
            activeTrackColor: UiTheme.btnCor,
            inactiveThumbColor: Palette.indigo,
            inactiveTrackColor: Palette.cinzaEsc,
            trackOutlineColor: const WidgetStatePropertyAll(Palette.preto),
            onChanged: (valor) => _alternarSom(valor),
          ),
          // `Flexible` pra ceder largura quando a coluna aperta — sem ele o
          // seletor insiste nos 290 e empurra a linha pra fora.
          Flexible(
            child: _seletorVolume(
              rotulo: '',
              valor: GameSettings.instance.soundVolume,
              // Com o som desligado o seletor não muda nada audível, então
              // fica desabilitado junto: arrastar e não ouvir diferença leria
              // como defeito.
              ativo: GameSettings.instance.soundEnabled,
              onChanged: _mudarVolumeSom,
            ),
          ),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          Text(
            context.l10n.settings_musica,
            style: const TextStyle(color: UiTheme.txtCor, fontSize: 14),
          ),
          Switch(
            value: GameSettings.instance.musicEnabled,
            activeThumbColor: UiTheme.txtCor,
            activeTrackColor: UiTheme.btnCor,
            inactiveThumbColor: Palette.indigo,
            inactiveTrackColor: Palette.cinzaEsc,
            trackOutlineColor: const WidgetStatePropertyAll(Palette.preto),
            onChanged: (valor) => _alternarMusica(valor),
          ),
          Flexible(
            child: _seletorVolume(
              rotulo: '',
              valor: GameSettings.instance.musicVolume,
              ativo: GameSettings.instance.musicEnabled,
              onChanged: _mudarVolumeMusica,
            ),
          ),
        ],
      ),
      _linhaSwitch(
        context.l10n.settings_godMode,
        GameSettings.instance.godMode,
        _alternarGodMode,
      ),
    ];
  }

  List<Widget> _botoesFinais(BuildContext context) {
    return [
      // Apaga a flag de intro e as criaturas liberadas. Sem isto a intro
      // aparece uma vez na vida do aparelho, e não dá pra revê-la sem
      // reinstalar o app.
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: UiTheme.btnCor,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          elevation: 0,
          shape: const BordaDuplaShape(),
        ),
        onPressed: withBtnSfx(_resetado ? null : _confirmarReset),
        child: Text(
          _resetado
              ? context.l10n.settings_progressoResetado
              : context.l10n.settings_resetarProgresso,
          style: const TextStyle(fontSize: 14, color: UiTheme.txtCor),
        ),
      ),
      const SizedBox(height: 4),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: UiTheme.btnCor,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
          elevation: 0,
          shape: const BordaDuplaShape(),
        ),
        onPressed: withVoltarSfx(() {
          widget.game.overlays.remove('Settings');
          widget.game.overlays.add(widget.game.settingsReturnOverlay);
        }),
        child: Text(
          context.l10n.settings_voltar,
          style: const TextStyle(fontSize: 20, color: UiTheme.txtCor),
        ),
      ),
    ];
  }
}
