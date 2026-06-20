import 'dart:io';

void main() async {
  // Binds directly to localhost:8080 to clear the OS 1225 connection error
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
  print('🚀 Grychat Signaling Server listening on ws://localhost:8080');

  final List<WebSocket> connectedPeers = [];

  await for (HttpRequest request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = await WebSocketTransformer.upgrade(request);
      connectedPeers.add(socket);
      print('📱 Peer connected. Active pool size: ${connectedPeers.length}');

      socket.listen(
        (message) {
          // Broadcaster loop relays offers, answers, and ICE candidates to everyone else
          for (final peer in connectedPeers) {
            if (peer != socket && peer.readyState == WebSocket.open) {
              peer.add(message);
            }
          }
        },
        onDone: () {
          connectedPeers.remove(socket);
          print('❌ Peer left. Active pool size: ${connectedPeers.length}');
        },
        onError: (error) {
          connectedPeers.remove(socket);
          print('⚠️ Socket error encountered: $error');
        },
      );
    } else {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  }
}
