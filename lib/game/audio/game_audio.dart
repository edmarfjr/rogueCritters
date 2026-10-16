import 'package:flame_audio/flame_audio.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'game_music.dart';
import 'sfx.dart';

/// Efeitos sonoros do jogo — dash, retorno de criatura, dano e ataques
/// elementais (ver [Sfx]). Ponto único de leitura de `assets/sounds/sfx/`.
///
/// Decisões que carregam o peso da parte "performático" do pedido — cada uma
/// veio de um teste real em campo (log de dispositivo Android), não de
/// suposição:
///
/// 1. `PlayerMode.mediaPlayer`, NÃO `lowLatency`. No Android, `lowLatency` é
///    `SoundPool`: cada `play()` faz o sistema alocar um `AudioTrack` nativo
///    de verdade (visto se repetindo no log, `createTrack_l`, durante o
///    próprio combate) — com um pool fixo de vozes reaproveitadas isso soma
///    trabalho nativo real por toque, saturando a MESMA thread de
///    plataforma que processa outras coisas (confirmado desligando o áudio:
///    a vibração, que usa essa thread, ficou instantânea). `SoundPool`
///    existe pra "várias vozes tocando ao mesmo tempo sem gerência manual"
///    — MAS este arquivo já faz a própria gerência de vozes (item 3), então
///    a vantagem do SoundPool não vale nada aqui, só o custo. `MediaPlayer`
///    aloca o `AudioTrack` uma vez por player e reaproveita — o preço fica
///    só no preload, não a cada toque.
/// 2. `player.seek(Duration.zero)` antes de `player.resume()` pra reiniciar
///    uma voz — e SÓ nesse modo. No `SoundPool` o `seekTo(0)` do plugin não
///    completa de forma confiável (achado real: `Future` pendurado até
///    estourar os 30s de timeout do `audioplayers`, um por toque, empilhando
///    até travar o app). No `MediaPlayer`, `seekTo` é implementação de
///    verdade, com callback de conclusão — o padrão que quebrava num modo é
///    o correto no outro. NUNCA chamar `stop()` aqui: no `MediaPlayer` isso
///    força o estado "Stopped", que exige `prepare()` de novo antes do
///    próximo `start()` — o oposto do que uma voz reaproveitável precisa.
/// 3. `AudioContextConfig(focus: mixWithOthers)` em CADA voz, setado antes de
///    tocar. Sem isso cada `resume()` pede foco de áudio ao sistema, o que
///    dispara `AUDIOFOCUS_LOSS` em toda outra voz ativa — com dezenas de
///    vozes isso é uma tempestade de handlers de foco disparando uns nos
///    outros (O(n²) no número de vozes), travando a thread principal até o
///    Android matar o app por ANR. `mixWithOthers` desliga isso.
/// 4. Vozes fixas por som ([_voiceCounts]), criadas uma vez em [preload] e
///    nunca mais. `play()` sempre reaproveita em turno (round-robin): a voz
///    mais antiga é cortada e reiniciada, nunca cria player novo. A
///    contagem por som é proporcional a quanto ele realmente sobrepõe
///    (hit/elementais pedem mais que um efeito de UI ou de evento único).
/// 5. Throttle por som ([_throttleMs]) mais um piso global
///    ([_globalThrottleMs]): mesmo com trabalho nativo mais barato por
///    trigger (item 1), ainda existe um teto de quantas chamadas de canal de
///    plataforma por segundo fazem sentido — sem o piso global, sons
///    diferentes tocando juntos ainda somam uma rajada no mesmo frame.
/// 6. Guarda de voz ocupada ([_busy]): uma voz só aceita um
///    `seek()`+`resume()` em voo por vez. Se o rodízio cai numa voz ainda em
///    voo, o toque é DESCARTADO (não enfileira, não tenta outra voz) — o
///    teto de chamadas simultâneas em voo passa a ser o número de vozes, não
///    a taxa de disparo do combate.
/// 7. `positionUpdater = null` em cada voz. O construtor de `AudioPlayer`
///    (audioplayers 6.7.1, `audioplayer.dart`) instala por conta própria um
///    `FramePositionUpdater`, que a cada `resume()` começa a chamar
///    `getCurrentPosition()` — uma ida e volta no canal de plataforma — UMA
///    VEZ POR QUADRO, por voz tocando, reagendando um frame callback a cada
///    tique. Com 10 vozes ativas num pico de combate isso são ~600 chamadas
///    de canal por segundo, e o resultado vai pra um `positionStream` que
///    nada neste projeto escuta: trabalho 100% jogado fora, que escala
///    exatamente com a intensidade do combate (quanto mais som, mais lento o
///    quadro). É por isso que pool e throttle sozinhos não resolviam — eles
///    limitam quantos toques COMEÇAM, não o custo por quadro de cada voz
///    enquanto ela toca.
class GameAudio {
  GameAudio._();
  static final GameAudio instance = GameAudio._();

