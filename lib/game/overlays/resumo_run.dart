import 'package:creatures_rogue/game/pactos.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/core/ui_theme.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/creatures_rogue_game.dart';
import 'package:creatures_rogue/game/overlays/barra_progressao.dart';
import 'package:creatures_rogue/game/overlays/selecao_widgets.dart';
import 'package:creatures_rogue/l10n/creature_i18n.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';

/// Resumo da run que acabou: até onde chegou, quanto durou, quantos caíram,
/// quem derrubou o grupo, quem jogou e a barra de progressão. Usado pelo Game Over e
/// pela vitória — as duas telas encerram uma run e contam a mesma história.
///
/// Lê o estado VIVO do jogo: no fim da run nada é resetado até o jogador
/// apertar RESTART ou escolher criatura de novo, então os contadores ainda
/// são os da run terminada.
///
/// [largura] é obrigatória porque o Game Over vive dentro do `FittedBox` do
/// `ResponsiveOverlayScaffold`, que dá largura INFINITA ao filho — e um
/// `Wrap` com largura infinita nunca quebra linha, só cresce pro lado.
class ResumoRun extends StatelessWidget {
  final CreaturesRogueGame game;
  final double largura;

  /// Repassado à [BarraProgressao]: chamado quando a barra terminou de
  /// encher e a última janela de item fechou.
  final VoidCallback aoConcluirProgressao;

  const ResumoRun({
    super.key,
    required this.game,
    required this.largura,
    required this.aoConcluirProgressao,
  });

  static const double _ladoCriatura = 48;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SizedBox(
      width: largura,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Os números da run num quadro próprio: separa o placar do resto
          // (derrota, elenco, barra), que são outra leitura.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: const BoxDecoration(
              color: UiTheme.quadroFundoCor,
              border: BordaDupla(cor: Palette.preto, espessura: 2),
            ),
            child: Column(
              children: [
                _linha(l.resumo_dungeon(game.currentLevel, game.currentFloor)),
                _linha(l.victory_tempo(game.tempoDeRunFormatado)),
                _linha(l.resumo_abates(game.abatesDaRun)),
                if (Pactos.calorDaRun > 0)
                  _linha(l.resumo_calor(Pactos.calorDaRun)),
              ],
            ),
          ),
          ..._derrota(context),
          const SizedBox(height: 12),
          _rotulo(l.victory_elenco),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [for (final id in game.criaturasUsadas) _criatura(id)],
          ),
          const SizedBox(height: 16),
          BarraProgressao(
            xpAntes: game.xpProgressaoAntes,
            xpGanho: game.xpProgressaoGanho,
            largura: largura,
            aoConcluir: aoConcluirProgressao,
          ),
        ],
      ),
    );
  }

  /// "Derrotado por": sprite e nome de quem deu o golpe final, ou o rótulo da
  /// armadilha. Sem origem conhecida, nada — melhor omitir do que apontar a
  /// criatura errada.
  List<Widget> _derrota(BuildContext context) {
    final l = context.l10n;
    final quem = game.derrotadoPor;
    if (quem == null && !game.derrotadoPorArmadilha) return const [];

    return [
      const SizedBox(height: 12),
      _rotulo(l.resumo_derrotadoPor),
      const SizedBox(height: 4),
      if (quem != null) ...[
        // A forma exata do agressor (o boss chega aqui já evoluído), não a
        // base do registro: é o sprite que o jogador viu na luta.
        SpriteUi(
          caminho: quem.spritePath,
          tamanho: Vector2(_ladoCriatura, _ladoCriatura),
          cor1: quem.corClara,
          cor2: quem.corEscura,
        ),
        _linha(creatureName(context, quem.id)),
      ] else
        _linha(l.resumo_armadilha),
    ];
  }

  Widget _criatura(String id) {
    final criatura = CreatureRegistry.all.firstWhere(
      (c) => c.id == id,
      // Id salvo de uma versão em que a criatura existia e hoje não mais.
      orElse: () => CreatureRegistry.all.first,
    );
    // Só o sprite: o nome quebrava no meio ("Torchmi/n") na largura de um
    // ícone, e o elenco já se reconhece pelo desenho.
    return SpriteUi(
      caminho: criatura.spritePath,
      tamanho: Vector2(_ladoCriatura, _ladoCriatura),
      cor1: criatura.corClara,
      cor2: criatura.corEscura,
    );
  }

  Widget _linha(String texto) => Text(
    texto,
    textAlign: TextAlign.center,
    style: const TextStyle(color: UiTheme.txtCor, fontSize: 16),
  );

  Widget _rotulo(String texto) => Text(
    texto,
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: UiTheme.txtCor,
      fontSize: 12,
      letterSpacing: 2,
    ),
  );
}
