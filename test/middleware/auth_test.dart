import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:familiars_server/middleware/auth.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('firebaseAuth', () {
    const projectId = 'test-project';

    // A second, unrelated keypair we use to sign "valid-shape but bad-sig"
    // tokens. The middleware's cert source returns the *first* keypair's cert
    // under the same kid, so signature verification must fail.
    late RSAPrivateKey attackerPrivKey;
    late String trustedCertPem;

    setUpAll(() {
      // Pre-generated 2048-bit RSA keypairs (PEM). Generated once with
      // `openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048`
      // and a self-signed cert via `openssl req -x509 -key …`. Inlined so
      // tests run hermetically (no openssl at test time).
      trustedCertPem = _trustedCertPem;
      attackerPrivKey = RSAPrivateKey(_attackerPrivKeyPem);
    });

    Future<Response> invoke(
      Request req, {
      Map<String, String>? certs,
    }) async {
      final mw = firebaseAuth(
        projectId: projectId,
        certSource: () async => certs ?? {'kid-1': trustedCertPem},
      );
      final handler = mw((Request r) {
        return Response.ok(jsonEncode({'uid': r.context['uid']}));
      });
      return handler(req);
    }

    test('missing Authorization header → 401', () async {
      final res = await invoke(Request('GET', Uri.parse('http://x/api/foo')));
      expect(res.statusCode, 401);
      expect(await res.readAsString(), contains('unauthenticated'));
    });

    test('non-Bearer Authorization header → 401', () async {
      final res = await invoke(Request(
        'GET',
        Uri.parse('http://x/api/foo'),
        headers: {'authorization': 'Basic abc'},
      ));
      expect(res.statusCode, 401);
    });

    test('malformed JWT → 401', () async {
      final res = await invoke(Request(
        'GET',
        Uri.parse('http://x/api/foo'),
        headers: {'authorization': 'Bearer not-a-jwt'},
      ));
      expect(res.statusCode, 401);
    });

    test('valid-shape JWT signed by wrong key → 401', () async {
      // Build a token that has all the right claims and structure, signed
      // with attackerPrivKey. The cert source returns trustedCertPem under
      // the kid the attacker claims; signature check must fail.
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final jwt = JWT(
        {
          'iss': 'https://securetoken.google.com/$projectId',
          'aud': projectId,
          'sub': 'user-123',
          'iat': now,
          'exp': now + 3600,
        },
        header: {'kid': 'kid-1', 'alg': 'RS256', 'typ': 'JWT'},
      );
      final token = jwt.sign(attackerPrivKey, algorithm: JWTAlgorithm.RS256);

      final res = await invoke(Request(
        'GET',
        Uri.parse('http://x/api/foo'),
        headers: {'authorization': 'Bearer $token'},
      ));
      expect(res.statusCode, 401);
    });

    test('JWT with unknown kid → 401', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final jwt = JWT(
        {
          'iss': 'https://securetoken.google.com/$projectId',
          'aud': projectId,
          'sub': 'user-123',
          'iat': now,
          'exp': now + 3600,
        },
        header: {'kid': 'no-such-kid', 'alg': 'RS256', 'typ': 'JWT'},
      );
      final token = jwt.sign(attackerPrivKey, algorithm: JWTAlgorithm.RS256);

      final res = await invoke(Request(
        'GET',
        Uri.parse('http://x/api/foo'),
        headers: {'authorization': 'Bearer $token'},
      ));
      expect(res.statusCode, 401);
    });

    test('empty bearer token → 401', () async {
      final res = await invoke(Request(
        'GET',
        Uri.parse('http://x/api/foo'),
        headers: {'authorization': 'Bearer '},
      ));
      expect(res.statusCode, 401);
    });
  });
}

// Self-signed x509 cert (PEM) for the "trusted" keypair. Generated once via:
//   openssl genrsa -out trusted.key 2048
//   openssl req -new -x509 -key trusted.key -out trusted.crt -days 3650 \
//     -subj "/CN=test"
// Inlined so tests run hermetically (no openssl at test time).
const String _trustedCertPem = '''
-----BEGIN CERTIFICATE-----
MIICmjCCAYICCQC8j/qdJTlXqTANBgkqhkiG9w0BAQsFADAPMQ0wCwYDVQQDDAR0
ZXN0MB4XDTI2MDUwMTAxMzA1MVoXDTM2MDQyODAxMzA1MVowDzENMAsGA1UEAwwE
dGVzdDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKa5SEgLwaegdile
sKC/wJb2ubX8M/StjCJePDea1GIAbT8odX5tYJYFZvov7tjJeEBlvjMS82jXDLH9
rJ8FcMgus7NWbv7JJ6xavGMdNrhYYDHj0KCWJmVqKp3IHB22EoMUcarddVYYSd5E
Z2Z1wJgfHRFTaMiUssN4HR60/zu0HvO3/WSU3xhH28gwvJSthpZKwfE6f4oVeGkh
IkKz24BzRKAn/A0VvrTb1s/icWew0nMPE3sn8NpZjdC3DSie+uixY9h6g9ZGSImC
t6iloDseYStOipYsHuQSAGezN5zDyE3Xw5M6Wc3xTaRsyaHT4TtU/nL2ghwbC7Yu
vzAERGMCAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAdi84LAK6Kd2+Got57k3AA3w8
cRIYo6lMwxQ/iju3k+Pd3NXRJrDf3REuHL3T173ScrS6T58ngSA3JEx8MBnviyI/
vzWppRym5NEVeJH2eA/HghqICKQfeyOD+BhY/hUDzxnBQ99rslgtVX8LWDZQCKV0
bXns12uwtH8+iqoVeF39nT7OTCM84zB7mm3wSUOt9bqFp/OLI0hvZaY6SOBpB6yv
kElQbedIjrGKY7uP+JoKW1gPL739zg65h3oJXR+x5biKqPVPPjGMeST0kuCxxeJT
JdacT1xk5U0VLreNVKOjQnlZebu2yHgq8sNUZdwr/cahYz2p90DkN5ZOE7EUfA==
-----END CERTIFICATE-----
''';

