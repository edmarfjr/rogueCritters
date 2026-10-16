import 'package:creatures_rogue/game/components/core/ui_theme.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/utils/palette_swapper.dart';
import 'package:creatures_rogue/game/creatures_rogue_game.dart';
import 'package:creatures_rogue/l10n/creature_i18n.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';
import '../audio/ui_sfx.dart';

/// Cerimônia de evolução (ver PIVOT_EVOLUCAO): o jogo já pausou e já trocou
/// os dados por baixo (`Player._evoluir`) — esta tela é só a encenação.
///
/// Diálogo normal (fundo semi-transparente, card branco) — só a JANELA da
/// animação (`_boxSize`x`_boxSize`) é preta. Sequência (uma
/// `AnimationController` só, dividida em trechos por tempo):
/// 1. `_fechando` (1000ms): sprite BASE em cores normais, uma CIRCUNFERÊNCIA
///    OCA vermelha (só o contorno) fecha do raio aberto até o centro
///    (implosão).
/// 2. `_flashBranco` (500ms): círculo já fechado, some da tela — o sprite
///    inteiro vira branco sólido, e É NESSA JANELA que ele pisca rapidamente
///    entre a forma BASE e a EVOLUÍDA (acelerando conforme avança —
///    `Curves.easeIn` no relógio dos flips), terminando na evoluída.
/// 3. `_abrindo` (500ms): a circunferência reabre até o raio cheio
///    (explosão) e o branco esmaece de volta pras cores normais do sprite
///    evoluído — assim que termina de abrir, some (não fica crescendo pra
///    fora da tela).
///
/// Só depois de tudo isso o diálogo "continuar" aparece.
class EvolutionOverlay extends StatefulWidget {
  final CreaturesRogueGame game;
  const EvolutionOverlay({super.key, required this.game});

  @override
  State<EvolutionOverlay> createState() => _EvolutionOverlayState();
}

