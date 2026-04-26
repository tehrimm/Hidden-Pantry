import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/chat_interface_part.dart';
import 'package:hidden_pantry_app/features/nutritionist/screens/nutritionist_chat_list.dart';
import '../functional/mock_firebase.dart';
import '../functional/test_utils.dart';

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
    setUpNetworkImageMock();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  Future<void> _setLargeViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Integration: Chat list shows login prompt when signed out', (tester) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(wrap(const NutritionistChatListScreen()));
    await tester.pump();

    expect(find.text('Please log in'), findsOneWidget);
  });

  testWidgets('Integration: Chat interface shows title and encryption copy', (tester) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(
      wrap(
        const ChatInterface(
          nutritionistId: 'nutri-1',
          nutritionistData: {'fullName': 'Coach Noor'},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Coach Noor'), findsOneWidget);
    expect(find.text('Messages are end-to-end encrypted'), findsOneWidget);
  });

  testWidgets('Integration: Chat interface exposes input and send affordance', (tester) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(
      wrap(
        const ChatInterface(
          nutritionistId: 'nutri-1',
          nutritionistData: {'fullName': 'Coach Noor'},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });

  testWidgets('Integration: Chat overflow menu contains clear chat action', (tester) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(
      wrap(
        const ChatInterface(
          nutritionistId: 'nutri-1',
          nutritionistData: {'fullName': 'Coach Noor'},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pump();

    expect(find.text('Clear Chat'), findsOneWidget);
  });

  testWidgets('Integration: Chat back navigation returns to previous route', (tester) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChatInterface(
                        nutritionistId: 'nutri-1',
                        nutritionistData: {'fullName': 'Coach Noor'},
                      ),
                    ),
                  );
                },
                child: const Text('Open Chat'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Chat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(ChatInterface), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Open Chat'), findsOneWidget);
  });
}
