import 'package:flutter/material.dart';
import '../models/user_model.dart';

class UserProvider with ChangeNotifier {
  UserModel? _user;
  int _credits = 0;

  UserModel? get user => _user;
  int get credits => _credits;

  void setUser(Map<String, dynamic> userData) {
    _user = UserModel.fromJson(userData);
    _credits = _user?.credits ?? 0;
    notifyListeners();
  }

  void updateCredits(int newCredits) {
    _credits = newCredits;
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    _credits = 0;
    notifyListeners();
  }
}
