// lib/services/locator.dart
import 'package:get_it/get_it.dart';

import '../repo/comment_repo.dart';
import '../repo/comment_repo_impl.dart';
import '../repo/notification_repo.dart';
import '../repo/notification_repo_impl.dart';
import '../repo/post_repo.dart';
import '../repo/post_repo_impl.dart';
import '../repo/user_repo.dart';
import '../repo/user_repo_impl.dart';
import '../viewmodel/home_feed_viewmodel.dart';
import '../viewmodel/notification_viewmodel.dart';
import '../viewmodel/search_viewmodel.dart';
import '../viewmodel/suggested_users_viewmodel.dart';

final locator = GetIt.instance;

void setupLocator() {
  // Repos — order matters: NotificationRepo must be registered before CommentRepo
  locator.registerLazySingleton<NotificationRepo>(() => NotificationRepoImpl());

  locator.registerLazySingleton<PostRepo>(() => PostRepoImpl());
  locator.registerLazySingleton<UserRepo>(() => UserRepoImpl());
  locator.registerLazySingleton<CommentRepo>(
    () => CommentRepoImpl(notificationRepo: locator<NotificationRepo>()),
  );

  // ViewModels
  locator.registerFactory<HomeFeedViewModel>(
    () => HomeFeedViewModel(locator<PostRepo>()),
  );
  locator.registerFactory<SuggestedUsersViewModel>(
    () => SuggestedUsersViewModel(locator<UserRepo>()),
  );
  locator.registerFactory<SearchViewModel>(
    () => SearchViewModel(locator<UserRepo>()),
  );
  locator.registerFactory<NotificationViewModel>(
    () => NotificationViewModel(locator<NotificationRepo>()),
  );
}
