import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/audio/ui_sfx.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/core/responsive.dart';
import 'package:creatures_rogue/game/components/core/ui_theme.dart';
import 'package:creatures_rogue/game/components/creatures/creature_data.dart';
import 'package:creatures_rogue/game/components/creatures/creature_progress.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/items/item_efeito.dart';
import 'package:creatures_rogue/game/components/items/progressao_itens.dart';
import 'package:creatures_rogue/game/creatures_rogue_game.dart';
import 'package:creatures_rogue/game/overlays/creature_select_overlay.dart';
import 'package:creatures_rogue/game/overlays/selecao_widgets.dart';
import 'package:creatures_rogue/l10n/creature_i18n.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';

enum _Aba { criaturas, itens, passivas }

/// Compêndio: o que o jogador já encontrou, em três abas — criaturas
/// (bestiário), itens sorteáveis e passivas de aposentadoria.
///
/// Só registra o que acontece DEPOIS de existir (ver os registros em
/// `CreatureProgress`): o passado não foi gravado em lugar nenhum, exceto os
/// abates e os desbloqueios, que o bestiário já aproveita.
class CompendioOverlay extends StatefulWidget {
  final CreaturesRogueGame game;
  const CompendioOverlay({super.key, required this.game});

  @override
  State<CompendioOverlay> createState() => _CompendioOverlayState();
}

class _CompendioOverlayState extends State<CompendioOverlay> {
  _Aba _aba = _Aba.criaturas;
  CreatureData _criatura = CreatureRegistry.all.first;

  /// Mostrando a forma evoluída da [_criatura]?
  bool _evoluida = false;
  ItemEfeito? _item;

  static final List<ItemEfeito> _sorteaveis = ItemEfeitoRegistry.todos
      .where((i) => i.sorteavel)
      .toList();
  static final List<ItemEfeito> _passivas = ItemEfeitoRegistry.todos
      .where((i) => !i.sorteavel)
      .toList();

