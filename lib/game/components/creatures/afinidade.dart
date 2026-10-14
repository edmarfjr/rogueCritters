import 'package:creatures_rogue/game/components/creatures/creature_type.dart';

/// Afinidade elemental do grupo: 2 criaturas do mesmo tipo = nível 1, 3 =
/// nível 2; três tipos diferentes = Diversidade. Conta o grupo inteiro —
/// em campo, no banco e desmaiadas —, senão o bônus piscaria no meio da luta.
///
/// O bônus de tipo só vale com uma criatura DAQUELE tipo em campo (ver
/// `Player._aplicarAfinidade`); a Diversidade vale sempre (ver
/// `CreaturesRogueGame.trocaCooldownMax`).
///
/// Neutro não tem afinidade própria, mas conta como tipo pra Diversidade.
class Afinidade {
  /// Tipo da afinidade, ou null sem afinidade de tipo.
  final CreatureType? tipo;

  /// 1 ou 2 com [tipo]; 0 sem.
  final int nivel;

  final bool diversidade;

  const Afinidade._({this.tipo, this.nivel = 0, this.diversidade = false});

  static const Afinidade nenhuma = Afinidade._();

  bool get ativa => tipo != null || diversidade;

  // Bônus por nível.
  static const double danoContraQueimandoPorNivel = 0.20;
  static const double regenEscudoPorNivel = 0.30;
  static const double curaAoLimparPorNivel = 0.25;
  static const double cooldownPorNivel = 0.10;
  static const double fatorTrocaDiversidade = 0.5;

  static Afinidade de(Iterable<CreatureType> tipos) {
    final lista = tipos.toList();
    final contagem = <CreatureType, int>{};
    for (final t in lista) {
      contagem[t] = (contagem[t] ?? 0) + 1;
    }
    if (lista.length == 3 && contagem.length == 3) {
      return const Afinidade._(diversidade: true);
    }
    for (final entrada in contagem.entries) {
      if (entrada.key == CreatureType.neutro || entrada.value < 2) continue;
      return Afinidade._(tipo: entrada.key, nivel: entrada.value - 1);
    }
    return nenhuma;
  }

  @override
  bool operator ==(Object other) =>
      other is Afinidade &&
      other.tipo == tipo &&
      other.nivel == nivel &&
      other.diversidade == diversidade;

  @override
  int get hashCode => Object.hash(tipo, nivel, diversidade);
}
