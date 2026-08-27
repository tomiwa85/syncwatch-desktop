// Framework-agnostic playback reconciliation — a faithful port of the web
// client's sync-engine.ts. The player is driven exclusively through the engine:
// user actions apply to the player optimistically AND emit an outbound event,
// while authoritative updates from the server are applied with a drift tolerance
// so tiny harmless differences don't cause visible seeking. Player-generated
// events are never fed back in as intent, so there's no seek→event→seek loop.

/// Seconds of drift tolerated before the engine hard-corrects the player.
const double kDriftThreshold = 0.75;

abstract class PlayerHandle {
  void play();
  void pause();
  void seek(double time);
  double getCurrentTime();
  void setVolume(double volume);
}

class SyncEngine {
  PlayerHandle? _player;

  /// Called with ('play'|'pause'|'seek', timeInSeconds) to broadcast intent.
  final void Function(String intent, double time) emit;

  SyncEngine(this.emit);

  void setPlayer(PlayerHandle? player) => _player = player;
  bool get hasPlayer => _player != null;

  // ---- local user intents (optimistic apply + broadcast) ----

  void userPlay() {
    final time = _player?.getCurrentTime() ?? 0;
    _player?.play();
    emit('play', time);
  }

  void userPause() {
    final time = _player?.getCurrentTime() ?? 0;
    _player?.pause();
    emit('pause', time);
  }

  void userSeek(double time) {
    _player?.seek(time);
    emit('seek', time);
  }

  // ---- authoritative state from the server ----

  void applyAuthoritative(double currentTime, bool isPlaying) {
    final player = _player;
    if (player == null) return;
    if ((player.getCurrentTime() - currentTime).abs() > kDriftThreshold) {
      player.seek(currentTime);
    }
    if (isPlaying) {
      player.play();
    } else {
      player.pause();
    }
  }

  /// Force convergence after a reconnect, bypassing drift tolerance.
  void hardApply(double currentTime, bool isPlaying) {
    final player = _player;
    if (player == null) return;
    player.seek(currentTime);
    if (isPlaying) {
      player.play();
    } else {
      player.pause();
    }
  }
}
