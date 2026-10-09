final _stripSuffixes = RegExp(
    r'\s*(?:pvt\.?\s*ltd\.?|private\s+limited|limited|inc\.?|llp|india|pvt)\s*$',
    caseSensitive: false);

final _multiSpace = RegExp(r'\s+');

/// Key used to remember a merchant's category ("Swiggy Ltd" == "swiggy").
String normalizeMerchant(String raw) {
  return raw
      .toLowerCase()
      .trim()
      .replaceAll(_stripSuffixes, '')
      .replaceAll(_multiSpace, ' ')
      .replaceAll(RegExp(r'[.\-_]+$'), '')
      .trim();
}
