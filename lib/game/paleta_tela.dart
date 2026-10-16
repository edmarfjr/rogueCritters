import 'package:flutter/widgets.dart';
import 'package:creatures_rogue/game/game_settings.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';

/// Paleta da tela inteira, escolhida nas configurações: as cores do jogo
/// convertidas pros tons de um portátil clássico.
///
/// Duotone: cada pixel vira a própria luminosidade, levada pra um degradê
/// entre [escuro] e [claro]. Não arredonda pros 4 tons exatos do hardware
/// (isso pediria shader), mas lê como o aparelho e vale em toda plataforma.
enum PaletaTela {
  normal(escuro: Color(0xFF000000), claro: Color(0xFFFFFFFF)),
  gameBoy(escuro: Color(0xFF0F380F), claro: Color(0xFF9BBC0F)),
  pocket(escuro: Color(0xFF1E2618), claro: Color(0xFFC4CFA1)),
  virtualBoy(escuro: Color(0xFF000000), claro: Color(0xFFEF0000)),
  sepia(escuro: Color(0xFF2B1B0E), claro: Color(0xFFF4E3C1));

  const PaletaTela({required this.escuro, required this.claro});

  final Color escuro;
  final Color claro;

  String nome(BuildContext context) {
    final l = context.l10n;
    return switch (this) {
      PaletaTela.normal => l.paleta_normal,
      PaletaTela.gameBoy => l.paleta_gameBoy,
      PaletaTela.pocket => l.paleta_pocket,
      PaletaTela.virtualBoy => l.paleta_virtualBoy,
      PaletaTela.sepia => l.paleta_sepia,
    };
  }

  /// Matriz do duotone. `null` na [normal]: sem filtro nenhum, nem o custo.
  ColorFilter? get filtro {
    if (this == PaletaTela.normal) return null;
    // A matriz trabalha em 0–255: canal = escuro + (claro - escuro) × L,
    // com L = 0,299 R + 0,587 G + 0,114 B, normalizado.
    List<double> linha(double e, double c) {
      final d = (c - e) / 255;
      return [d * 0.299, d * 0.587, d * 0.114, 0, e];
    }

    double canal(double v) => v * 255;
    return ColorFilter.matrix([
      ...linha(canal(escuro.r), canal(claro.r)),
      ...linha(canal(escuro.g), canal(claro.g)),
      ...linha(canal(escuro.b), canal(claro.b)),
      0, 0, 0, 1, 0,
    ]);
  }
}

/// Aplica a paleta escolhida em tudo que está abaixo dele — no `main.dart`,
/// o app inteiro: mundo, HUD, menus e diálogos.
class FiltroPaleta extends StatelessWidget {
  final Widget child;
  const FiltroPaleta({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PaletaTela>(
      valueListenable: GameSettings.instance.paletaNotifier,
      builder: (context, paleta, filho) {
        final filtro = paleta.filtro;
        if (filtro == null) return filho!;
        return ColorFiltered(colorFilter: filtro, child: filho);
      },
      child: child,
    );
  }
}
