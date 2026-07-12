// test/viewmodel/notification_viewmodel_test.dart
import 'dart:async';

import 'package:conexus/models/notification_model.dart';
import 'package:conexus/repo/notification_repo.dart';
import 'package:conexus/viewmodel/notification_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeNotificationRepo implements NotificationRepo {
  final _controller = StreamController<List<NotificationModel>>.broadcast();
  String? lastMarkedReadId;

  void emit(List<NotificationModel> notifications) =>
      _controller.add(notifications);

  @override
  Stream<List<NotificationModel>> getNotifications(String userId) =>
      _controller.stream;

  @override
  Future<void> createNotification({
    required NotificationType type,
    required String postId,
    required String fromUserId,
    required String fromUsername,
    required String fromUserPhotoUrl,
    required String toUserId,
  }) async {}

  @override
  Future<void> markAsRead(String notificationId) async {
    lastMarkedReadId = notificationId;
  }
}

NotificationModel _sampleNotification() => NotificationModel(
  notificationId: 'n1',
  type: NotificationType.comment,
  postId: 'p1',
  fromUserId: 'u1',
  fromUsername: 'jack',
  fromUserPhotoUrl: '',
  toUserId: 'u2',
  createdAt: DateTime.now(),
);

void main() {
  group('NotificationViewModel', () {
    test('listenToNotifications populates list when stream emits', () async {
      final fakeRepo = FakeNotificationRepo();
      final vm = NotificationViewModel(fakeRepo);

      vm.listenToNotifications('u2');
      fakeRepo.emit([_sampleNotification()]);
      await Future.delayed(Duration.zero);

      expect(vm.notifications.length, 1);
      expect(vm.isLoading, isFalse);
    });

    test('markAsRead delegates to the repo with correct id', () async {
      final fakeRepo = FakeNotificationRepo();
      final vm = NotificationViewModel(fakeRepo);

      await vm.markAsRead('n1');

      expect(fakeRepo.lastMarkedReadId, 'n1');
    });
  });
}
