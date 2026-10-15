import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Anúncio com recompensa — hoje só o "assista pra reviver" do game over.
///
/// Só Android e iOS têm SDK de anúncio. Nas outras plataformas [suportado] é
/// false e [mostrarRecompensado] entrega a recompensa de graça: decisão
/// PROVISÓRIA, pra dar pra testar o reviver no PC. Tirar antes de publicar
/// em web/desktop (ou esconder o botão lá).
///
/// Os ids são os de TESTE do Google, que sempre carregam um anúncio de
/// mentira. Os de verdade saem da conta AdMob, depois que o app tiver o
/// `applicationId` definitivo — trocar aqui, no `AndroidManifest.xml` e no
/// `Info.plist`.
class Anuncios extends ChangeNotifier {
  Anuncios._();
  static final Anuncios instance = Anuncios._();

  static const String _idRecompensadoAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _idRecompensadoIos =
      'ca-app-pub-3940256099942544/1712485313';

  bool get suportado =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String get _idRecompensado => defaultTargetPlatform == TargetPlatform.iOS
      ? _idRecompensadoIos
      : _idRecompensadoAndroid;

  RewardedAd? _recompensado;
  bool _carregando = false;
  bool _iniciado = false;

  /// Tem um anúncio pronto pra mostrar agora? Fora do celular, sempre.
  bool get pronto => !suportado || _recompensado != null;

  /// Chamado uma vez no `main`, sem `await`: o consentimento (LGPD/GDPR, via
  /// UMP do Google) pode abrir um formulário, e a primeira tela não espera.
  /// Só depois do consentimento o SDK sobe e o primeiro anúncio carrega.
  void iniciar() {
    if (!suportado || _iniciado) return;
    _iniciado = true;
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((_) => _subir()),
      // Sem conseguir falar com o servidor de consentimento, tenta mesmo
      // assim: `canRequestAds` decide com o que ficou guardado.
      (_) => _subir(),
    );
  }

  Future<void> _subir() async {
    if (!await ConsentInformation.instance.canRequestAds()) return;
    await MobileAds.instance.initialize();
    _carregar();
  }

  void _carregar() {
    if (_carregando || _recompensado != null) return;
    _carregando = true;
    RewardedAd.load(
      adUnitId: _idRecompensado,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (anuncio) {
          _carregando = false;
          _recompensado = anuncio;
          notifyListeners();
        },
        onAdFailedToLoad: (_) {
          _carregando = false;
          // Sem rede ou sem anúncio no estoque: tenta de novo daqui a pouco,
          // pra quando o jogador morrer já haver um.
          Timer(const Duration(seconds: 30), _carregar);
        },
      ),
    );
  }

  /// Mostra o anúncio e devolve se o jogador ganhou a recompensa (viu até o
  /// fim). Fechar antes da hora, ou falhar ao abrir, devolve false. Já pede
  /// o próximo anúncio na saída.
  Future<bool> mostrarRecompensado() {
    if (!suportado) return Future.value(true);
    final anuncio = _recompensado;
    if (anuncio == null) return Future.value(false);
    _recompensado = null;
    notifyListeners();

    final fim = Completer<bool>();
    var ganhou = false;
    anuncio.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!fim.isCompleted) fim.complete(ganhou);
        _carregar();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        if (!fim.isCompleted) fim.complete(false);
        _carregar();
      },
    );
    anuncio.show(onUserEarnedReward: (_, _) => ganhou = true);
    return fim.future;
  }
}
