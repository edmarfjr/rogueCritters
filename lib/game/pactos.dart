import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';

/// Pactos de dificuldade (o "Calor" do Hades): restrições que o jogador liga
/// antes da run, cada uma valendo pontos de calor. Liberam depois da
/// primeira vitória (ver `CreatureProgress.pactosLiberados`).
///
/// Recompensa: +[xpPorCalor] de XP de progressão por ponto, e a marca do
/// maior calor vencido com cada criatura (ver `CreatureProgress.calorVencido`).
enum Pacto {
  furia(maxNivel: 3, calorPorNivel: 1),
  couro(maxNivel: 3, calorPorNivel: 1),
  pressa(maxNivel: 2, calorPorNivel: 1),
  campeoes(maxNivel: 2, calorPorNivel: 1),
  chefe(maxNivel: 2, calorPorNivel: 2),
  vidaCurta(maxNivel: 1, calorPorNivel: 3),
  escudoFragil(maxNivel: 2, calorPorNivel: 1),
  inflacao(maxNivel: 2, calorPorNivel: 1),
  escassez(maxNivel: 1, calorPorNivel: 2),
  semVolta(maxNivel: 1, calorPorNivel: 2);

  const Pacto({required this.maxNivel, required this.calorPorNivel});

  final int maxNivel;
  final int calorPorNivel;

  String nome(BuildContext context) {
    final l = context.l10n;
    return switch (this) {
      Pacto.furia => l.pacto_furia,
      Pacto.couro => l.pacto_couro,
      Pacto.pressa => l.pacto_pressa,
      Pacto.campeoes => l.pacto_campeoes,
      Pacto.chefe => l.pacto_chefe,
      Pacto.vidaCurta => l.pacto_vidaCurta,
      Pacto.escudoFragil => l.pacto_escudoFragil,
      Pacto.inflacao => l.pacto_inflacao,
      Pacto.escassez => l.pacto_escassez,
      Pacto.semVolta => l.pacto_semVolta,
    };
  }

  /// O efeito no [nivel] dado. Com 0, mostra o do nível 1 — é o que o
  /// jogador está pra ligar.
  String descricao(BuildContext context, int nivel) {
    final l = context.l10n;
    final n = max(nivel, 1);
    return switch (this) {
      Pacto.furia => l.pacto_furiaDesc(Pactos.danoInimigoPorNivel100 * n),
      Pacto.couro => l.pacto_couroDesc(Pactos.vidaInimigoPorNivel100 * n),
      Pacto.pressa => l.pacto_pressaDesc(Pactos.tempoInimigoPorNivel100 * n),
      Pacto.campeoes => l.pacto_campeoesDesc(Pactos.campeaoPorNivel100 * n),
      Pacto.chefe => l.pacto_chefeDesc(Pactos.vidaChefePorNivel100 * n),
      Pacto.vidaCurta => l.pacto_vidaCurtaDesc,
      Pacto.escudoFragil =>
        l.pacto_escudoFragilDesc(Pactos.regenEscudoPorNivel100 * n),
      Pacto.inflacao => l.pacto_inflacaoDesc(Pactos.precoLojaPorNivel100 * n),
      Pacto.escassez => l.pacto_escassezDesc,
      Pacto.semVolta => l.pacto_semVoltaDesc,
    };
  }
}

/// Os pactos DA RUN em andamento e o efeito de cada um. Estático porque é
/// lido de pontos que não têm o jogo à mão (`Enemy.onLoad`, a vida máxima do
/// `Player`); quem escreve é só o `CreaturesRogueGame.startRun`.
class Pactos {
  Pactos._();

  static Map<Pacto, int> daRun = const {};

  static int nivel(Pacto p) => daRun[p] ?? 0;

  static int calorDe(Map<Pacto, int> pactos) => pactos.entries.fold(
    0,
    (soma, e) => soma + e.value * e.key.calorPorNivel,
  );

  static int get calorDaRun => calorDe(daRun);

  // Por nível, em porcento — os textos mostram estes mesmos números.
  static const int danoInimigoPorNivel100 = 15;
  static const int vidaInimigoPorNivel100 = 20;
  static const int tempoInimigoPorNivel100 = 10;
  static const int campeaoPorNivel100 = 15;
  static const int vidaChefePorNivel100 = 30;
  static const int regenEscudoPorNivel100 = 30;
  static const int precoLojaPorNivel100 = 25;
  static const double xpPorCalor = 0.05;

  static double get multDanoInimigo =>
      1 + danoInimigoPorNivel100 / 100 * nivel(Pacto.furia);
  static double get multVidaInimigo =>
      1 + vidaInimigoPorNivel100 / 100 * nivel(Pacto.couro);
  static double get multTempoInimigo =>
      1 + tempoInimigoPorNivel100 / 100 * nivel(Pacto.pressa);
  static double get bonusChanceCampeao =>
      campeaoPorNivel100 / 100 * nivel(Pacto.campeoes);
  static double get multVidaChefe =>
      1 + vidaChefePorNivel100 / 100 * nivel(Pacto.chefe);
  static double get multRegenEscudo =>
      1 - regenEscudoPorNivel100 / 100 * nivel(Pacto.escudoFragil);
  static double get multPrecoLoja =>
      1 + precoLojaPorNivel100 / 100 * nivel(Pacto.inflacao);
  static bool get escassez => nivel(Pacto.escassez) > 0;
  static bool get semVolta => nivel(Pacto.semVolta) > 0;
  static double get multXp => 1 + xpPorCalor * calorDaRun;

  /// Vida máxima base de uma criatura com o `Vida Curta`: um coração (2
  /// pontos) a menos, nunca abaixo de um coração.
  static double vidaMaximaBase(double maxHp) =>
      nivel(Pacto.vidaCurta) > 0 ? max(2.0, maxHp - 2) : maxHp;

  // ------------------------------------------------------------ save

  static Map<String, int> paraSave(Map<Pacto, int> pactos) => {
    for (final e in pactos.entries)
      if (e.value > 0) e.key.name: e.value,
  };

  /// Lê o que [paraSave] gravou. Pacto desconhecido (renomeado) é ignorado,
  /// e o nível é limitado ao máximo de hoje.
  static Map<Pacto, int> deSave(Object? dados) {
    if (dados is! Map) return {};
    final resultado = <Pacto, int>{};
    for (final p in Pacto.values) {
      final n = dados[p.name];
      if (n is int && n > 0) resultado[p] = min(n, p.maxNivel);
    }
    return resultado;
  }
}
