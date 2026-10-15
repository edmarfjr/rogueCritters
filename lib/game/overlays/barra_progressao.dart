import 'package:creatures_rogue/game/audio/sfx.dart';
import 'package:creatures_rogue/game/audio/game_audio.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/audio/ui_sfx.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/core/ui_theme.dart';
import 'package:creatures_rogue/game/components/items/item_efeito.dart';
import 'package:creatures_rogue/game/components/items/progressao_itens.dart';
import 'package:creatures_rogue/game/overlays/selecao_widgets.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';

/// Barra de progressão do fim de run: começa no XP de antes da run e enche
/// até o de depois. Cada nível cruzado PAUSA a barra e abre a janela do item
/// destravado; ela só volta a encher quando a janela fecha.
///
/// O XP já foi gravado antes desta tela abrir (ver
/// `CreaturesRogueGame._premiarProgressao`): a animação é só reprodução, e
/// fechar o app no meio não perde nada.
///
/// Tocar a barra pula a animação, mas NÃO pula as janelas — elas aparecem em
/// fila, uma por nível, porque são o prêmio. [aoConcluir] dispara quando a
/// barra chegou ao fim e a última janela fechou; as telas usam isso pra
/// liberar os botões.
class BarraProgressao extends StatefulWidget {
  final int xpAntes;
  final int xpGanho;
  final double largura;
  final VoidCallback aoConcluir;

  const BarraProgressao({
    super.key,
    required this.xpAntes,
    required this.xpGanho,
    required this.largura,
    required this.aoConcluir,
  });

  @override
  State<BarraProgressao> createState() => _BarraProgressaoState();
}

class _BarraProgressaoState extends State<BarraProgressao>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controle;

  /// Velocidade da barra: quantos milissegundos cada ponto de XP leva pra
  /// entrar. Taxa FIXA — a duração é só `xpGanho × _msPorXp`, sem piso nem
  /// teto, então run que rende o dobro enche pelo dobro do tempo.
  static const int _msPorXp = 30;

  /// Último nível cuja janela já foi mostrada. Começa no nível de antes da run.
  late int _nivelMostrado;
  bool _janelaAberta = false;
  bool _concluido = false;

  int get _xpExibido =>
      widget.xpAntes + (widget.xpGanho * _controle.value).round();

  @override
  void initState() {
    super.initState();
    _nivelMostrado = ProgressaoItens.nivelPara(widget.xpAntes);
    _ultimoTique = widget.xpAntes ~/ _xpPorTique;
    _controle = AnimationController(
      vsync: this,
      // Run longa demora de verdade (650 XP a 30 ms dá ~20 s) — tocar a
      // barra pula pro fim.
      duration: Duration(milliseconds: widget.xpGanho * _msPorXp),
    )..addListener(_aoAnimar);

    // Um quadro de respiro antes de encher: abrindo junto com a tela, o
    // começo da animação passaria despercebido.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.xpGanho <= 0) {
        _concluir();
      } else {
        _controle.forward();
      }
    });
  }

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  /// Tique de XP enquanto a barra enche: um a cada [_xpPorTique] XP, com o
  /// som de pegar XP no jogo.
  static const int _xpPorTique = 5;
  int _ultimoTique = 0;

  void _aoAnimar() {
    setState(() {});
    final tique = _xpExibido ~/ _xpPorTique;
    if (tique != _ultimoTique) {
      _ultimoTique = tique;
      GameAudio.instance.play(Sfx.pick);
    }
    _verificarNivel();
  }

  Future<void> _verificarNivel() async {
    if (_janelaAberta) return;
    final nivel = ProgressaoItens.nivelPara(_xpExibido);

    if (nivel > _nivelMostrado) {
      _janelaAberta = true;
      _controle.stop();
      final item = ProgressaoItens.porNivel[_nivelMostrado];
      await _mostrarDesbloqueio(item);
      if (!mounted) return;
      _nivelMostrado++;
      _janelaAberta = false;
      // Pode haver mais de um nível já cruzado (barra pulada, ou ganho que
      // atravessa dois níveis num quadro): checa de novo antes de seguir.
      _verificarNivel();
      return;
    }

    if (_controle.value >= 1.0) {
      _concluir();
    } else if (!_controle.isAnimating) {
      _controle.forward();
    }
  }

  void _concluir() {
    if (_concluido) return;
    _concluido = true;
    widget.aoConcluir();
  }

  void _pular() {
    if (_concluido || _janelaAberta) return;
    _controle.value = 1.0;
  }

  Future<void> _mostrarDesbloqueio(ItemEfeito item) {
    GameAudio.instance.play(Sfx.item);
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _JanelaDesbloqueio(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final xp = _xpExibido;
    final nivel = ProgressaoItens.nivelPara(xp);
    final maximo = ProgressaoItens.ehMaximo(nivel);
    final custo = ProgressaoItens.custoDoNivel(nivel);
    final noNivel = ProgressaoItens.xpNoNivel(xp);
    final fracao = maximo ? 1.0 : noNivel / custo;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _pular,
      child: SizedBox(
        width: widget.largura,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  maximo ? l.progressao_max : l.progressao_nivel(nivel),
                  style: const TextStyle(color: UiTheme.txtCor, fontSize: 12),
                ),
                Text(
                  l.progressao_xpGanho(widget.xpGanho),
                  style: const TextStyle(color: UiTheme.txtCor, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              height: 18,
              decoration: const BoxDecoration(
                color: UiTheme.quadroFundoCor,
                border: BordaDupla(cor: Palette.preto, espessura: 2),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fracao.clamp(0.0, 1.0),
                heightFactor: 1,
                child: const ColoredBox(color: Palette.verde),
              ),
            ),
            if (!maximo) ...[
              const SizedBox(height: 4),
            /*  Text(
                '$noNivel / $custo XP',
                style: const TextStyle(color: UiTheme.txtCor, fontSize: 10),
              ),
           */   const SizedBox(height: 6),
              _proximo(nivel),
            ],
          
          ],
        ),
      ),
    );
  }

  /// Silhueta preta do próximo prêmio, alinhada ao FIM da barra — é lá que
  /// ela chega quando enche. A meta fica visível sem entregar qual é o item.
  Widget _proximo(int nivel) {
    final item = ProgressaoItens.porNivel[nivel];
    return Align(
      alignment: Alignment.centerRight,
      child: SpriteUi(
        caminho: item.spritePath,
        tamanho: Vector2(32, 32),
        cor1: Palette.preto,
        cor2: Palette.preto,
        corBranco: Palette.preto,
      ),
    );
  }
}

class _JanelaDesbloqueio extends StatelessWidget {
  final ItemEfeito item;

  const _JanelaDesbloqueio({required this.item});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Dialog(
      backgroundColor: UiTheme.quadroFundoCor,
      shape: const BordaDuplaShape(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.progressao_novoItem,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: UiTheme.txtCor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SpriteUi(
                caminho: item.spritePath,
                tamanho: Vector2(48, 48),
                cor1: item.cor1,
                cor2: item.cor2,
              ),
              const SizedBox(height: 8),
              Text(
                item.nome(context),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: UiTheme.txtCor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.descricao(context),
                textAlign: TextAlign.center,
                style: const TextStyle(color: UiTheme.txtCor, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: UiTheme.btnCor,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 24,
                  ),
                  elevation: 0,
                  shape: const BordaDuplaShape(),
                ),
                onPressed: withBtnSfx(() => Navigator.of(context).pop()),
                child: Text(
                  l.progressao_ok,
                  style: const TextStyle(fontSize: 16, color: UiTheme.txtCor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
