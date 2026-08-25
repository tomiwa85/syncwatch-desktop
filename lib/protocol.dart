// Dart mirror of @syncwatch/shared. These event names and payload shapes must
// match the TypeScript definitions EXACTLY, or desktop and mobile won't sync.

/// Socket.IO event names — mirror of shared/src/socket/events.ts.
class SocketEvents {
  static const roomJoin = 'room:join';
  static const roomLeave = 'room:leave';
  static const roomState = 'room:state';
  static const roomMemberJoined = 'room:member-joined';
  static const roomMemberLeft = 'room:member-left';
  static const roomEnd = 'room:end';
  static const roomEnded = 'room:ended';

  static const videoSetSource = 'video:set-source';
  static const videoSourceChanged = 'video:source-changed';

  static const roomSetControl = 'room:set-control';

  static const chatSend = 'chat:send';
  static const chatMessage = 'chat:message';

  static const subtitleSet = 'subtitle:set';
  static const subtitleChanged = 'subtitle:changed';
  static const subtitleClear = 'subtitle:clear';
  static const subtitleCleared = 'subtitle:cleared';

  static const fileVerify = 'file:verify';
  static const fileVerifyResult = 'file:verify-result';

  static const playbackPlay = 'playback:play';
  static const playbackPause = 'playback:pause';
  static const playbackSeek = 'playback:seek';
  static const playbackSync = 'playback:sync';
  static const playbackHeartbeat = 'playback:heartbeat';

  // Server error channel (not in the enum, but emitted by the server).
  static const roomError = 'room:error';
}

/// socket.io payloads arrive as loosely-typed maps; normalize to Map<String,dynamic>.
Map<String, dynamic> asMap(dynamic data) =>
    data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);

// ---- models (mirror of shared DTOs) ----

class AuthUser {
  final String id;
  final String email;
  final String displayName;
  AuthUser({required this.id, required this.email, required this.displayName});

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] as String,
        email: j['email'] as String,
        displayName: j['displayName'] as String,
      );
}

class AuthResponse {
  final AuthUser user;
  final String accessToken;
  final String refreshToken;
  AuthResponse({required this.user, required this.accessToken, required this.refreshToken});

  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
        user: AuthUser.fromJson(asMap(j['user'])),
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
      );
}

class PlaybackStateData {
  final double currentTime;
  final bool isPlaying;
  final String updatedAt;
  PlaybackStateData({required this.currentTime, required this.isPlaying, required this.updatedAt});

  factory PlaybackStateData.fromJson(Map<String, dynamic> j) => PlaybackStateData(
        currentTime: (j['currentTime'] as num).toDouble(),
        isPlaying: j['isPlaying'] as bool,
        updatedAt: j['updatedAt'] as String,
      );

  factory PlaybackStateData.initial() => PlaybackStateData(
        currentTime: 0,
        isPlaying: false,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );
}

/// LOCAL_FILE | STREAMING_URL (discriminated union in shared).
class VideoSourceData {
  final String sourceType;
  final String? fileName;
  final int? fileSize;
  final String? url;

  VideoSourceData.local(this.fileName, this.fileSize)
      : sourceType = 'LOCAL_FILE',
        url = null;
  VideoSourceData.streaming(this.url)
      : sourceType = 'STREAMING_URL',
        fileName = null,
        fileSize = null;

  factory VideoSourceData.fromJson(Map<String, dynamic> j) {
    if (j['sourceType'] == 'LOCAL_FILE') {
      return VideoSourceData.local(j['fileName'] as String, (j['fileSize'] as num).toInt());
    }
    return VideoSourceData.streaming(j['url'] as String);
  }

  Map<String, dynamic> toJson() => sourceType == 'LOCAL_FILE'
      ? {'sourceType': 'LOCAL_FILE', 'fileName': fileName, 'fileSize': fileSize}
      : {'sourceType': 'STREAMING_URL', 'url': url};

  String get label => sourceType == 'LOCAL_FILE' ? (fileName ?? 'a local file') : (url ?? 'a link');
}

class RoomMemberData {
  final String userId;
  final String displayName;
  final String role; // host | member
  final bool fileVerified;
  RoomMemberData({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.fileVerified,
  });

  factory RoomMemberData.fromJson(Map<String, dynamic> j) => RoomMemberData(
        userId: j['userId'] as String,
        displayName: j['displayName'] as String,
        role: j['role'] as String,
        fileVerified: j['fileVerified'] as bool,
      );

  RoomMemberData copyWith({bool? fileVerified}) => RoomMemberData(
        userId: userId,
        displayName: displayName,
        role: role,
        fileVerified: fileVerified ?? this.fileVerified,
      );
}

class RoomSummaryData {
  final String code;
  final String? title;
  final String visibility; // PUBLIC | PRIVATE
  final String playbackControl; // EVERYONE | HOST
  final bool hasPassword;
  final String hostId;
  final VideoSourceData? source;
  final List<RoomMemberData> members;

  RoomSummaryData({
    required this.code,
    required this.title,
    required this.visibility,
    required this.playbackControl,
    required this.hasPassword,
    required this.hostId,
    required this.source,
    required this.members,
  });

  factory RoomSummaryData.fromJson(Map<String, dynamic> j) => RoomSummaryData(
        code: j['code'] as String,
        title: j['title'] as String?,
        visibility: j['visibility'] as String,
        playbackControl: j['playbackControl'] as String,
        hasPassword: j['hasPassword'] as bool,
        hostId: j['hostId'] as String,
        source: j['source'] == null ? null : VideoSourceData.fromJson(asMap(j['source'])),
        members: (j['members'] as List).map((m) => RoomMemberData.fromJson(asMap(m))).toList(),
      );
}

class ChatMessageData {
  final String id;
  final String userId;
  final String displayName;
  final String text;
  final String at;
  ChatMessageData({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.text,
    required this.at,
  });

  factory ChatMessageData.fromJson(Map<String, dynamic> j) => ChatMessageData(
        id: j['id'] as String,
        userId: j['userId'] as String,
        displayName: j['displayName'] as String,
        text: j['text'] as String,
        at: j['at'] as String,
      );
}
