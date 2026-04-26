import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/widgets/nutritionist_bottom_nav.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(bottomNavigationBar: child));

  testWidgets('Nutritionist bottom nav: plus and message taps emit indices', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    int? lastTap;
    await tester.pumpWidget(wrap(NbBottomNav(
      currentIndex: 0,
      onTap: (i) => lastTap = i,
      orange: const Color(0xFFEF8A54),
    )));

    final plusImage = find.byWidgetPredicate((w) {
      if (w is Image && w.image is AssetImage) {
        final img = w.image as AssetImage;
        return img.assetName.endsWith('plus.png');
      }
      return false;
    });
    expect(plusImage, findsOneWidget);

    await tester.tap(plusImage);
    await tester.pump();
    expect(lastTap, 2);

    final messageIcon = find.byWidgetPredicate((w) {
      if (w is Image && w.image is AssetImage) {
        final img = w.image as AssetImage;
        return img.assetName.endsWith('message_inactive.png') || img.assetName.endsWith('message_active.png');
      }
      return false;
    });
    expect(messageIcon, findsOneWidget);

    await tester.tap(messageIcon);
    await tester.pump();
    expect(lastTap, 4);
  });
}