  static const Map<Sfx, String> _paths = {
    Sfx.dash: 'sfx/dash.wav',
    Sfx.retorno: 'sfx/retorno.wav',
    Sfx.liberar: 'sfx/liberar.wav',
    Sfx.enemyDie: 'sfx/enemy_die.wav',
    Sfx.die: 'sfx/die.wav',
    Sfx.stairs: 'sfx/enterStairs.wav',
    Sfx.btn: 'sfx/btn.wav',
    Sfx.hit: 'sfx/hit.wav',
    Sfx.fogo: 'sfx/fogo.wav',
    Sfx.agua: 'sfx/agua.wav',
    Sfx.raio: 'sfx/raio.wav',
    Sfx.veneno: 'sfx/veneno.wav',
    Sfx.pick: 'sfx/pick.wav',
    Sfx.defesa: 'sfx/defesa.wav',
    Sfx.tiro: 'sfx/tiro.wav',
    Sfx.dano: 'sfx/dano.wav',
    Sfx.critico: 'sfx/critico.wav',
    Sfx.escudoQuebra: 'sfx/escudoQuebra.wav',
    Sfx.esquiva: 'sfx/esquiva.wav',
    Sfx.vidaBaixa: 'sfx/vidaBaixa.wav',
    Sfx.golpe: 'sfx/golpe.wav',
    Sfx.moeda: 'sfx/moeda.wav',
    Sfx.cura: 'sfx/cura.wav',
    Sfx.item: 'sfx/item.wav',
    Sfx.salaLimpa: 'sfx/salaLimpa.wav',
    Sfx.salaTranca: 'sfx/salaTranca.wav',
    Sfx.semDinheiro: 'sfx/semDinheiro.wav',
    Sfx.bossEntrada: 'sfx/bossEntrada.wav',
    Sfx.evolucao: 'sfx/evolucao.wav',
    Sfx.atordoado: 'sfx/atordoado.wav',
    Sfx.energiaVazia: 'sfx/energiaVazia.wav',
    Sfx.cursor: 'sfx/cursor.wav',
    Sfx.voltar: 'sfx/voltar.wav',
    Sfx.explosao: 'sfx/explosao.wav',
    Sfx.explosaoFogo: 'sfx/explosaoFogo.wav',
    Sfx.explosaoAgua: 'sfx/explosaoAgua.wav',
    Sfx.explosaoRaio: 'sfx/explosaoRaio.wav',
    Sfx.explosaoVeneno: 'sfx/explosaoVeneno.wav',
    Sfx.bossDerrotado: 'sfx/bossDerrotado.wav',
    Sfx.campeao: 'sfx/campeao.wav',
    Sfx.escudoRecarga: 'sfx/escudoRecarga.wav',
  };

