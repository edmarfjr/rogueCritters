import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/anuncios.dart';
import 'package:creatures_rogue/game/audio/ui_sfx.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/core/ui_theme.dart';
import 'package:creatures_rogue/game/creatures_rogue_game.dart';
import 'package:creatures_rogue/game/overlays/creature_select_overlay.dart';
import 'package:creatures_rogue/l10n/creature_i18n.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';

/// Oferta de reviver, entre a cena de morte e o game over: assistir a um
/// anúncio traz a última criatura de volta com a vida cheia, uma vez por run
/// (ver `CreaturesRogueGame.reviverComAnuncio`). Desistir segue pro game
/// over de sempre.
class ReviverOverlay extends StatefulWidget {
  final CreaturesRogueGame game;
  const ReviverOverlay({super.key, required this.game});

  @override
  State<ReviverOverlay> createState() => _ReviverOverlayState();
}

class _ReviverOverlayState extends State<ReviverOverlay> {
  /// Anúncio na tela: os botões travam até ele fechar.
  bool _assistindo = false;

  /// O último anúncio fechou sem dar a recompensa.
  bool _naoTerminou = false;

  Future<void> _assistir() async {
    setState(() {
      _assistindo = true;
      _naoTerminou = false;
    });
    final reviveu = await widget.game.reviverComAnuncio();
    if (!mounted || reviveu) return;
    setState(() {
      _assistindo = false;
      _naoTerminou = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final criatura = widget.game.player.creatureData;
    final anuncios = Anuncios.instance;

    return Material(
      color: Palette.preto.withAlpha(200),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: UiTheme.quadroFundoCor,
                  border: BordaDupla(cor: Palette.preto, espessura: 4),
                ),
                child: ListenableBuilder(
                  listenable: anuncios,
                  builder: (context, _) {
                    final pronto = anuncios.pronto;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l.reviver_titulo,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: UiTheme.txtCor,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: CreatureSprite(creature: criatura, size: 64),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l.reviver_texto(creatureName(context, criatura.id)),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: UiTheme.txtCor,
                            fontSize: 14,
                          ),
                        ),
                        if (_naoTerminou || !pronto) ...[
                          const SizedBox(height: 8),
                          Text(
                            _naoTerminou
                                ? l.reviver_naoTerminou
                                : l.reviver_indisponivel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Palette.cinzaEsc,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _botao(
                          anuncios.suportado
                              ? l.reviver_assistir
                              : l.reviver_teste,
                          pronto && !_assistindo ? _assistir : null,
                        ),
                        const SizedBox(height: 8),
                        _botao(
                          l.reviver_desistir,
                          _assistindo ? null : widget.game.recusarReviver,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _botao(String texto, VoidCallback? onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: UiTheme.btnCor,
        disabledBackgroundColor: Palette.cinza,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        elevation: 0,
        shape: const BordaDuplaShape(),
      ),
      onPressed: onPressed == null ? null : withBtnSfx(onPressed),
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
