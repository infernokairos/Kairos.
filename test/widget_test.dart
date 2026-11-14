import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_planner/main.dart';
import 'package:task_planner/models/schedule_slot.dart';

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

    test('TaskStorage serialize and deserialize preserves weeklySchedule with S, A, B slots', () {
      final tasks = {
        TierCategory.s: <TierTask>[],
        TierCategory.a: <TierTask>[],
        TierCategory.b: <TierTask>[],
      };
      final thresholds = TaskStorageData.defaultThresholds(2);
      final schedule = [
        ScheduleSlot(
          id: 'slot1',
          dayOfWeek: 1,
          startMinutes: 540, // 09:00
          endMinutes: 720, // 12:00
          tier: TierCategory.s,
        ),
        ScheduleSlot(
          id: 'slot2',
          dayOfWeek: 1,
          startMinutes: 780, // 13:00
          endMinutes: 900, // 15:00
          tier: TierCategory.a,
        ),
        ScheduleSlot(
          id: 'slot3',
          dayOfWeek: 1,
          startMinutes: 960, // 16:00
          endMinutes: 1020, // 17:00
          tier: TierCategory.b,
        ),
      ];

      final jsonStr = TaskStorage.serialize(tasks, thresholds, schedule);
      expect(jsonStr.contains('"weeklySchedule"'), isTrue);
      expect(jsonStr.contains('"start": "09:00"'), isTrue);
      expect(jsonStr.contains('"end": "12:00"'), isTrue);
      expect(jsonStr.contains('"tier": "s"'), isTrue);

      final deserialized = TaskStorage.deserialize(jsonStr);
      expect(deserialized.weeklySchedule.length, 3);
      expect(deserialized.weeklySchedule[0].tier, TierCategory.s);
      expect(deserialized.weeklySchedule[0].durationMinutes, 180);
      expect(deserialized.weeklySchedule[1].tier, TierCategory.a);
      expect(deserialized.weeklySchedule[2].tier, TierCategory.b);
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
      expect(find.text('0 Sittings completed'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Switch to Loop tab and verify active tasks
      await tester.tap(find.text('Loop'));
      await tester.pumpAndSettle();
      expect(find.text('Critical Server Hotfix'), findsOneWidget);
      expect(find.text('Payment Gateway Integration'), findsOneWidget);

      // Switch back to S tab and add a task using top-right add button
      await tester.tap(find.text('S'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('Add Task'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Unit Test Instant Task');
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

    testWidgets('Habit details dialog allows setting and increasing total sittings with bar analysis', (tester) async {
      SharedPreferences.setMockInitialValues({
        'kairos_tasks_data_json': json.encode({
          'activeThresholds': {'s': 2, 'a': 0, 'b': 0},
          'tasks': {
            's': [
              {
                'id': 's1',
                'title': 'Solid Works',
                'rank': 1,
                'isCompleted': false,
                'totalSittings': 0,
              },
            ],
            'a': [],
            'b': [],
          }
        })
      });

      await pumpApp(tester);
      expect(find.text('Solid Works'), findsOneWidget);

      // Open habit tracker details
      await tester.tap(find.text('Solid Works'));
      await tester.pumpAndSettle();

      expect(find.text('0 Sittings completed'), findsOneWidget);

      // Increase total sittings via + button
      await tester.tap(find.byTooltip('Increase target sittings'));
      await tester.pumpAndSettle();
      expect(find.text('Goal: 1'), findsOneWidget);
      expect(find.text('0 / 1 Sittings'), findsOneWidget);

      // Open set goal dialog and set target to 10
      await tester.tap(find.text('Goal: 1'));
      await tester.pumpAndSettle();
      expect(find.text('Set Target Sittings'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '10');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Goal: 10'), findsOneWidget);
      expect(find.text('0 / 10 Sittings'), findsOneWidget);
      expect(find.text('(0%)'), findsOneWidget);

      // Toggle today's date in calendar to complete 1 session
      final now = DateTime.now();
      await tester.tap(find.text('${now.day}').last);
      await tester.pumpAndSettle();

      // Bar analysis updates to 1 / 10 Sittings and (10%)
      expect(find.text('1 / 10 Sittings'), findsOneWidget);
      expect(find.text('(10%)'), findsOneWidget);

      // Close dialog
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // TaskTile subtitle displays sittings
      expect(find.text('1/10 Sittings'), findsOneWidget);

      // Verify persisted in storage
      final saved = await TaskStorage.loadInitialData();
      final task = saved.tasks[TierCategory.s]!.first;
      expect(task.totalSittings, 10);
      expect(task.currentSittings, 1);
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets('Task auto-archives when total sittings target reached, viewable via 3-dots Archive menu and restorable', (tester) async {
      SharedPreferences.setMockInitialValues({
        'kairos_tasks_data_json': '''
{
  "activeThresholds": {"s": 2, "a": 2, "b": 2},
  "tasks": {
    "s": [
      {
        "id": "task_target",
        "title": "Thermodynamics",
        "rank": 1,
        "isCompleted": false,
        "totalSittings": 1,
        "completedDates": []
      }
    ],
    "a": [],
    "b": []
  }
}
'''
      });

      await tester.pumpWidget(const TaskPlannerApp());
      await tester.pumpAndSettle();

      // Switch to Loop tab
      await tester.tap(find.text('Loop'));
      await tester.pumpAndSettle();

      expect(find.text('Thermodynamics'), findsOneWidget);

      // Complete the task (reaching 1/1 sitting)
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      // Task is auto-archived and removed from Loop tab
      expect(find.text('No active tasks'), findsOneWidget);

      // Verify SnackBar notification
      expect(
        find.text('"Thermodynamics" completed all sittings and moved to Archive.'),
        findsOneWidget,
      );

      // Open 3-dots settings menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Archive'), findsOneWidget);

      // Tap 'Archive' menu item
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();

      // Archive sheet is open
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('1 task completed'), findsOneWidget);
      expect(find.text('Thermodynamics'), findsOneWidget);
      expect(find.text('1 / 1 Sittings completed'), findsOneWidget);

      // Tap restore icon
      await tester.tap(find.byIcon(Icons.unarchive_outlined));
      await tester.pumpAndSettle();

      // Sheet now shows empty archive
      expect(find.text('No archived tasks'), findsOneWidget);

      // Dismiss bottom sheet by tapping outside / dragging down / pressing escape / popping
      tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Switch to S tab
      await tester.tap(find.text('S'));
      await tester.pumpAndSettle();

      // Task is restored to active S tier list
      expect(find.text('Thermodynamics'), findsOneWidget);

      final saved = await TaskStorage.loadInitialData();
      final restoredTask = saved.tasks[TierCategory.s]!.first;
      expect(restoredTask.isArchived, isFalse);
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets('Weekly Loop calendar opens from top-right icon, starts week on Sunday, allows adding slots, and copying day to all days', (tester) async {
      await pumpApp(tester);

      // Verify the calendar button in top right
      final calendarBtn = find.byTooltip('Weekly Loop Schedule');
      expect(calendarBtn, findsOneWidget);

      await tester.tap(calendarBtn);
      await tester.pumpAndSettle();

      // Screen opens: Weekly Loop
      expect(find.text('Weekly Loop'), findsOneWidget);

      // Verify 7 day headers with Sunday starting first
      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);

      // Sunday header is to the left of Monday header
      final sunX = tester.getTopLeft(find.text('Sun')).dx;
      final monX = tester.getTopLeft(find.text('Mon')).dx;
      expect(sunX, lessThan(monX));

      // Add a slot via the top right '+' button
      await tester.tap(find.byTooltip('Add Slot'));
      await tester.pumpAndSettle();

      expect(find.text('Add Loop Slot'), findsOneWidget);

      // Tap 'Save' to add the default 09:00-11:00 S slot on Sunday (first day)
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // Verify Sunday shows 2.0h
      expect(find.text('2.0h'), findsWidgets);

      // Tap Sunday header to open copy menu
      await tester.tap(find.text('Sun'));
      await tester.pumpAndSettle();

      expect(find.text('Copy to all days'), findsOneWidget);

      // Tap 'Copy to all days'
      await tester.tap(find.text('Copy to all days'));
      await tester.pumpAndSettle();

      // Total week time updates to 14.0h (2h * 7 days)
      expect(find.text('14.0h'), findsWidgets);
      expect(find.text('total'), findsOneWidget);

      // Test Undo: restores back to 1 day (2.0h)
      await tester.tap(find.byTooltip('Undo (Ctrl+Z)'));
      await tester.pumpAndSettle();
      expect(find.text('2.0h'), findsWidgets);

      // Test Redo: reapplies copy to all days (14.0h)
      await tester.tap(find.byTooltip('Redo (Ctrl+Shift+Z)'));
      await tester.pumpAndSettle();
      expect(find.text('14.0h'), findsWidgets);

      // Test Clear Day confirmation dialog
      await tester.tap(find.text('Sun'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear this day'));
      await tester.pumpAndSettle();
      expect(find.text('Clear Sunday?'), findsOneWidget);
      // Cancel first
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('14.0h'), findsWidgets);

      // Clear with confirmation
      await tester.tap(find.text('Sun'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear this day'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
      await tester.pumpAndSettle();
      expect(find.text('12.0h'), findsWidgets);

      // Pop back to main tasks screen
      tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Kairos'), findsOneWidget);

      // Verify saved in storage
      final saved = await TaskStorage.loadInitialData();
      expect(saved.weeklySchedule.length, 6);
      expect(saved.weeklySchedule.every((s) => s.tier == TierCategory.s), isTrue);
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets('Weekly Loop calendar allows adding custom named Other slot with grey color and solid appearance', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byTooltip('Weekly Loop Schedule'));
      await tester.pumpAndSettle();

      // Add a slot
      await tester.tap(find.byTooltip('Add Slot'));
      await tester.pumpAndSettle();

      // Select 'Other' category
      await tester.tap(find.text('Other'));
      await tester.pumpAndSettle();

      // Enter custom name 'Gym'
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Gym');
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // Card with 'Gym' is rendered on Sunday
      expect(find.text('Gym'), findsOneWidget);

      // Check ratio bar includes 'Other'
      expect(find.text('Other'), findsWidgets);
      expect(find.text('2.0h'), findsWidgets);

      // Verify saved in storage with null tier and 'Gym' title
      final saved = await TaskStorage.loadInitialData();
      final otherSlot = saved.weeklySchedule.firstWhere((s) => s.title == 'Gym');
      expect(otherSlot.isOther, isTrue);
      expect(otherSlot.tier, isNull);
      expect(otherSlot.title, 'Gym');
      expect(otherSlot.displayName, 'Gym');
      expect(otherSlot.color, const Color(0xFF9E9E9E));
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets('12/24 hour switching in 3-dots settings and weekly calendar view toggles format and persists', (tester) async {
      await pumpApp(tester);

      // Open 3-dots settings menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('24-hour time'), findsOneWidget);

      // Switch to 24-hour time
      await tester.tap(find.text('24-hour time'));
      await tester.pumpAndSettle();

      expect(find.text('Switched to 24-hour time'), findsOneWidget);

      // Verify preference saved in storage
      var is24 = await TaskStorage.loadIs24Hour();
      expect(is24, isTrue);

      // Open Weekly Loop view
      await tester.tap(find.byTooltip('Weekly Loop Schedule'));
      await tester.pumpAndSettle();

      // In 24h mode, time gutter displays 08:00
      expect(find.text('08:00'), findsOneWidget);

      // Switch back to 12-hour mode from the calendar 3-dots menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('12-hour time (AM/PM)'), findsOneWidget);
      await tester.tap(find.text('12-hour time (AM/PM)'));
      await tester.pumpAndSettle();

      // In 12h mode, time gutter displays 8 AM
      expect(find.text('8 AM'), findsOneWidget);

      is24 = await TaskStorage.loadIs24Hour();
      expect(is24, isFalse);
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets('Weekly Loop calendar focuses waking hours without showing sleep blocks in grid, and configures sleep analysis & targets in 3-dots options', (tester) async {
      await pumpApp(tester);

      // Open Weekly Loop view
      await tester.tap(find.byTooltip('Weekly Loop Schedule'));
      await tester.pumpAndSettle();

      // Verify Sleep Block is NOT rendered in the calendar grid
      expect(find.text('Sleep'), findsNothing);

      // Open Sleep Schedule from calendar 3-dots menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Sleep Schedule'), findsOneWidget);
      await tester.tap(find.text('Sleep Schedule'));
      await tester.pumpAndSettle();

      // Sleep dialog opens
      expect(find.text('Sleep Schedule & Focus'), findsOneWidget);
      expect(find.text('Sleep Analysis'), findsOneWidget);
      expect(find.text('Focus Mode (Shorten Scroll)'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      // Open Loop Target Ratios from 3-dots menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Loop Target Ratios'));
      await tester.pumpAndSettle();

      // Dialog opens: Loop Target Ratios
      expect(find.text('Loop Target Ratios'), findsOneWidget);
      expect(find.text('Tier Percentages'), findsOneWidget);

      // Tweak Target Ratios to 50% S, 25% A, 25% B
      final sField = find.widgetWithText(TextField, '60');
      if (sField.evaluate().isNotEmpty) {
        await tester.enterText(sField, '50');
      }
      final bField = find.widgetWithText(TextField, '15');
      if (bField.evaluate().isNotEmpty) {
        await tester.enterText(bField, '25');
      }
      await tester.pumpAndSettle();

      // Tap 'Save'
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Weekly Loop'), findsOneWidget);
      final savedTargets = await TaskStorage.loadWeekTargets();
      expect(savedTargets.sPct, 50);
      expect(savedTargets.bPct, 25);

      // Pop back to main screen
      tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Open 3-dots settings from main Kairos screen: verify Sleep Schedule is NOT shown
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Sleep Schedule'), findsNothing);
      expect(find.text('Thresholds'), findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
