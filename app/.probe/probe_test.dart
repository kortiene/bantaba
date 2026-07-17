import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers.dart';

void main() {
  testWidgets('find the overflowing row', (tester) async {
    final client = newMockClient();
    await pumpReadyMobileApp(tester, client);
    await pumpSteps(tester, steps: 6);
    // Walk every RenderFlex that reported overflow and print its children.
    void visit(RenderObject o) {
      if (o is RenderFlex && o.direction == Axis.horizontal) {
        double sum = 0;
        final kids = <String>[];
        o.visitChildren((c) {
          if (c is RenderBox) {
            sum += c.size.width;
            kids.add(c.size.width.toStringAsFixed(1));
          }
        });
        if (sum > o.size.width + 0.5 && o.size.width > 0) {
          debugPrint('PROBE overflow row: box=${o.size.width.toStringAsFixed(1)} '
              'children=$kids sum=${sum.toStringAsFixed(1)}');
          debugPrint('   desc: ${o.toStringShallow(joiner: " | ").substring(0, 160)}');
          RenderObject? p = o.parent;
          for (var i = 0; i < 6 && p != null; i++) { p = p.parent; }
        }
      }
      o.visitChildren(visit);
    }
    visit(tester.binding.rootElement!.renderObject!);
  });
}
