import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:conexus/view/profile_screen.dart';
import 'package:conexus/viewmodel/user_view_model.dart';
import 'package:conexus/model/user_model.dart';

class MockUserViewModel extends Mock implements UserViewModel {}

void main() {
  late MockUserViewModel mockUserViewModel;

  final tUserModel = UserModel(
    id: 'uid123',
    name: 'Jane Doe',
    contact: '9876543210',
    email: 'jane@example.com',
    profileImage: '',
    aboutMe: 'Software Engineer',
  );

  setUpAll(() {
    registerFallbackValue(tUserModel);
  });

  setUp(() {
    mockUserViewModel = MockUserViewModel();
    when(() => mockUserViewModel.user).thenReturn(tUserModel);
    when(() => mockUserViewModel.loading).thenReturn(false);
    when(() => mockUserViewModel.error).thenReturn("");
    when(() => mockUserViewModel.editProfile(any())).thenAnswer((_) async => true);
  });

  Widget createProfileScreen() {
    return ChangeNotifierProvider<UserViewModel>.value(
      value: mockUserViewModel,
      child: const MaterialApp(
        home: ProfileScreen(),
      ),
    );
  }

  testWidgets('ProfileScreen renders user information and saves profile changes', (WidgetTester tester) async {
    await tester.pumpWidget(createProfileScreen());

    // Verify fields are populated with user details
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('Software Engineer'), findsOneWidget);

    // Verify Display Name and About Me inputs are present
    final displayNameFinder = find.widgetWithText(TextField, 'Display Name');
    expect(displayNameFinder, findsOneWidget);

    // Enter a new name
    await tester.enterText(find.widgetWithText(TextField, 'Display Name'), 'Jane Roe');
    await tester.pump();

    // Tap Save Changes
    await tester.tap(find.text('Save Changes'));
    await tester.pump();

    // Verify editProfile is invoked
    verify(() => mockUserViewModel.editProfile(any())).called(1);
  });
}
