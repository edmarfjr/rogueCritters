import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/audio/ui_sfx.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/core/responsive.dart';
import 'package:creatures_rogue/game/components/core/ui_theme.dart';
import 'package:creatures_rogue/game/components/creatures/creature_data.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/creatures/creature_type.dart';
import 'package:creatures_rogue/game/components/enemies/enemy.dart'
    show CampeaoTipo;
import 'package:creatures_rogue/game/components/items/consumable_item.dart';
import 'package:creatures_rogue/game/components/items/item_descritor.dart';
import 'package:creatures_rogue/game/components/items/item_efeito.dart';
import 'package:creatures_rogue/game/creatures_rogue_game.dart';
import 'package:creatures_rogue/game/overlays/creature_select_overlay.dart';
import 'package:creatures_rogue/game/overlays/selecao_widgets.dart';
import 'package:creatures_rogue/l10n/creature_i18n.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';

/// Manual de instruções no estilo dos livretos de cartucho: páginas de papel,
/// número no rodapé, caixas de DICA e fichas de inimigo.
///
/// Conteúdo FIXO e só do começo do jogo (primeiras masmorras, itens da pool
/// inicial): é um manual, não o compêndio — o que o jogador ainda não viu
/// fica, no máximo, insinuado. Em paisagem as páginas aparecem em pares, como
/// o livreto aberto; em retrato, uma por vez.
class ManualOverlay extends StatefulWidget {
  final CreaturesRogueGame game;
  const ManualOverlay({super.key, required this.game});

  @override
  State<ManualOverlay> createState() => _ManualOverlayState();
}

typedef _Pagina = ({String? titulo, Widget Function() corpo});

class _ManualOverlayState extends State<ManualOverlay> {
  /// Primeira página visível.
  int _pagina = 0;

  static const Color _papel = UiTheme.manualPapelCor;
  static const Color _tinta = UiTheme.manualTintaCor;
  static const Color _destaque = UiTheme.manualDestaqueCor;
  static const Color _linha = UiTheme.manualLinhaCor;

  /// Lado de todo sprite do manual (criaturas, itens, ícones), pra página
  /// não misturar tamanhos.
  static const double _ladoSprite = 40;

  void _irPara(int pagina, int porVez, int total) {
    final alvo = (pagina ~/ porVez) * porVez;
    if (alvo < 0 || alvo >= total || alvo == _pagina) return;
    setState(() => _pagina = alvo);
  }

  void _fechar() {
    widget.game.overlays.remove('Manual');
    widget.game.overlays.add('MainMenu');
  }

  @override
  Widget build(BuildContext context) {
    final paginas = _paginas(context);
    final porVez = Responsive.ehRetrato(context) ? 1 : 2;
    // Girar o aparelho com uma página ímpar aberta: alinha no par.
    final inicio = (_pagina ~/ porVez) * porVez;
    final total = paginas.length;

    final visiveis = [
      for (var i = inicio; i < inicio + porVez; i++)
        Expanded(
          child: i < total ? _folha(paginas[i], i) : const SizedBox.shrink(),
        ),
    ];

    return Material(
      color: UiTheme.manualMesaCor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onHorizontalDragEnd: (detalhes) {
                    final v = detalhes.primaryVelocity ?? 0;
                    if (v < -200) {
                      withCursorSfx(
                        () => _irPara(inicio + porVez, porVez, total),
                      )!();
                    } else if (v > 200) {
                      withCursorSfx(
                        () => _irPara(inicio - porVez, porVez, total),
                      )!();
                    }
                  },
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 440.0 * porVez),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var k = 0; k < visiveis.length; k++) ...[
                            // Lombada entre as duas páginas do livreto aberto.
                            if (k > 0) Container(width: 3, color: _tinta),
                            visiveis[k],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _navegacao(inicio, porVez, total),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navegacao(int inicio, int porVez, int total) {
    final fim = (inicio + porVez).clamp(0, total);
    final rotulo = porVez == 1 || fim - inicio == 1
        ? '${inicio + 1} / $total'
        : '${inicio + 1}-$fim / $total';
    Widget seta(IconData icone, VoidCallback? acao) => IconButton(
      onPressed: withCursorSfx(acao),
      icon: Icon(icone),
      color: _papel,
      disabledColor: _linha.withValues(alpha: 0.4),
    );

    return Row(
      children: [
        IconButton(
          onPressed: withVoltarSfx(_fechar),
          icon: const Icon(Icons.close, color: _papel),
        ),
        const Spacer(),
        seta(
          Icons.chevron_left,
          inicio > 0 ? () => _irPara(inicio - porVez, porVez, total) : null,
        ),
        SizedBox(
          width: 90,
          child: Text(
            rotulo,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _papel, fontSize: 14),
          ),
        ),
        seta(
          Icons.chevron_right,
          fim < total ? () => _irPara(inicio + porVez, porVez, total) : null,
        ),
        const Spacer(),
        // Contrapeso do botão de fechar: mantém a numeração centrada.
        const SizedBox(width: 48),
      ],
    );
  }

