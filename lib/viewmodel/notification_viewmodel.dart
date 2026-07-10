// lib/viewmodel/notification_viewmodel.dart
import 'package:flutter/foundation.dart';

import '../models/notification_model.dart';
import '../repo/notification_repo.dart';

class NotificationViewModel extends ChangeNotifier {
  final NotificationRepo _notificationRepo;

  NotificationViewModel(this._notificationRepo);

  List<NotificationModel> _notifications = [];
  List<NotificationModel> get notifications => _notifications;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  void listenToNotifications(String userId) {
    _isLoading = true;
    notifyListeners();

    _notificationRepo.getNotifications(userId).listen((notifications) {
      _notifications = notifications;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> markAsRead(String notificationId) async {
    await _notificationRepo.markAsRead(notificationId);
  }
}
