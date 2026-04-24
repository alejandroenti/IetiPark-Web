import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:ietipark_web/gt_compat/test.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// ── Importa tus modelos ──────────────────────────────────
// import 'game_data.dart'; // descomenta si están en otro archivo

final String serverUrl = kIsWeb
    ? 'wss://pico1.ieti.site'
    : 'ws://pico1.ieti.site';

void main() {
  runApp(const MyApp());
}

mockJson() {
  return {
    "type": "GAME STATE",
    "payload": [
      {"name": "cliente_1", "x": 0, "y": 0},
      {"name": "cliente_2", "x": 3.33, "y": 4.44},
      {"name": "cliente_3", "x": 7.5, "y": 2.5},
    ],
  };
}

// ── Loader del JSON ──────────────────────────────────────
Future<GameData> loadGameData() async {
  final String response =
      await rootBundle.loadString('assets/levels/game_data.json');
  final Map<String, dynamic> json = jsonDecode(response);
  return GameData.fromJson(json);
}

Future<TileMap> loadTileMap(String path) async {
  final String response = await rootBundle.loadString('assets/levels/$path');
  final Map<String, dynamic> json = jsonDecode(response);
  return TileMap.fromJson(json);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    wasawasa();
    return MaterialApp(
      title: 'IetiPark Scenario',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Game Scenario'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late List<Map<String, dynamic>> clients;
  WebSocketChannel? _channel;
  bool isLoading = true;
  String? errorMessage;

  // ── Nuevo: estado del GameData ───────────────────────
  GameData? gameData;

  @override
  void initState() {
    super.initState();
    _loadGameDataAndConnect();
  }

  // ── Carga el JSON primero, luego conecta el WebSocket ─
  Future<void> _loadGameDataAndConnect() async {
    try {
      final data = await loadGameData();
      setState(() => gameData = data);
    } catch (e) {
      print('Error cargando game_data.json: $e');
      // Continúa sin gameData; los sprites usarán fallback
    }
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message) as Map<String, dynamic>;
            if (data['type'] == 'GAME STATE') {
              setState(() {
                clients = List<Map<String, dynamic>>.from(data['payload']);
                isLoading = false;
                errorMessage = null;
              });
            }
          } catch (e) {
            print('Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          setState(() {
            errorMessage = 'Error de conexión WebSocket: $error';
            isLoading = false;
          });
          _reconnectWebSocket();
        },
        onDone: () {
          setState(() {
            errorMessage = 'Conexión WebSocket cerrada';
            isLoading = false;
          });
          _reconnectWebSocket();
        },
      );
    } catch (e) {
      setState(() {
        errorMessage = 'Error al conectar: $e';
        isLoading = false;
      });
      _loadMockData();
    }
  }

  void _reconnectWebSocket() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _connectWebSocket();
    });
  }

  void _loadMockData() {
    final mockData = mockJson();
    setState(() {
      clients = List<Map<String, dynamic>>.from(mockData['payload']);
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _channel?.sink.close(status.goingAway);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isLoading = true;
                    errorMessage = null;
                  });
                  _connectWebSocket();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      // ── Pasa gameData a GameScenario ─────────────────
      body: GameScenario(clients: clients, gameData: gameData),
    );
  }
}

// ── GameScenario usa GameData para dibujar ────────────────
// ── GameScenario ─────────────────────────────────────────
class GameScenario extends StatefulWidget {
  final List<Map<String, dynamic>> clients;
  final GameData? gameData;

  const GameScenario({
    super.key,
    required this.clients,
    this.gameData,
  });

  @override
  State<GameScenario> createState() => _GameScenarioState();
}

class _GameScenarioState extends State<GameScenario> {
  
  TileMap? tileMap;
  ui.Image? atlasImage;
  bool tileDataLoaded = false;

  double get viewportWidth =>
      widget.gameData?.levels.first.viewportWidth.toDouble() ?? 800;
  double get viewportHeight =>
      widget.gameData?.levels.first.viewportHeight.toDouble() ?? 480;

