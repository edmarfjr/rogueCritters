import 'package:creatures_rogue/game/components/utils/palette_swapper.dart';
import 'package:creatures_rogue/game/components/items/power_up_item.dart';
import 'package:creatures_rogue/game/components/items/item_descritor.dart';
import 'dart:ui' as ui;
import 'package:creatures_rogue/game/components/core/ui_theme.dart';
import 'package:creatures_rogue/game/audio/ui_sfx.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/core/responsive.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/creatures_rogue_game.dart';
import 'package:creatures_rogue/game/components/creatures/creature_data.dart';
import 'package:creatures_rogue/l10n/ability_passive_i18n.dart';
import 'package:creatures_rogue/l10n/creature_i18n.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';
import 'creature_select_overlay.dart' show CreatureSprite;

class PauseMenuOverlay extends StatefulWidget {
  final CreaturesRogueGame game;
  const PauseMenuOverlay({super.key, required this.game});

  @override
  State<PauseMenuOverlay> createState() => _PauseMenuOverlayState();
}

class _PauseMenuOverlayState extends State<PauseMenuOverlay> {
  /// Aba aberta. Estado local, e nao no jogo: qual aba estava aberta na ultima
  /// pausa nao e informacao de partida, e reabrir no inventario surpreenderia
  /// quem pausou so pra continuar.
  bool _inventario = false;

  CreaturesRogueGame get game => widget.game;

