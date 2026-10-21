import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:task_planner/main.dart';

void main() {
  testWidgets('App renders Tier-Loops with S/A/B tabs and active threshold',
      (WidgetTester tester) async {
    // Build app
    await tester.pumpWidget(const TaskPlannerApp());

    // Verify header and panels
    expect(find.byType(Material3ExpressiveAppBar), findsOneWidget);
    expect(find.byType(LeftPanelWidget), findsOneWidget);
    expect(find.byType(RightPanelWidget), findsOneWidget);

    // Verify S, A, B tabs
    expect(find.text('S Tier'), findsOneWidget);
    expect(find.text('A Tier'), findsOneWidget);
    expect(find.text('B Tier'), findsOneWidget);

    // Verify View All Tiers icon button is present
    expect(find.byIcon(Icons.view_agenda_rounded), findsOneWidget);

    // Verify threshold controller
    expect(find.text('Active Threshold:'), findsOneWidget);
    expect(find.text('Top-5'), findsOneWidget);

    // Helper finder for LeftPanelWidget tasks
    Finder findInLeftPanel(String text) {
      return find.descendant(
        of: find.byType(LeftPanelWidget),
        matching: find.text(text),
      );
    }

    // Verify numbered active task in LeftPanelWidget S tier
    expect(find.text('#1 ACTIVE'), findsOneWidget);
    expect(
      findInLeftPanel('Deploy Production Security Patch'),
      findsOneWidget,
    );

    // Switch to A Tier tab
    await tester.tap(find.text('A Tier'));
    await tester.pumpAndSettle();

    // Verify A Tier tasks are visible and numbered in LeftPanelWidget
    expect(
      findInLeftPanel('Tier-Loop Active Threshold Engine'),
      findsOneWidget,
    );

    // Switch to B Tier tab
    await tester.tap(find.text('B Tier'));
    await tester.pumpAndSettle();

    // Verify B Tier tasks are visible and numbered in LeftPanelWidget
    expect(
      findInLeftPanel('Automated CI/CD Pipeline Artifacts'),
      findsOneWidget,
    );

    // Click View All Tiers icon
    await tester.tap(find.byIcon(Icons.view_agenda_rounded));
    await tester.pumpAndSettle();

    // In All Tiers view, top S tier task is visible
    expect(
      findInLeftPanel('Deploy Production Security Patch'),
      findsOneWidget,
    );

    // Increase threshold
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Top-6'), findsOneWidget);
  });
}
