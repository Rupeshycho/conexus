import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:conexus/view/select_user_screen.dart';
import 'package:conexus/viewmodel/user_view_model.dart';
import 'package:conexus/model/user_model.dart';

class MockUserViewModel extends Mock implements UserViewModel {}

void main() {
  late MockUserViewModel mockUserViewModel;

  final currentUser = UserModel(
    id: 'current_uid',
    name: 'Current User',
    contact: '',
    email: 'current@example.com',
    profileImage: '',
  );

  final otherUser1 = UserModel(
    id: 'other_uid1',
    name: 'Alice Johnson',
    contact: '',
    email: 'alice@example.com',
    profileImage: '',
  );

  final otherUser2 = UserModel(
    id: 'other_uid2',
    name: 'Bob Miller',
    contact: '',
    email: 'bob@example.com',
    profileImage: '',
  );

  setUp(() {
    mockUserViewModel = MockUserViewModel();
    when(() => mockUserViewModel.userId).thenReturn(currentUser.id);
    when(() => mockUserViewModel.allUsers).thenReturn([currentUser, otherUser1, otherUser2]);
    when(() => mockUserViewModel.loading).thenReturn(false);
    when(() => mockUserViewModel.getAllUser()).thenAnswer((_) async {});
  });

  Widget createSelectUserScreen() {
    return ChangeNotifierProvider<UserViewModel>.value(
      value: mockUserViewModel,
      child: const MaterialApp(
        home: SelectUserScreen(),
      ),
    );
  }

  testWidgets('SelectUserScreen renders other users list and allows search filtering', (WidgetTester tester) async {
    await tester.pumpWidget(createSelectUserScreen());
    await tester.pump();

    // Verify getAllUser was called on init
    verify(() => mockUserViewModel.getAllUser()).called(1);

    // Verify other users are in the list, but NOT the current user
    expect(find.text('Alice Johnson'), findsOneWidget);
    expect(find.text('Bob Miller'), findsOneWidget);
    expect(find.text('Current User'), findsNothing);

    // Search for Alice
    await tester.enterText(find.byType(TextField), 'Alice');
    await tester.pump();

    // Verify Bob is filtered out and Alice remains
    expect(find.text('Alice Johnson'), findsOneWidget);
    expect(find.text('Bob Miller'), findsNothing);
  });
}