  @override
  Widget build(BuildContext context) {
    return ResponsiveOverlayScaffold(
      background: Palette.preto.withValues(alpha: 0.7),
      // Um pouco mais larga que o padrão: os cards de equipe (ver
      // `_EquipeRow`) precisam de espaço pra caber 2-3 lado a lado antes de
      // `Wrap` empilhar.
      // Em pé o cartão precisa ser estreito pra não encostar nas bordas;
      // deitado sobra largura e 640 deixava tudo espremido numa coluna fina
      // no meio da tela. Valores achados testando no aparelho.
      maxWidth: Responsive.ehRetrato(context) ? 640 : 1140,
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: UiTheme.quadroFundoCor,
          border: const BordaDupla(cor: Palette.preto, espessura: 4),
          borderRadius: BorderRadius.circular(0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.pause_jogoPausado,
              style: const TextStyle(color: UiTheme.txtCor, fontSize: 32),
            ),
            // Tempo de run. Lido no build e nao animado de proposito: o motor
            // esta pausado aqui, entao o valor nao muda enquanto a tela esta
            // aberta — nao ha o que atualizar.
            Text(
              game.tempoDeRunFormatado,
              style: const TextStyle(color: UiTheme.txtCor, fontSize: 18),
            ),
            const SizedBox(height: 5),
            _Abas(
              inventario: _inventario,
              aoTrocar: (v) => setState(() => _inventario = v),
            ),
            const SizedBox(height: 5),
            if (_inventario)
              _InventarioAba(game: game)
            else
              _EquipeRow(game: game),
            const SizedBox(height: 5),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: UiTheme.btnCor,
                padding: const EdgeInsets.symmetric(vertical: 10),
                elevation: 0,
                shape: const BordaDuplaShape(),
              ),
              onPressed: withBtnSfx(() {
                game.overlays.remove('PauseMenu');
                game.resumeEngine();
              }),
              child: Text(
                context.l10n.pause_continuar,
                style: const TextStyle(fontSize: 20, color: UiTheme.txtCor),
              ),
            ),
            const SizedBox(height: 5),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: UiTheme.btnCor,
                padding: const EdgeInsets.symmetric(vertical: 10),
                elevation: 0,
                shape: const BordaDuplaShape(),
              ),
              // Motor continua pausado: só troca de overlay. `VOLTAR` em
              // `SettingsOverlay` lê `settingsReturnOverlay` pra saber que
              // precisa reabrir o PauseMenu, não o MainMenu.
              onPressed: withBtnSfx(() {
                game.overlays.remove('PauseMenu');
                game.settingsReturnOverlay = 'PauseMenu';
                game.overlays.add('Settings');
              }),
              child: Text(
                context.l10n.pause_configuracoes,
                style: const TextStyle(fontSize: 20, color: UiTheme.txtCor),
              ),
            ),
            const SizedBox(height: 5),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: UiTheme.btnCor,
                padding: const EdgeInsets.symmetric(vertical: 10),
                elevation: 0,
                shape: const BordaDuplaShape(),
              ),
              onPressed: withBtnSfx(() {
                game.overlays.remove('PauseMenu');
                game.overlays.remove('Hud');
                game.overlays.add('MainMenu');
                // Chama a sua função de limpar/reiniciar a fase!
                //game.resetGame();
              }),
              child: Text(
                context.l10n.pause_sairParaMenu,
                style: const TextStyle(fontSize: 20, color: UiTheme.txtCor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fileira com um card por slot do grupo (até 3 — ver
/// `CreaturesRogueGame.maxCompanions`). Lê `grupo`, não
/// `companions`: a criatura recolhida no bolso continua no grupo (a passiva
/// dela continua valendo, ver PIVOT_TREINADOR.md) e precisa aparecer aqui
/// igual a uma fora do bolso — só marcada como "no bolso". Slot vazio (grupo
/// ainda não completo) não desenha card nenhum.
class _EquipeRow extends StatelessWidget {
  final CreaturesRogueGame game;
  const _EquipeRow({required this.game});

  @override
  Widget build(BuildContext context) {
    final slots = <Widget>[];
    for (int i = 0; i < game.grupo.length; i++) {
      final membro = game.grupo[i];
      if (membro == null) continue;
      slots.add(
        _EquipeCard(
          creature: membro.criatura,
          pocketed: membro.noBanco,
          ativa: i == game.companionAtivoIndex,
        ),
      );
    }
    if (slots.isEmpty) return const SizedBox.shrink();

    // `Wrap`, não `Row`: até 3 cards de 220-280px lado a lado não cabem numa
    // janela estreita — `Wrap` empilha em vez de estourar a largura.
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: slots,
    );
  }
}

class _EquipeCard extends StatelessWidget {
  final CreatureData creature;
  final bool pocketed;
  final bool ativa;
  const _EquipeCard({
    required this.creature,
    required this.pocketed,
    required this.ativa,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // 280 é a largura "de design"; numa tela muito estreita, `Wrap` só
      // ajuda quando o card em si já cabe — `Responsive.largura` encolhe o
      // card antes de precisar quebrar linha.
      width: Responsive.largura(context, 320),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: UiTheme.quadroFundoCor,
        border: BordaDupla(cor: Palette.preto, espessura: ativa ? 3 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          CreatureSprite(creature: creature, size: 40),
          const SizedBox(height: 4),
          Text(
            creatureName(context, creature.id),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: UiTheme.txtCor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
         // if (pocketed)
         //   Text(
         //     context.l10n.pause_noBolso,
         //     style: const TextStyle(color: Palette.cinzaEsc, fontSize: 9),
         //   ),
          const SizedBox(height: 4),
          Text(
            context.l10n.pause_habilidade(
              slotUmDaCriatura(context, creature).nome,
              slotUmDaCriatura(context, creature).descricao,
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: UiTheme.txtCor, fontSize: 9),
          ),
          Text(
            context.l10n.pause_habilidade(
              abilityName(context, creature.ability2),
              abilityDescription(context, creature.ability2),
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: UiTheme.txtCor, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

/// Duas abas no topo do cartao de pausa. A ativa inverte as cores (fundo
/// preto, texto branco), que e a mesma leitura de "selecionado" que o resto
/// da UI usa.
class _Abas extends StatelessWidget {
  const _Abas({required this.inventario, required this.aoTrocar});

  final bool inventario;
  final ValueChanged<bool> aoTrocar;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Aba(
          texto: context.l10n.pause_abaCriaturas,
          ativa: !inventario,
          aoTocar: () => aoTrocar(false),
        ),
        const SizedBox(width: 4),
        _Aba(
          texto: context.l10n.pause_abaInventario,
          ativa: inventario,
          aoTocar: () => aoTrocar(true),
        ),
      ],
    );
  }
}

class _Aba extends StatelessWidget {
  const _Aba({
    required this.texto,
    required this.ativa,
    required this.aoTocar,
  });

  final String texto;
  final bool ativa;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: withBtnSfx(aoTocar),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: ativa ? UiTheme.txtCor : UiTheme.btnCor,
          border: const BordaDupla(cor: Palette.preto, espessura: 2),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: ativa ? UiTheme.btnCor : UiTheme.txtCor,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

/// Uma entrada do histórico: o item e quantas vezes ele foi pego.
///
/// A contagem só passa de 1 nos upgrades de stat — os `ItemEfeito` são
/// deduplicados por id quando entram em `Player.itens`, então nunca repetem.
class _Entrada {
  const _Entrada(this.item, this.quantidade);
  final ItemDescritor item;
  final int quantidade;
}

/// Aba de inventário: mostra UM item por vez, com setas pros lados.
///
/// Carrossel, e não grade, por causa do `FittedBox(scaleDown)` do
/// `ResponsiveOverlayScaffold`: ele encolhe o cartão inteiro quando o conteúdo
/// cresce, então uma grade faria o menu de pause inteiro (botões inclusive)
/// diminuir a cada item novo da run. O carrossel tem altura fixa, não importa
/// se o histórico tem 2 ou 30 entradas.
class _InventarioAba extends StatefulWidget {
  const _InventarioAba({required this.game});
  final CreaturesRogueGame game;

  @override
  State<_InventarioAba> createState() => _InventarioAbaState();
}

class _InventarioAbaState extends State<_InventarioAba> {
  int _indice = 0;

  /// Itens de gatilho primeiro, upgrades de stat depois.
  ///
  /// Não dá pra intercalar na ordem real de coleta: são duas listas separadas
  /// (`Player.itens` e `Player.upgradesPegos`) e nenhuma guarda quando o item
  /// entrou. Intercalar exigiria um carimbo de tempo que nada mais usaria.
  List<_Entrada> get _entradas {
    final player = widget.game.player;
    final entradas = <_Entrada>[
      for (final item in player.itens) _Entrada(item, 1),
    ];

    // Agrupa upgrades iguais mantendo a posição da PRIMEIRA vez que apareceu —
    // é o que preserva a ordem do histórico mesmo com a contagem agregada.
    final contagem = <PowerUpType, int>{};
    for (final upgrade in player.upgradesPegos) {
      contagem[upgrade] = (contagem[upgrade] ?? 0) + 1;
    }
    for (final entry in contagem.entries) {
      entradas.add(_Entrada(entry.key, entry.value));
    }
    return entradas;
  }

  @override
  Widget build(BuildContext context) {
    final entradas = _entradas;

    if (entradas.isEmpty) {
      return SizedBox(
        width: Responsive.largura(context, 320),
        height: _alturaCarrossel,
        child: Center(
          child: Text(
            context.l10n.pause_inventarioVazio,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Palette.cinzaEsc, fontSize: 16),
          ),
        ),
      );
    }

    // Trava o índice: a lista cresce durante a run, mas também pode encolher
    // entre duas aberturas do pause (criatura aposentada devolve passiva, por
    // exemplo), e um índice velho estouraria.
    final indice = _indice % entradas.length;
    final entrada = entradas[indice];
    final item = entrada.item;
    final unico = entradas.length == 1;

    return SizedBox(
      // Mesma largura de referencia do `_EquipeCard`, e nao a largura natural
      // do conteudo. O `FittedBox(scaleDown)` do `ResponsiveOverlayScaffold`
      // tira a escala do cartao da largura NATURAL do que esta dentro: sem
      // este limite, a descricao do item esticava numa linha so, o cartao
      // media muito mais largo que na aba de criaturas, e o `FittedBox`
      // encolhia tudo — borda, texto e botoes — pra caber.
      //
      // Casar a largura com a da outra aba e o que mantem as duas na mesma
      // escala, e de quebra faz a descricao quebrar linha em vez de esticar.
      width: Responsive.largura(context, 320),
      height: _alturaCarrossel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Com um item só as setas somem em vez de virarem enfeite morto,
              // mas o espaço delas fica reservado pra o sprite não pular de
              // lugar quando o segundo item entrar.
              _Seta(
                icone: Icons.arrow_left,
                aoTocar: unico
                    ? null
                    : () => setState(() => _indice = indice - 1 + entradas.length),
              ),
              const SizedBox(width: 12),
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  ItemSprite(item: item, size: 64),
                  if (entrada.quantidade > 1)
                    Text(
                      'x${entrada.quantidade}',
                      style: const TextStyle(
                        color: UiTheme.txtCor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              _Seta(
                icone: Icons.arrow_right,
                aoTocar: unico
                    ? null
                    : () => setState(() => _indice = indice + 1),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.nome(context),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: UiTheme.txtCor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
         // const SizedBox(height: 10),
          Expanded(
            child: Text(
              item.descricao(context),
              textAlign: TextAlign.center,
              style: const TextStyle(color: UiTheme.txtCor, fontSize: 16),
            ),
          ),
          Text(
            '${indice + 1}/${entradas.length}',
            style: const TextStyle(color: UiTheme.txtCor, fontSize: 16),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  /// Fixa de propósito — ver a doc da classe. Comporta o sprite, o nome e duas
  /// linhas de descrição sem empurrar os botões do menu.
  static const double _alturaCarrossel = 200;
}

class _Seta extends StatelessWidget {
  const _Seta({required this.icone, required this.aoTocar});
  final IconData icone;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    if (aoTocar == null) return const SizedBox(width: 40, height: 40);
    return IconButton(
      onPressed: withBtnSfx(aoTocar!),
      icon: Icon(icone, color: Palette.preto, size: 40),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}

/// Sprite de um item com a paleta já trocada. Irmão do `CreatureSprite`, e
/// pelo mesmo motivo: o PNG em disco é cinza-marcador (169/84) e quem pinta é
/// o [PaletteSwapper], que devolve `ui.Image` em vez de asset.
///
/// Recebe um [ItemDescritor], então desenha igual um `ItemEfeito`, um
/// `PowerUpType` ou um `ConsumableType` — as três famílias já respondem às
/// mesmas perguntas de apresentação.
class ItemSprite extends StatelessWidget {
  const ItemSprite({super.key, required this.item, required this.size});

  final ItemDescritor item;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: FutureBuilder<ui.Image>(
        future: PaletteSwapper.createSwappedImage(
          imagePath: item.spritePath,
          lightGrayReplacement: item.cor1,
          darkGrayReplacement: item.cor2,
        ),
        builder: (context, snapshot) {
          final image = snapshot.data;
          if (image == null) return SizedBox(width: size, height: size);
          return RawImage(
            image: image,
            width: size,
            height: size,
            // Mesma armadilha do `CreatureSprite`: sem `fit`, o padrão do
            // Flutter só REDUZ, e um sprite de 16x16 sairia minúsculo.
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
          );
        },
      ),
    );
  }
}
