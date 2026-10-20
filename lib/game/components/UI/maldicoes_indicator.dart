import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/core/ui_theme.dart';
import 'package:creatures_rogue/game/components/utils/palette_swapper.dart';
import 'package:creatures_rogue/game/maldicoes.dart';

/// Maldições ativas na Hud: um ícone por maldição e, embaixo dele, as salas
/// que faltam em quadradinhos — mesmo idioma visual das cargas de sala (ver
/// `CargaSalaIndicator`), porque algarismo na fonte da Hud não cabe aqui.
///
/// O ícone vai num quadrinho escuro: os desenhos não têm contorno, e sem
/// fundo sumiriam no chão claro.
class MaldicoesIndicator extends PositionComponent {
  MaldicoesIndicator({required this.maldicoes, super.position});

  final Map<Maldicao, int> Function() maldicoes;

  static const double _icone = 8.0;
  static const double _margem = 1.0;
  static const double _passo = _icone + _margem * 2 + 2;
  static const double _pip = 2.0;
  static const double _espaco = 1.0;
  static const int _pipsPorLinha = 3;

  /// Sprite e cores (cinza claro, cinza escuro) de cada maldição.
  static const Map<Maldicao, (String, Color, Color)> _visual = {
    Maldicao.nevoa: ('ui/nevoa.png', Palette.cinza, Palette.cinzaEsc),
    Maldicao.cegueira: ('ui/cegueira.png', Palette.branco, Palette.indigo),
    Maldicao.corrente: ('ui/corrente.png', Palette.cinza, Palette.cinzaEsc),
    Maldicao.maosFuradas: (
      'ui/moedaFurada.png',
      Palette.amarelo,
      Palette.laranja,
    ),
    Maldicao.cansaco: ('ui/cansaco.png', Palette.laranja, Palette.marrom),
    Maldicao.assombracao: ('ui/assombra.png', Palette.cinza, Palette.cinzaEsc),
    Maldicao.dissonancia: ('ui/dissonancia.png', Palette.rosa, Palette.vermelho),
  };

  final Map<Maldicao, Sprite> _sprites = {};

  final Paint _fundo = Paint()..color = Palette.preto;
  final Paint _borda = Paint()
    ..color = Palette.roxoEsc
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final Paint _paint = Paint()..filterQuality = FilterQuality.none;
  final Paint _cheio = Paint()..color = Palette.rosa;
  final Paint _vazio = Paint()..color = UiTheme.hudSlotFundoCor.withAlpha(160);

  @override
  Future<void> onLoad() async {
    for (final e in _visual.entries) {
      final (caminho, cor1, cor2) = e.value;
      final ui.Image imagem = await PaletteSwapper.createSwappedImage(
        imagePath: caminho,
        lightGrayReplacement: cor1,
        darkGrayReplacement: cor2,
      );
      _sprites[e.key] = Sprite(imagem);
    }
  }

  @override
  void render(Canvas canvas) {
    var x = 0.0;
    for (final e in maldicoes().entries) {
      final caixa = Rect.fromLTWH(
        x,
        0,
        _icone + _margem * 2,
        _icone + _margem * 2,
      );
      canvas.drawRect(caixa, _fundo);
      canvas.drawRect(caixa.deflate(0.5), _borda);
      _sprites[e.key]?.render(
        canvas,
        position: Vector2(x + _margem, _margem),
        size: Vector2.all(_icone),
        overridePaint: _paint,
      );

      final topoPips = caixa.bottom + _espaco;
      for (var i = 0; i < Maldicao.salas; i++) {
        final linha = i ~/ _pipsPorLinha;
        final coluna = i % _pipsPorLinha;
        canvas.drawRect(
          Rect.fromLTWH(
            x + _margem + coluna * (_pip + _espaco),
            topoPips + linha * (_pip + _espaco),
            _pip,
            _pip,
          ),
          i < e.value ? _cheio : _vazio,
        );
      }
      x += _passo;
    }
  }
}
