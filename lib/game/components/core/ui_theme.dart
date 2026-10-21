import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/creature_type.dart';

/// Cores da "casca" da tela de jogo — tudo que não é o mundo desenhado pela
/// câmera de resolução fixa (160x144). Hoje só a área lateral onde ficam
/// joystick e botões de habilidade (letterbox/pillarbox fora do mapa), mas é
/// o ponto único pra qualquer cor de UI que precise ser trocada depois sem
/// caçar hex espalhado pelo código.
class UiTheme {
  UiTheme._();

  /// Cor que representa cada elemento na INTERFACE.
  ///
  /// Não confundir com `CreatureData.corClara`/`corEscura`, que pintam o
  /// SPRITE de uma criatura específica: duas criaturas de fogo podem ter
  /// tons diferentes, e aqui o que se quer é o contrário — "fogo é laranja"
  /// valendo igual pra todas, pra que a etiqueta de tipo seja reconhecível à
  /// primeira vista.
  static const Map<CreatureType, Color> _porTipo = {
    CreatureType.fogo: Palette.laranja,
    CreatureType.planta: Palette.verde,
    CreatureType.agua: Palette.azul,
    CreatureType.eletrico: Palette.amarelo,
    CreatureType.neutro: Palette.cinza,
  };

  static Color corDoTipo(CreatureType tipo) => _porTipo[tipo] ?? Palette.cinza;

  static const Map<CreatureType, Color> _porTipo2 = {
    CreatureType.fogo: Palette.vermelho,
    CreatureType.planta: Palette.forest,
    CreatureType.agua: Palette.royal,
    CreatureType.eletrico: Palette.marrom,
    CreatureType.neutro: Palette.indigo,
  };

  static Color corDoTipo2(CreatureType tipo) => _porTipo2[tipo] ?? Palette.cinza;

  /// Preenche a tela inteira atrás do mundo do jogo — visível nas margens
  /// laterais onde os controles ficam, já que o mapa só ocupa a resolução
  /// fixa da câmera. Cinza claro = plástico do Game Boy original.
  static const Color screenBackground = Palette.cinza;

  /// Moldura escura ao redor da área jogável — o "vão" preto que cerca a
  /// tela de LCD no Game Boy de verdade, separando o plástico do shell do
  /// conteúdo da tela.
  static const Color screenBezel = Palette.preto;

  /// Cores da cápsula do botão de pause (estilo START/SELECT do Game Boy).
  static const Color pauseCapsuleCor1 = Palette.indigo;
  static const Color pauseCapsuleCor2 = Palette.azulEsc;

  /// Cores do botão de ação e (estilo A/B do Game Boy).
  static const Color actionButtonCor1 = Palette.burgundy;
  static const Color actionButtonCor2 = Palette.roxoEsc;

  /// Cores do dpad.
  static const Color dpadCor1 = Palette.cinzaEsc;
  static const Color dpadCor2 = Palette.azulEsc;

  /// Cores do apad.
  static const Color apadCor1 = Palette.burgundy;
  static const Color apadCor2 = Palette.roxoEsc;

  ///Cor botões
  static const Color btnCor = Palette.branco;

  /// Fundo do botão que representa a opção JÁ ESCOLHIDA — o esquema de
  /// controle e o idioma em uso, nas configurações.
  ///
  /// É o único sinal de "este é o ativo" que esses botões têm, então ele
  /// precisa contrastar forte com [btnCor]: se os dois ficarem próximos, a
  /// tela deixa de dizer qual opção está valendo.
  static const Color btnCorAtivo = Palette.preto;

  /// Fundo do menu principal, que cobre a tela inteira e precisa contrastar
  static const Color backgroundMenuCor = Palette.branco;
  static const Color backgroundMenuCor2 = Palette.preto;

  /// Cor de TEXTO dos menus — títulos, rótulos, descrições e o texto dentro
  /// dos botões.
  ///
  /// Existe pra que escurecer [backgroundMenuCor] ou [btnCor] não exija
  /// caçar `color: Palette.preto` por dez arquivos. NÃO cobre o texto
  /// branco de [btnCorAtivo] nem o dos cartões de evolução e aposentadoria,
  /// que são escuros por dentro — aqueles pedem um token próprio se um dia
  /// o tema mudar.
  static const Color txtCor = Palette.preto;