  /// Quantas vozes cada som ganha — só os que realmente se sobrepõem em
  /// combate (dano e ataques elementais) precisam de mais de uma. O padrão
  /// pra quem não está aqui é [_defaultVoiceCount].
  ///
  /// ESTE MAPA TEM ORÇAMENTO. Cada voz é um `MediaPlayer` NATIVO vivo o tempo
  /// todo, e o Android tem teto de instâncias por processo — perto de 32 na
  /// maioria dos aparelhos. A soma daqui era 54, e enquanto o jogo era mudo de
  /// trilha isso passou despercebido; no dia em que a música entrou, o player
  /// dela foi o 55º, não conseguiu decodificador (`MediaPlayer error (1, -19)`)
  /// e o reinício do loop derrubou o app com um `IllegalStateException` NATIVO,
  /// que nenhum `catch` em Dart alcança.
  ///
  /// O teto real de sobreposição é muito menor do que parece: [_globalThrottleMs]
  /// de 80ms limita o jogo INTEIRO a ~12 toques por segundo, e um efeito curto
  /// dura uns 0,3s — ou seja, nunca há muito mais que meia dúzia de vozes
  /// soando ao mesmo tempo. Três vozes no som mais disputado já sobra.
  ///
  /// Antes de aumentar qualquer número aqui, some o mapa inteiro e lembre de
  /// reservar uma vaga pra música.
  ///
  /// Conta atual: 29 vozes próprias + 1 compartilhada ([_raros]) + a música.
  /// Os elementais ficam com uma voz cada desde que as explosões ganharam
  /// som próprio ([CreatureTypeSfx.explosaoSfx]): antes as duas coisas
  /// disputavam a mesma voz.
  static const Map<Sfx, int> _voiceCounts = {
    Sfx.hit: 2,
  };
  static const int _defaultVoiceCount = 1;

  static const int _throttleMs = 50;

  /// Piso entre QUAISQUER dois toques, não importa o som — sem isso, sons
  /// diferentes tocando ao mesmo tempo (cada um dentro do próprio throttle)
  /// ainda somam uma rajada de chamadas de canal de plataforma no mesmo
  /// frame. Era 120ms enquanto o modo era `lowLatency`/`SoundPool` (cada
  /// `play()` alocava `AudioTrack` nativo de verdade); depois da troca pra
  /// `PlayerMode.mediaPlayer` (item 1 da doc da classe) esse custo por toque
  /// já não existe mais — 80ms (~12 toques/s) volta a dar folga sem reabrir
  /// a saturação antiga.
  static const int _globalThrottleMs = 80;

  bool _ready = false;
  bool get isReady => _ready;

  final Map<Sfx, List<AudioPlayer>> _voices = {};
  final Map<Sfx, int> _nextVoice = {};
  final Map<Sfx, int> _lastPlayedAtMs = {};
  int _lastPlayedAnyAtMs = 0;

  /// Vozes com um `stop()`/`resume()` em voo agora — achado de campo #2
  /// (depois do `seek` travado): nada limitava quantos `_restart` ficavam
  /// pendurados ao mesmo tempo. Em combate pesado, disparo mais rápido que o
  /// canal de plataforma consegue confirmar vira fila crescente — os sons
  /// não tocam na hora, tocam depois, todos de uma vez, quando o combate já
  /// acabou. Esta guarda faz o teto real ser o número de vozes (35), não a
  /// taxa de disparo: se a voz escolhida no rodízio já está ocupada, ESTE
  /// toque é descartado (não tenta outra voz, não enfileira) — perder um som
  /// isolado em pico de combate é aceitável, acumular um estoque de sons
  /// atrasados não é.
  final Set<AudioPlayer> _busy = {};

  double volume = volumePadrao;
  bool enabled = true;

  static const double volumePadrao = 0.7;

