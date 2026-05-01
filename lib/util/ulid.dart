import 'dart:math';

/// Crockford base32 alphabet used by ULID.
const String _crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

final Random _rng = Random.secure();

/// Generate a ULID — 26-char Crockford-base32, lexicographically sortable
/// by creation time. Spec: https://github.com/ulid/spec
///
/// 48-bit timestamp (ms since epoch) || 80-bit randomness. Good enough for
/// in-process IDs; not collision-proof across machines, which doesn't matter
/// because Phase 0 is single-server.
String newUlid() {
  final now = DateTime.now().millisecondsSinceEpoch;
  final sb = StringBuffer();
  // 10 Crockford chars × 5 bits = 50 bits of encoding space. The ULID spec
  // defines a 48-bit timestamp; the top 2 bits of the encoding are
  // therefore always zero (and stay that way for ~10 000 years).
  var ts = now;
  final tsChars = List<String>.filled(10, '0');
  for (var i = 9; i >= 0; i--) {
    tsChars[i] = _crockford[ts & 0x1F];
    ts >>= 5;
  }
  sb.writeAll(tsChars);
  // 16 chars of randomness (80 bits).
  for (var i = 0; i < 16; i++) {
    sb.write(_crockford[_rng.nextInt(32)]);
  }
  return sb.toString();
}
