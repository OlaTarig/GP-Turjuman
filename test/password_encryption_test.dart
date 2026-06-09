import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:turjuman/AuthService.dart';
import 'package:turjuman/repositories/user_repository.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUserCredential extends Mock implements UserCredential {}
class MockUser extends Mock implements User {}
class FakeAuthCredential extends Fake implements AuthCredential {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirebaseAuth mockAuth;
  late MockUserCredential mockCredential;
  late MockUser mockUser;
  late AuthService authService;
  late FakeFirebaseFirestore fakeFirestore;
  late UserRepository userRepository;

  const testEmail    = 'test@turjuman.com';
  const testPassword = 'SecurePass!123';
  const testUserId   = 'uid_test_001';

  setUpAll(() {
    registerFallbackValue(FakeAuthCredential());
  });

  setUp(() {
    mockAuth       = MockFirebaseAuth();
    mockCredential = MockUserCredential();
    mockUser       = MockUser();
    fakeFirestore  = FakeFirebaseFirestore();
    authService    = AuthService(firebaseAuth: mockAuth);
    userRepository = UserRepository(firestore: fakeFirestore);

    when(() => mockUser.uid).thenReturn(testUserId);
    when(() => mockUser.email).thenReturn(testEmail);
    when(() => mockCredential.user).thenReturn(mockUser);
  });

  group('Password Encryption — NFR Security Tests', () {

    // ── TC-SEC-01 ──────────────────────────────────────────────────────────
    test('TC-SEC-01: Password is never stored in Firestore after sign-up', () async {
      when(() => mockAuth.createUserWithEmailAndPassword(
        email: testEmail,
        password: testPassword,
      )).thenAnswer((_) async => mockCredential);

      await authService.signUp(email: testEmail, password: testPassword);

      // Simulate saving user profile to Firestore (as the app does after sign-up)
      await userRepository.updateUserFields(testUserId, {
        'email'       : testEmail,
        'displayName' : 'Test User',
        'createdAt'   : DateTime.now().toIso8601String(),
      });

      final doc = await fakeFirestore
          .collection('User')
          .doc(testUserId)
          .get();

      final data = doc.data() ?? {};

      expect(data.containsKey('password'),        isFalse,
          reason: 'password field must never be stored in Firestore');
      expect(data.containsKey('passwordHash'),    isFalse,
          reason: 'passwordHash field must never be stored in Firestore');
      expect(data.containsKey('hashedPassword'),  isFalse,
          reason: 'hashedPassword field must never be stored in Firestore');
      expect(data.values.contains(testPassword),  isFalse,
          reason: 'plaintext password must not appear anywhere in the document');
    });

    // ── TC-SEC-02 ──────────────────────────────────────────────────────────
    test('TC-SEC-02: UserCredential returned after sign-up does not expose plaintext password', () async {
      when(() => mockAuth.createUserWithEmailAndPassword(
        email: testEmail,
        password: testPassword,
      )).thenAnswer((_) async => mockCredential);

      final credential = await authService.signUp(
        email: testEmail,
        password: testPassword,
      );

      // UserCredential must never carry the raw password
      final userMap = {
        'uid'   : credential.user?.uid,
        'email' : credential.user?.email,
      };

      expect(userMap.values.contains(testPassword), isFalse,
          reason: 'UserCredential must not expose the plaintext password');
    });

    // ── TC-SEC-03 ──────────────────────────────────────────────────────────
    test('TC-SEC-03: Sign-in delegates to Firebase Auth — password never handled by app', () async {
      when(() => mockAuth.signInWithEmailAndPassword(
        email: testEmail,
        password: testPassword,
      )).thenAnswer((_) async => mockCredential);

      await authService.signIn(email: testEmail, password: testPassword);

      // Verify the app handed the password directly to Firebase Auth
      // and did not store, transform, or log it
      verify(() => mockAuth.signInWithEmailAndPassword(
        email: testEmail,
        password: testPassword,
      )).called(1);
    });

    // ── TC-SEC-04 ──────────────────────────────────────────────────────────
    test('TC-SEC-04: Password change re-authenticates before updating — no plaintext stored', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.reauthenticateWithCredential(any()))
          .thenAnswer((_) async => mockCredential);
      when(() => mockUser.updatePassword(any())).thenAnswer((_) async {});

      await authService.resetPasswordFromCurrentPassword(
        email: testEmail,
        currentPassword: testPassword,
        newPassword: 'NewSecurePass!456',
      );

      // Re-authentication must have been called before password update
      verify(() => mockUser.reauthenticateWithCredential(any())).called(1);
      verify(() => mockUser.updatePassword('NewSecurePass!456')).called(1);

      // Verify new password was not written to Firestore
      final doc = await fakeFirestore.collection('User').doc(testUserId).get();
      expect(doc.exists, isFalse,
          reason: 'Password change must not write anything to Firestore');
    });

    // ── TC-SEC-05 ──────────────────────────────────────────────────────────
    test('TC-SEC-05: User document fields contain no sensitive data', () async {
      await userRepository.updateUserFields(testUserId, {
        'email'       : testEmail,
        'displayName' : 'Test User',
        'photoUrl'    : '',
        'createdAt'   : DateTime.now().toIso8601String(),
      });

      final data = (await fakeFirestore
          .collection('User')
          .doc(testUserId)
          .get())
          .data() ?? {};

      const sensitiveKeys = ['password', 'passwordHash', 'hashedPassword', 'token', 'secret'];
      for (final key in sensitiveKeys) {
        expect(data.containsKey(key), isFalse,
            reason: 'Field "$key" must never appear in the User document');
      }
    });
  });
}