  /// Troca o volume de TODAS as vozes já criadas, além do campo.
  ///
  /// Mexer só no campo não faria nada audível: ele é lido uma vez por voz no
  /// `preload`, e as 30 vozes já existem com o valor antigo gravado no player
  /// nativo. Quem chama é o seletor das configurações, então o custo das 30
  /// chamadas de canal de plataforma cai fora do jogo.
  ///
  /// Nenhum `await`: o seletor arrasta e dispara isto a cada passo, e segurar
  /// o quadro esperando confirmação de 30 players deixaria o arraste travado.
  void aplicarVolume(double novo) {
    volume = novo.clamp(0.0, 1.0);
    for (final vozes in _voices.values) {
      for (final player in vozes) {
        player.setVolume(volume).catchError(
          (e, st) => debugPrint('GameAudio.aplicarVolume falhou: $e'),
        );
      }
    }
  }

  Future<void>? _preloadFuture;

  /// Chamado no boot (`main.dart`, sem `await` — só pra começar cedo) e de
  /// novo no `onLoad` do jogo (`CreaturesRogueGame`, com `await`, mesmo
  /// tratamento de `_preloadCombatSprites`: nenhum som deve faltar no
  /// primeiro uso). "Single-flight": a segunda chamada não recarrega nada,
  /// só espera o mesmo `Future` da primeira — sem isso as duas chamadas
  /// disparariam `loadAll`/`createPool` em paralelo, duplicando trabalho.
  Future<void> preload() => _preloadFuture ??= _doPreload();

  /// Se o áudio do dispositivo falhar (driver ausente, permissão negada,
  /// etc.), o jogo segue mudo em vez de travar: [play] já sai cedo enquanto
  /// `_ready` for false.
  Future<void> _doPreload() async {
    try {
      // `flame_audio` resolve caminho como `<prefix><path>`, e o prefixo
      // padrão é `assets/audio/` — não bate com `assets/sounds/`, que é onde
      // o projeto guarda tudo (sfx e música). Sem isso, `loadAll`/`createPool`
      // buscam um arquivo que não existe; no web isso não falha na hora (o
      // dev server devolve o fallback da SPA em vez de 404), só quebra depois
      // ao tocar, como "Format error" — parecia problema de codec do .wav,
      // mas era o caminho errado o tempo todo. `updatePrefix` acerta tanto o
      // cache de efeitos quanto o de `FlameAudio.bgm` (música) numa chamada só.
      FlameAudio.updatePrefix('assets/sounds/');
      // Aquece o cache de bytes uma vez: sem isso, cada voz chamando
      // `setSource` abaixo buscaria o mesmo arquivo de novo.
      await FlameAudio.audioCache.loadAll(_paths.values.toList());

      // `mixWithOthers`: cada voz toca sem pedir foco de áudio exclusivo —
      // é o que evita a tempestade de AUDIOFOCUS_LOSS entre as próprias
      // vozes do jogo (ver doc da classe). Uma instância só, reaproveitada
      // em todas as vozes.
      final audioContext = AudioContextConfig(
        focus: AudioContextConfigFocus.mixWithOthers,
      ).build();

      // Em PARALELO por som, serial dentro de cada som. Antes era uma fila
      // única de ~170 idas e voltas ao canal de plataforma, e ela já estourou
      // o timeout de 30s do `audioplayers` em campo — quando isso acontece o
      // `catch` lá embaixo deixa `_ready` em false e o jogo fica MUDO, não
      // lento. Dezessete correntes curtas encurtam o caminho crítico sem
      // virar uma rajada de 170 chamadas de uma vez.
      //
      // O alerta de rajada na doc desta classe (item 5) é sobre COMBATE, com
      // o quadro correndo; aqui não há quadro pra atrapalhar.
      await Future.wait(
        _paths.entries.where((e) => !_raros.contains(e.key)).map((entry) async {
          final voiceCount = _voiceCounts[entry.key] ?? _defaultVoiceCount;
          final players = <AudioPlayer>[];
          for (var i = 0; i < voiceCount; i++) {
            final player = AudioPlayer(playerId: '${entry.key.name}_$i')
              ..audioCache = FlameAudio.audioCache
              // Achado #7 (ver doc da classe): desliga o `FramePositionUpdater`
              // que o `AudioPlayer` instala sozinho no construtor.
              ..positionUpdater = null;
            await player.setPlayerMode(PlayerMode.mediaPlayer);
            await player.setAudioContext(audioContext);
            await player.setReleaseMode(ReleaseMode.stop);
            // O volume fica fixado AQUI, no caminho crítico. O aquecimento
            // também o reajusta no fim, mas ele é opcional e pulado no web —
            // depender dele deixaria as vozes no 1.0 padrão do `AudioPlayer`.
            await player.setVolume(volume);
            await player.setSource(AssetSource(entry.value));
            players.add(player);
          }
          _voices[entry.key] = players;
          _nextVoice[entry.key] = 0;
        }),
      );
      // A voz dos [_raros]: mesma configuração, sem arquivo fixo.
      final vozRara = AudioPlayer(playerId: 'raros')
        ..audioCache = FlameAudio.audioCache
        ..positionUpdater = null;
      await vozRara.setPlayerMode(PlayerMode.mediaPlayer);
      await vozRara.setAudioContext(audioContext);
      await vozRara.setReleaseMode(ReleaseMode.stop);
      await vozRara.setVolume(volume);
      _vozRara = vozRara;
      _ready = true;

      // Fora do caminho crítico de propósito: sem `await`, o `onLoad` do jogo
      // segue e a tela de loading sai. Ter pôsto trabalho opcional aqui dentro
      // já travou o jogo no navegador uma vez, onde a política de autoplay
      // deixa chamadas de áudio penduradas sem nunca resolver.
      unawaited(FlameAudio.audioCache.loadAll(GameMusic.todas));
    } catch (e, st) {
      // Loga em vez de engolir: roda uma vez no boot, então o custo é zero e
      // um preload que falha calado deixa o jogo mudo sem nenhuma pista.
      debugPrint('GameAudio.preload falhou: $e\n$st');
    }
  }