  /// Cor do vão entre as duas linhas de toda [BordaDupla] e
  /// [BordaDuplaShape] que não passar a sua. Nula = vão transparente, que
  /// deixa aparecer o fundo do painel (o visual de sempre). Trocar aqui pinta
  /// o vão de todas as molduras e botões de uma vez.
  static const Color bordaVaoCor = Palette.cinza;

  /// Fundo de todo QUADRO emoldurado com [BordaDupla] (cartões, painéis,
  /// barra de progressão, janela de item destravado). Separado de
  /// [backgroundMenuCor], que é o fundo da TELA atrás deles — com os dois
  /// iguais o quadro se funde na tela; com tokens próprios dá pra destacá-lo.
  static const Color quadroFundoCor = Palette.branco;

  // ------------------------------------------------------------------ HUD
  // Cores do HUD DENTRO do jogo (desenhado pelo Flame no canvas), separadas
  // das de menu acima de propósito: o HUD passa por cima do mundo, e o texto
  // dele é branco com contorno — o oposto do [txtCor]. Ligar os dois faria
  // escurecer o menu apagar o HUD.
  //
  // Só papéis que se repetem entre componentes viraram token. Cor que DIZ
  // algo (vermelho da vida do boss, laranja da energia, cores do minimapa)
  // continua em `Palette`, porque trocá-la muda o significado, não o tema.

  /// Texto do HUD: contador de moedas/bombas e nome do boss.
  static const Color hudTxtCor = Palette.branco;

  /// Contorno do [hudTxtCor], que precisa ler em cima de qualquer chão.
  static const Color hudTxtContornoCor = Palette.preto;

  /// Contorno de 1px nas oito direções, pra `TextStyle.shadows`. Era copiado
  /// igual no HUD e na barra do boss.
  static const List<Shadow> hudTxtContorno = [
    Shadow(color: hudTxtContornoCor, offset: Offset(1, 1)),
    Shadow(color: hudTxtContornoCor, offset: Offset(-1, -1)),
    Shadow(color: hudTxtContornoCor, offset: Offset(1, -1)),
    Shadow(color: hudTxtContornoCor, offset: Offset(-1, 1)),
    Shadow(color: hudTxtContornoCor, offset: Offset(0, 1)),
    Shadow(color: hudTxtContornoCor, offset: Offset(0, -1)),
    Shadow(color: hudTxtContornoCor, offset: Offset(1, 0)),
    Shadow(color: hudTxtContornoCor, offset: Offset(-1, 0)),
  ];

  /// Moldura das barras (evolução, energia, vida do boss) e borda do retrato
  /// da criatura ativa.
  static const Color hudMolduraCor = Palette.preto;

  /// Fundo das barras de evolução e energia e do retrato da criatura.
  /// A barra do boss NÃO usa: o fundo dela é cinza escuro, pra o vermelho da
  /// vida destacar.
  static const Color hudFundoCor = Palette.branco;

  /// Véu de recarga por cima de botões, retratos e anéis. Cada componente
  /// aplica a própria opacidade.
  static const Color hudRecargaCor = Palette.cinzaEsc;

  /// Fundo de slot vazio ou apagado (retrato sem criatura, consumível,
  /// carga de sala gasta). Também com opacidade por componente.
  static const Color hudSlotFundoCor = Palette.cinzaEsc;

  // Manual: livreto de papel envelhecido sobre a mesa.
  static const Color manualPapelCor = Palette.bege;
  static const Color manualTintaCor = Palette.onyx;
  static const Color manualDestaqueCor = Palette.burgundy;
  static const Color manualLinhaCor = Palette.picotronBege;
  static const Color manualMesaCor = Palette.chocolate;
  // Capa e contracapa: cartolina roxa com letreiro amarelo.
  static const Color manualCapaCor = Palette.roxoEsc;
  static const Color manualCapaTextoCor = Palette.lemon;
  
}

