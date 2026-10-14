import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import '../map/dungeon_generator.dart';

class MinimapHud extends PositionComponent with HasGameRef {
  Map _mapData;
  final Vector2 Function() getCurrentLogicalRoom;

  Map get mapData => _mapData;

  // Ao trocar de fase, recalcula os limites uma vez (antes era por frame)
  set mapData(Map value) {
    _mapData = value;
    _recalculateBounds();
  }

  /// Lado do bloco de uma sala. Subiu de 4 pra 7 por causa do "?" das salas
  /// de tesouro e desafio: em 4x4 não cabia o desenho completo (3 de largura
  /// por 5 de altura, com o pingo separado do gancho), e o que cabia lia como
  /// "2".
  ///
  /// O minimapa é dimensionado a partir deste valor (ver `_recalculateBounds`)
  /// e ancorado no canto superior DIREITO da área de jogo, então aumentá-lo
  /// faz o mapa crescer pra esquerda, na direção do contador de moedas da Hud.
  /// Com os 15 quartos de `DungeonGenerator.maxRooms` a largura raramente
  /// passa de 5 colunas, mas é aqui que se mexe se encostar.
  final double cellSize = 7.0;
  final double spacing = 1.0; 
  
  final Paint currentRoomPaint = Paint()..color = Palette.branco;
  final Paint visitedRoomPaint = Paint()..color = Palette.indigo;
  final Paint bossRoomPaint = Paint()..color = Palette.vermelho;
  final Paint shopRoomPaint = Paint()..color = Palette.verde;
  final Paint unvisitedPaint = Paint()..color = Palette.cinzaEsc;

  /// Tinta do "?" das salas de tesouro e desafio. Amarelo porque precisa
  /// aparecer sobre as TRÊS cores de bloco que essas salas podem ter: indigo
  /// (visitada), cinza escuro (não visitada) e branco (sala atual).
  final Paint marcaPaint = Paint()..color = Palette.amarelo;

  /// O "?" desenhado pixel a pixel, em vez de texto.
  ///
  /// O bloco de uma sala tem [cellSize] = 4px, e nenhuma fonte desenha um
  /// interrogação legível nesse tamanho — sairia um borrão. Aqui cada 'X' é
  /// um pixel do minimapa, então o desenho é exato.
  ///
  /// 3 de largura por 5 de altura: gancho, linha vazia e pingo — o "?" de
  /// verdade, que só passou a caber depois que [cellSize] foi pra 7.
  ///
  /// Trocar o desenho é editar estas linhas e nada mais: `_desenharMarca`
  /// centraliza pelo tamanho do próprio glifo, então um maior ou menor
  /// continua caindo no meio do bloco.
  static const List<String> glifoInterrogacao = [
    'XX.',
    '..X',
    '.X.',
    '...',
    '.X.',
  ];

  static const List<String> glifoExclama = [
    '.X.',
    '.X.',
    '.X.',
    '...',
    '.X.',
  ];

  static const List<String> glifoBoss= [
    '.XXX.',
    'XXXXX',
    'X.X.X',
    'XXXXX',
    '.X.X.',
  ];

  static const List<String> glifoStairs= [
    '.....',
    '....X',
    '..X.X',
    'X.X.X',
    'X.X.X',
  ];

  final Paint backgroundPaint = Paint()..color = Palette.preto;
  final Paint borderPaint = Paint()
    ..color = Palette.branco
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  final Paint roomOutlinePaint = Paint()
    ..color = Palette.preto
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5;

  // Armazenam os limites para não ter que recalcular dentro do render
  int _minX = 0;
  int _minY = 0;
  final double _padding = 8.0; // Espaço preto de borda (4px pra cada lado)

  MinimapHud({
    required Map mapData,
    required this.getCurrentLogicalRoom,
    required Vector2 position,
  })  : _mapData = mapData,
        super(
         position: position,
         anchor: Anchor.topRight,
         size: Vector2.zero(), // Começa zerado, a classe define isso sozinha agora!
       ) {
    _recalculateBounds();
  }

