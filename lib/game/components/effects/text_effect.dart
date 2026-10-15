import 'package:creatures_rogue/game/components/utils/y_sort.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';

/// Texto que se desloca numa direção (pra cima, por padrão) e desaparece
/// depois de um tempo. Usado principalmente pra números de dano em combate,
/// mas serve pra qualquer aviso rápido ("Crítico!", "Bloqueado", etc.).
class TextEffect extends PositionComponent {
  final String text;
  final Vector2 direction;
  final double speed;
  final double duration;
  final Color color;
  double fontSize;
  double _elapsed = 0.0;

  /// Largura máxima da linha, em pixels de jogo, antes de quebrar. A tela tem
  /// 192 de largura; 110 deixa folga pro texto nascer colado numa parede sem
  /// vazar pela borda. Números de dano (o uso mais comum) nunca chegam perto
  /// disso, então pra eles a quebra nunca acontece.
  final double larguraMax;

  /// Duração de texto pra LER — descrição de item, upgrade, consumível ou
  /// compra —, o dobro do padrão de número de dano.
  static const double duracaoLeitura = 1.6;

  /// `TextPaint` e linhas são calculados uma vez e guardados: antes o
  /// `TextPaint` era reconstruído a cada quadro, e agora a quebra de linha
  /// precisa MEDIR o texto, o que seria pior ainda por frame.
  TextPaint? _paintCache;
  List<String>? _linhasCache;

  TextEffect({
    required this.text,
    required Vector2 position,
    Vector2? direction,
    this.speed = 20.0,
    this.duration = 0.8,
    this.color = Palette.branco,
    this.fontSize = 6.0,
    this.larguraMax = 110.0,
  })  : direction = (direction ?? Vector2(0, -1)).normalized(),
        super(position: position.clone(), anchor: Anchor.center, priority: 200);

  /// Formata o número de dano: até duas casas decimais, e no mínimo uma.
  ///
  /// O dano é fracionado em quase todo golpe — a cadeia é multiplicativa
  /// (`danoMult`, `danoMultDerivado`, vantagem de tipo em 2 ou 0,5, redução
  /// de dano, crítico em 1,5), então valores como 1,725 são o normal, não a
  /// exceção. Antes isto mostrava `toStringAsFixed(0)`, e com isso um golpe
  /// abaixo de 0,5 aparecia como "0" (lendo como "errei") e a soma do que a
  /// tela mostrava nunca fechava com a barra de vida do inimigo.
  ///
  /// Corta UM zero à direita, nunca dois: é o que dá "3.0" em vez de "3.00" e
  /// "1.2" em vez de "1.20", mantendo sempre pelo menos uma casa. A casa fixa
  /// existe pra deixar claro, de relance, que o número é contínuo.
  static String formatarDano(num valor) {
    final texto = valor.toStringAsFixed(2);
    return texto.endsWith('0') ? texto.substring(0, texto.length - 1) : texto;
  }

  /// Atalho pro uso mais comum: número de dano subindo.
  factory TextEffect.dano(
    num valor, {
    required Vector2 position,
    Color color = Palette.branco,  double fontSize = 6.0,
  }) {
    return TextEffect(
      text: formatarDano(valor),
      position: position,
      color: color,
      fontSize: fontSize,
    );
  }

  @override
  void onLoad(){
    priority = ySortPriority(position.y + size.y / 2);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    position += direction * speed * dt;

    if (_elapsed >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    //final t = (_elapsed / duration).clamp(0.0, 1.0);
    final alpha = 255;//((1 - t) * 255).round().clamp(0, 255);

    final paint = _paintCache ??= TextPaint(
      style: TextStyle(
        color: color.withAlpha(alpha),
        fontSize: fontSize,
        fontFamily: 'pixelFont',
        fontWeight: FontWeight.bold,
        shadows: [Shadow(color: Palette.preto, offset: Offset(1, 1)),
          Shadow(color: Palette.preto, offset: Offset(-1, -1)),
          Shadow(color: Palette.preto, offset: Offset(1, -1)),
          Shadow(color: Palette.preto, offset: Offset(-1, 1)),
          Shadow(color: Palette.preto, offset: Offset(0, 1)),
          Shadow(color: Palette.preto, offset: Offset(0, -1)),
          Shadow(color: Palette.preto, offset: Offset(1, 0)),
          Shadow(color: Palette.preto, offset: Offset(-1, 0)),],
      ),
    );
   /* final paintBorda = TextPaint(
      style: TextStyle(
        color: Palette.preto.withAlpha(alpha),
        fontSize: fontSize,
        fontFamily: 'pixelFont',
        fontWeight: FontWeight.bold,
      ),
    );
   
    final dirs = [Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1)];
    for (final dir in dirs) {
      var off = dir * fontSize/16;
      paintBorda.render(canvas, text, off, anchor: Anchor.center);
    }
    */
    final linhas = _linhasCache ??= _quebrar(paint);

    // Bloco centrado no ponto do efeito: com duas linhas, uma sobe metade da
    // altura de linha e a outra desce a mesma coisa, então o conjunto fica no
    // mesmo lugar que uma linha só ficaria.
    final alturaLinha = fontSize + 1;
    final topo = -(linhas.length - 1) * alturaLinha / 2;
    for (var i = 0; i < linhas.length; i++) {
      paint.render(
        canvas,
        linhas[i],
        Vector2(0, topo + i * alturaLinha),
        anchor: Anchor.center,
      );
    }
  }

  /// Quebra por palavra, medindo de verdade em vez de contar caracteres — a
  /// `pixelFont` não é monoespaçada. Palavra sozinha mais larga que
  /// [larguraMax] não é cortada no meio: fica numa linha estourando, que é
  /// melhor que partir a palavra.
  List<String> _quebrar(TextPaint paint) {
    final linhas = <String>[];
    var atual = '';
    for (final palavra in text.split(' ')) {
      final tentativa = atual.isEmpty ? palavra : '$atual $palavra';
      if (atual.isNotEmpty &&
          paint.getLineMetrics(tentativa).width > larguraMax) {
        linhas.add(atual);
        atual = palavra;
      } else {
        atual = tentativa;
      }
    }
    if (atual.isNotEmpty) linhas.add(atual);
    return linhas;
  }
}
