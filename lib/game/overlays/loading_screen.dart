import 'package:flutter/material.dart';

import 'package:creatures_rogue/game/components/core/ui_theme.dart';
import 'package:creatures_rogue/game/components/core/responsive.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';

/// Tela de abertura, mostrada do momento em que o `GameWidget` monta até o
/// `onLoad` do jogo terminar — e é só então que o menu principal aparece.
///
/// NÃO é um overlay do Flame, e não pode ser: o `GameWidget` só empilha os
/// overlays depois que o future de carregamento resolve, então um
/// `overlays.add('Splash')` apareceria no mesmo quadro que o `MainMenu`, sem
/// cobrir nada. Quem pinta durante o carregamento é o `loadingBuilder`, e é de
/// lá que esta tela é construída (ver `main.dart`).
///
/// O que ela cobre, na prática, é o `onLoad` do `CreaturesRogueGame`: paleta
/// dos sprites de combate, ícones de habilidade e pool de sons. O que ela NÃO
/// cobre são os `await` de `main()` antes do `runApp` (saves e
/// `Flame.device.fullScreen`), porque nesse trecho ainda não existe árvore de
/// widget — ali quem aparece é a splash nativa da plataforma.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final estreita = Responsive.ehEstreita(context);

    return ResponsiveOverlayScaffold(
      background: UiTheme.backgroundMenuCor,
      child: Container(
        padding: const EdgeInsets.all(20),
       // decoration: const BoxDecoration(
       //   color: UiTheme.quadroFundoCor,
       //   border: BordaDupla(cor: Palette.preto, espessura: 3),
       // ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // `FilterQuality.none` mantém o pixel art nítido na ampliação —
            // mesmo tratamento que todo sprite do jogo recebe no Flame.
            Image.asset(
              'assets/images/logo.png',
              width: estreita ? 96 : 128,
              height: estreita ? 96 : 128,
              filterQuality: FilterQuality.none,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.menu_titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: UiTheme.txtCor,
                fontSize: estreita ? 32 : 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.loading_carregando,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: UiTheme.txtCor,
                fontSize: estreita ? 16 : 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
