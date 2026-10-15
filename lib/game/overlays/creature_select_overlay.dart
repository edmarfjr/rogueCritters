import 'dart:ui' as ui;

import 'package:creatures_rogue/game/audio/ui_sfx.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/core/responsive.dart';
import 'package:creatures_rogue/game/components/core/ui_theme.dart';
import 'package:creatures_rogue/game/overlays/selecao_widgets.dart';
import 'package:creatures_rogue/game/components/utils/palette_swapper.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/components/creatures/creature_data.dart';
import 'package:creatures_rogue/game/components/creatures/creature_progress.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/creatures/creature_type.dart';
import 'package:creatures_rogue/game/creatures_rogue_game.dart';
import 'package:creatures_rogue/l10n/ability_passive_i18n.dart';
import 'package:creatures_rogue/l10n/creature_i18n.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';

class CreatureSelectOverlay extends StatefulWidget {
  final CreaturesRogueGame game;
  const CreatureSelectOverlay({super.key, required this.game});

  static String typeLabel(BuildContext context, CreatureType tipo) {
    final l = context.l10n;
    switch (tipo) {
      case CreatureType.fogo:
        return l.creatureType_fogo;
      case CreatureType.planta:
        return l.creatureType_planta;
      case CreatureType.agua:
        return l.creatureType_agua;
      case CreatureType.eletrico:
        return l.creatureType_eletrico;
      case CreatureType.neutro:
        return l.creatureType_neutro;
    }
  }

  static Color typeColor(CreatureType tipo) {
    switch (tipo) {
      case CreatureType.fogo:
        return Palette.vermelho;
      case CreatureType.planta:
        return Palette.verde;
      case CreatureType.agua:
        return Palette.azul;
      case CreatureType.eletrico:
        return Palette.amarelo;
      case CreatureType.neutro:
        return Colors.grey;
    }
  }

  @override
  State<CreatureSelectOverlay> createState() => _CreatureSelectOverlayState();
}

class _CreatureSelectOverlayState extends State<CreatureSelectOverlay> {
  // Nunca abre já selecionando uma criatura travada, mesmo que a ordem de
  // CreatureRegistry.all mude no futuro.
  late CreatureData _selected = CreatureRegistry.all.firstWhere(
    (c) => CreatureProgress.instance.isUnlocked(c.id),
    orElse: () => CreatureRegistry.all.first,
  );

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
            Padding(
              padding: const EdgeInsets.only(
                top: 16,
                bottom: 8,
                left: 8,
                right: 8,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: withVoltarSfx(() {
                      widget.game.overlays.remove('CreatureSelect');
                      widget.game.overlays.add('MainMenu');
                    }),
                    icon: const Icon(Icons.arrow_back, color: UiTheme.txtCor),
                  ),
                  Expanded(
                    child: Text(
                      context.l10n.creatureSelect_titulo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: UiTheme.txtCor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Espaçador do mesmo tamanho do botão — sem ele o título
                  // centraliza no espaço que sobra à direita DO botão, não
                  // no meio de verdade da tela.
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                // Lado a lado (lista de 160px + painel) só cabe numa tela
                // larga o bastante. Numa estreita (celular em retrato), os
                // 160px da lista sozinhos já comeriam quase metade da
                // largura — empilha lista (altura fixa, rolável) em cima do
                // painel de detalhe em vez de espremer os dois na horizontal.
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final list = _CreatureList(
                      selected: _selected,
                      onSelect: (creature) =>
                          setState(() => _selected = creature),
                    );
                    final detail = PainelDetalheCriatura(
                      creature: _selected,
                      onPlay: () => widget.game.startRun(_selected),
                    );

                    // O painel sozinho, dentro de um `Expanded`, esticava até
                    // preencher o que sobrasse — numa tela bem alta (retrato,
                    // celular redimensionado bem estreito) ficava
                    // ridiculamente alto, numa bem larga (paisagem de
                    // desktop) ridiculamente largo. `ConstrainedBox` trava um
                    // teto quadrado de referência e o `Center` deixa a sobra
                    // como respiro em vez de esticar o cartão.
                    final detailLimitado = Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 480,
                          maxHeight: 480,
                        ),
                        child: detail,
                      ),
                    );

                    if (constraints.maxWidth < Responsive.larguraEstreita) {
                      // Frações, e não os 160px fixos de antes: a linha da lista
                      // cresceu (ganhou sprite e etiqueta de tipo), e em 160px
                      // só cabiam duas e meia — a terceira aparecia cortada no
                      // meio, parecendo defeito.
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 2, child: list),
                          const SizedBox(height: 12),
                          Expanded(flex: 3, child: detailLimitado),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 160, child: list),
                        const SizedBox(width: 12),
                        Expanded(child: detailLimitado),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

/// Coluna da esquerda: uma linha por criatura, travada ou não conforme
/// [CreatureProgress].
class _CreatureList extends StatelessWidget {
  final CreatureData selected;
  final ValueChanged<CreatureData> onSelect;

