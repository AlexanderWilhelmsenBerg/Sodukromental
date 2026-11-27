import 'dart:convert';

/// Small dependency-free SHA-256 used to bind an installed definition to the
/// exact source package. Puzzle payloads are small, so a one-shot digest keeps
/// the acquisition boundary simple and deterministic on every platform.
String librarySha256(String value) {
  final bytes = utf8.encode(value);
  final message = <int>[...bytes, 0x80];
  while (message.length % 64 != 56) message.add(0);
  final bits = bytes.length * 8;
  for (var shift = 56; shift >= 0; shift -= 8) {
    message.add((bits >> shift) & 0xff);
  }
  final hash = <int>[
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ];
  const constants = <int>[
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];
  int rotate(int value, int amount) =>
      ((value >>> amount) | (value << (32 - amount))) & 0xffffffff;
  for (var offset = 0; offset < message.length; offset += 64) {
    final words = List<int>.filled(64, 0);
    for (var i = 0; i < 16; i++) {
      final start = offset + i * 4;
      words[i] =
          (message[start] << 24) |
          (message[start + 1] << 16) |
          (message[start + 2] << 8) |
          message[start + 3];
    }
    for (var i = 16; i < 64; i++) {
      final a = words[i - 15];
      final b = words[i - 2];
      final s0 = rotate(a, 7) ^ rotate(a, 18) ^ (a >>> 3);
      final s1 = rotate(b, 17) ^ rotate(b, 19) ^ (b >>> 10);
      words[i] = (words[i - 16] + s0 + words[i - 7] + s1) & 0xffffffff;
    }
    var a = hash[0];
    var b = hash[1];
    var c = hash[2];
    var d = hash[3];
    var e = hash[4];
    var f = hash[5];
    var g = hash[6];
    var h = hash[7];
    for (var i = 0; i < 64; i++) {
      final sum1 = rotate(e, 6) ^ rotate(e, 11) ^ rotate(e, 25);
      final choose = (e & f) ^ ((~e) & g);
      final temp1 = (h + sum1 + choose + constants[i] + words[i]) & 0xffffffff;
      final sum0 = rotate(a, 2) ^ rotate(a, 13) ^ rotate(a, 22);
      final majority = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (sum0 + majority) & 0xffffffff;
      h = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xffffffff;
    }
    final work = [a, b, c, d, e, f, g, h];
    for (var i = 0; i < 8; i++) {
      hash[i] = (hash[i] + work[i]) & 0xffffffff;
    }
  }
  return hash.map((word) => word.toRadixString(16).padLeft(8, '0')).join();
}
