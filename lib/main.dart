import 'dart:async';

import 'package:creatures_rogue/game/overlays/victory_overlay.dart';
import 'package:creatures_rogue/game/overlays/compendio_overlay.dart';
import 'package:creatures_rogue/game/overlays/evento_overlay.dart';
import 'package:creatures_rogue/game/overlays/reviver_overlay.dart';
import 'package:creatures_rogue/game/anuncios.dart';
import 'package:creatures_rogue/game/overlays/retirement_overlay.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/core/ui_theme.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/components/creatures/creature_progress.dart';
import 'package:creatures_rogue/game/overlays/boss_reveal_overlay.dart';
import 'package:creatures_rogue/game/overlays/console_overlay.dart';
import 'package:creatures_rogue/game/overlays/creature_select_overlay.dart';
import 'package:creatures_rogue/game/overlays/evolution_overlay.dart';
import 'package:creatures_rogue/game/overlays/game_over_overlay.dart';
import 'package:creatures_rogue/game/overlays/intro_overlay.dart';
import 'package:creatures_rogue/game/overlays/loading_screen.dart';
import 'package:creatures_rogue/game/overlays/main_menu_overlay.dart';
import 'package:creatures_rogue/game/overlays/title_overlay.dart';
import 'package:creatures_rogue/game/overlays/wild_creature_info_overlay.dart';
import 'package:creatures_rogue/game/overlays/pause_overlay.dart';
import 'package:creatures_rogue/game/overlays/settings_overlay.dart';
import 'package:creatures_rogue/game/game_settings.dart';
import 'package:creatures_rogue/game/run_save.dart';
import 'package:creatures_rogue/game/creatures_rogue_game.dart';
import 'package:creatures_rogue/game/audio/game_audio.dart';
import 'package:creatures_rogue/l10n/gen/app_localizations.dart';

bool get isDesktopPlatform {
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CreatureProgress.instance.load();
  await GameSettings.instance.load();
  await RunSave.instance.load();
  // Sem `await`: os .wav são pequenos, mas carregar áudio não pode ser o que
  // atrasa a primeira tela. `GameAudio.play()` já é seguro de chamar antes
  // disso terminar — só fica mudo até o pool ficar pronto.
  unawaited(GameAudio.instance.preload());
  // Consentimento de privacidade + SDK de anúncio, sem segurar a abertura.
  Anuncios.instance.iniciar();
  //await Flame.device.setLandscape();
  await Flame.device.fullScreen();

  //if (!isDesktopPlatform) {
  //  await SystemChrome.setPreferredOrientations([
  //    DeviceOrientation.landscapeLeft,
  //    DeviceOrientation.landscapeRight,
  //  ]);
  // }

  final creaturesGame = CreaturesRogueGame(
    // Esquema escolhido na última sessão (ver GameSettings).
    controlScheme: GameSettings.instance.controlScheme,
  );

  // Construído uma vez só, fora do `builder` abaixo, e reaproveitado em toda
  // troca de idioma. `GameWidget(game: ...)` roda `_initializeGame` no
  // próprio construtor (não no `initState`) — reconstruir este widget a cada
  // rebuild do `ValueListenableBuilder` chamava `overlays.addAll(['MainMenu'])`
  // de novo a cada troca, empilhando o menu principal por cima da run em
  // andamento (era o bug: idioma trocava, mas o `MainMenu` aparecia encima da
  // Hud/tela ativa).
  final gameHome = Scaffold(
    // Mesma cor que `CreaturesRogueGame.backgroundColor` escolhe: o Scaffold
    // fica atrás do GameWidget e aparece em qualquer folga de layout, então
    // duas cores diferentes aqui dariam uma emenda visível.
    backgroundColor: GameSettings.instance.controlesNaTela
        ? UiTheme.screenBackground
        : Palette.preto,
    body: GameWidget<CreaturesRogueGame>(
      game: creaturesGame,
      overlayBuilderMap: {
        'Title': (context, game) => TitleOverlay(game: game),
        'WildCreatureInfo': (context, game) =>
            WildCreatureInfoOverlay(game: game),
        'MainMenu': (context, game) => MainMenuOverlay(game: game),
        'Compendio': (context, game) => CompendioOverlay(game: game),
        'Evento': (context, game) => EventoOverlay(game: game),
        'Reviver': (context, game) => ReviverOverlay(game: game),
        'Settings': (context, game) => SettingsOverlay(game: game),
        'Intro': (context, game) => IntroOverlay(game: game),
        'CreatureSelect': (context, game) => CreatureSelectOverlay(game: game),
        'BossReveal': (context, game) => BossRevealOverlay(game: game),
        'PauseMenu': (context, game) => PauseMenuOverlay(game: game),
        'Hud': (context, game) => HudOverlay(game: game),
        'GameOver': (context, game) =>
            GameOverMenu(game: game), // <--- REGISTRO NOVO
        'Evolution': (context, game) => EvolutionOverlay(game: game),
        'Retirement': (context, game) => RetirementOverlay(game: game),
        'Victory': (context, game) => VictoryOverlay(game: game),
      },
      // O GameWidget só empilha os overlays (inclusive o MainMenu) depois
      // que o onLoad do jogo resolve; até lá quem pinta a tela é isto.
      loadingBuilder: (context) => const LoadingScreen(),
      // Começa na tela de título; só a abertura do app passa por ela — os
      // caminhos de volta (game over, pausa...) abrem o 'MainMenu' direto.
      initialActiveOverlays: const ['Title'],
    ),
  );

  runApp(
    ValueListenableBuilder<Locale?>(
      valueListenable: GameSettings.instance.localeNotifier,
      builder: (context, locale, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          fontFamily: 'pixelFont', // Define a fonte padrão para todo o app
          //primarySwatch: Colors.blue,
        ),
        home: gameHome,
      ),
    ),
  );
}

class GameOverOverlay {}
