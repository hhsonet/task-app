import 'package:flutter_test/flutter_test.dart';
import 'package:local_task/main.dart';

void main() {
  test('task serializes and restores locally', () {
    final original = Task(
      id: '1',
      title: 'Buy groceries',
      category: 'Shopping',
      recurring: 'Weekly',
    );
    final restored = Task.fromJson(original.toJson());
    expect(restored.title, 'Buy groceries');
    expect(restored.category, 'Shopping');
    expect(restored.recurring, 'Weekly');
  });

  test('meeting serializes and restores locally', () {
    final original = Meeting(
      id: 'm1',
      title: 'Project review',
      date: DateTime(2026, 9, 28),
      link: 'https://meet.google.com/example',
    );
    final restored = Meeting.fromJson(original.toJson());
    expect(restored.title, 'Project review');
    expect(restored.date, DateTime(2026, 9, 28));
    expect(restored.link, 'https://meet.google.com/example');
  });
}