/// Borda de DUAS linhas com um vão entre elas — o quadro clássico de caixa de
/// Game Boy, usado nos painéis e cards dos overlays.
///
/// É um [BoxBorder] de verdade, e não um widget que embrulha o conteúdo, por
/// um motivo prático: assim cada tela troca UMA linha
/// (`border: Border.all(...)` vira `border: const BordaDupla(...)`) e nada na
/// árvore de widgets muda. Embrulhar exigiria mexer no layout de cada painel,
/// que é onde moram os `FittedBox`/`Expanded` que já foram ajustados no
/// aparelho.
///
/// O vão só é pintado com [corVao]. Sem ela, o `BoxDecoration` desenha o
/// `color` dele por baixo da borda inteira, então entre as duas linhas
/// aparece o próprio fundo do painel — e painel sem `color` deixa passar o
/// que estiver atrás, que é o comportamento esperado nos cards transparentes.
///
/// Só desenha CANTO RETO. Toda a UI do jogo usa `BorderRadius.zero` (é pixel
/// art), e suportar raio aqui seria código sem chamador.
@immutable
class BordaDupla extends BoxBorder {
  const BordaDupla({
    this.cor = UiTheme.backgroundMenuCor2,
    this.corExterna,
    this.corVao = UiTheme.bordaVaoCor,
    this.espessura = 2.0,
    this.vao = 2.0,
    this.raio = 5.0,
  });

  /// Cor da linha de DENTRO, e também da de fora quando [corExterna] é nula.
  /// Por padrão as duas têm a mesma cor: a distinção vem do vão, não do
  /// contraste entre as linhas.
  final Color cor;

  /// Cor só da linha de FORA, quando ela precisa destoar da de dentro — é
  /// como o cartão da criatura selecionada se marca, ganhando um contorno da
  /// cor do próprio elemento (ver `_CartaoCandidata`).
  ///
  /// Marcar seleção por COR, e não por espessura, é o que mantém a geometria
  /// idêntica nos dois estados: [dimensions] não muda, então o conteúdo do
  /// cartão não se mexe nem um pixel quando a seleção troca.
  final Color? corExterna;

  /// Cor do vão entre as duas linhas — por padrão [UiTheme.bordaVaoCor]. Nula
  /// deixa o vão transparente: aparece o fundo do painel (ou o que estiver
  /// atrás dele).
  final Color? corVao;

  /// Espessura de CADA linha.
  final double espessura;

  /// Distância entre a linha de fora e a de dentro.
  final double vao;

  final double raio;

  BorderSide get _lado => BorderSide(color: cor, width: espessura);

  @override
  BorderSide get top => _lado;
  @override
  BorderSide get bottom => _lado;

  /// O conteúdo começa depois das duas linhas E do vão — senão o texto do
  /// painel encostaria na linha de dentro.
  @override
  EdgeInsetsGeometry get dimensions =>
      EdgeInsets.all(espessura * 2 + vao);

  @override
  bool get isUniform => true;

  @override
  ShapeBorder scale(double t) => BordaDupla(
    cor: cor,
    corExterna: corExterna,
    corVao: corVao,
    espessura: espessura * t,
    vao: vao * t,
  );

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(dimensions.resolve(textDirection).deflateRect(rect));

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    final tinta = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = espessura
      // Pixel art: nada de suavizar a linha, senão a borda sai cinza nas
      // pontas em vez de preta.
      ..isAntiAlias = false;

    // `deflate(espessura / 2)`: o Canvas centra o traço na linha do caminho,
    // então sem isso metade da linha de fora cairia fora do retângulo e
    // sumiria no corte do widget.
    //canvas.drawRect(rect.deflate(espessura / 2), tinta);
    //canvas.drawRect(rect.deflate(espessura * 1.5 + vao), tinta);
    _pintarVao(canvas, rect, corVao, espessura, vao, raio);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(espessura / 2), Radius.circular(raio)),
      tinta..color = corExterna ?? cor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(espessura * 1.5 + vao),
        Radius.circular(raio),
      ),
      tinta..color = cor,
    );
  }
}


