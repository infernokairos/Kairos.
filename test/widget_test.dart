import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_planner/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    rootBundle.evict('assets/tasks.json');
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(const TaskPlannerApp());
    for (int i = 0;
        i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
        i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpAndSettle();
  }

  group('TaskPlanner JSON Storage & Unit Tests', () {
    test('TaskStorage serialize and deserialize uses clean JSON format without unused fields', () {
      final tasks = {
        TierCategory.s: [
          TierTask(
            id: 's1',
            title: 'Task S1',
            tier: TierCategory.s,
            rank: 1,
            isCompleted: true,
            completedDates: {'2026-11-11', '2026-11-10'},
          ),
          TierTask(id: 's2', title: 'Task S2', tier: TierCategory.s, rank: 2),
        ],
        TierCategory.a: [
          TierTask(id: 'a1', title: 'Task A1', tier: TierCategory.a, rank: 1),
        ],
        TierCategory.b: [
          TierTask(id: 'b1', title: 'Task B1', tier: TierCategory.b, rank: 1),
          TierTask(id: 'b2', title: 'Task B2', tier: TierCategory.b, rank: 2),
          TierTask(id: 'b3', title: 'Task B3', tier: TierCategory.b, rank: 3),
        ],
      };
      final thresholds = {
        TierCategory.s: 1,
        TierCategory.a: 3,
        TierCategory.b: 0,
      };

      final jsonStr = TaskStorage.serialize(tasks, thresholds);
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;

      expect(decoded.keys.toSet(), {'activeThresholds', 'tasks'});
      expect(decoded['activeThresholds'], {'s': 1, 'a': 3, 'b': 0});

      final s1Json = decoded['tasks']['s'][0] as Map<String, dynamic>;
      expect(s1Json.keys.toSet(), {'id', 'title', 'rank', 'isCompleted', 'completedDates'});
      expect(s1Json['completedDates'], ['2026-11-10', '2026-11-11']);

      final s2Json = decoded['tasks']['s'][1] as Map<String, dynamic>;
      expect(s2Json.keys.toSet(), {'id', 'title', 'rank', 'isCompleted'});
      expect(s2Json.containsKey('completedDates'), isFalse);

      // Ensure removed bloat fields never appear
      for (final unusedKey in ['question', 'notes', 'frequency', 'repetitions', 'createdAtMillis']) {
        expect(s1Json.containsKey(unusedKey), isFalse);
        expect(s2Json.containsKey(unusedKey), isFalse);
      }

      final deserialized = TaskStorage.deserialize(jsonStr);
      expect(deserialized.thresholdFor(TierCategory.s), 1);
      expect(deserialized.thresholdFor(TierCategory.a), 3);
      expect(deserialized.thresholdFor(TierCategory.b), 0);
      expect(deserialized.tasks[TierCategory.s]!.length, 2);
      expect(
        deserialized.tasks[TierCategory.s]!.first.completedDates,
        {'2026-11-10', '2026-11-11'},
      );
      expect(deserialized.tasks[TierCategory.b]!.length, 3);
    });

    test('TaskStorage deserialize migrates legacy repetitions and ignores unused fields', () {
      const legacyJson = '''
      {
        "activeThreshold": 4,
        "tasks": {
          "s": [
            {
              "id": "s1",
              "title": "Old Format S1",
              "rank": 1,
              "isCompleted": false,
              "question": "Did you do it?",
              "notes": "Some notes",
              "frequency": {"num": 3, "den": 7},
              "repetitions": {"2026-11-09": 1, "2026-11-10": 2, "2026-11-11": 1},
              "createdAtMillis": 1794404000000
            }
          ],
          "a": [],
          "b": []
        }
      }
      ''';
      final parsed = TaskStorage.deserialize(legacyJson);
      expect(parsed.thresholdFor(TierCategory.s), 4);
      expect(parsed.thresholdFor(TierCategory.a), 4);
      expect(parsed.thresholdFor(TierCategory.b), 4);
      final task = parsed.tasks[TierCategory.s]!.first;
      expect(task.title, 'Old Format S1');
      expect(task.completedDates, {'2026-11-09', '2026-11-11'});
    });

    test('TaskStorage deserialize handles partial maps, clamping, and singular map fallback', () {
      const partialJson = '''
      {
        "activeThresholds": {"s": 99, "a": -5},
        "tasks": {}
      }
      ''';
      final parsed = TaskStorage.deserialize(partialJson);
      expect(parsed.thresholdFor(TierCategory.s), TaskStorageData.maxThreshold);
      expect(parsed.thresholdFor(TierCategory.a), TaskStorageData.minThreshold);
      expect(parsed.thresholdFor(TierCategory.b), TaskStorageData.defaultThreshold);

      const singularMapJson = '''
      {
        "activeThreshold": {"s": 1, "a": 5},
        "tasks": {}
      }
      ''';
      final parsedSingular = TaskStorage.deserialize(singularMapJson);
      expect(parsedSingular.thresholdFor(TierCategory.s), 1);
      expect(parsedSingular.thresholdFor(TierCategory.a), 5);
      expect(parsedSingular.thresholdFor(TierCategory.b), 2);
    });
  });

  group('Widget Tests', () {
    testWidgets('App renders UI, tier tabs, menu actions, and supports calendar dialog', (tester) async {
      await pumpApp(tester);

      // Verify title & tabs
      expect(find.text('Kairos'), findsOneWidget);
      expect(find.text('S'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('Loop'), findsOneWidget);

      // Open overflow menu and verify actions
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Thresholds'), findsOneWidget);
      expect(find.text('Import'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Light mode'), findsOneWidget);

      // Open Active thresholds sheet
      await tester.tap(find.text('Thresholds'));
      await tester.pumpAndSettle();
      expect(find.text('Active thresholds'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Tap a task to open the calendar popup
      await tester.tap(find.text('Critical Server Hotfix'));
      await tester.pumpAndSettle();
      expect(find.text('0 days completed'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Switch to Loop tab and verify active tasks
      await tester.tap(find.text('Loop'));
      await tester.pumpAndSettle();
      expect(find.text('Critical Server Hotfix'), findsOneWidget);
      expect(find.text('Payment Gateway Integration'), findsOneWidget);

      // Switch back to S tab and add a task using FAB
      await tester.tap(find.text('S'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Add Task'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Unit Test Instant Task');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(find.text('Unit Test Instant Task'), findsOneWidget);

      // Toggle theme via menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Light mode'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark mode'));
      await tester.pumpAndSettle();
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets('Threshold sheet and Loop tab have no overflow on compact viewport', (tester) async {
      tester.view.physicalSize = const Size(380, 560);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpApp(tester);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thresholds'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Done'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Loop'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets('App loads legacy activeThreshold format cleanly from storage', (tester) async {
      SharedPreferences.setMockInitialValues({
        'kairos_tasks_data_json': json.encode({
          'activeThreshold': 1,
          'tasks': {
            's': [
              {'id': 's1', 'title': 'Legacy S1', 'rank': 1, 'isCompleted': false},
              {'id': 's2', 'title': 'Legacy S2', 'rank': 2, 'isCompleted': false},
            ],
            'a': [
              {'id': 'a1', 'title': 'Legacy A1', 'rank': 1, 'isCompleted': false},
              {'id': 'a2', 'title': 'Legacy A2', 'rank': 2, 'isCompleted': false},
            ],
            'b': [
              {'id': 'b1', 'title': 'Legacy B1', 'rank': 1, 'isCompleted': false},
            ]
          }
        })
      });

      await pumpApp(tester);
      expect(find.text('Legacy S1'), findsOneWidget);

      await tester.tap(find.text('Loop'));
      await tester.pumpAndSettle();
      expect(find.text('Legacy S1'), findsOneWidget);
      expect(find.text('Legacy A1'), findsOneWidget);
      expect(find.text('Legacy B1'), findsOneWidget);
      expect(find.text('Legacy S2'), findsNothing);
      expect(find.text('Legacy A2'), findsNothing);
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets('Loop shows checkbox strictly on first pending item per tier, sends done last, and keeps checkboxes completed on same day', (tester) async {
      SharedPreferences.setMockInitialValues({
        'kairos_tasks_data_json': json.encode({
          'activeThresholds': {'s': 2, 'a': 0, 'b': 0},
          'tasks': {
            's': [
              {'id': 's1', 'title': 'First Item', 'rank': 1, 'isCompleted': false},
              {'id': 's2', 'title': 'Second Item', 'rank': 2, 'isCompleted': false},
              {'id': 's3', 'title': 'Queued Item', 'rank': 3, 'isCompleted': false},
            ],
            'a': [],
            'b': [],
          }
        })
      });

      await pumpApp(tester);
      await tester.tap(find.text('Loop'));
      await tester.pumpAndSettle();

      // Strictly 1 interactive (uncompleted) checkbox in Loop for S tier (First Item)
      final interactiveCheckboxFinder = find.byWidgetPredicate(
        (w) => w is Checkbox && w.value == false && w.onChanged != null,
      );
      expect(interactiveCheckboxFinder, findsOneWidget);
      final firstTileY = tester.getTopLeft(find.text('First Item')).dy;
      final secondTileY = tester.getTopLeft(find.text('Second Item')).dy;
      expect(firstTileY, lessThan(secondTileY));

      // Mark First Item as done
      await tester.tap(interactiveCheckboxFinder);
      await tester.pumpAndSettle();

      // First Item is now sent last (below Second Item), still keeps #1 rank
      // Second Item now has the interactive checkbox, First Item has a checked checkbox
      expect(interactiveCheckboxFinder, findsOneWidget);
      final checkedCheckboxFinder = find.byWidgetPredicate(
        (w) => w is Checkbox && w.value == true,
      );
      expect(checkedCheckboxFinder, findsOneWidget);
      expect(tester.getTopLeft(find.text('Second Item')).dy, lessThan(tester.getTopLeft(find.text('First Item')).dy));
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);

      // Verify today's activity is saved in storage while loop is mid-cycle
      final todayKey = TierTask.dateKey(DateTime.now());
      var saved = await TaskStorage.loadInitialData();
      expect(saved.tasks[TierCategory.s]![0].isCompleted, isTrue);
      expect(saved.tasks[TierCategory.s]![0].completedDates, contains(todayKey));
      expect(saved.tasks[TierCategory.s]![1].isCompleted, isFalse);

      // Finish Second Item (same day) -> DO NOT reset checkboxes, keep them completed today!
      await tester.tap(interactiveCheckboxFinder);
      await tester.pumpAndSettle();

      // All active tasks are completed today: both show checked checkboxes, 0 pending checkboxes
      expect(interactiveCheckboxFinder, findsNothing);
      expect(find.byWidgetPredicate((w) => w is Checkbox && w.value == true), findsNWidgets(2));

      saved = await TaskStorage.loadInitialData();
      expect(saved.tasks[TierCategory.s]![0].isCompleted, isTrue);
      expect(saved.tasks[TierCategory.s]![1].isCompleted, isTrue);
      expect(saved.tasks[TierCategory.s]![0].completedDates, contains(todayKey));
      expect(saved.tasks[TierCategory.s]![1].completedDates, contains(todayKey));
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets('Loop resets checkboxes on next day while preserving completedDates history', (tester) async {
      final yesterdayKey = TierTask.dateKey(DateTime.now().subtract(const Duration(days: 1)));
      SharedPreferences.setMockInitialValues({
        'kairos_tasks_data_json': json.encode({
          'activeThresholds': {'s': 2, 'a': 0, 'b': 0},
          'tasks': {
            's': [
              {
                'id': 's1',
                'title': 'Day 1 Item',
                'rank': 1,
                'isCompleted': true,
                'completedDates': [yesterdayKey],
              },
              {
                'id': 's2',
                'title': 'Day 2 Item',
                'rank': 2,
                'isCompleted': true,
                'completedDates': [yesterdayKey],
              },
            ],
            'a': [],
            'b': [],
          }
        })
      });

      // Loading app on the next day automatically resets isCompleted to false
      await pumpApp(tester);
      await tester.tap(find.text('Loop'));
      await tester.pumpAndSettle();

      final interactiveCheckboxFinder = find.byWidgetPredicate(
        (w) => w is Checkbox && w.value == false && w.onChanged != null,
      );
      // Both tasks were reset for the new day: Day 1 Item is pending with interactive checkbox at top
      expect(interactiveCheckboxFinder, findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Checkbox && w.value == true), findsNothing);
      expect(tester.getTopLeft(find.text('Day 1 Item')).dy, lessThan(tester.getTopLeft(find.text('Day 2 Item')).dy));

      // Storage shows isCompleted reset to false, but yesterday's completedDates preserved
      final todayKey = TierTask.dateKey(DateTime.now());
      var saved = await TaskStorage.loadInitialData();
      expect(saved.tasks[TierCategory.s]![0].isCompleted, isFalse);
      expect(saved.tasks[TierCategory.s]![1].isCompleted, isFalse);
      expect(saved.tasks[TierCategory.s]![0].completedDates, {yesterdayKey});
      expect(saved.tasks[TierCategory.s]![1].completedDates, {yesterdayKey});

      // Complete Day 1 Item today -> adds todayKey, keeps yesterdayKey
      await tester.tap(interactiveCheckboxFinder);
      await tester.pumpAndSettle();

      saved = await TaskStorage.loadInitialData();
      expect(saved.tasks[TierCategory.s]![0].isCompleted, isTrue);
      expect(saved.tasks[TierCategory.s]![0].completedDates, {yesterdayKey, todayKey});
      expect(saved.tasks[TierCategory.s]![1].isCompleted, isFalse);
      expect(saved.tasks[TierCategory.s]![1].completedDates, {yesterdayKey});
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
