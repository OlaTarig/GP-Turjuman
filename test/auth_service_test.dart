import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:turjuman/AuthService.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUserCredential extends Mock implements UserCredential {}
class MockUser extends Mock implements User {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirebaseAuth mockAuth;
  late AuthService authService;
  late MockUserCredential mockCredential;
  late MockUser mockUser;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    authService = AuthService(firebaseAuth: mockAuth);
    mockCredential = MockUserCredential();
    mockUser = MockUser();
  });

  test('TC08 – Sign In – succeeds with valid email and password', () async {
    when(() => mockAuth.signInWithEmailAndPassword(
      email: 'test@gmail.com',
      password: 'Password!123',
    )).thenAnswer((_) async => mockCredential);

    when(() => mockCredential.user).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('12345');

    final result = await authService.signIn(
      email: 'test@gmail.com',
      password: 'Password!123',
    );

    expect(result.user, isNotNull);
    expect(result.user!.uid, '12345');
  });

  test('TC09 – Sign In – fails with empty email', () async {
    when(() => mockAuth.signInWithEmailAndPassword(
      email: '',
      password: 'Password!123',
    )).thenThrow(FirebaseAuthException(code: 'invalid-email'));

    expect(
          () => authService.signIn(email: '', password: 'Password!123'),
      throwsA(isA<FirebaseAuthException>()),
    );
  });

  test('TC10 – Sign In – fails with invalid email format', () async {
    when(() => mockAuth.signInWithEmailAndPassword(
      email: 'wrong-email',
      password: 'Password!123',
    )).thenThrow(FirebaseAuthException(code: 'invalid-email'));

    expect(
          () => authService.signIn(
        email: 'wrong-email',
        password: 'Password!123',
      ),
      throwsA(predicate(
            (e) => e is FirebaseAuthException && e.code == 'invalid-email',
      )),
    );
  });

  test('TC11 – Sign In – fails when network request fails', () async {
    when(() => mockAuth.signInWithEmailAndPassword(
      email: 'test@gmail.com',
      password: 'Password!123',
    )).thenThrow(FirebaseAuthException(code: 'network-request-failed'));

    expect(
          () => authService.signIn(
        email: 'test@gmail.com',
        password: 'Password!123',
      ),
      throwsA(predicate(
            (e) =>
        e is FirebaseAuthException &&
            e.code == 'network-request-failed',
      )),
    );
  });

  test('TC12 – Sign Out – succeeds and terminates user session', () async {
    when(() => mockAuth.signOut()).thenAnswer((_) async {});

    await authService.signOut();

    verify(() => mockAuth.signOut()).called(1);
  });

}