/// A borda dupla na forma de `ShapeBorder`, pra usar no `shape:` de botão.
///
/// Existe separada da [BordaDupla] porque as duas vivem em mundos diferentes
/// do Flutter: aquela é `BoxBorder`, que só entra em `BoxDecoration`; o
/// `shape:` de um `ElevatedButton`/`OutlinedButton` exige `OutlinedBorder`.
/// A alternativa seria embrulhar cada botão num `Container` decorado, o que
/// tiraria o recorte da tinta de toque do botão e deixaria o respingo
/// vazando pra fora da moldura.
///
/// O desenho é o mesmo da [BordaDupla], de propósito: as molduras de caixa e
/// as de botão precisam ser indistinguíveis na tela.
class BordaDuplaShape extends OutlinedBorder {
  const BordaDuplaShape({
    this.cor = UiTheme.backgroundMenuCor2,
    this.corVao = UiTheme.bordaVaoCor,
    this.espessura = 2.0,
    this.vao = 2.0,
    this.raio = 5.0,
  }) : super(side: BorderSide.none);

  final Color cor;

  /// Cor do vão entre as linhas — mesma regra da [BordaDupla.corVao].
  final Color? corVao;

  final double espessura;
  final double vao;

  /// Raio do arredondamento. Igual ao da [BordaDupla] — se mudar lá, muda
  /// aqui.
  final double raio;

  /// O conteúdo começa depois das duas linhas E do vão, senão o rótulo do
  /// botão encostaria na linha de dentro.
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(espessura * 2 + vao);

  @override
  BordaDuplaShape copyWith({
    BorderSide? side,
    Color? cor,
    Color? corVao,
    double? espessura,
    double? vao,
    double? raio,
  }) =>
      BordaDuplaShape(
        cor: cor ?? this.cor,
        corVao: corVao ?? this.corVao,
        espessura: espessura ?? this.espessura,
        vao: vao ?? this.vao,
        raio: raio ?? this.raio,
      );

  @override
  ShapeBorder scale(double t) => BordaDuplaShape(
    cor: cor,
    corVao: corVao,
    espessura: espessura * t,
    vao: vao * t,
    raio: raio * t,
  );

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()
    ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(raio)));

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        dimensions.resolve(textDirection).deflateRect(rect),
         Radius.circular(raio),
      ),
    );

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final tinta = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = espessura
      // Pixel art: nada de suavizar, senão a linha sai cinza nas pontas.
      ..isAntiAlias = false;

    _pintarVao(canvas, rect, corVao, espessura, vao, raio);
    // `deflate(espessura / 2)`: o Canvas centra o traço na linha do caminho,
    // então sem isso metade da linha de fora cairia fora do retângulo.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(espessura / 2),
         Radius.circular(raio),
      ),
      tinta,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(espessura * 1.5 + vao),
         Radius.circular(raio),
      ),
      tinta,
    );
  }
}

/// Pinta o vão entre as duas linhas da borda dupla, usado pela [BordaDupla] e
/// pela [BordaDuplaShape]. Vem ANTES das linhas.
///
/// Preenchimento, e não traço: um traço da largura do vão com o mesmo raio
/// das linhas não acompanha a curva delas, e as quinas ficavam com frestas
/// sem cor. Aqui a área pintada vai do CENTRO da linha de fora ao CENTRO da
/// linha de dentro — exatamente os dois retângulos que as linhas usam — então
/// cada linha, desenhada por cima, cobre a borda do preenchimento sem deixar
/// fresta em ponto nenhum, quina inclusive.
void _pintarVao(
  Canvas canvas,
  Rect rect,
  Color? corVao,
  double espessura,
  double vao,
  double raio,
) {
  if (corVao == null || vao <= 0) return;
  canvas.drawDRRect(
    RRect.fromRectAndRadius(rect.deflate(espessura / 2), Radius.circular(raio)),
    RRect.fromRectAndRadius(
      rect.deflate(espessura * 1.5 + vao),
      Radius.circular(raio),
    ),
    Paint()
      ..color = corVao
      ..style = PaintingStyle.fill
      ..isAntiAlias = false,
  );
}
