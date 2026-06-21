import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conexus/model/user_model.dart';
import 'user_repo.dart';


class UserRepoImpl implements UserRepo {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  Future<void> createUser(UserModel user) async {
    await firestore.collection("users").doc(user.uid).set(user.toMap());
  }

  @override
  Future<UserModel> getUser(String uid) async {
    final doc = await firestore.collection("users").doc(uid).get();
    return UserModel.fromMap(doc.data()!);
  }

  @override
  Future<void> updateUser(UserModel user) async {
    await firestore.collection("users").doc(user.uid).update(user.toMap());
  }

  @override
  Future<void> followUser(String myUid, String targetUid) async {
    await firestore.collection("users").doc(myUid).update({
      "following": FieldValue.arrayUnion([targetUid])
    });

    await firestore.collection("users").doc(targetUid).update({
      "followers": FieldValue.arrayUnion([myUid])
    });
  }

  @override
  Future<void> unfollowUser(String myUid, String targetUid) async {
    await firestore.collection("users").doc(myUid).update({
      "following": FieldValue.arrayRemove([targetUid])
    });

    await firestore.collection("users").doc(targetUid).update({
      "followers": FieldValue.arrayRemove([myUid])
    });
  }
}