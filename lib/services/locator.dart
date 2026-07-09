// lib/services/locator.dart
import 'package:get_it/get_it.dart';
import '../repo/post_repo.dart';
import '../repo/post_repo_impl.dart';
import '../repo/user_repo.dart';
import '../repo/user_repo_impl.dart';
import '../viewmodel/home_feed_viewmodel.dart';
import '../viewmodel/suggested_users_viewmodel.dart';

final locator = GetIt.instance;

void setupLocator() {
  locator.registerLazySingleton<PostRepo>(() => PostRepoImpl());
  locator.registerLazySingleton<UserRepo>(() => UserRepoImpl());

  locator.registerFactory<HomeFeedViewModel>(
        () => HomeFeedViewModel(locator<PostRepo>()),
  );

  locator.registerFactory<SuggestedUsersViewModel>(
        () => SuggestedUsersViewModel(locator<UserRepo>()),
  );
}