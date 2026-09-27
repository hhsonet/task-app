import 'package:flutter_test/flutter_test.dart';
import 'package:local_task/main.dart';

void main() {
  test('task serializes and restores locally', () {
    final original = Task(id: '1', title: 'Buy groceries', category: 'Shopping', recurring: 'Weekly');
    final restored = Task.fromJson(original.toJson());
    expect(restored.title, 'Buy groceries');
    expect(restored.category, 'Shopping');
    expect(restored.recurring, 'Weekly');
  });
}
