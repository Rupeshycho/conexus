import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:conexus/view/create_group_screen.dart';
import 'package:conexus/viewmodel/user_view_model.dart';
import 'package:conexus/model/user_model.dart';
import 'firebase_mocks.dart';

class MockUserViewModel extends Mock implements UserViewModel {}

void main() {
  late MockUserViewModel mockUserViewModel;

  final otherUser = UserModel(
    id: 'other_uid',
    name: 'Alice Cooper',
    contact: '',
    email: 'alice@example.com',
    profileImage: '',
  );

  setUpAll(() async {
    setupFirebaseMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    mockUserViewModel = MockUserViewModel();
    when(() => mockUserViewModel.user).thenReturn(null);
    when(() => mockUserViewModel.allUsers).thenReturn([otherUser]);
    when(() => mockUserViewModel.loading).thenReturn(false);
  });

  Widget createCreateGroupScreen() {
    return ChangeNotifierProvider<UserViewModel>.value(
      value: mockUserViewModel,
      child: const MaterialApp(
        home: CreateGroupScreen(),
      ),
    );
  }

  testWidgets('CreateGroupScreen renders fields and lists users to select', (WidgetTester tester) async {
    await tester.pumpWidget(createCreateGroupScreen());
    await tester.pump();

    // Verify Title and input fields are present
    expect(find.text('Create Group'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Group Name'), findsOneWidget);

    // Verify other users list renders
    expect(find.text('Alice Cooper'), findsOneWidget);
    expect(find.byIcon(Icons.circle_outlined), findsOneWidget);

    // Toggle user selection
    await tester.tap(find.text('Alice Cooper'));
    await tester.pump();

    // Verify selected state icon
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
