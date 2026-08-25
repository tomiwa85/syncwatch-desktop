import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'config.dart';
import 'protocol.dart';
import 'sync_engine.dart';

/// Owns the single Socket.IO connection for the session. Auth token is set at
/// build time; token-rotation-over-socket comes later (access tokens outlive a
/// test session). Mirror of socket-client.ts.
class SocketService {
  io.Socket? _socket;

  io.Socket connect(String token) {
    _socket?.dispose();
    final s = io.io(
      Config.socketUrl,
      io.OptionBuilder()
          // WebSocket first, long-polling fallback — matches the web client so
          // networks that block the WS upgrade still connect.
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _socket = s;
    s.connect();
    return s;
  }

  io.Socket get socket => _socket!;
  bool get hasSocket => _socket != null;

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}

/// Adapts a media_kit [Player] to the engine's [PlayerHandle].
class MediaKitPlayerHandle implements PlayerHandle {
  final Player player;
  MediaKitPlayerHandle(this.player);

  @override
  void play() => player.play();

  @override
  void pause() => player.pause();

  @override
  void seek(double time) => player.seek(Duration(milliseconds: (time * 1000).round()));

  @override
  double getCurrentTime() => player.state.position.inMilliseconds / 1000.0;

  @override
  void setVolume(double volume) => player.setVolume((volume * 100).clamp(0, 100).toDouble());
}

/// Wires the socket to room state — a port of useRoomSync.ts as a ChangeNotifier.
class RoomSync extends ChangeNotifier {
  final io.Socket socket;
  final String roomCode;
  final String myUserId;
  late final SyncEngine engine;

  bool connected = false;
  PlaybackStateData playback = PlaybackStateData.initial();
  RoomSummaryData? room;
  final List<ChatMessageData> messages = [];
  bool verifyPending = false;
  bool? myVerified;
  String? verifyReason;
  String? lastEvent; // small debug breadcrumb for the test UI
  bool ended = false;

  bool _hasConnected = false;
  bool _pendingHardSync = false;

