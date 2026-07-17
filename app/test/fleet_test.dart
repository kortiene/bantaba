/// Fleet dashboard (top-level Agents view): stat tiles computed from the mock
/// fleet data — liveness derived from real peer state + real agent_status
/// events, never fabricated (P4).
library;

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:jeliya_app/src/screens/fleet_dashboard.dart';
import 'package:jeliya_app/src/screens/sidebar.dart';

import 'helpers.dart';

/// Asserts one stat tile shows [value] and [sub] under its unique [label].
void expectStatTile(
    WidgetTester tester, String label, String value, String sub) {
  final labelFinder = find.text(label);
  expect(labelFinder, findsOneWidget, reason: 'tile "$label" should exist');
  final column =
      find.ancestor(of: labelFinder, matching: find.byType(Column)).first;
  expect(find.descendant(of: column, matching: find.text(value)),
      findsOneWidget, reason: 'tile "$label" value should be $value');
  expect(find.descendant(of: column, matching: find.text(sub)),
      findsOneWidget, reason: 'tile "$label" sub should be "$sub"');
}

void main() {
  testWidgets('fleet stat tiles reflect the mock fleet data', (tester) async {
    await pumpReadyApp(tester, newMockClient());

    await tester.tap(find.descendant(
        of: find.byType(Sidebar), matching: find.text(en.sidebarNavFleet)));
    await pumpSteps(tester, steps: 10);
    expect(find.byType(FleetDashboard), findsOneWidget);

    // Fixture fleet with the main room open: backend = working (connected
    // peer + fresh working label), frontend = online-idle, research = stale
    // (working label but no live peer — never shown active), qa = offline.
    // 4 agents across 5 rooms, every room has at least one agent.
    expectStatTile(
        tester, en.fleetStatActiveAgents, '2', en.fleetStatOfTotal(4));
    expectStatTile(
        tester, en.fleetStatRunningTasks, '1', en.fleetStatOneTaskPerAgent);
    expectStatTile(tester, en.fleetStatRoomCoverage, en.commonPercent('100'),
        en.fleetStatRoomsCovered(5, 5));

    // One card per fixture agent (each shows its last-update footer). The
    // needle is the catalog message's static prefix (rel varies per card).
    expect(find.textContaining(en.fleetLastUpdate('').trim()), findsNWidgets(4));
    expect(find.text(en.fleetOpenRoom), findsNWidgets(4));
  });
}