  const _CreatureList({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(0),
      ),
      padding: const EdgeInsets.all(6),
      child: ListView.separated(
        itemCount: CreatureRegistry.all.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final creature = CreatureRegistry.all[index];
          final isSelected = creature.id == selected.id;
          final locked = !CreatureProgress.instance.isUnlocked(creature.id);

          return _CreatureListTile(
            creature: creature,
            isSelected: isSelected,
            locked: locked,
            onTap: locked ? null : () => onSelect(creature),
          );
        },
      ),
    );
  }
}

class _CreatureListTile extends StatelessWidget {
  final CreatureData creature;
  final bool isSelected;
  final bool locked;
  final VoidCallback? onTap;

  const _CreatureListTile({
    required this.creature,
    required this.isSelected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final corTipo = UiTheme.corDoTipo(creature.tipo);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: withCursorSfx(onTap),
        child: Row(
          children: [
            // Seta à esquerda marcando a linha atual. Ocupa lugar mesmo quando
            // invisível: sem isso a lista inteira escorregava alguns pixels
            // toda vez que a seleção mudava de linha.
            SizedBox(
              width: 24,
              child: isSelected
                  ? Icon(Icons.play_arrow, size: 28, color: corTipo)
                  : null,
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(
                  color: UiTheme.quadroFundoCor,
                  // Mesma regra do cartão da intro: seleção muda a COR da linha
                  // de fora, nunca a espessura, pra geometria não se mexer.
                  border: BordaDupla(
                    cor: Palette.preto,
                    corExterna: isSelected ? corTipo : null,
                    espessura: 2,
                  ),
                ),
                child: Row(
                  children: [
                    CreatureSprite(
                      creature: creature,
                      size: 34,
                      tudoPreto: locked,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              locked
                                  ? context.l10n.creatureSelect_bloqueada
                                  : creatureName(context, creature.id),
                              style: const TextStyle(
                                color: UiTheme.txtCor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!locked) ...[
                            const SizedBox(height: 2),
                            EtiquetaTipo(
                              tipo: creature.tipo,
                              rotulo: CreatureSelectOverlay.typeLabel(
                                context,
                                creature.tipo,
                              ),
                              fontSize: 10,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (locked)
                      const Icon(Icons.lock, color: Palette.cinzaEsc, size: 16)
                    // Marca de conclusão: já venceu uma run com esta criatura.
                    else if (CreatureProgress.instance.venceuCom(creature.id))
                      const Icon(Icons.star, color: UiTheme.txtCor, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painel de detalhe: sprite e identidade em cima, status e habilidades
/// embaixo, botão de jogar no pé — o rascunho de paisagem.
///
/// Público porque a janela da criatura selvagem (`WildCreatureInfoOverlay`)
/// mostra a mesma ficha, trocando só os botões do pé por [rodape].
class PainelDetalheCriatura extends StatelessWidget {
  final CreatureData creature;
  final VoidCallback? onPlay;

  /// Substitui o botão JOGAR no pé do painel.
  final Widget? rodape;

  const PainelDetalheCriatura({
    super.key,
    required this.creature,
    this.onPlay,
    this.rodape,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: UiTheme.quadroFundoCor,
        border: BordaDupla(cor: Palette.preto, espessura: 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: _identidade(context)),
          const SizedBox(height: 8),
          const Divider(color: Palette.preto, thickness: 2, height: 2),
          const SizedBox(height: 8),
          Expanded(flex: 4, child: _habilidades(context)),
          const SizedBox(height: 10),
          Center(child: rodape ?? _botaoJogar(context)),
        ],
      ),
    );
  }

  /// Sprite grande à esquerda, nome / tipo / frase / barras à direita.
  Widget _identidade(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: CreatureSprite(creature: creature, size: 110),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(flex: 6, child: _ficha(context)),
      ],
    );
  }

  /// Nome, etiqueta, frase e barras.
  ///
  /// Tudo dentro de `SizedBox` de largura medida + `FittedBox`, a mesma receita
  /// da caixa de habilidade, e aqui ela é OBRIGATÓRIA: o conteúdo tem altura
  /// variável (a frase quebra em uma a três linhas conforme a criatura e a
  /// largura) e o espaço é uma fração fixa do painel. Sem rede, a criatura de
  /// frase mais longa estourava a caixa — era o "BOTTOM OVERFLOWED BY 74
  /// PIXELS" com as barras por cima do texto.
  ///
  /// A largura fixada antes do `FittedBox` é o que mantém a ordem certa:
  /// quebra de linha primeiro, encolher a fonte só se o já quebrado não couber.
  Widget _ficha(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: constraints.maxWidth,
          child: _fichaConteudo(context),
        ),
      ),
    );
  }

  Widget _fichaConteudo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            creatureName(context, creature.id).toUpperCase(),
            style: const TextStyle(
              color: UiTheme.txtCor,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: EtiquetaTipo(
            tipo: creature.tipo,
            rotulo: CreatureSelectOverlay.typeLabel(context, creature.tipo),
          ),
        ),
        const SizedBox(height: 6),
        // A frase é a única coisa aqui que QUEBRA em várias linhas, então fica
        // fora de qualquer `FittedBox` — dentro de um, largura infinita faria
        // dela uma linha só, encolhida até não dar pra ler.
        Text(
          creatureDescription(context, creature.id),
          style: const TextStyle(color: UiTheme.txtCor, fontSize: 13),
        ),
        const SizedBox(height: 8),
        _linhaStatus(
          context.l10n.intro_saudeRotulo,
          creature.stats.maxHp.toDouble(),
          TetosStatus.saude,
          Palette.vermelho,
        ),
        _linhaStatus(
          context.l10n.intro_velocidadeRotulo,
          creature.stats.speed,
          TetosStatus.velocidade,
          Palette.azul,
        ),
        _linhaStatus(
          context.l10n.intro_ataqueRotulo,
          creature.stats.ataque,
          TetosStatus.ataque,
          Palette.laranja,
        ),
        _linhaStatus(
          context.l10n.intro_evasaoRotulo,
          creature.stats.evasao,
          TetosStatus.evasao,
          Palette.verde,
        ),
      ],
    );
  }

  /// Rótulo e barra na MESMA linha, ao contrário da intro: aqui a ficha tem
  /// 6/10 da largura do painel, então cabe lado a lado.
  Widget _linhaStatus(String rotulo, double valor, double teto, Color cor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                rotulo,
                style: const TextStyle(
                  color: UiTheme.txtCor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // `Flexible` porque a ficha agora vive dentro de um `SizedBox` de
          // largura medida: os dez segmentos são largura fixa, e numa janela
          // estreita eles passavam do que sobrava depois do rótulo.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: BarraStatus(valor: valor, teto: teto, cor: cor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _habilidades(BuildContext context) {
    final slotUm = slotUmDaCriatura(context, creature);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _caixaHabilidade(slotUm.nome, slotUm.descricao, ehAtaque: true),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _caixaHabilidade(
            abilityName(context, creature.ability2),
            abilityDescription(context, creature.ability2),
            ehAtaque: false,
          ),
        ),
      ],
    );
  }

