import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Frozen fingerprint of `_buildTopAppBar` body — Phase 08+ must not change it.
/// Update only with explicit approval to change the locked green header.
const String kProtectedHeaderSha256 =
    '781fa8c4bbe0ae69272e89ae14e0a6beb63894df3f63c7cd45877338fbf8a503';

void main() {
  test('green REGA header body fingerprint is locked', () {
    final src = File('lib/main.dart').readAsStringSync();
    final start = src.indexOf('  Widget _buildTopAppBar() {');
    expect(start, greaterThan(0), reason: '_buildTopAppBar missing');
    expect(
      src.substring((start - 120).clamp(0, start), start).contains('PHASE LOCK'),
      isTrue,
    );

    final brace = src.indexOf('{', start);
    var depth = 0;
    var end = brace;
    for (var i = brace; i < src.length; i++) {
      final ch = src[i];
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) {
          end = i;
          break;
        }
      }
    }
    final body = src.substring(start, end + 1).replaceAll('\r\n', '\n');
    final hash = sha256.convert(utf8.encode(body)).toString();

    expect(body.contains('0xFF22C55E'), isTrue);
    expect(body.contains('navbar_logo.png'), isTrue);
    expect(body.contains('_toggleOnlineStatus'), isTrue);
    expect(body.contains('Radius.circular(26)'), isTrue);
    expect(body.contains('height: phone ? 66 : 76'), isTrue);
    expect(hash, kProtectedHeaderSha256);
  });
}