  CreatureProgress get _progresso => CreatureProgress.instance;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: UiTheme.backgroundMenuCor,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(4),
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: UiTheme.quadroFundoCor,
            border: BordaDupla(cor: Palette.preto, espessura: 3),
          ),
          child: Column(
            children: [
              _cabecalho(context),
              _abas(context),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: switch (_aba) {
                    _Aba.criaturas => _bestiario(context),
                    _Aba.itens => _colecao(context, _sorteaveis),
                    _Aba.passivas => _colecao(context, _passivas),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cabecalho(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 8, right: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: withVoltarSfx(() {
              widget.game.overlays.remove('Compendio');
              widget.game.overlays.add('MainMenu');
            }),
            icon: const Icon(Icons.arrow_back, color: UiTheme.txtCor),
          ),
          Expanded(
            child: Text(
              context.l10n.menu_compendio,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: UiTheme.txtCor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Mesmo espaçador da seleção de criatura: centraliza o título de
          // verdade, e não no que sobra à direita do botão.
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _abas(BuildContext context) {
    final l = context.l10n;
    final criaturasVistas = CreatureRegistry.all
        .where((c) => _progresso.criaturaVista(c.id))
        .length;
    final itensColetados = _sorteaveis
        .where((i) => _progresso.itemColetado(i.id))
        .length;
    final passivasColetadas = _passivas
        .where((i) => _progresso.itemColetado(i.id))
        .length;

    Widget aba(_Aba qual, String rotulo, int tem, int total) {
      final ativa = qual == _aba;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ativa ? UiTheme.btnCorAtivo : UiTheme.btnCor,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              elevation: 0,
              shape: const BordaDuplaShape(),
            ),
            onPressed: withCursorSfx(
              ativa ? null : () => setState(() => _aba = qual),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$rotulo $tem/$total',
                style: TextStyle(
                  fontSize: 14,
                  color: ativa ? Palette.branco : UiTheme.txtCor,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          aba(
            _Aba.criaturas,
            l.compendio_criaturas,
            criaturasVistas,
            CreatureRegistry.all.length,
          ),
          aba(
            _Aba.itens,
            l.compendio_itens,
            itensColetados,
            _sorteaveis.length,
          ),
          aba(
            _Aba.passivas,
            l.compendio_passivas,
            passivasColetadas,
            _passivas.length,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ bestiário

  /// Mesmo arranjo da seleção de criatura: lista + ficha lado a lado, ou
  /// empilhadas numa tela estreita.
  Widget _bestiario(BuildContext context) {
    final lista = ListView.separated(
      itemCount: CreatureRegistry.all.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final c = CreatureRegistry.all[i];
        return _linhaCriatura(context, c);
      },
    );
    final ficha = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 480),
        child: _fichaCriatura(context),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < Responsive.larguraEstreita) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: lista),
              const SizedBox(height: 12),
              Expanded(flex: 3, child: ficha),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 160, child: lista),
            const SizedBox(width: 12),
            Expanded(child: ficha),
          ],
        );
      },
    );
  }

  Widget _linhaCriatura(BuildContext context, CreatureData c) {
    final vista = _progresso.criaturaVista(c.id);
    final selecionada = c.id == _criatura.id;
    return InkWell(
      onTap: withCursorSfx(
        () => setState(() {
          _criatura = c;
          _evoluida = false;
        }),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: UiTheme.quadroFundoCor,
          border: BordaDupla(
            cor: Palette.preto,
            corExterna: selecionada ? UiTheme.corDoTipo(c.tipo) : null,
            espessura: 2,
          ),
        ),
        child: Row(
          children: [
            CreatureSprite(creature: c, size: 34, tudoPreto: !vista),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  vista ? creatureName(context, c.id) : '???',
                  style: const TextStyle(
                    color: UiTheme.txtCor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            MarcaVitoria(creatureId: c.id),
          ],
        ),
      ),
    );
  }

  Widget _fichaCriatura(BuildContext context) {
    final base = _criatura;
    if (!_progresso.criaturaVista(base.id)) {
      return _quadro(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CreatureSprite(creature: base, size: 110, tudoPreto: true),
            const SizedBox(height: 12),
            Text(
              context.l10n.compendio_naoEncontrado,
              textAlign: TextAlign.center,
              style: const TextStyle(color: UiTheme.txtCor, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final temEvo =
        base.evoluir != null && _progresso.evolucaoVista(base.id);
    final mostrada = _evoluida && temEvo ? base.evoluir!() : base;

    return PainelDetalheCriatura(
      creature: mostrada,
      rodape: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.compendio_abates(_progresso.killCount(base.id)),
            style: const TextStyle(
              color: UiTheme.txtCor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (temEvo) ...[
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: UiTheme.btnCor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                elevation: 0,
                shape: const BordaDuplaShape(),
              ),
              onPressed: withBtnSfx(
                () => setState(() => _evoluida = !_evoluida),
              ),
              child: Text(
                _evoluida
                    ? context.l10n.compendio_base
                    : context.l10n.compendio_evolucao,
                style: const TextStyle(color: UiTheme.txtCor, fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------ itens

  /// Grade de ícones + ficha do item tocado. Serve às duas abas de item.
  Widget _colecao(BuildContext context, List<ItemEfeito> itens) {
    final selecionado = itens.contains(_item) ? _item : null;
    final grade = SingleChildScrollView(
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [for (final item in itens) _celulaItem(item, selecionado)],
      ),
    );
    final ficha = _fichaItem(context, selecionado);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < Responsive.larguraEstreita) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: grade),
              const SizedBox(height: 12),
              Expanded(flex: 2, child: ficha),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: grade),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: ficha),
          ],
        );
      },
    );
  }

  Widget _celulaItem(ItemEfeito item, ItemEfeito? selecionado) {
    final coletado = _progresso.itemColetado(item.id);
    final bloqueado =
        !coletado &&
        ProgressaoItens.bloqueado(item, _progresso.nivelProgressao);
    return InkWell(
      onTap: withCursorSfx(() => setState(() => _item = item)),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: UiTheme.quadroFundoCor,
          border: BordaDupla(
            cor: Palette.preto,
            corExterna: item == selecionado ? Palette.amarelo : null,
            espessura: 2,
          ),
        ),
        child: Center(
          child: bloqueado
              ? const Icon(Icons.lock, color: Palette.cinzaEsc, size: 20)
              : _iconeItem(item, coletado, 32),
        ),
      ),
    );
  }

  /// Coletado em cores; o resto em silhueta preta.
  Widget _iconeItem(ItemEfeito item, bool colorido, double lado) {
    return SpriteUi(
      caminho: item.spritePath,
      tamanho: Vector2.all(lado),
      cor1: colorido ? item.cor1 : Palette.preto,
      cor2: colorido ? item.cor2 : Palette.preto,
      corBranco: colorido ? null : Palette.preto,
    );
  }

  Widget _fichaItem(BuildContext context, ItemEfeito? item) {
    final l = context.l10n;
    if (item == null) {
      return _quadro(
        child: Center(
          child: Text(
            l.compendio_toqueNumItem,
            textAlign: TextAlign.center,
            style: const TextStyle(color: UiTheme.txtCor, fontSize: 14),
          ),
        ),
      );
    }

    final coletado = _progresso.itemColetado(item.id);
    final visto = _progresso.itemVisto(item.id);
    final nivel = ProgressaoItens.nivelDoItem(item);
    final bloqueado =
        !coletado &&
        ProgressaoItens.bloqueado(item, _progresso.nivelProgressao);

    final String nome;
    final String texto;
    if (coletado) {
      nome = item.nome(context);
      texto = item.descricao(context);
    } else if (bloqueado && nivel != null) {
      nome = '???';
      texto = l.compendio_liberaNoNivel(nivel);
    } else if (visto) {
      nome = item.nome(context);
      texto = l.compendio_naoColetado;
    } else {
      nome = '???';
      texto = l.compendio_naoEncontrado;
    }

    return _quadro(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bloqueado)
              const Icon(Icons.lock, color: Palette.cinzaEsc, size: 48)
            else
              _iconeItem(item, coletado, 64),
            const SizedBox(height: 8),
            Text(
              nome,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: UiTheme.txtCor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: UiTheme.txtCor, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quadro({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: UiTheme.quadroFundoCor,
        border: BordaDupla(cor: Palette.preto, espessura: 4),
      ),
      child: child,
    );
  }
}