  /// Toca [sfx] se as vozes já estiverem prontas, habilitado, e fora do
  /// throttle (por som e global). Nunca lança e nunca bloqueia o frame —
  /// chamável direto de qualquer `update`/`onCollision` sem `await`.
  /// Sons que nunca tocam juntos — um por evento raro da run — e por isso
  /// dividem UMA voz, que troca de arquivo a cada toque ([_tocarRaro]).
  /// Cada voz própria custa um `MediaPlayer` do orçamento de [_voiceCounts];
  /// estes todos juntos custam um.
  ///
  /// O preço é a troca de arquivo no toque (`setSource`), que voz própria
  /// não paga. Por isso só entra aqui som que não é de combate.
  static const Set<Sfx> _raros = {
    Sfx.die,
    Sfx.stairs,
    Sfx.retorno,
    // Troca de criatura, recrutar, reviver: ação do jogador, um por vez.
    Sfx.liberar,
    Sfx.salaLimpa,
    Sfx.salaTranca,
    Sfx.semDinheiro,
    Sfx.bossEntrada,
    Sfx.bossDerrotado,
    Sfx.campeao,
    Sfx.evolucao,
    // Menu: só toca com o jogo parado, quando nenhum som de combate disputa.
    Sfx.cursor,
    Sfx.voltar,
  };
  AudioPlayer? _vozRara;

  /// Sons que tocam o arquivo de outro e dividem as vozes dele, em vez de
  /// gastar orçamento com uma cópia (ver [_voiceCounts]).
  static const Map<Sfx, Sfx> _apelidos = {Sfx.use: Sfx.pick};

