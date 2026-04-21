const WebSocket = require('ws');

const wss = new WebSocket.Server({ port: 3000 });

console.log('Servidor WebSocket ejecutándose en ws://localhost:3000');

// Datos de ejemplo
let gameState = {
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

wss.on('connection', (ws) => {
  console.log('Cliente conectado');
  
  // Enviar estado inicial
  ws.send(JSON.stringify(gameState));
  
  // Simular actualización de posiciones cada 2 segundos
  const interval = setInterval(() => {
    // Actualizar posiciones aleatoriamente
    gameState.payload.forEach(client => {
      client.x = Math.max(0, Math.min(10, client.x + (Math.random() - 0.5) * 0.5));
      client.y = Math.max(0, Math.min(10, client.y + (Math.random() - 0.5) * 0.5));
    });
    
    // Enviar actualización a todos los clientes conectados
    wss.clients.forEach(client => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(JSON.stringify(gameState));
      }
    });
  }, 2000);
  
  ws.on('close', () => {
    console.log('Cliente desconectado');
    clearInterval(interval);
  });
  
  ws.on('error', (error) => {
    console.error('Error en WebSocket:', error);
  });
});

console.log('Servidor listo. Los clientes se actualizarán cada 2 segundos.');
