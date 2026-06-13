// lib/features/yourvpn/bootstrap/version_utils.dart

/// Compares two `major.minor.patch` version strings (build metadata after
/// `+` is ignored). Returns -1, 0 or 1, similar to [Comparable.compareTo].
int compareVersions(String a, String b) {
  final partsA = _parse(a);
  final partsB = _parse(b);
  for (var i = 0; i < 3; i++) {
    final cmp = partsA[i].compareTo(partsB[i]);
    if (cmp != 0) return cmp;
  }
  return 0;
}

List<int> _parse(String version) {
  final segments = version.split('+').first.split('.');
  return List.generate(3, (i) => i < segments.length ? int.tryParse(segments[i]) ?? 0 : 0);
}
