import 'package:flame_audio/flame_audio.dart';

/// Player de música de fundo. Três faixas hoje: [menu], [run] e [boss].
///
/// Pra ligar uma faixa nova: solte o arquivo em `assets/sounds/music/`
/// (a pasta inteira já está declarada no `pubspec.yaml`), acrescente uma
/// constante aqui e chame [play]. O caminho é relativo a `assets/sounds/`,
/// prefixo acertado em `GameAudio.preload`.
///
/// Separado de `GameAudio` de propósito: música é um único player em loop
/// (`FlameAudio.bgm`), efeito sonoro é pool de vários players tocando ao
/// mesmo tempo — são dois problemas diferentes, não faz sentido no mesmo
/// objeto.
class GameMusic {
  GameMusic._();
  static final GameMusic instance = GameMusic._();

  /// Menu principal. Tocada pelo `MainMenuOverlay`.
  static const String menu = 'music/menuTema.wav';

  /// Trilha da partida, do começo da run até o fim.
  static const String run = 'music/runTema.wav';

  /// Luta de boss. Volta pra [run] quando o boss cai (ver `Enemy.death`).
  static const String boss = 'music/bossTema.wav';

  /// Fim da run por derrota. Entra junto com a cena de morte (ver
  /// `CreaturesRogueGame._handleGameOver`).
  static const String gameOver = 'music/gameoverTema.wav';

  /// Tela de vitória (zerou o jogo).
  static const String vitoria = 'music/vitoriaTema.wav';

  /// Todas as faixas, pro preload do `GameAudio` aquecer o cache de bytes.
  ///
  /// `FlameAudio.bgm.play` faz `setSource` NA HORA da chamada, e a troca pra
  /// faixa de boss acontece exatamente quando o jogador abre a porta da sala
  /// — o pior instante possível pra engasgar. Aquecendo aqui, aquele
  /// `setSource` encontra os bytes já em memória.
  static const List<String> todas = [menu, run, boss, gameOver, vitoria];

  String? _current;
  double volume = volumePadrao;

  static const double volumePadrao = 0.5;

  /// Troca o volume da faixa que está tocando AGORA, além do campo.
  ///
  /// O campo sozinho só valeria pra próxima troca de faixa — e trocar de faixa
  /// numa run pode demorar uma masmorra inteira.
  Future<void> aplicarVolume(double novo) async {
    volume = novo.clamp(0.0, 1.0);
    try {
      await FlameAudio.bgm.audioPlayer.setVolume(volume);
    } catch (_) {}
  }
  bool enabled = true;

  bool _iniciado = false;

  /// Troca a faixa atual. Não faz nada se [asset] já é a faixa tocando —
  /// evita reiniciar a música do zero toda vez que o chamador re-emite o
  /// mesmo "entrar na masmorra".
  Future<void> play(String asset) async {
    if (!enabled || _current == asset) return;
    _current = asset;
    try {
      // `initialize()` NÃO é opcional aqui, apesar de o `play` do `Bgm`
      // funcionar sem ele: é ele que põe o player de música em
      // `mixWithOthers`. Sem isso a música pede foco de áudio EXCLUSIVO a cada
      // troca de faixa, e cada pedido dispara `AUDIOFOCUS_LOSS` em todas as
      // vozes de efeito do `GameAudio` — a mesma tempestade de handlers que
      // já derrubou o app por ANR e está documentada lá (item 3).
      //
      // Preguiçoso e idempotente de propósito: nenhum chamador precisa
      // lembrar de ligar nada antes de pedir uma faixa.
      if (!_iniciado) {
        _iniciado = true;
        await FlameAudio.bgm.initialize();
      }
      // Mesmo motivo do achado #7 em `GameAudio`: o `AudioPlayer` do `Bgm`
      // vem com um `FramePositionUpdater`, que faz uma chamada de canal de
      // plataforma por quadro enquanto toca. A música toca em loop, então
      // aqui esse custo seria permanente, não só em combate.
      FlameAudio.bgm.audioPlayer.positionUpdater = null;
      await FlameAudio.bgm.play(asset, volume: volume);
    } catch (_) {
      _current = null;
    }
  }

  Future<void> stop() async {
    _current = null;
    try {
      await FlameAudio.bgm.stop();
    } catch (_) {}
  }

  Future<void> pause() async {
    try {
      await FlameAudio.bgm.pause();
    } catch (_) {}
  }

  Future<void> resume() async {
    try {
      await FlameAudio.bgm.resume();
    } catch (_) {}
  }
}
