import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/audio/ui_sfx.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/core/ui_theme.dart';
import 'package:creatures_rogue/game/components/creatures/creature_progress.dart';
import 'package:creatures_rogue/game/creatures_rogue_game.dart';
import 'package:creatures_rogue/game/pactos.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';

/// Escolha dos pactos de dificuldade, aberta por cima da seleção de criatura
/// (ver [Pactos]). A escolha é gravada na hora e vale pra próxima run — e
/// pras seguintes, até o jogador mudar.
class PactosOverlay extends StatefulWidget {
  final CreaturesRogueGame game;
  const PactosOverlay({super.key, required this.game});

  @override
  State<PactosOverlay> createState() => _PactosOverlayState();
}

class _PactosOverlayState extends State<PactosOverlay> {
  CreatureProgress get _progresso => CreatureProgress.instance;

  void _mudar(Pacto pacto, int delta) {
    final atual = _progresso.pactosEscolhidos[pacto] ?? 0;
    final novo = (atual + delta).clamp(0, pacto.maxNivel);
    if (novo == atual) return;
    setState(() => _progresso.escolherPacto(pacto, novo));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final escolhidos = _progresso.pactosEscolhidos;
    final calor = Pactos.calorDe(escolhidos);
    final bonusXp = (Pactos.xpPorCalor * calor * 100).round();

    return Material(
      color: Palette.preto.withAlpha(200),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: UiTheme.quadroFundoCor,
                  border: BordaDupla(cor: Palette.preto, espessura: 4),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: withVoltarSfx(
                            () => widget.game.overlays.remove('Pactos'),
                          ),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: UiTheme.txtCor,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            l.pactos_titulo,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: UiTheme.txtCor,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final p in Pacto.values)
                              _linha(context, p, escolhidos[p] ?? 0),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.pactos_rodape(calor, bonusXp),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: UiTheme.txtCor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _linha(BuildContext context, Pacto pacto, int nivel) {
    final ligado = nivel > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: UiTheme.quadroFundoCor,
          border: BordaDupla(
            cor: Palette.preto,
            corExterna: ligado ? Palette.vermelho : null,
            espessura: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pacto.nome(context)}  '
                    '${context.l10n.pactos_calor(pacto.calorPorNivel)}',
                    style: const TextStyle(
                      color: UiTheme.txtCor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    pacto.descricao(context, nivel),
                    style: TextStyle(
                      color: ligado ? UiTheme.txtCor : Palette.cinzaEsc,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            _botao(Icons.remove, nivel > 0 ? () => _mudar(pacto, -1) : null),
            SizedBox(
              width: 44,
              child: Text(
                '$nivel/${pacto.maxNivel}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: UiTheme.txtCor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _botao(
              Icons.add,
              nivel < pacto.maxNivel ? () => _mudar(pacto, 1) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _botao(IconData icone, VoidCallback? onPressed) {
    return IconButton(
      onPressed: withCursorSfx(onPressed),
      icon: Icon(icone, size: 20),
      color: UiTheme.txtCor,
      disabledColor: Palette.cinza,
    );
  }
}
