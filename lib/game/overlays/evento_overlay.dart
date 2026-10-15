import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/audio/sfx.dart';
import 'package:creatures_rogue/game/audio/ui_sfx.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/core/ui_theme.dart';
import 'package:creatures_rogue/game/creatures_rogue_game.dart';
import 'package:creatures_rogue/game/overlays/selecao_widgets.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';

/// Janela do evento que o jogador encostou (ver `EventoNpc`). O jogo fica
/// pausado enquanto ela está aberta. Fica aberta entre um botão e outro —
/// doar ao mendigo seis vezes não pede seis toques no objeto — e mostra o
/// que o último botão rendeu.
class EventoOverlay extends StatefulWidget {
  final CreaturesRogueGame game;
  const EventoOverlay({super.key, required this.game});

  @override
  State<EventoOverlay> createState() => _EventoOverlayState();
}

class _EventoOverlayState extends State<EventoOverlay> {
  @override
  Widget build(BuildContext context) {
    final evento = widget.game.eventoAberto;
    if (evento == null) return const SizedBox.shrink();
    final resultado = evento.resultado;

    return Material(
      color: Palette.preto.withAlpha(180),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: UiTheme.quadroFundoCor,
                  border: BordaDupla(cor: Palette.preto, espessura: 4),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          SpriteUi(
                            caminho: evento.spritePath,
                            tamanho: Vector2.all(56),
                            cor1: evento.cor1,
                            cor2: evento.cor2,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              evento.titulo(context),
                              style: const TextStyle(
                                color: UiTheme.txtCor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        evento.texto(context),
                        style: const TextStyle(
                          color: UiTheme.txtCor,
                          fontSize: 14,
                        ),
                      ),
                      if (resultado != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          resultado,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: UiTheme.txtCor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      for (final opcao in evento.opcoes(context)) ...[
                        _botao(
                          opcao.rotulo,
                          opcao.bloqueio == null
                              ? () => setState(opcao.acao)
                              : null,
                        ),
                        if (opcao.bloqueio != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              opcao.bloqueio!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Palette.cinzaEsc,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                      _botao(
                        context.l10n.settings_voltar.trim(),
                        widget.game.fecharEvento,
                        som: Sfx.voltar,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _botao(String texto, VoidCallback? onPressed, {Sfx som = Sfx.btn}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: UiTheme.btnCor,
        disabledBackgroundColor: Palette.cinza,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        elevation: 0,
        shape: const BordaDuplaShape(),
      ),
      onPressed: withBtnSfx(onPressed, som: som),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 16,
          color: UiTheme.txtCor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
