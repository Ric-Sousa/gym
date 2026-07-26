/// Mock simples de Timestamp do Firestore para testes unitários.
/// Usado em vez de importar `cloud_firestore` nos testes.
class MockTimestamp {
  final DateTime date;
  const MockTimestamp(this.date);
  DateTime toDate() => date;
}