  void play(Sfx sfx, {double? volume}) {
    if (!_ready || !enabled) return;
    sfx = _apelidos[sfx] ?? sfx;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastPlayedAnyAtMs < _globalThrottleMs) return;
    final last = _lastPlayedAtMs[sfx] ?? 0;
    if (nowMs - last < _throttleMs) return;

    if (_raros.contains(sfx)) {
      _lastPlayedAtMs[sfx] = nowMs;
      _lastPlayedAnyAtMs = nowMs;
      _tocarRaro(sfx);
      return;
    }

    final players = _voices[sfx];
    if (players == null || players.isEmpty) return;
    _lastPlayedAtMs[sfx] = nowMs;
    _lastPlayedAnyAtMs = nowMs;

    final i = _nextVoice[sfx]!;
    // Sempre avança o rodízio, mesmo se esta voz estiver ocupada e o toque
    // for descartado — é isso que faz a PRÓXIMA chamada cair numa voz
    // diferente em vez de tentar a mesma de novo.
    _nextVoice[sfx] = (i + 1) % players.length;

    final player = players[i];
    if (_busy.contains(player)) return;
    _busy.add(player);

    // Volume é fixado uma vez no preload (acima); só manda `setVolume` de
    // novo se ALGUÉM pediu um volume diferente pra este toque específico —
    // no caminho comum isso é uma chamada de canal de plataforma a menos.
    if (volume != null) {
      player.setVolume(volume).catchError(
        (e, st) => debugPrint('GameAudio.play(${sfx.name}) setVolume falhou: $e'),
      );
    }
    _restart(sfx, player);
  }

  /// `seek(0)` DE VERDADE espera a posição mudar antes de tocar — no
  /// `PlayerMode.mediaPlayer` isso é seguro (callback de conclusão real, ver
  /// doc da classe), diferente do `lowLatency`/`SoundPool` onde o mesmo
  /// `await` pendurava 30s. Por isso vale esperar ELE — é o que evita duas
  /// chamadas de `seek` correndo ao mesmo tempo na mesma voz.
  ///
  /// `resume()` já dispara solto, sem esperar: uma vez que a posição voltou
  /// pro zero, começar a tocar não tem corrida nenhuma pra evitar, e segurar
  /// a voz "ocupada" até o `resume()` também confirmar só encurtava a folga
  /// pra dois sons do mesmo tipo tocarem quase juntos (achado de campo: a
  /// guarda descartava som demais em rajada, ex. dois ataques de água quase
  /// simultâneos). Liberar a voz assim que o `seek` aterrissa é suficiente.
  ///
  /// O `catch`/log foi o que expôs o bug do `seek` no modo antigo (ver
  /// histórico do arquivo). Fica: só dispara em erro, nunca no caminho comum.
  /// Toca [sfx] na voz compartilhada dos [_raros]: troca o arquivo e toca.
  /// Voz ainda trocando (dois raros no mesmo instante) descarta o segundo,
  /// pela mesma regra de [_busy].
  Future<void> _tocarRaro(Sfx sfx) async {
    final voz = _vozRara;
    if (voz == null || _busy.contains(voz)) return;
    _busy.add(voz);
    try {
      await voz.setSource(AssetSource(_paths[sfx]!));
    } catch (e) {
      debugPrint('GameAudio.play(${sfx.name}) setSource falhou: $e');
      _busy.remove(voz);
      return;
    }
    _busy.remove(voz);
    voz.resume().catchError(
      (e, st) => debugPrint('GameAudio.play(${sfx.name}) resume falhou: $e'),
    );
  }

  Future<void> _restart(Sfx sfx, AudioPlayer player) async {
    try {
      await player.seek(Duration.zero);
    } catch (e) {
      debugPrint('GameAudio.play(${sfx.name}) seek falhou: $e');
      _busy.remove(player);
      return;
    }
    _busy.remove(player);
    player.resume().catchError(
      (e, st) => debugPrint('GameAudio.play(${sfx.name}) resume falhou: $e'),
    );
  }
}
