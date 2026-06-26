import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:conexus/viewmodel/user_view_model.dart';
import 'package:conexus/repo/user_repo.dart';
import 'package:conexus/model/user_model.dart';

class MockUserRepo extends Mock implements UserRepo {}

void main() {
  late UserViewModel userViewModel;
  late MockUserRepo mockUserRepo;

  setUp(() {
    mockUserRepo = MockUserRepo();
    userViewModel = UserViewModel(userRepo: mockUserRepo);
  });

  final tUserModel = UserModel(
    id: '1',
    name: 'Test User',
    contact: '1234567890',
    email: 'test@example.com',
    profileImage: '',
  );

  group('UserViewModel Tests', () {
    test('initial state should be correct', () {
      expect(userViewModel.user, null);
      expect(userViewModel.loading, false);
      expect(userViewModel.error, "");
    });

    test('login should set user and return true on success', () async {
      // Arrange
      when(() => mockUserRepo.login(any(), any())).thenAnswer((_) async => 'uid123');
      when(() => mockUserRepo.getUserId('uid123')).thenAnswer((_) async => tUserModel);

      // Act
      final result = await userViewModel.login('test@example.com', 'password');

      // Assert
      expect(result, true);
      expect(userViewModel.user, tUserModel);
      expect(userViewModel.loading, false);
      verify(() => mockUserRepo.login('test@example.com', 'password')).called(1);
    });

    test('login should set error and return false on failure', () async {
      // Arrange
      when(() => mockUserRepo.login(any(), any())).thenThrow(Exception('Login error'));

      // Act
      final result = await userViewModel.login('test@example.com', 'password');

      // Assert
      expect(result, false);
      expect(userViewModel.user, null);
      expect(userViewModel.error, contains('Login error'));
    });

    test('getAllUser should update allUsers list', () async {
      // Arrange
      final usersList = [tUserModel];
      when(() => mockUserRepo.getAllUser()).thenAnswer((_) async => usersList);

      // Act
      await userViewModel.getAllUser();

      // Assert
      expect(userViewModel.allUsers, usersList);
      verify(() => mockUserRepo.getAllUser()).called(1);
    });

    test('logout should clear user data', () async {
      // Arrange
      when(() => mockUserRepo.logout()).thenAnswer((_) async => {});

      // Act
      await userViewModel.logout();

      // Assert
      expect(userViewModel.user, null);
      expect(userViewModel.userId, null);
      verify(() => mockUserRepo.logout()).called(1);
    });
  });
}
