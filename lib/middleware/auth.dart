import 'dart:async';
import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';

/// URL of Google's public x509 certs used to verify Firebase ID tokens.
///
/// The endpoint returns a JSON object mapping key id (`kid`) to a PEM-encoded
/// x509 certificate. The certs rotate roughly daily; the response includes a
/// `Cache-Control: max-age=<seconds>` header that we honour.
const String _googleCertsUrl =
    'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';

/// Allowed clock skew when validating `iat` (issued-at) claims, in seconds.
const int _clockSkewSeconds = 60;

/// Signature for an injectable certificate source.
///
/// Returns a map of `kid → PEM-encoded x509 certificate`. Implementations
/// should cache aggressively — production callers go to the network on miss.
typedef CertSource = Future<Map<String, String>> Function();

/// Shelf middleware that verifies Firebase ID tokens on the `Authorization`
/// header.
///
/// Verification steps:
///   1. Extract the bearer token from the `Authorization: Bearer …` header.
///   2. Fetch (and cache) Google's public x509 certs.
///   3. Decode the JWT header to find the signing key (`kid`).
///   4. Verify the RS256 signature against the matching cert.
///   5. Validate claims:
///      - `aud` equals [projectId]
///      - `iss` equals `https://securetoken.google.com/<projectId>`
///      - `exp` is in the future
///      - `iat` is not in the future (with [_clockSkewSeconds] of skew)
///      - `sub` (uid) is present and non-empty
///   6. On success, attach `uid` to `Request.context` and call the inner
///      handler. On any verification failure, respond `401` with JSON body
///      `{"error": "unauthenticated"}`.
///
/// Unexpected exceptions (e.g. cert endpoint outage, malformed cert response)
/// are NOT swallowed — they bubble up so the Shelf pipeline returns 500 and
/// cert-rotation issues are surfaced rather than masked as auth failures.
///
/// Pass [certSource] in tests to avoid hitting the network. In production,
/// leave it null to use the real Google endpoint with HTTP cache honouring.
Middleware firebaseAuth({
  required String projectId,
  CertSource? certSource,
}) {
  final source = certSource ?? _CachingGoogleCertSource().fetch;

  return (Handler inner) {
    return (Request request) async {
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return _unauthenticated();
      }
      final token = authHeader.substring('Bearer '.length).trim();
      if (token.isEmpty) {
        return _unauthenticated();
      }

      final String uid;
      try {
        uid = await _verifyFirebaseToken(
          token: token,
          projectId: projectId,
          certSource: source,
        );
      } on _AuthFailure {
        return _unauthenticated();
      }
      // Other exceptions bubble up — let cert-fetch / parse failures surface
      // as 500s rather than be masked as auth failures.

      final updated = request.change(context: {...request.context, 'uid': uid});
      return inner(updated);
    };
  };
}

Response _unauthenticated() => Response(
      401,
      body: '{"error":"unauthenticated"}',
      headers: {'content-type': 'application/json'},
    );

/// Internal failure marker — anything caller-attributable (bad token, bad
/// signature, expired, wrong audience, etc).
class _AuthFailure implements Exception {
  final String reason;
  _AuthFailure(this.reason);
  @override
  String toString() => 'AuthFailure: $reason';
}

Future<String> _verifyFirebaseToken({
  required String token,
  required String projectId,
  required CertSource certSource,
}) async {
  // Pull the kid from the JWT header without verifying yet.
  final parts = token.split('.');
  if (parts.length != 3) throw _AuthFailure('malformed jwt');

  final Map<String, Object?> header;
  try {
    header = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))),
    ) as Map<String, Object?>;
  } catch (_) {
    throw _AuthFailure('malformed jwt header');
  }

  final kid = header['kid'];
  if (kid is! String || kid.isEmpty) {
    throw _AuthFailure('missing kid');
  }
  final alg = header['alg'];
  if (alg != 'RS256') {
    throw _AuthFailure('unexpected alg: $alg');
  }

  final certs = await certSource();
  final pem = certs[kid];
  if (pem == null) {
    throw _AuthFailure('unknown kid');
  }

  final JWT jwt;
  try {
    jwt = JWT.verify(token, RSAPublicKey.cert(pem));
  } on JWTException catch (e) {
    throw _AuthFailure('signature: ${e.message}');
  }

  final payload = jwt.payload;
  if (payload is! Map) {
    throw _AuthFailure('non-object payload');
  }

  if (payload['aud'] != projectId) {
    throw _AuthFailure('bad aud');
  }
  if (payload['iss'] != 'https://securetoken.google.com/$projectId') {
    throw _AuthFailure('bad iss');
  }

  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final exp = payload['exp'];
  if (exp is! int || exp < now) {
    throw _AuthFailure('expired');
  }
  final iat = payload['iat'];
  if (iat is! int || iat > now + _clockSkewSeconds) {
    throw _AuthFailure('iat in future');
  }

  final sub = payload['sub'];
  if (sub is! String || sub.isEmpty) {
    throw _AuthFailure('missing sub');
  }
  return sub;
}

/// Caches Google's public certs in-process, honouring `Cache-Control:
/// max-age` on the response. Falls back to a 1-hour TTL if the header is
/// missing or unparseable.
class _CachingGoogleCertSource {
  Map<String, String>? _cached;
  DateTime _expiresAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<Map<String, String>>? _inFlight;

  /// HTTP client — overridable for tests (kept package-private rather than
  /// public to avoid widening the API surface; the test path injects via
  /// [CertSource] instead).
  final http.Client _client;

  _CachingGoogleCertSource({http.Client? client})
      : _client = client ?? http.Client();

  Future<Map<String, String>> fetch() async {
    if (_cached != null && DateTime.now().isBefore(_expiresAt)) {
      return _cached!;
    }
    return _inFlight ??= _refresh().whenComplete(() => _inFlight = null);
  }

  Future<Map<String, String>> _refresh() async {
    final res = await _client.get(Uri.parse(_googleCertsUrl));
    if (res.statusCode != 200) {
      throw StateError(
        'cert fetch failed: HTTP ${res.statusCode} ${res.reasonPhrase}',
      );
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      throw StateError('cert payload not a JSON object');
    }
    final certs = decoded.map((k, v) => MapEntry(k as String, v as String));
    _cached = certs;
    _expiresAt = DateTime.now().add(_parseMaxAge(res.headers['cache-control']));
    return certs;
  }

  static Duration _parseMaxAge(String? cacheControl) {
    if (cacheControl == null) return const Duration(hours: 1);
    final match = RegExp(r'max-age=(\d+)').firstMatch(cacheControl);
    if (match == null) return const Duration(hours: 1);
    final seconds = int.tryParse(match.group(1)!);
    if (seconds == null || seconds <= 0) return const Duration(hours: 1);
    return Duration(seconds: seconds);
  }
}
