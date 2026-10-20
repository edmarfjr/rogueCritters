import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';

/// Maldições: fardos TEMPORÁRIOS que vêm grudados numa recompensa forte — o
/// pedestal amaldiçoado da sala do tesouro e o evento do Ídolo. O jogador
/// sempre vê qual é antes de aceitar.
///
/// Cada uma dura [salas] salas limpas (ver `Player.avancarMaldicoes`). Não
/// confundir com os `Pactos` (antes da run, valem a run toda) nem com os
/// itens de troca como o `Jejum` (o lado ruim É o item, e é permanente).
///
/// Cada maldição mexe num verbo diferente do jogo, e nenhuma repete um pacto.
enum Maldicao {
  /// O minimapa só mostra a sala atual.
  nevoa,

  /// Itens de pedestal, chão e loja aparecem em silhueta, como "???".
  cegueira,

  /// Não dá pra trocar de criatura — exceto a troca forçada de quem cai.
  corrente,

  /// Moedas no chão somem poucos segundos depois que o jogador chega perto.
  maosFuradas,

  /// A energia só recupera com o jogador parado.
  cansaco,

  /// Cada inimigo comum abatido solta uma alma que persegue e machuca.
  assombracao,

  /// O dano dobrado da vantagem elemental vira dano normal. O espelho do
  /// `Prisma`, que tira a desvantagem.
  dissonancia;

  /// Salas limpas até a maldição se dissipar.
  static const int salas = 6;

  /// Quantas maldições podem vir ao mesmo tempo. Vale na OFERTA (pedestal
  /// e Ídolo não oferecem além disso), não no aceite.
  static const int maximo = 3;

  String nome(BuildContext context) {
    final l = context.l10n;
    return switch (this) {
      Maldicao.nevoa => l.maldicao_nevoa,
      Maldicao.cegueira => l.maldicao_cegueira,
      Maldicao.corrente => l.maldicao_corrente,
      Maldicao.maosFuradas => l.maldicao_maosFuradas,
      Maldicao.cansaco => l.maldicao_cansaco,
      Maldicao.assombracao => l.maldicao_assombracao,
      Maldicao.dissonancia => l.maldicao_dissonancia,
    };
  }

  String descricao(BuildContext context) {
    final l = context.l10n;
    return switch (this) {
      Maldicao.nevoa => l.maldicao_nevoaDesc,
      Maldicao.cegueira => l.maldicao_cegueiraDesc,
      Maldicao.corrente => l.maldicao_correnteDesc,
      Maldicao.maosFuradas => l.maldicao_maosFuradasDesc,
      Maldicao.cansaco => l.maldicao_cansacoDesc,
      Maldicao.assombracao => l.maldicao_assombracaoDesc,
      Maldicao.dissonancia => l.maldicao_dissonanciaDesc,
    };
  }

  /// Uma maldição que o jogador ainda não carrega, ou `null` quando ele já
  /// está no [maximo] (ou carrega todas).
  static Maldicao? sortear(Map<Maldicao, int> ativas, Random rng) {
    if (ativas.length >= maximo) return null;
    final livres = values.where((m) => !ativas.containsKey(m)).toList();
    if (livres.isEmpty) return null;
    return livres[rng.nextInt(livres.length)];
  }

  static Map<String, int> paraSave(Map<Maldicao, int> ativas) => {
    for (final e in ativas.entries) e.key.name: e.value,
  };

  /// Lê o que [paraSave] gravou. Nome desconhecido (renomeado) é ignorado, e
  /// a contagem é limitada a [salas].
  static Map<Maldicao, int> deSave(Object? dados) {
    if (dados is! Map) return {};
    final resultado = <Maldicao, int>{};
    for (final m in values) {
      final n = dados[m.name];
      if (n is int && n > 0) resultado[m] = min(n, salas);
    }
    return resultado;
  }
}
