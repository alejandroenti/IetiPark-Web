import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:convert';

const String serverUrl = 'ws://localhost:3000'; // Cambia a tu URL del servidor WebSocket

void main() {
  runApp(const MyApp());
}

mockJson() {
  return {
    "type": "GAME STATE",
    "payload": [
      {
        "name": "cliente_1",
        "x": 0,
        "y": 0
      },
      {
        "name": "cliente_2",
        "x": 3.33,
        "y": 4.44
      },
      {
        "name": "cliente_3",
        "x": 7.5,
        "y": 2.5
      }
    ]
  };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
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

  @override
  void initState() {
    super.initState();
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
          print('WebSocket error: $error');
          setState(() {
            errorMessage = 'Error de conexión WebSocket: $error';
            isLoading = false;
          });
          _reconnectWebSocket();
        },
        onDone: () {
          print('WebSocket connection closed');
          setState(() {
            errorMessage = 'Conexión WebSocket cerrada';
            isLoading = false;
          });
          _reconnectWebSocket();
        },
      );
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      setState(() {
        errorMessage = 'Error al conectar: $e';
        isLoading = false;
      });
      // Usar datos mock como fallback
      _loadMockData();
    }
  }

  void _reconnectWebSocket() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _connectWebSocket();
      }
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
        body: const Center(
          child: CircularProgressIndicator(),
        ),
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
      body: GameScenario(clients: clients),
    );
  }
}

class GameScenario extends StatelessWidget {
  final List<Map<String, dynamic>> clients;
  static const double gridSize = 10.0;
  static const double baseSize = 32.0;

  const GameScenario({
    super.key,
    required this.clients,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          color: Colors.grey[100],
          child: Stack(
            children: [
              // Grid de fondo
              CustomPaint(
                painter: GridPainter(),
                size: Size(constraints.maxWidth, constraints.maxHeight),
              ),
              // Clientes
              ...clients.map((client) {
                final pixelX = (client['x'] as num).toDouble() / gridSize * constraints.maxWidth;
                final pixelY = (client['y'] as num).toDouble() / gridSize * constraints.maxHeight;

                return Positioned(
                  left: pixelX - baseSize / 2,
                  top: pixelY - baseSize / 2,
                  child: Column(
                    children: [
                      // Nombre del cliente
                      Text(
                        client['name'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(
                        width: baseSize,
                        height: baseSize,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue[400],
                            border: Border.all(color: Colors.blue),
                          ),
                          child: Center(
                            child: Text(
                              (client['name'] as String).substring((client['name'] as String).lastIndexOf('_') + 1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
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

    // Líneas verticales
    for (int i = 0; i <= gridSize.toInt(); i++) {
      final x = i * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Líneas horizontales
    for (int i = 0; i <= gridSize.toInt(); i++) {
      final y = i * cellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) => false;
}
