import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/audio/ui_sfx.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/core/ui_theme.dart';
import 'package:creatures_rogue/game/creatures_rogue_game.dart';
import 'package:creatures_rogue/game/overlays/creature_select_overlay.dart';
import 'package:creatures_rogue/game/components/creatures/afinidade.dart';
import 'package:creatures_rogue/game/components/creatures/creature_data.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';

/// Ficha da criatura selvagem que o jogador encostou na sala da escada: a
/// mesma ficha da tela de seleção ([PainelDetalheCriatura]), com VOLTAR e
/// ESCOLHER no pé. O jogo fica pausado enquanto ela está aberta (ver
/// `CreaturesRogueGame.abrirInfoCriaturaSelvagem`).
class WildCreatureInfoOverlay extends StatelessWidget {
  final CreaturesRogueGame game;
  const WildCreatureInfoOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final criatura = game.npcEmAnalise?.creatureData;
    if (criatura == null) return const SizedBox.shrink();

    return Material(
      color: Palette.preto.withAlpha(180),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            // Mesmo teto da tela de seleção: o painel divide a altura em
            // frações e precisa de uma altura fechada pra isso.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 440),
              child: PainelDetalheCriatura(
                creature: criatura,
                rodape: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_previaAfinidade(context, criatura) case final previa?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          previa,
                          style: const TextStyle(
                            color: UiTheme.txtCor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _botao(
                          context.l10n.settings_voltar,
                          () =>
                              game.fecharInfoCriaturaSelvagem(escolher: false),
                        ),
                        const SizedBox(width: 12),
                        _botao(
                          context.l10n.intro_escolher,
                          () => game.fecharInfoCriaturaSelvagem(escolher: true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// O que o grupo ganha de afinidade recrutando [criatura] — só quando muda
  /// alguma coisa em relação ao grupo de agora.
  String? _previaAfinidade(BuildContext context, CreatureData criatura) {
    final tipos = game.grupo.nonNulls.map((m) => m.criatura.tipo).toList();
    final antes = Afinidade.de(tipos);
    final depois = Afinidade.de([...tipos, criatura.tipo]);
    if (!depois.ativa || depois == antes) return null;
    final tipo = depois.tipo;
    if (tipo == null) return context.l10n.afinidade_previaDiversidade;
    return context.l10n.afinidade_previa(
      CreatureSelectOverlay.typeLabel(context, tipo),
      depois.nivel,
    );
  }

  Widget _botao(String texto, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: UiTheme.btnCor,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        elevation: 0,
        shape: const BordaDuplaShape(),
      ),
      onPressed: withBtnSfx(onPressed),
      child: Text(
        texto.trim(),
        style: const TextStyle(
          fontSize: 18,
          color: UiTheme.txtCor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