// 2048-bit RSA private key for the *attacker* — different key, so signatures
// produced with this key will not verify against [_trustedCertPem].
const String _attackerPrivKeyPem = '''
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA1r43yfL9wJf9W1hXZwK0NbeMk/RqmbGX6/3euzxIke8iXbN6
j2cM23tuiBUvUYDjxnE8ZK8AjxuFKVpLCqAr1lvHDU0HG6L0zfH3eWAVm88YgZp9
WDa1xH5o4NNLda6DMAaVuS52J3x7L9XXVMAvGjY4Ja8X02RSeBpJcz9jcz36ctPe
AEB5TkDkUreHzp2S4zafphcSavp6GF3LLzrKs+8XHHZhvpSqYUJkhQlW+ATwc76s
eeRVHqllvUT3GZ/aRnD5zLO2+mM/AGj29ut+pHvwYnTtrxyb3bcjxswjJHUUzNTw
oejIITOj3tHXlUYDCQV2S/15ab7fn5Un6m2CZQIDAQABAoIBAGXYbUkgL2zqKMTr
zvgR9joLxWZeYzhlW/IWw031t01PJvNdreDZNOXbUn7D3V9AS8bP6Z6uyQsWOD92
jWSKtn/Bo1QRli9rR8Ns4Lv18AmnXK4LASuXNvnsIf2O+JjlnV5noRbkjDEJ/rqf
JrMROsWptVNaCWi+icZgYTmBdL8wZPL/K9tmgE3TohdubNIQkiNG6Thku2lHxSeL
ZC0Opm1ErtIWBbDaabM9rSbnaZ5CKgbsqSvnKsJLr3i+GugAEo+FsAcWVo4NfFlp
fHQ4eycZJhpee5Vyvqx72C99/1ARjCN9Mp4Py+WETTjiy4JJCBs0A2xPf8wu5HPz
jpHui7kCgYEA+rQZsbc/V9oU1Plx05FfxCdnBXWVftIiLHOnzJWoM/OZ9cBqj/WH
LvSJmtSE3aTV8671DnE3Nwi3vOeU8ITGWlT7zrnCvWyAJfAw+tw37F0R4Vm46e7a
RCWVeOr6S2LqpqYoSrN9n4czIW2tBduLMJF/P/cXP4fIxY3xy4mkNMMCgYEA20eh
MY07FWSnzW7puB9qJmbeq6wuuKCTylRvhvj1WJncJ7YtU5T3MLEJ5T5KyGEjOT84
8CUa5tMgrJIJzdUmgR23p7texHGJmWTGD8qaq4jsVI1iEyt+J0vaZtDlmm2bIbnx
zJDJAMsFzr/h68J9HNriv/lBQKfOuiiiPIY8WbcCgYAIzGFKd1/luWWZw9dW0XdG
7wsSifnhJYbFgJmW+HmauSXiFgqnWrqPz000/dhb3vkTQEShaR/C8q9gFdCIUGCV
sv3TV3maJECrFC7j3u6ngOyrt/ZhX1yRn7ALOlPmaWZKyvIHDR2Ph7MnrS2xUu8j
mTeaCxXpyN4m8MBXoFD++QKBgAgnaLoT+193R7oe5rf/Cw50gtE1bONWrUg3zZHi
ThVGW2ZqotLZ1jtMSgbpQxSicBHf5PkhGBf/P9bK82xhAbaJaVvmXsbFRg2bLrZF
nWzFgaw/Oadm1aEWc/+gwvj0HHGrnW8y7xaFdijS/86pg8d/6DClTyTdWJWZjzba
8wGPAoGBALfpOjJJZhBo0UFpBUtopIk1S8Iu4lhyDasLQ4eU1EKVVQuL++qTpDbQ
n1t9YmEHLXHA4hNSqhVycUaV7RiZ+iLb1uYIU/H/N6SGNkelboM+Brk2+s/36zfM
DCDAIojXEv3Lh5wQSHlX6YsFqySFjEWFTJmu3T7f1UwLM0nLhOx8
-----END RSA PRIVATE KEY-----
''';
