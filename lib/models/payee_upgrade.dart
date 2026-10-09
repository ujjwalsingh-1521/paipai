/// Data version 9: entries get a `payee` column. Before it, a captured
/// payment's payee was stored in `notes`, so typing a note replaced it.
/// For every entry made from a captured payment, the payee comes back from
/// that capture, and a note that only repeated the payee is cleared.
/// Used by the database upgrade and by restore of older backups.
List<Map<String, Object?>> movePayeesOutOfNotes(
  List<Map<String, Object?>> entries,
  List<Map<String, Object?>> captures, {
  required String linkColumn,
}) {
  final payeeByEntry = <Object?, String>{
    for (final capture in captures)
      if (capture[linkColumn] != null && capture['merchant'] is String)
        capture[linkColumn]: capture['merchant'] as String,
  };
  return [
    for (final entry in entries) _withPayee(entry, payeeByEntry[entry['id']]),
  ];
}

Map<String, Object?> _withPayee(Map<String, Object?> entry, String? payee) {
  if (payee == null || entry['payee'] != null) return entry;
  final notes = (entry['notes'] as String?)?.trim();
  return {
    ...entry,
    'payee': payee,
    'notes': notes == null || notes.isEmpty || notes == payee.trim() ? null : entry['notes'],
  };
}
