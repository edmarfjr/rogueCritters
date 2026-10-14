import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'door.dart';

/// Metade da passagem pra sala secreta, disfarçada de parede rachada: o
/// sprite é a versão quebrada da parede da fase (`arvoreSeca` /
/// `pedraQuebrada`), a pista que o jogador tem.
///
/// Quem conta os golpes é a SALA (ver `RoomComponent._golpeNaParedeSecreta`),
/// porque a passagem são duas metades e um golpe em qualquer uma vale pras
/// duas. Aberta, vira chão como uma porta comum.
class PortaSecreta extends Door {
  final void Function({bool forte}) aoSerAtingida;

  PortaSecreta({
    required super.position,
    required super.spritePath,
    required super.cor1,
    required super.cor2,
    required super.cor3,
    required super.cor4,
    required this.aoSerAtingida,
  }) : super(angleVal: 0, isOpen: false);

  /// [forte] = explosão: abre de uma vez. As lascas saem só da metade
  /// atingida; o tremor a sala aplica nas duas (ver [tremer]).
  void atingir({bool forte = false}) {
    if (isOpen) return;
    _soltarLascas();
    aoSerAtingida(forte: forte);
  }

  // ------------------------------------------------------------ tremor

  static const double _duracaoTremor = 0.15;
  double _tremor = 0.0;

  void tremer() => _tremor = _duracaoTremor;

  @override
  void update(double dt) {
    super.update(dt);
    if (_tremor > 0) _tremor -= dt;
  }

  @override
  void render(Canvas canvas) {
    if (_tremor <= 0) {
      super.render(canvas);
      return;
    }
    // 1px pra um lado e pro outro, alternando a cada ~quadro: em pixel art
    // um seno suave vira borrão.
    final lado = (_tremor * 60).floor().isEven ? 1.0 : -1.0;
    canvas.save();
    canvas.translate(lado, 0);
    super.render(canvas);
    canvas.restore();
  }

  // ------------------------------------------------------------ lascas

  static const int _lascas = 8;

  /// Pedacinhos quadrados nas cores da parede, espirrando e caindo.
  void _soltarLascas() {
    final rng = Random();
    parent?.add(
      ParticleSystemComponent(
        position: position.clone(),
        priority: 1000,
        particle: Particle.generate(
          count: _lascas,
          lifespan: 0.35,
          generator: (i) {
            final angulo = rng.nextDouble() * 2 * pi;
            final velocidade = 30 + rng.nextDouble() * 40;
            final cor = i.isEven ? cor1 : cor2;
            final lado = 1.0 + rng.nextInt(2);
            return AcceleratedParticle(
              acceleration: Vector2(0, 160),
              speed: Vector2(cos(angulo), sin(angulo)) * velocidade,
              child: ComputedParticle(
                renderer: (canvas, particula) {
                  canvas.drawRect(
                    Rect.fromLTWH(0, 0, lado, lado),
                    Paint()
                      ..color = cor.withAlpha(
                        (255 * (1 - particula.progress)).round(),
                      ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
