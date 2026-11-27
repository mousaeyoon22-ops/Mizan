import 'package:signalr_netcore/signalr_client.dart';
import '../../core/config/app_config.dart';

/// Realtime SignalR bridge to `MizanRealtimeHub` (.NET 8) for:
/// 1) QR Live Collaborative Cart (Buyer <-> Cashier real-time sync)
/// 2) Transaction-Bound Contextual Chat
class MizanSignalRService {
  HubConnection? _connection;

  Future<void> connect(String jwtToken, {
    required void Function(dynamic cartSnapshot) onCartUpdated,
    required void Function(dynamic message) onMessageReceived,
  }) async {
    _connection = HubConnectionBuilder()
        .withUrl(
          AppConfig.signalRHubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => jwtToken,
          ),
        )
        .withAutomaticReconnect()
        .build();

    _connection!.on('CartUpdated', (args) {
      if (args != null && args.isNotEmpty) onCartUpdated(args.first);
    });

    _connection!.on('MessageReceived', (args) {
      if (args != null && args.isNotEmpty) onMessageReceived(args.first);
    });

    await _connection!.start();
  }

  Future<void> joinOrderChannel(String orderId) async {
    await _connection?.invoke('JoinOrderChannel', args: <Object>[orderId]);
  }

  Future<void> broadcastCartUpdate(String orderId, Map<String, dynamic> snapshot) async {
    await _connection?.invoke('BroadcastCartUpdate', args: <Object>[orderId, snapshot]);
  }

  Future<void> sendTransactionMessage({
    required String orderId,
    required String senderRole,
    required String body,
    String? liveCardRef,
  }) async {
    await _connection?.invoke(
      'SendTransactionMessage',
      args: <Object>[orderId, senderRole, body, liveCardRef ?? ''],
    );
  }

  Future<void> disconnect() async => _connection?.stop();
}