  // ------------------------------------------------------------ página

  Widget _folha(_Pagina pagina, int indice) {
    return Container(
      color: _papel,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pagina.titulo != null) ...[
            Text(
              pagina.titulo!,
              style: const TextStyle(
                color: _destaque,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Container(height: 2, color: _tinta),
            const SizedBox(height: 8),
          ],
          // Página que não cabe numa tela baixa rola, em vez de estourar.
          Expanded(child: SingleChildScrollView(child: pagina.corpo())),
          // Capa sem número, como no livreto.
          if (indice > 0)
            Text(
              '- ${indice + 1} -',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _tinta, fontSize: 11),
            ),
        ],
      ),
    );
  }

  List<_Pagina> _paginas(BuildContext context) {
    final l = context.l10n;
    late final List<_Pagina> paginas;
    paginas = [
      (titulo: null, corpo: () => _capa(context)),
      (titulo: l.manual_indice, corpo: () => _indice(paginas)),
      (titulo: l.manual_historia, corpo: () => _historia(context)),
      (titulo: l.manual_controles, corpo: () => _controles(context)),
      (titulo: l.manual_tela, corpo: () => _tela(context)),
      (titulo: l.manual_criatura, corpo: () => _criatura(context)),
      (titulo: l.manual_grupo, corpo: () => _grupo(context)),
      (titulo: l.manual_elementos, corpo: () => _elementos(context)),
      (titulo: l.manual_afinidade, corpo: () => _afinidade(context)),
      (titulo: l.manual_masmorra, corpo: () => _masmorra(context)),
      (titulo: l.manual_salas, corpo: () => _salas(context)),
      (titulo: l.manual_itens, corpo: () => _itens(context)),
      (titulo: l.manual_consumiveis, corpo: () => _consumiveis(context)),
      (
        titulo: '${l.manual_inimigos} I',
        corpo: () => _inimigos(context, [
          (CreatureRegistry.roedorFogo, l.manual_inimigoRoedor),
          (CreatureRegistry.tartarugaPlanta, l.manual_inimigoTartaruga),
          (CreatureRegistry.sapoAgua, l.manual_inimigoSapo),
          (CreatureRegistry.aveEletrica, l.manual_inimigoAve),
        ], comTexto: true),
      ),
      (
        titulo: '${l.manual_inimigos} II',
        corpo: () => _inimigos(context, [
          (CreatureRegistry.tornadoFogo, l.manual_inimigoTornado),
          (CreatureRegistry.ursoPlanta, l.manual_inimigoUrso),
          (CreatureRegistry.cobraAgua, l.manual_inimigoCobra),
          (CreatureRegistry.griloEletrico, l.manual_inimigoGrilo),
        ]),
      ),
      (titulo: l.manual_campeoes, corpo: () => _campeoes(context)),
      (titulo: l.manual_dicas, corpo: () => _dicas(context)),
      (titulo: null, corpo: () => _contracapa(context)),
    ];
    return paginas;
  }

  // ------------------------------------------------------------ blocos

  Widget _texto(
    String texto, {
    double tamanho = 12,
    bool negrito = false,
    Color cor = _tinta,
    TextAlign alinhamento = TextAlign.left,
  }) {
    return Text(
      texto,
      textAlign: alinhamento,
      style: TextStyle(
        color: cor,
        fontSize: tamanho,
        height: 1.25,
        fontWeight: negrito ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _paragrafo(String texto) =>
      Padding(padding: const EdgeInsets.only(bottom: 8), child: _texto(texto));

  /// Caixa de DICA!/ATENÇÃO!/BOATO! — o quadro que todo manual tinha.
  Widget _caixa(String rotulo, String texto) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: _destaque, width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _texto(rotulo, negrito: true, cor: _destaque, tamanho: 13),
          const SizedBox(height: 2),
          _texto(texto),
        ],
      ),
    );
  }

  Widget _linhaIcone(Widget icone, String texto, {String? titulo}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _ladoSprite + 12,
            child: Center(child: icone),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (titulo != null) _texto(titulo, negrito: true),
                _texto(texto),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sprite(
    String caminho,
    double lado, {
    Color cor1 = Palette.cinza,
    Color cor2 = Palette.cinzaEsc,
    Color? corBranco,
  }) {
    return SpriteUi(
      caminho: caminho,
      tamanho: Vector2.all(lado),
      cor1: cor1,
      cor2: cor2,
      corBranco: corBranco,
    );
  }

  /// Primeiro quadro de uma tira horizontal de [quadros] quadros quadrados
  /// (os botões da Hud vêm em tira: solto / apertado).
  Widget _primeiroQuadro(
    String caminho, {
    required int quadros,
    required double lado,
    Color cor1 = UiTheme.actionButtonCor1,
    Color cor2 = UiTheme.actionButtonCor2,
  }) {
    return SizedBox(
      width: lado,
      height: lado,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: lado * quadros,
          maxWidth: lado * quadros,
          minHeight: lado,
          maxHeight: lado,
          child: SpriteUi(
            caminho: caminho,
            tamanho: Vector2(lado * quadros, lado),
            cor1: cor1,
            cor2: cor2,
          ),
        ),
      ),
    );
  }

  static const Map<CreatureType, String> _iconeDoTipo = {
    CreatureType.fogo: 'ui/fogo.png',
    CreatureType.agua: 'ui/agua.png',
    CreatureType.planta: 'ui/planta.png',
    CreatureType.eletrico: 'ui/eletrico.png',
  };

  Widget _iconeTipo(CreatureType tipo, double lado) => _sprite(
    _iconeDoTipo[tipo] ?? 'ui/ataque.png',
    lado,
    cor1: UiTheme.corDoTipo(tipo),
    cor2: UiTheme.corDoTipo2(tipo),
    corBranco: Palette.branco,
  );

  Widget _itemLinha(BuildContext context, ItemDescritor item, String texto) {
    return _linhaIcone(
      _sprite(item.spritePath, _ladoSprite, cor1: item.cor1, cor2: item.cor2),
      texto,
      titulo: item.nome(context),
    );
  }

  /// Número em círculo das legendas da tela de jogo.
  Widget _marcador(int n, {double lado = 15, bool contorno = false}) {
    return Container(
      width: lado,
      height: lado,
      alignment: Alignment.center,
      // Contorno branco sobre a captura, pra não sumir no cenário.
      decoration: BoxDecoration(
        color: _destaque,
        shape: BoxShape.circle,
        border: contorno ? Border.all(color: Palette.branco, width: 1.5) : null,
      ),
      child: Text(
        '$n',
        style: TextStyle(
          color: Palette.branco,
          fontSize: lado * 0.62,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ------------------------------------------------------------ páginas

  Widget _capa(BuildContext context) {
    final l = context.l10n;
    return LayoutBuilder(
      builder: (context, c) {
        final largura = c.maxWidth;
        return Column(
          children: [
            const SizedBox(height: 12),
            SpriteUi(
              caminho: 'title.png',
              tamanho: Vector2(largura, largura / 5),
              cor1: Palette.lemon,
              cor2: Palette.indigo,
            ),
            const SizedBox(height: 14),
            _texto(
              l.manual_capaSub,
              tamanho: 16,
              negrito: true,
              cor: _destaque,
              alinhamento: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final c in [
                  CreatureRegistry.roedorFogo,
                  CreatureRegistry.tartarugaPlanta,
                  CreatureRegistry.sapoAgua,
                  CreatureRegistry.aveEletrica,
                ])
                  CreatureSprite(creature: c, size: _ladoSprite),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: _tinta, width: 2),
              ),
              child: _texto(
                l.manual_capaAviso,
                tamanho: 11,
                alinhamento: TextAlign.center,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _indice(List<_Pagina> paginas) {
    final porVez = Responsive.ehRetrato(context) ? 1 : 2;
    return Column(
      children: [
        for (var i = 2; i < paginas.length; i++)
          if (paginas[i].titulo != null)
            InkWell(
              onTap: withCursorSfx(() => _irPara(i, porVez, paginas.length)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Flexible(child: _texto(paginas[i].titulo!, negrito: true)),
                    // Os pontinhos do sumário, até o número da página.
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '.' * 60,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(color: _linha, fontSize: 12),
                        ),
                      ),
                    ),
                    _texto('${i + 1}', negrito: true),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _historia(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final t in _iconeDoTipo.keys)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _iconeTipo(t, _ladoSprite),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _paragrafo(l.intro_pagina1),
        _paragrafo(l.intro_pagina2),
        _paragrafo(l.intro_pagina3),
        _paragrafo(l.intro_pagina4),
      ],
    );
  }

  Widget _controles(BuildContext context) {
    final l = context.l10n;
    Widget metade(String rotulo, IconData icone) => Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icone, color: _tinta, size: 22),
          const SizedBox(height: 4),
          _texto(rotulo, negrito: true, tamanho: 11),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _texto(l.manual_ctrlToque, negrito: true, cor: _destaque),
        const SizedBox(height: 6),
        // O aparelho deitado, dividido nas duas metades.
        AspectRatio(
          aspectRatio: 2.2,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: _tinta, width: 3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                metade(l.manual_ctrlMoverCurto, Icons.open_with),
                Container(width: 2, color: _linha),
                metade(l.manual_ctrlAtacarCurto, Icons.gps_fixed),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _paragrafo(l.manual_ctrlMover),
        _paragrafo(l.manual_ctrlAtacar),
        _paragrafo(l.manual_ctrlModos),
        _linhaIcone(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _primeiroQuadro(
                'ui/btnDefesa.png',
                quadros: 2,
                lado: _ladoSprite,
              ),
              _primeiroQuadro('ui/btnTroca.png', quadros: 2, lado: _ladoSprite),
            ],
          ),
          l.settings_controleBotoesDesc,
          titulo: l.settings_controleBotoes,
        ),
        _linhaIcone(
          const Icon(Icons.touch_app, color: _tinta, size: 24),
          l.settings_controleGestosDesc,
          titulo: l.settings_controleGestos,
        ),
        _paragrafo(l.manual_ctrlConsumivel),
        _caixa(l.manual_ctrlTeclado, l.manual_ctrlTecladoTexto),
      ],
    );
  }

  Widget _tela(BuildContext context) {
    final l = context.l10n;
    final legendas = [
      l.manual_hudVida,
      l.manual_hudEnergia,
      l.manual_hudHab2,
      l.manual_hudCargas,
      l.manual_hudGrupo,
      l.manual_hudAndar,
      l.manual_hudMoedas,
      l.manual_hudMapa,
      l.manual_hudXp,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _telaCapturada(),
        const SizedBox(height: 8),
        for (var i = 0; i < legendas.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _marcador(i + 1),
                const SizedBox(width: 6),
                Expanded(child: _texto(legendas[i], tamanho: 11)),
              ],
            ),
          ),
      ],
    );
  }

  /// Canto superior esquerdo de cada número sobre a captura, em fração da
  /// imagem, na ordem das legendas. Trocou a captura? Revise estes pontos.
  static const List<(double, double)> _marcadoresTela = [
    (0.10, 0.012), // vida e escudo
    (0.115, 0.09), // energia
    (0.19, 0.09), // habilidade 2
    (0.245, 0.005), // cargas de sala
    (0.095, 0.145), // grupo
    (0.36, 0.075), // andar - masmorra
    (0.52, 0.075), // moedas
    (0.745, 0.02), // mapa
    (0.31, 0.935), // xp
  ];

  /// Captura da tela de jogo com os números da legenda por cima.
  Widget _telaCapturada() {
    return AspectRatio(
      aspectRatio: 1079 / 1093,
      child: LayoutBuilder(
        builder: (context, c) {
          final lado = (c.maxWidth * 0.05).clamp(14.0, 24.0);
          return Container(
            // Borda por cima, sem encolher a imagem: as frações de
            // [_marcadoresTela] valem pra imagem inteira.
            foregroundDecoration: BoxDecoration(
              border: Border.all(color: _tinta, width: 3),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/manualTela.jpg',
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                for (var i = 0; i < _marcadoresTela.length; i++)
                  Positioned(
                    left: c.maxWidth * _marcadoresTela[i].$1,
                    top: c.maxHeight * _marcadoresTela[i].$2,
                    child: _marcador(i + 1, lado: lado, contorno: true),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _criatura(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _paragrafo(l.manual_criaturaTexto),
        _linhaIcone(
          _iconeTipo(CreatureType.fogo, _ladoSprite),
          l.manual_criaturaHab1,
        ),
        _linhaIcone(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sprite('ui/defesa.png', _ladoSprite),
              _sprite('ui/esquiva.png', _ladoSprite),
            ],
          ),
          l.manual_criaturaHab2,
        ),
        _linhaIcone(
          _sprite(
            'ui/escudo.png',
            _ladoSprite,
            cor1: Palette.azul,
            cor2: Palette.azulEsc,
          ),
          l.manual_criaturaEscudo,
        ),
        _linhaIcone(
          CreatureSprite(
            creature: CreatureRegistry.roedorFogo,
            size: _ladoSprite,
          ),
          l.manual_criaturaPassiva,
        ),
        _caixa(l.manual_dica, l.manual_criaturaDica),
      ],
    );
  }

  Widget _grupo(BuildContext context) {
    final l = context.l10n;
    final base = CreatureRegistry.roedorFogo;
    final evoluida = base.evoluir?.call();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (evoluida != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CreatureSprite(creature: base, size: _ladoSprite),
              const Icon(Icons.arrow_forward, color: _destaque),
              CreatureSprite(creature: evoluida, size: _ladoSprite),
            ],
          ),
        const SizedBox(height: 6),
        _paragrafo(l.manual_grupoEvolucao),
        _paragrafo(l.manual_grupoAposentar),
        _paragrafo(l.manual_grupoTexto),
        _paragrafo(l.manual_grupoDesmaio),
        _paragrafo(l.manual_grupoRecrutar),
        _caixa(l.manual_atencao, l.manual_grupoDica),
      ],
    );
  }

  Widget _elementos(BuildContext context) {
    final l = context.l10n;
    // Exatamente os pares de `creature_type.dart`.
    const fortes = [
      (CreatureType.fogo, CreatureType.planta),
      (CreatureType.planta, CreatureType.eletrico),
      (CreatureType.eletrico, CreatureType.agua),
      (CreatureType.agua, CreatureType.fogo),
    ];
    const fracos = [
      (CreatureType.fogo, CreatureType.agua),
      (CreatureType.planta, CreatureType.fogo),
      (CreatureType.agua, CreatureType.eletrico),
      (CreatureType.eletrico, CreatureType.planta),
    ];

    Widget par((CreatureType, CreatureType) p, String mult) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _iconeTipo(p.$1, _ladoSprite),
          const Icon(Icons.arrow_forward, color: _tinta, size: 16),
          _iconeTipo(p.$2, _ladoSprite),
          const SizedBox(width: 6),
          // Largura fixa pros x2 e x0.5 alinharem; sem quebra de linha.
          SizedBox(
            width: 52,
            child: Text(
              mult,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                color: _tinta,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _paragrafo(l.manual_elementosTexto),
        _texto(
          l.manual_elementosForte,
          negrito: true,
          cor: _destaque,
          alinhamento: TextAlign.center,
        ),
        for (final p in fortes) par(p, 'x2'),
        const SizedBox(height: 6),
        _texto(
          l.manual_elementosFraco,
          negrito: true,
          cor: _destaque,
          alinhamento: TextAlign.center,
        ),
        for (final p in fracos) par(p, 'x0.5'),
        const SizedBox(height: 8),
        _paragrafo(l.manual_elementosNeutro),
        _caixa(l.manual_dica, l.manual_elementosDica),
      ],
    );
  }

  Widget _afinidade(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _paragrafo(l.manual_afinidadeTexto),
        _linhaIcone(
          _iconeTipo(CreatureType.fogo, _ladoSprite),
          l.manual_afinidadeFogo,
        ),
        _linhaIcone(
          _iconeTipo(CreatureType.agua, _ladoSprite),
          l.manual_afinidadeAgua,
        ),
        _linhaIcone(
          _iconeTipo(CreatureType.planta, _ladoSprite),
          l.manual_afinidadePlanta,
        ),
        _linhaIcone(
          _iconeTipo(CreatureType.eletrico, _ladoSprite),
          l.manual_afinidadeEletrico,
        ),
        _caixa(l.manual_dica, l.manual_afinidadeDiversidade),
      ],
    );
  }

  Widget _masmorra(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _paragrafo(l.manual_masmorraTexto),
        _linhaIcone(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sprite(
                'items/fruta.png',
                _ladoSprite,
                cor1: Palette.laranja,
                cor2: Palette.verdeEsc,
              ),
              _sprite(
                'ui/moeda.png',
                _ladoSprite,
                cor1: Palette.amarelo,
                cor2: Palette.laranja,
              ),
            ],
          ),
          l.manual_masmorraRecompensa,
        ),
        _paragrafo(l.manual_masmorraEscada),
        _paragrafo(l.manual_masmorraMapa),
        _caixa(l.manual_dica, l.manual_masmorraDica),
      ],
    );
  }

  Widget _salas(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _paragrafo(l.manual_salaTesouro),
        _paragrafo(l.manual_salaLoja),
        _paragrafo(l.manual_salaDesafio),
        _paragrafo(l.manual_salaEvento),
        _caixa(l.manual_boato, l.manual_salaSegredo),
      ],
    );
  }

  Widget _itens(BuildContext context) {
    final l = context.l10n;
    // Só itens da pool inicial (fora de `ProgressaoItens.porNivel`): o
    // jogador pode achar qualquer um deles já na primeira jornada.
    const ids = [
      'estilhaco',
      'couraca',
      'eloDoGrupo',
      'frenesi',
      'segundoFolego',
      'bussola',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _paragrafo(l.manual_itensTexto),
        for (final id in ids)
          if (ItemEfeitoRegistry.porId(id) case final item?)
            _itemLinha(context, item, item.descricao(context)),
        _caixa(l.manual_dica, l.manual_itensDica),
      ],
    );
  }

  Widget _consumiveis(BuildContext context) {
    final l = context.l10n;
    // Texto próprio do manual, e não a `descricao` do consumível: aquela é o
    // aviso curto que sobe na tela quando o efeito acontece.
    String texto(ConsumableType tipo) => switch (tipo) {
      ConsumableType.pocao => l.manual_consPocao,
      ConsumableType.escudo => l.manual_consEscudo,
      ConsumableType.congelar => l.manual_consCongelar,
      ConsumableType.mapa => l.manual_consMapa,
      ConsumableType.doce => l.manual_consDoce,
      ConsumableType.espelho => l.manual_consEspelho,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _paragrafo(l.manual_consumiveisTexto),
        for (final tipo in ConsumableType.values)
          _itemLinha(context, tipo, texto(tipo)),
      ],
    );
  }

  Widget _inimigos(
    BuildContext context,
    List<(CreatureData, String)> fichas, {
    bool comTexto = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (comTexto) _paragrafo(context.l10n.manual_inimigosTexto),
        for (final (criatura, texto) in fichas)
          _ficha(context, criatura, texto),
      ],
    );
  }

  Widget _ficha(BuildContext context, CreatureData criatura, String texto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(border: Border.all(color: _tinta, width: 2)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CreatureSprite(creature: criatura, size: _ladoSprite),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: _texto(
                        creatureName(context, criatura.id).toUpperCase(),
                        negrito: true,
                        tamanho: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    EtiquetaTipo(
                      tipo: criatura.tipo,
                      rotulo: CreatureSelectOverlay.typeLabel(
                        context,
                        criatura.tipo,
                      ),
                      fontSize: 9,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                _texto(texto, tamanho: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _campeoes(BuildContext context) {
    final l = context.l10n;
    Widget aura(CampeaoTipo tipo, CreatureData criatura) => Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tipo.corAura.withValues(alpha: 0.5),
        border: Border.all(color: tipo.corAura, width: 2),
      ),
      child: CreatureSprite(creature: criatura, size: _ladoSprite),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _paragrafo(l.manual_campeoesTexto),
        _linhaIcone(
          aura(CampeaoTipo.couracado, CreatureRegistry.tartarugaPlanta),
          l.manual_campeaoCouracado,
        ),
        _linhaIcone(
          aura(CampeaoTipo.veloz, CreatureRegistry.aveEletrica),
          l.manual_campeaoVeloz,
        ),
        _linhaIcone(
          aura(CampeaoTipo.explosivo, CreatureRegistry.roedorFogo),
          l.manual_campeaoExplosivo,
        ),
        const SizedBox(height: 6),
        // O chefe só em silhueta: quem ele é fica pra masmorra contar.
        Center(
          child: CreatureSprite(
            creature: CreatureRegistry.ursoPlanta,
            size: _ladoSprite * 1.5,
            tudoPreto: true,
          ),
        ),
        const SizedBox(height: 6),
        _paragrafo(l.manual_chefeTexto),
      ],
    );
  }

  Widget _dicas(BuildContext context) {
    final l = context.l10n;
    final dicas = [
      l.manual_dica1,
      l.manual_dica2,
      l.manual_dica3,
      l.manual_dica4,
      l.manual_dica5,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < dicas.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _marcador(i + 1, lado: 18),
                const SizedBox(width: 8),
                Expanded(child: _texto(dicas[i])),
              ],
            ),
          ),
      ],
    );
  }

  Widget _contracapa(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 30),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final c in [
              CreatureRegistry.roedorFogo,
              CreatureRegistry.sapoAgua,
              CreatureRegistry.tartarugaPlanta,
              CreatureRegistry.aveEletrica,
            ])
              CreatureSprite(creature: c, size: _ladoSprite),
          ],
        ),
        const SizedBox(height: 24),
        _texto(
          context.l10n.manual_fim,
          tamanho: 16,
          negrito: true,
          cor: _destaque,
          alinhamento: TextAlign.center,
        ),
      ],
    );
  }
}