  RoomSync({
    required this.socket,
    required this.roomCode,
    required this.myUserId,
    RoomSummaryData? initialRoom,
  }) {
    room = initialRoom;
    engine = SyncEngine((intent, time) {
      final event = intent == 'play'
          ? SocketEvents.playbackPlay
          : intent == 'pause'
              ? SocketEvents.playbackPause
              : SocketEvents.playbackSeek;
      final timeKey = intent == 'seek' ? 'toTime' : 'atTime';
      socket.emit(event, {
        'roomCode': roomCode,
        timeKey: time,
        'clientTimestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
    _wire();
    if (socket.connected) {
      _onConnect();
    } else {
      socket.connect();
    }
  }

  bool get iAmHost => room?.hostId == myUserId;
  bool get canControl => room == null ? true : room!.playbackControl == 'EVERYONE' || iAmHost;

  void _wire() {
    socket.onConnect((_) => _onConnect());
    socket.onDisconnect((_) {
      connected = false;
      notifyListeners();
    });
    socket.on(SocketEvents.roomState, (d) => _onRoomState(asMap(d)));
    socket.on(SocketEvents.playbackSync, (d) => _onSync(asMap(d)));
    socket.on(SocketEvents.roomMemberJoined, (d) => _onMemberJoined(asMap(d)));
    socket.on(SocketEvents.roomMemberLeft, (d) => _onMemberLeft(asMap(d)));
    socket.on(SocketEvents.fileVerifyResult, (d) => _onVerifyResult(asMap(d)));
    socket.on(SocketEvents.videoSourceChanged, (d) => _onSourceChanged(asMap(d)));
    socket.on(SocketEvents.chatMessage, (d) {
      messages.add(ChatMessageData.fromJson(asMap(d)));
      notifyListeners();
    });
    socket.on(SocketEvents.roomEnded, (_) {
      ended = true;
      lastEvent = 'room:ended';
      notifyListeners();
    });
    socket.on(SocketEvents.roomError, (d) {
      final m = d is Map ? d['message'] : null;
      lastEvent = 'room:error ${m ?? ''}';
      notifyListeners();
    });
  }

  void _onConnect() {
    final isReconnect = _hasConnected;
    _hasConnected = true;
    connected = true;
    if (isReconnect) _pendingHardSync = true;
    socket.emit(SocketEvents.roomJoin, {'roomCode': roomCode});
    lastEvent = isReconnect ? 'reconnected' : 'connected';
    notifyListeners();
  }

  void _onRoomState(Map<String, dynamic> p) {
    room = RoomSummaryData.fromJson(asMap(p['room']));
    playback = PlaybackStateData.fromJson(asMap(p['playback']));
    final me = room!.members.where((m) => m.userId == myUserId);
    if (me.isNotEmpty) myVerified = me.first.fileVerified;
    if (_pendingHardSync) {
      _pendingHardSync = false;
      engine.hardApply(playback.currentTime, playback.isPlaying);
    } else {
      engine.applyAuthoritative(playback.currentTime, playback.isPlaying);
    }
    lastEvent = 'room:state';
    notifyListeners();
  }

  void _onSync(Map<String, dynamic> p) {
    playback = PlaybackStateData(
      currentTime: (p['currentTime'] as num).toDouble(),
      isPlaying: p['isPlaying'] as bool,
      updatedAt: p['updatedAt'] as String,
    );
    engine.applyAuthoritative(playback.currentTime, playback.isPlaying);
    lastEvent = 'playback:sync (${p['origin']})';
    notifyListeners();
  }

  void _onMemberJoined(Map<String, dynamic> p) {
    final r = room;
    if (r == null) return;
    if (r.members.any((m) => m.userId == p['userId'])) return;
    r.members.add(RoomMemberData(
      userId: p['userId'] as String,
      displayName: p['displayName'] as String,
      role: 'member',
      fileVerified: false,
    ));
    notifyListeners();
  }

  void _onMemberLeft(Map<String, dynamic> p) {
    room?.members.removeWhere((m) => m.userId == p['userId']);
    notifyListeners();
  }

  void _onVerifyResult(Map<String, dynamic> p) {
    final uid = p['userId'] as String;
    final verified = p['verified'] as bool;
    if (uid == myUserId) {
      verifyPending = false;
      myVerified = verified;
      verifyReason = p['reason'] as String?;
    }
    final r = room;
    if (r != null) {
      for (var i = 0; i < r.members.length; i++) {
        if (r.members[i].userId == uid) {
          r.members[i] = r.members[i].copyWith(fileVerified: verified);
        }
      }
    }
    notifyListeners();
  }

  void _onSourceChanged(Map<String, dynamic> p) {
    lastEvent = 'video:source-changed';
    notifyListeners();
  }

  // ---- outbound actions ----

  void setSource(VideoSourceData source) =>
      socket.emit(SocketEvents.videoSetSource, {'roomCode': roomCode, 'source': source.toJson()});

  void verifyFile(String fileName, int fileSize) {
    verifyPending = true;
    notifyListeners();
    socket.emit(SocketEvents.fileVerify, {'roomCode': roomCode, 'fileName': fileName, 'fileSize': fileSize});
  }

  void sendChat(String text) => socket.emit(SocketEvents.chatSend, {'roomCode': roomCode, 'text': text});

  void endRoom() => socket.emit(SocketEvents.roomEnd, {'roomCode': roomCode});

  void leave() => socket.emit(SocketEvents.roomLeave, {'roomCode': roomCode});

  @override
  void dispose() {
    leave();
    // Detach this room's handlers (single shared socket, one room at a time).
    socket.off('connect');
    socket.off('disconnect');
    for (final e in const [
      SocketEvents.roomState,
      SocketEvents.playbackSync,
      SocketEvents.roomMemberJoined,
      SocketEvents.roomMemberLeft,
      SocketEvents.fileVerifyResult,
      SocketEvents.videoSourceChanged,
      SocketEvents.chatMessage,
      SocketEvents.roomEnded,
      SocketEvents.roomError,
    ]) {
      socket.off(e);
    }
    engine.setPlayer(null);
    super.dispose();
  }
}