class _EvolutionOverlayState extends State<EvolutionOverlay>
    with SingleTickerProviderStateMixin {
  static const double _boxSize = 180;

  /// Raio da circunferência "aberta" — início do fechamento, e ponto de
  /// partida da reabertura.
  static const double _raioAnel = 62.0;

  static const int _msFechando = 1000;
  static const int _msFlash = 500;
  static const int _msAbrindo = 500;
  static const int _msTotal = _msFechando + _msFlash + _msAbrindo;

  /// Quantas vezes o sprite troca de forma durante a janela branca
  /// (`_msFlash`). Número par: a última troca (índice ímpar, ver
  /// `_quadroDaFase`) cai na forma evoluída, então nunca termina na base por
  /// acaso mesmo se o arredondamento bater bem no fim da janela.
  static const int _totalFlips = 50;

  late final AnimationController _controle;
  ui.Image? _imgBase;
  ui.Image? _imgEvoluida;
  bool _prontaParaAnimar = false;
  bool _mostrarContinuar = false;

  @override
  void initState() {
    super.initState();
    _controle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _msTotal),
    )..addListener(() => setState(() {}));

    _controle.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _mostrarContinuar = true);
      }
    });

    _carregarSprites();
  }

  Future<void> _carregarSprites() async {
    final base = widget.game.evolucaoBase;
    final nova = widget.game.evolucaoNova;
    if (base == null || nova == null) return;

    final resultados = await Future.wait([
      PaletteSwapper.createSwappedImage(
        imagePath: base.spritePath,
        lightGrayReplacement: base.corClara,
        darkGrayReplacement: base.corEscura,
      ),
      PaletteSwapper.createSwappedImage(
        imagePath: nova.spritePath,
        lightGrayReplacement: nova.corClara,
        darkGrayReplacement: nova.corEscura,
      ),
    ]);

    if (!mounted) return;
    setState(() {
      _imgBase = resultados[0];
      _imgEvoluida = resultados[1];
      _prontaParaAnimar = true;
    });
    _controle.forward();
  }

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nova = widget.game.evolucaoNova;

    return Material(
      color: Palette.preto.withAlpha(200),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Palette.branco,
            border: const BordaDupla(cor: Palette.preto, espessura: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.evolution_titulo,
                style: const TextStyle(
                  color: Palette.branco,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: _boxSize,
                height: _boxSize,
                child: _prontaParaAnimar
                    ? _buildAnimacao()
                    : const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black45,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              if (nova != null)
                Text(
                  creatureName(context, nova.id),
                  style: const TextStyle(
                    color: UiTheme.txtCor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: _mostrarContinuar
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UiTheme.btnCor,
                          elevation: 0,
                          shape: const BordaDuplaShape(),
                        ),
                        onPressed: withBtnSfx(widget.game.dismissEvolucao),
                        child: Text(
                          context.l10n.pause_continuar,
                          style: const TextStyle(
                            fontSize: 16,
                            color: UiTheme.txtCor,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimacao() {
    final tMs = _controle.value * _msTotal;

    late final double raioAnel;
    late final bool mostraAnel;
    late final bool mostraEvoluida;
    late final double alphaBranco; // 0 = cores normais, 1 = branco sólido

    if (tMs < _msFechando) {
      final progresso = tMs / _msFechando;
      raioAnel = _raioAnel * (1 - progresso);
      mostraAnel = true;
      mostraEvoluida = false;
      alphaBranco = 0;
    } else if (tMs < _msFechando + _msFlash) {
      raioAnel = 0;
      mostraAnel = false;
      alphaBranco = 1;
      // Pisca rapidamente entre base/evoluída ENQUANTO o sprite está
      // branco — acelera conforme a janela avança (`Curves.easeIn` no
      // relógio dos flips: intervalo entre trocas começa longo e encolhe).
      final progressoFlash = (tMs - _msFechando) / _msFlash;
      final aceleradoFlash = Curves.easeIn.transform(
        progressoFlash.clamp(0.0, 1.0),
      );
      mostraEvoluida = (aceleradoFlash * _totalFlips).floor().isOdd;
    } else {
      final progresso = ((tMs - _msFechando - _msFlash) / _msAbrindo).clamp(
        0.0,
        1.0,
      );
      raioAnel = _raioAnel * progresso;
      // Assim que termina de abrir (progresso 1.0), some — não fica
      // parado no raio cheio nem cresce pra fora da tela.
      mostraAnel = progresso < 1.0;
      mostraEvoluida = true;
      alphaBranco = 1 - progresso;
    }

    final imagem = mostraEvoluida ? _imgEvoluida : _imgBase;
    final centro = Offset(_boxSize / 2, _boxSize / 2);

    return ClipRect(
      child: Container(
        width: _boxSize,
        height: _boxSize,
        // Só esta janela é preta — o resto do diálogo continua no estilo
        // branco/preto normal (ver `build`).
        color: Palette.branco,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ColorFiltered(
              // Alpha 0 = filtro é transparente, imagem passa intacta.
              // Alpha 255 = tinge tudo de branco preservando o formato
              // (alfa) da imagem — silhueta sólida branca. Ver fórmula do
              // Porter-Duff `srcATop`.
              colorFilter: ColorFilter.mode(
                Palette.amarelo.withAlpha((alphaBranco * 255).round()),
                BlendMode.srcATop,
              ),
              child: SizedBox(
                width: _boxSize,
                height: _boxSize,
                child: imagem == null
                    ? null
                    : RawImage(
                        image: imagem,
                        // `width`/`height`+`fit: contain` OBRIGATÓRIOS: a
                        // forma base é 16x16 e a evoluída 24x24 — sem isso,
                        // `RawImage` desenha cada uma no seu tamanho NATIVO
                        // (mesma pegadinha que `CreatureSprite` documenta),
                        // e a evoluída apareceria maior que a base no
                        // pisca-pisca. `contain` escala as duas pro mesmo
                        // tamanho final (ambas são quadradas).
                        width: _boxSize,
                        height: _boxSize,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                      ),
              ),
            ),
            if (mostraAnel)
              CustomPaint(
                size: const Size(_boxSize, _boxSize),
                painter: _CircunferenciaPainter(raio: raioAnel, centro: centro),
              ),
          ],
        ),
      ),
    );
  }
}

/// Só o contorno (`PaintingStyle.stroke`) — uma circunferência OCA, não um
/// disco preenchido. `raio <= 0` não desenha nada (evita um traço
/// degenerado no instante exato em que fecha de vez).
class _CircunferenciaPainter extends CustomPainter {
  final double raio;
  final Offset centro;
  static const double _espessura = 4;

  _CircunferenciaPainter({required this.raio, required this.centro});

  @override
  void paint(Canvas canvas, Size size) {
    if (raio <= 0) return;
    canvas.drawCircle(
      centro,
      raio,
      Paint()
        ..color = Palette.vermelho
        ..style = PaintingStyle.stroke
        ..strokeWidth = _espessura,
    );
  }

  @override
  bool shouldRepaint(covariant _CircunferenciaPainter oldDelegate) =>
      oldDelegate.raio != raio;
}
