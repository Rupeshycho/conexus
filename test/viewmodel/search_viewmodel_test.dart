// test/viewmodel/search_viewmodel_test.dart
import 'package:conexus/models/user_model.dart';
import 'package:conexus/repo/user_repo.dart';
import 'package:conexus/viewmodel/search_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeUserRepo implements UserRepo {
  List<UserModel> searchResult = [];
  List<UserModel> suggestedResult = [];

  @override
  Future<List<UserModel>> searchUsers(String query) async => searchResult;

  @override
  Future<List<UserModel>> getSuggestedUsers(String currentUserId) async =>
      suggestedResult;
}

void main() {
  late FakeUserRepo fakeRepo;

  setUp(() {
    fakeRepo = FakeUserRepo();
  });

  group('SearchViewModel', () {
    test(
      'searching with empty query clears results without calling repo',
      () async {
        fakeRepo.searchResult = [
          UserModel(
            uid: '1',
            username: 'x',
            email: 'x@example.com',
            photoUrl: '',
          ),
        ];
        final vm = SearchViewModel(fakeRepo);

        await vm.searchUsers('   ');

        expect(vm.userResults, isEmpty);
      },
    );

    test('searchUsers populates userResults from repo', () async {
      fakeRepo.searchResult = [
        UserModel(
          uid: '1',
          username: 'rupesh',
          email: 'rupesh@example.com',
          photoUrl: '',
        ),
      ];
      final vm = SearchViewModel(fakeRepo);

      await vm.searchUsers('rup');

      expect(vm.userResults.length, 1);
      expect(vm.userResults.first.username, 'rupesh');
      expect(vm.isSearching, isFalse);
    });

    test('clearSearch resets query and results', () async {
      fakeRepo.searchResult = [
        UserModel(
          uid: '1',
          username: 'x',
          email: 'x@example.com',
          photoUrl: '',
        ),
      ];
      final vm = SearchViewModel(fakeRepo);
      await vm.searchUsers('x');

      vm.clearSearch();

      expect(vm.query, '');
      expect(vm.userResults, isEmpty);
    });
  });
}
