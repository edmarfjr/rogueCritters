import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:creatures_rogue/game/game_settings.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';

/// Paleta da tela inteira, escolhida nas configurações: as cores do jogo
/// convertidas pros tons de um portátil clássico.
///
/// Dois caminhos, escolhidos sozinhos:
/// - **4 tons exatos** ([filtroShader]): um shader arredonda cada pixel pro
///   tom mais próximo, como o hardware. Só com o renderizador Impeller
///   (Android e iOS).
/// - **Duotone** ([filtro]): sem Impeller (web, desktop), cada pixel vira um
///   degradê entre o tom mais escuro e o mais claro. Não é exato, mas lê
///   como o aparelho.
enum PaletaTela {
  normal([
    Color(0xFF000000),
    Color(0xFF555555),
    Color(0xFFAAAAAA),
    Color(0xFFFFFFFF),
  ]),
  gameBoy([
    Color(0xFF0F380F),
    Color(0xFF306230),
    Color(0xFF8BAC0F),
    Color(0xFF9BBC0F),
  ]),
  pocket([
    Color(0xFF181818),
    Color(0xFF4A5138),
    Color(0xFF8C926B),
    Color(0xFFC5CAA4),
  ]),
  virtualBoy([
    Color(0xFF000000),
    Color(0xFF550000),
    Color(0xFFA40000),
    Color(0xFFEF0000),
  ]),
  sepia([
    Color(0xFF2B1B0E),
    Color(0xFF6B4A2B),
    Color(0xFFB8946A),
    Color(0xFFF4E3C1),
  ]);

  const PaletaTela(this.tons);

  /// Os 4 tons, do mais escuro ao mais claro.
  final List<Color> tons;

  Color get escuro => tons.first;
  Color get claro => tons.last;

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

/// Shader dos 4 tons, carregado uma vez no `main` ([carregarShaderPaleta]).
/// Nulo sem Impeller, ou se o carregamento falhar: aí vale o duotone.
ui.FragmentProgram? _programaPaleta;

Future<void> carregarShaderPaleta() async {
  if (!ui.ImageFilter.isShaderFilterSupported) return;
  try {
    _programaPaleta = await ui.FragmentProgram.fromAsset('shaders/paleta4.frag');
  } catch (e) {
    debugPrint('Paleta: shader indisponível, usando duotone ($e)');
  }
}

final Map<PaletaTela, ui.ImageFilter> _filtrosShader = {};

extension on PaletaTela {
  /// Filtro dos 4 tons exatos, ou nulo quando o shader não está disponível.
  /// Um por paleta, montado uma vez.
  ui.ImageFilter? get filtroShader {
    final programa = _programaPaleta;
    if (programa == null || this == PaletaTela.normal) return null;
    return _filtrosShader.putIfAbsent(this, () {
      final shader = programa.fragmentShader();
      // 0 e 1 são o `uTamanho`, que o motor preenche.
      var i = 2;
      for (final tom in tons) {
        shader
          ..setFloat(i++, tom.r)
          ..setFloat(i++, tom.g)
          ..setFloat(i++, tom.b)
          ..setFloat(i++, 1.0);
      }
      return ui.ImageFilter.shader(shader);
    });
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
        final exato = paleta.filtroShader;
        if (exato != null) return ImageFiltered(imageFilter: exato, child: filho!);
        final filtro = paleta.filtro;
        if (filtro == null) return filho!;
        return ColorFiltered(colorFilter: filtro, child: filho);
      },
      child: child,
    );
  }
}