  Color get backgroundColor {
    final hex = widget.gameData?.levels.first.backgroundColorHex ?? '#CCCCCC';
    final buffer = StringBuffer()
      ..write('ff')
      ..write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  void initState() {
    super.initState();
    _loadTileData();
  }

  Future<void> _loadTileData() async {
    final level = widget.gameData?.levels.first;
    final layer = level?.layers.first;
    if (layer == null) return;

    try {
      // Carga el tileMap JSON
      final loadedTileMap = await loadTileMap(layer.tileMapFile);

      // Carga el atlas como ui.Image para poder recortarlo
      final ByteData data = await rootBundle.load('assets/levels/${layer.tilesSheetFile}');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final image = frame.image;

      setState(() {
        tileMap = loadedTileMap;
        atlasImage = image;
        tileDataLoaded = true;
      });
    } catch (e) {
      print('Error cargando tile data: $e');
      setState(() => tileDataLoaded = true); // muestra escena sin tiles
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.gameData?.levels.first;
    final layer = level?.layers.first;
    final staticSprites = level?.sprites
            .where((s) => s.type != 'quixote')
            .toList() ?? [];

    // Sprite quixote del JSON
    final quixoteSprite = level?.sprites.firstWhere(
      (s) => s.type == 'quixote',
      orElse: () => Sprite(
        name: 'quixote', gameplayData: '', type: 'quixote',
        animationId: '', x: 0, y: 0, width: 32, height: 32,
        imageFile: 'media/quixote_1.png',
        flipX: false, flipY: false, depth: 0, groupId: '__main__',
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: viewportWidth,
            height: viewportHeight,
            child: Stack(
              children: [
                // 1. Color de fondo del JSON
                Container(color: backgroundColor),

                // 2. TileMap renderizado con el atlas
                if (tileDataLoaded && tileMap != null && atlasImage != null && layer != null)
                  CustomPaint(
                    painter: TileMapPainter(
                      tileMap: tileMap!,
                      atlas: atlasImage!,
                      tileWidth: layer.tilesWidth,
                      tileHeight: layer.tilesHeight,
                      // Columnas del atlas = ancho imagen / ancho tile
                      atlasColumns: atlasImage!.width ~/ layer.tilesWidth,
                    ),
                    size: Size(viewportWidth, viewportHeight),
                  ),

                // 3. Grid
                CustomPaint(
                  painter: GridPainter(),
                  size: Size(viewportWidth, viewportHeight),
                ),

                // 4. Sprites estáticos del JSON
                ...staticSprites.map((sprite) => Positioned(
                      left: sprite.x.toDouble(),
                      top: sprite.y.toDouble(),
                      child: _buildStaticSprite(
                        'assets/levels/${sprite.imageFile}',
                        sprite.width.toDouble(),
                        sprite.height.toDouble(),
                      ),
                    )),

                // 5. Clientes dinámicos del WebSocket
                ...widget.clients.map((client) {
                  final pixelX = (client['x'] as num).toDouble();
                  final pixelY = (client['y'] as num).toDouble();
                  final spriteW = (quixoteSprite?.width ?? 32) * 3.0;
                  final spriteH = (quixoteSprite?.height ?? 32) * 3.0;
                  final imagePath =
                      'assets/levels/${quixoteSprite?.imageFile ?? 'assets/levels/media/quixote_1.png'}';

                  return Positioned(
                    left: pixelX - spriteW / 2,
                    bottom: pixelY + 100,
                    child: Column(
                      children: [
                        Text(
                          client['name'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(
                          width: spriteW,
                          height: spriteH,
                          child: Image.asset(
                            imagePath,
                            fit: BoxFit.cover,
                            isAntiAlias: false,
                            filterQuality: FilterQuality.none,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: BoxDecoration(
                                color: Colors.blue[400],
                                border: Border.all(color: Colors.blue),
                              ),
                              child: const Icon(Icons.person, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStaticSprite(String path, double width, double height) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        path,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.broken_image, size: width, color: Colors.grey),
      ),
    );
  }
}

// ── TileMapPainter ────────────────────────────────────────
class TileMapPainter extends CustomPainter {
  final TileMap tileMap;
  final ui.Image atlas;
  final int tileWidth;
  final int tileHeight;
  final int atlasColumns; // cuántos tiles tiene el atlas por fila

  TileMapPainter({
    required this.tileMap,
    required this.atlas,
    required this.tileWidth,
    required this.tileHeight,
    required this.atlasColumns,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.none;

    final rows = tileMap.tileMap;

    for (int row = 0; row < rows.length; row++) {
      for (int col = 0; col < rows[row].length; col++) {
        final tileIndex = rows[row][col];
        if (tileIndex == -1) continue; // celda vacía

        // Posición del tile en el atlas (fila/columna dentro del spritesheet)
        final atlasCol = tileIndex % atlasColumns;
        final atlasRow = tileIndex ~/ atlasColumns;

        // Recorte del atlas
        final src = Rect.fromLTWH(
          (atlasCol * tileWidth).toDouble(),
          (atlasRow * tileHeight).toDouble(),
          tileWidth.toDouble(),
          tileHeight.toDouble(),
        );

        // Destino en el canvas
        final dst = Rect.fromLTWH(
          (col * tileWidth).toDouble(),
          (row * tileHeight).toDouble(),
          tileWidth.toDouble(),
          tileHeight.toDouble(),
        );

        canvas.drawImageRect(atlas, src, dst, paint);
      }
    }
  }

  @override
  bool shouldRepaint(TileMapPainter old) =>
      old.tileMap != tileMap || old.atlas != atlas;
}

class GridPainter extends CustomPainter {
  static const double gridSize = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;

    for (int i = 0; i <= gridSize.toInt(); i++) {
      canvas.drawLine(
          Offset(i * cellWidth, 0), Offset(i * cellWidth, size.height), paint);
      canvas.drawLine(
          Offset(0, i * cellHeight), Offset(size.width, i * cellHeight), paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) => false;
}