  void _recalculateBounds() {
    if (_mapData.isEmpty) return;

    // 1. Calcula os extremos do mapa
    int minX = 9999;
    int maxX = -9999;
    int minY = 9999;
    int maxY = -9999;

    for (var room in _mapData.values) {
      if (room.x < minX) minX = room.x;
      if (room.x > maxX) maxX = room.x;
      if (room.y < minY) minY = room.y;
      if (room.y > maxY) maxY = room.y;
    }

    _minX = minX;
    _minY = minY;

    // 2. Descobre quantos pixels exatos as salas ocupam
    double totalBlockSize = cellSize + spacing;
    double mapPixelWidth = (maxX - minX + 1) * totalBlockSize;
    double mapPixelHeight = (maxY - minY + 1) * totalBlockSize;

    // 3. ATUALIZA O TAMANHO DO MINIMAPA
    size = Vector2(mapPixelWidth + _padding, mapPixelHeight + _padding);
  }

  @override
  void render(Canvas canvas) {
    if (mapData.isEmpty) return; 

    Vector2 currentRoomCoords = getCurrentLogicalRoom();

    // CHECAGEM DE OCULTAÇÃO (SALA TRANCADA)
    // A sala onde o jogador está. Guardada aqui, no laço que já a procurava
    // pra decidir se o minimapa aparece, porque a vizinhança desenhada lá
    // embaixo sai das PORTAS dela (ver `temLigacao`).
    dynamic salaAtual;

    for (var room in mapData.values) {
      if (room.x == currentRoomCoords.x && room.y == currentRoomCoords.y) {
        if (!room.isCleared && room.type != RoomType.start) {
          return; // Aborta e esconde o minimapa!
        }
        salaAtual = room;
        break; 
      }
    }

    // DESENHA O FUNDO COM O TAMANHO ATUALIZADO
    // Adicionei 0.5 no offset do Rect para a linha de 1px da borda não ser cortada
    Rect bgRect = Rect.fromLTWH(0.5, 0.5, width - 1, height - 1);
    canvas.drawRect(bgRect, backgroundPaint);
    canvas.drawRect(bgRect, borderPaint);

    // Agora o offset é apenas metade da margem (para centralizar as salas dentro da caixinha)
    double offset = _padding / 2;
    double totalBlockSize = cellSize + spacing;

    canvas.save();
    canvas.clipRect(bgRect);

    // DESENHA AS SALAS
    for (var room in mapData.values) {
      
      bool isCurrentRoom = room.x == currentRoomCoords.x && room.y == currentRoomCoords.y;
      
      // Vizinha por PORTA, e não por grade: antes bastava encostar na sala
      // atual em X ou Y pra aparecer, e o minimapa entregava salas que o
      // jogador não tinha como alcançar dali — duas salas coladas na grade
      // são rotina no gerador, e boa parte desses pares não tem porta entre
      // si. Com isto, o que está desenhado em volta é exatamente pra onde dá
      // pra ir daqui.
      //
      // Basta consultar as portas de [salaAtual]: o gerador sempre marca o
      // par junto (`origem.doorRight` com `nova.doorLeft`, e assim por
      // diante), então os dois lados nunca discordam.
      final dx = room.x - currentRoomCoords.x;
      final dy = room.y - currentRoomCoords.y;
      final bool temLigacao =
          salaAtual != null &&
          ((dx == 1 && dy == 0 && salaAtual.doorRight) ||
              (dx == -1 && dy == 0 && salaAtual.doorLeft) ||
              (dx == 0 && dy == 1 && salaAtual.doorBottom) ||
              (dx == 0 && dy == -1 && salaAtual.doorTop));

      // `isRevealed` é o item MAPA: a sala aparece sem nunca ter sido pisada.
      if (!room.isVisited && !room.isRevealed && !isCurrentRoom && !temLigacao) {
        continue;
      }

      double drawX = offset + (room.x - _minX) * totalBlockSize;
      double drawY = offset + (room.y - _minY) * totalBlockSize;

      Paint roomPaint = unvisitedPaint; 

      if (room.x == currentRoomCoords.x && room.y == currentRoomCoords.y) {
        roomPaint = currentRoomPaint; 
      } else{
        // Salas especiais mantêm a cor mesmo reveladas sem visita — é
        // justamente pra isso que serve o item MAPA.
        // Tesouro e desafio NÃO têm cor própria: usam a cor de sala comum e
        // se distinguem pelo "?" desenhado por cima (ver `_desenharMarca`).
        // A ideia é que o jogador leia "tem alguma coisa aqui" sem que o mapa
        // entregue de antemão o que é.
        /* if (room.type == RoomType.boss) {
          roomPaint = bossRoomPaint;
        //} else if (room.type == RoomType.shop) {
        //  roomPaint = shopRoomPaint;
        } else */ if (!room.isVisited) {
          // Sala comum que o jogador ainda não pisou (revelada pelo mapa, ou
          // apenas adjacente): cor apagada, pra separar do que já foi andado.
          roomPaint = unvisitedPaint;
        } else {
          roomPaint = visitedRoomPaint; 
        }
      }

      Rect roomRect = Rect.fromLTWH(drawX, drawY, cellSize, cellSize);
      
      canvas.drawRect(roomRect, roomPaint);
      canvas.drawRect(roomRect, roomOutlinePaint);
//start, normal, boss, item, shop, desafio 
      if (room.type == RoomType.item || room.type == RoomType.desafio || room.type == RoomType.shop || room.type == RoomType.evento || room.type == RoomType.secreta) {
        _desenharMarca(canvas,glifoExclama, drawX, drawY);
      }
      if (!room.isVisited && room.type == RoomType.normal) {
        _desenharMarca(canvas,glifoInterrogacao, drawX, drawY);
      }
      if (room.type == RoomType.boss) {
        _desenharMarca(canvas,glifoBoss, drawX, drawY);
      }
      // Sala final SEM luta: a escada, e nada mais. Marca diferente da de
      // boss de propósito — é o que diz ao jogador se ele vai só subir ou se
      // vai brigar antes.
      if (room.type == RoomType.stairs) {
        _desenharMarca(canvas,glifoStairs, drawX, drawY);
      }

      // Reaproveita o mesmo Paint da sala (mesma cor, mesmo estilo)
      final Paint passagePaint = roomPaint;
      double passageThickness = 2.0;
      double centerOffset = (cellSize - passageThickness) / 2;

      // Desenha passagem para a DIREITA
      if (room.doorRight) {
        canvas.drawRect(
          Rect.fromLTWH(
            drawX + cellSize,          // Começa na borda direita da sala
            drawY + centerOffset,      // Centralizado no Y
            spacing,                   // Comprimento = espaço entre salas
            passageThickness           // Espessura da porta
          ), 
          passagePaint
        );
      }

      // Desenha passagem para BAIXO
      if (room.doorBottom) {
        canvas.drawRect(
          Rect.fromLTWH(
            drawX + centerOffset,      // Centralizado no X
            drawY + cellSize,          // Começa na borda inferior da sala
            passageThickness,          // Espessura da porta
            spacing                    // Comprimento = espaço entre salas
          ), 
          passagePaint
        );
      }

      if (room.doorLeft) {
        canvas.drawRect(
          Rect.fromLTWH(
            drawX - spacing,          // Começa na borda direita da sala
            drawY + centerOffset,      // Centralizado no Y
            spacing,                   // Comprimento = espaço entre salas
            passageThickness           // Espessura da porta
          ), 
          passagePaint
        );
      }

      // Desenha passagem para BAIXO
      if (room.doorTop) {
        canvas.drawRect(
          Rect.fromLTWH(
            drawX + centerOffset,      // Centralizado no X
            drawY - spacing,          // Começa na borda inferior da sala
            passageThickness,          // Espessura da porta
            spacing                    // Comprimento = espaço entre salas
          ), 
          passagePaint
        );
      }
    }

    canvas.restore(); 
  }

  /// Carimba [glifoInterrogacao] dentro do bloco que começa em
  /// ([drawX], [drawY]).
  ///
  /// Centralizado pelo tamanho do próprio desenho, e não por números fixos:
  /// assim trocar o glifo por um maior ou menor continua caindo no meio do
  /// bloco sem mexer aqui.
  void _desenharMarca(Canvas canvas,List<String> glifo, double drawX, double drawY) {
    final altura = glifo.length;
    final largura = glifo.first.length;
    final origemX = drawX + (cellSize - largura) / 2;
    final origemY = drawY + (cellSize - altura) / 2;

    for (var linha = 0; linha < altura; linha++) {
      final texto = glifo[linha];
      for (var coluna = 0; coluna < texto.length; coluna++) {
        if (texto[coluna] != 'X') continue;
        canvas.drawRect(
          Rect.fromLTWH(origemX + coluna, origemY + linha, 1, 1),
          marcaPaint,
        );
      }
    }
  }
}