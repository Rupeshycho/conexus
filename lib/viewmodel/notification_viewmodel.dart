// lib/viewmodel/notification_viewmodel.dart
import 'dart:async';

import 'package:conexus/model/notification_model.dart';
import 'package:flutter/foundation.dart';

import '../repo/notification_repo.dart';

class NotificationViewModel extends ChangeNotifier {
  final NotificationRepo _notificationRepo;

  NotificationViewModel(this._notificationRepo);

  StreamSubscription<List<NotificationModel>>? _subscription;
  String? _userId;

  List<NotificationModel> _notifications = [];
  List<NotificationModel> get notifications => _notifications;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  void listenToNotifications(String userId) {
    if (userId.isEmpty || _userId == userId) return;
    _userId = userId;

    _isLoading = true;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _notificationRepo.getNotifications(userId).listen((
      notifications,
    ) {
      _notifications = notifications;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> markAsRead(String notificationId) async {
    await _notificationRepo.markAsRead(notificationId);
  }

  Future<void> markAllAsRead() async {
    if (_userId == null) return;

    final unreadIds = _notifications
        .where((n) => !n.isRead)
        .map((n) => n.notificationId)
        .toList();

    if (unreadIds.isEmpty) return;

    await _notificationRepo.markAllAsRead(_userId!, unreadIds);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
