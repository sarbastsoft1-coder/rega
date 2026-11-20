import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays the customer notification chime (inbox + in-app push banner).
class CustomerNotificationSound {
  CustomerNotificationSound._();
  static final CustomerNotificationSound instance = CustomerNotificationSound._();

  static const String assetPath =
      'assets/sounds/mixkit-correct-answer-tone-2870.wav';

  final AudioPlayer _player = AudioPlayer();
  DateTime? _lastPlayedAt;

  Future<void> play() async {
    final now = DateTime.now();
    if (_lastPlayedAt != null &&
        now.difference(_lastPlayedAt!) < const Duration(milliseconds: 1500)) {
      return;
    }
    _lastPlayedAt = now;
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('Customer notification sound failed: $e');
    }
  }
}
