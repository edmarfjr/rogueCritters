import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:creatures_rogue/game/audio/game_audio.dart';
import 'package:creatures_rogue/game/audio/sfx.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/effects/companion_revive_effect.dart';
import 'package:creatures_rogue/game/components/effects/movement_animator.dart';
import 'package:creatures_rogue/game/components/utils/palette_swapper.dart';

enum _Fase { entrando, invocando, saindo, esperando }

/// Cena de abertura da sala de boss: o treinador entra por uma borda, para no
/// meio, invoca a criatura e sai por outra borda.
///
/// Máquina de estados com um `double` no `update`, e não `SequenceEffect`: a
/// cena precisa de PAUSAS (a pose da invocação) e de opacidade derivada do
/// progresso de cada trecho, e encadear isso com efeitos exigiria efeitos de
/// movimento nulo servindo de cronômetro. É também o padrão que o resto do
/// projeto usa (`_invulnerabilityTimer`, `lentidaoTimer`, `stunTimer`).
///
/// Coordenadas são LOCAIS à sala — este componente é filho do `RoomComponent`.
///
/// O treinador aparece e desaparece com fade em vez de atravessar as paredes:
/// todo lado da sala tem 16px de parede (e o topo perde outros 16 pra HUD), e
/// entrar ou sair andando passaria por dentro dela. O fade mantém a leitura da
/// cena (chegou, foi embora) sem sobrepor tile de parede.
class BossCutscene extends SpriteComponent {
  /// Onde o treinador aparece, onde ele para pra invocar, e por onde sai —
  /// todos locais à sala. Quem escolhe os três é `RoomComponent`, em função da
  /// porta por onde o JOGADOR entrou (ver `_iniciarCutsceneBoss`): a cena aqui
  /// só executa o trajeto, sem saber de lados.
  final Vector2 entrada;
  final Vector2 centro;
  final Vector2 saida;

  /// Onde o boss nasce (local à sala) — só pro efeito visual da invocação
  /// cair no lugar certo. Quem realmente cria o boss é [aoInvocar].
  final Vector2 posBoss;

  /// Chamado no instante da invocação. A sala usa pra nascer o boss, o que
  /// também tira a sala do risco de se declarar limpa: enquanto
  /// `activeEnemies` está vazia, é `RoomComponent.cutsceneAtiva` que segura a
  /// checagem de sala limpa.
  final void Function() aoInvocar;

  /// Chamado quando a cena acaba de vez. A sala usa pra devolver o controle
  /// ao jogador e religar a checagem de sala limpa.
  final void Function() aoTerminar;

  static const double _duracaoFade = 0.8;
  static const double _duracaoEntrada = 2.0;
  static const double _duracaoPose = 1.2;
  static const double _duracaoSaida = 2.2;

  /// Parada depois de ele sumir, antes da briga começar — pra cena respirar
  /// em vez de cortar seco pro combate.
  static const double _esperaAposSair = 1.0;

  /// Fração do trajeto de saída em que ele ainda está opaco. Depois disso
  /// começa a desaparecer, e termina invisível antes de tocar a parede.
  static const double _inicioFadeSaida = 0.6;

  late final Sprite _andando;
  late final Sprite _invocando;

  /// Mesma animação da criatura que caminha (`MovementAnimation.caminhada`):
  /// inclina o sprite de um lado pro outro enquanto anda, e respira parado.
  ///
  /// `caminhada` mexe só em `angle` e `scale`, nunca em `position` — é o que
  /// deixa a animação conviver com a interpolação do trajeto que este
  /// componente faz no [update]. Um estilo que deslocasse a posição
  /// (`saltitar`, `flutuar`) brigaria com ela.
  final MovementAnimator _animador = MovementAnimator(
    MovementAnimation.caminhada,
  );

  _Fase _fase = _Fase.entrando;
  double _t = 0.0;

  BossCutscene({
    required this.entrada,
    required this.centro,
    required this.saida,
    required this.posBoss,
    required this.aoInvocar,
    required this.aoTerminar,
  }) : super(
         size: Vector2.all(16),
         anchor: Anchor.center,
         // Acima de qualquer tile e de qualquer ator: é cena, não gameplay.
         priority: 250,
       );

  @override
  Future<void> onLoad() async {
    // `plr.png` é 32x16: dois quadros de 16x16 lado a lado — o primeiro
    // andando, o segundo invocando.
    final ui.Image img = await PaletteSwapper.createSwappedImage(
      imagePath: 'actors/plr.png',
      lightGrayReplacement: Palette.bege,
      darkGrayReplacement: Palette.burgundy,
    );
    _andando = Sprite(img, srcPosition: Vector2.zero(), srcSize: Vector2.all(16));
    _invocando = Sprite(
      img,
      srcPosition: Vector2(16, 0),
      srcSize: Vector2.all(16),
    );

    sprite = _andando;
    paint.filterQuality = FilterQuality.none;
    position = entrada.clone();
    opacity = 0.0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;

    final antes = position.clone();

    switch (_fase) {
      case _Fase.entrando:
        final p = (_t / _duracaoEntrada).clamp(0.0, 1.0);
        position = entrada + (centro - entrada) * p;
        opacity = (_t / _duracaoFade).clamp(0.0, 1.0);
        if (p >= 1.0) {
          _t = 0.0;
          _fase = _Fase.invocando;
          _invocar();
        }

      case _Fase.invocando:
        if (_t >= _duracaoPose) {
          _t = 0.0;
          _fase = _Fase.saindo;
          sprite = _andando;
        }

      case _Fase.saindo:
        final p = (_t / _duracaoSaida).clamp(0.0, 1.0);
        position = centro + (saida - centro) * p;
        opacity = p < _inicioFadeSaida
            ? 1.0
            : (1.0 - (p - _inicioFadeSaida) / (1.0 - _inicioFadeSaida)).clamp(
                0.0,
                1.0,
              );
        if (p >= 1.0) {
          _t = 0.0;
          opacity = 0.0;
          _fase = _Fase.esperando;
        }

      case _Fase.esperando:
        if (_t >= _esperaAposSair) {
          aoTerminar();
          removeFromParent();
        }
    }

    // `isMoving` derivado do deslocamento real deste quadro, em vez da fase:
    // sai de graça certo nas pausas (pose e espera), onde ele fica respirando.
    final passo = position - antes;

    // Espelha só andando pra ESQUERDA; em qualquer outro caso (direita, cima,
    // baixo, parado) volta pro sentido padrão do sprite.
    //
    // Tem que vir ANTES do animador: `MovementAnimator` lê o sinal de
    // `scale.x` pra saber o flip atual e depois reescreve `scale` inteiro
    // preservando esse sinal — invertido aqui depois, o próximo quadro
    // desfaria. Mexe no sinal e não em `flipHorizontallyAroundCenter()` pra
    // não arriscar deslocamento de posição no meio do trajeto.
    final espelhar = passo.x < 0;
    if (scale.x.isNegative != espelhar) scale.x = -scale.x;

    _animador.update(
      visual: this,
      basePosition: position.clone(),
      isMoving: !passo.isZero(),
      horizontalDir: passo.x.sign,
      dt: dt,
    );
  }

  void _invocar() {
    sprite = _invocando;
    GameAudio.instance.play(Sfx.bossEntrada);
    parent?.add(CompanionReviveEffect(position: posBoss));
    aoInvocar();
  }
}
