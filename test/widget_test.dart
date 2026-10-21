import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:task_planner/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TaskPlanner JSON Storage & Unit Tests', () {
    test('TaskStorage serialize and deserialize maintains tier loops and independent rankings', () {
      final tasks = {
        TierCategory.s: [
          TierTask(id: 's1', title: 'Task S1', tier: TierCategory.s, rank: 1),
          TierTask(id: 's2', title: 'Task S2', tier: TierCategory.s, rank: 2),
        ],
        TierCategory.a: [
          TierTask(id: 'a1', title: 'Task A1', tier: TierCategory.a, rank: 1),
        ],
        TierCategory.b: [
          TierTask(id: 'b1', title: 'Task B1', tier: TierCategory.b, rank: 1),
          TierTask(id: 'b2', title: 'Task B2', tier: TierCategory.b, rank: 2),
        ],
      };

      final jsonStr = TaskStorage.serialize(tasks, 3);
      expect(jsonStr, contains('"activeThreshold": 3'));
      expect(jsonStr, contains('"Task S1"'));

      final parsed = TaskStorage.deserialize(jsonStr);
      expect(parsed.activeThreshold, 3);
      expect(parsed.tasks[TierCategory.s]?.length, 2);
      expect(parsed.tasks[TierCategory.s]?[0].title, 'Task S1');
      expect(parsed.tasks[TierCategory.s]?[0].rank, 1);
      expect(parsed.tasks[TierCategory.s]?[1].rank, 2);
      expect(parsed.tasks[TierCategory.a]?[0].rank, 1);
      expect(parsed.tasks[TierCategory.b]?[0].rank, 1);
      expect(parsed.tasks[TierCategory.b]?[1].rank, 2);
    });
  });

  group('Widget Tests', () {
    testWidgets('App renders UI, tier tabs, Import/Export buttons, and active threshold', (tester) async {
      await tester.pumpWidget(const TaskPlannerApp());
      await tester.pumpAndSettle();

      // Verify title
      expect(find.text('Task Planner'), findsOneWidget);

      // Verify Import & Export buttons
      expect(find.byKey(const ValueKey('import_json_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('export_json_btn')), findsOneWidget);

      // Verify Tier tabs
      expect(find.text('S Tier'), findsWidgets);
      expect(find.text('A Tier'), findsWidgets);
      expect(find.text('B Tier'), findsWidgets);

      // Verify active threshold stepper
      expect(find.textContaining('Active Threshold: Top'), findsOneWidget);

      // Verify Quick Add input and button
      expect(find.text('Add'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Test adding a task to current tier
      await tester.enterText(find.byType(TextField), 'Unit Test Instant Task');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Unit Test Instant Task'), findsOneWidget);
    });
  });
}
