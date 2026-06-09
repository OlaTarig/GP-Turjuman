import '../repositories/user_repository.dart';

class ProfileController {
  final UserRepository _repo;

  ProfileController({UserRepository? repo}) : _repo = repo ?? UserRepository();

  Future<void> updateProfile({
    required String userId,
    required String name,
    String? photoUrl,
  }) async {
    final data = <String, dynamic>{
      'name': name.trim(),
    };

    if (photoUrl != null) {
      data['photoUrl'] = photoUrl;
    }

    await _repo.updateUserFields(userId, data);
  }
}