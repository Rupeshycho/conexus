// test/viewmodel/suggested_users_viewmodel_test.dart
import 'package:conexus/models/user_model.dart';
import 'package:conexus/repo/user_repo.dart';
import 'package:conexus/viewmodel/suggested_users_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeUserRepo implements UserRepo {
  List<UserModel> suggested = [];
  bool shouldThrow = false;

  @override
  Future<List<UserModel>> getSuggestedUsers(String currentUserId) async {
    if (shouldThrow) throw Exception('network error');
    return suggested;
  }

  @override
  Future<List<UserModel>> searchUsers(String query) async => [];
}

void main() {
  group('SuggestedUsersViewModel', () {
    test('loadSuggestedUsers populates the list on success', () async {
      final fakeRepo = FakeUserRepo()
        ..suggested = [
          UserModel(uid: '1', username: 'jack', photoUrl: '', email: ''),
        ];
      final vm = SuggestedUsersViewModel(fakeRepo);

      await vm.loadSuggestedUsers('me');

      expect(vm.suggestedUsers.length, 1);
      expect(vm.isLoading, isFalse);
    });

    test(
      'loadSuggestedUsers clears list and does not throw on repo error',
      () async {
        final fakeRepo = FakeUserRepo()..shouldThrow = true;
        final vm = SuggestedUsersViewModel(fakeRepo);

        await vm.loadSuggestedUsers('me');

        expect(vm.suggestedUsers, isEmpty);
        expect(vm.isLoading, isFalse);
      },
    );
  });
}