  /// Ícone à esquerda, nome em negrito e descrição normal à direita.
  ///
  /// O texto fica num `SizedBox` de largura medida, e não solto dentro do
  /// `FittedBox`: com largura infinita o `Text` nunca quebra — monta tudo numa
  /// linha e o `FittedBox` encolhe a fonte até não dar pra ler. Quebra
  /// primeiro; encolher só se o texto JÁ QUEBRADO ainda não couber.
  Widget _caixaHabilidade(
    String nome,
    String descricao, {
    required bool ehAtaque,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Palette.preto, width: 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            IconeHabilidade(criatura: creature, ehAtaque: ehAtaque),
            const SizedBox(width: 8),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: (constraints.maxWidth - 48).clamp(
                      1.0,
                      double.infinity,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          nome,
                          style: const TextStyle(
                            color: UiTheme.txtCor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          descricao,
                          style: const TextStyle(
                            color: UiTheme.txtCor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botaoJogar(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: UiTheme.btnCor,
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 10),
        elevation: 0,
        shape: const BordaDuplaShape(),
      ),
      onPressed: withBtnSfx(onPlay),
      child: Text(
        context.l10n.creatureSelect_jogar,
        style: const TextStyle(
          fontSize: 18,
          color: UiTheme.txtCor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class CreatureSprite extends StatelessWidget {
  final CreatureData creature;
  final double size;
  final bool tudoPreto;

  const CreatureSprite({
    super.key,
    required this.creature,
    required this.size,
    this.tudoPreto = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: FutureBuilder<ui.Image>(
        // Cache por caminho+cores dentro do PaletteSwapper: mesma textura que
        // o jogo usa, sem reprocessar a cada rebuild.
        future: PaletteSwapper.createSwappedImage(
          imagePath: creature.spritePath,
          lightGrayReplacement: tudoPreto ? Palette.preto : creature.corClara,
          darkGrayReplacement: tudoPreto ? Palette.preto : creature.corEscura,
          whiteReplacement: tudoPreto ? Palette.preto : Palette.branco,
        ),
        builder: (context, snapshot) {
          final image = snapshot.data;
          if (image == null) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.black45,
              ),
            );
          }
          return RawImage(
            image: image,
            width: size,
            height: size,
            // OBRIGATÓRIO: sem `fit`, o paintImage do Flutter assume
            // BoxFit.scaleDown, que só REDUZ. Um sprite de 16x16 já cabe em
            // qualquer caixa maior, então ele ficava desenhado em 16x16 no
            // canto — a caixa crescia com `size`, a imagem não.
            fit: BoxFit.contain,
            // Sem isso o upscale de 16x16 sai borrado.
            filterQuality: FilterQuality.none,
          );
        },
      ),
    );
  }
}
