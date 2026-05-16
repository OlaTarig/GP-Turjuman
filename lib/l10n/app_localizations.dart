import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome To Turjuman App'**
  String get welcomeTitle;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back! Login to your account'**
  String get loginSubtitle;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @signUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account to continue!'**
  String get signUpSubtitle;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'example@mail.com'**
  String get emailHint;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @fullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get fullNameHint;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get dontHaveAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// No description provided for @resetPasswordDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we\'ll send you a link to reset your password.'**
  String get resetPasswordDesc;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// No description provided for @errEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get errEnterEmail;

  /// No description provided for @errEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get errEnterPassword;

  /// No description provided for @errEnterEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address'**
  String get errEnterEmailAddress;

  /// No description provided for @errOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again.'**
  String get errOccurred;

  /// No description provided for @errInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect. Please check your credentials.'**
  String get errInvalidCredentials;

  /// No description provided for @errInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'The email address format is invalid.'**
  String get errInvalidEmail;

  /// No description provided for @errNoInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please check your network.'**
  String get errNoInternet;

  /// No description provided for @errTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Please try again later.'**
  String get errTooManyRequests;

  /// No description provided for @errWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak. Use at least 9 characters with mix of letters and numbers.'**
  String get errWeakPassword;

  /// No description provided for @errEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'An account already exists with this email address.'**
  String get errEmailInUse;

  /// No description provided for @errOperationNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Email/password accounts are not enabled. Please contact support.'**
  String get errOperationNotAllowed;

  /// No description provided for @errRegistrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed. Please try again later.'**
  String get errRegistrationFailed;

  /// No description provided for @errUnexpected.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get errUnexpected;

  /// No description provided for @errNoAccountFound.
  ///
  /// In en, this message translates to:
  /// **'No account found with this email address.'**
  String get errNoAccountFound;

  /// No description provided for @loginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Login successful! Welcome back'**
  String get loginSuccess;

  /// No description provided for @accountCreated.
  ///
  /// In en, this message translates to:
  /// **'Account created successfully! Please verify your email'**
  String get accountCreated;

  /// No description provided for @passwordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent! Check your inbox'**
  String get passwordResetSent;

  /// No description provided for @valEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get valEnterName;

  /// No description provided for @valNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get valNameTooShort;

  /// No description provided for @valNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Name cannot exceed 20 characters'**
  String get valNameTooLong;

  /// No description provided for @valNameStartsNumber.
  ///
  /// In en, this message translates to:
  /// **'Name cannot start with a number'**
  String get valNameStartsNumber;

  /// No description provided for @valEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get valEnterEmail;

  /// No description provided for @valEmailSpace.
  ///
  /// In en, this message translates to:
  /// **'Email cannot contain spaces'**
  String get valEmailSpace;

  /// No description provided for @valEmailDots.
  ///
  /// In en, this message translates to:
  /// **'Email cannot contain consecutive dots'**
  String get valEmailDots;

  /// No description provided for @valInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get valInvalidEmail;

  /// No description provided for @valInvalidDomain.
  ///
  /// In en, this message translates to:
  /// **'Invalid email domain'**
  String get valInvalidDomain;

  /// No description provided for @valEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get valEnterPassword;

  /// No description provided for @valPasswordShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 9 characters'**
  String get valPasswordShort;

  /// No description provided for @valPasswordLong.
  ///
  /// In en, this message translates to:
  /// **'Password cannot exceed 20 characters'**
  String get valPasswordLong;

  /// No description provided for @valPasswordLetters.
  ///
  /// In en, this message translates to:
  /// **'Password must contain letters'**
  String get valPasswordLetters;

  /// No description provided for @valPasswordNumbers.
  ///
  /// In en, this message translates to:
  /// **'Password must contain numbers'**
  String get valPasswordNumbers;

  /// No description provided for @verifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Email'**
  String get verifyEmail;

  /// No description provided for @verificationSentTo.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a verification link to:'**
  String get verificationSentTo;

  /// No description provided for @verificationInstructions.
  ///
  /// In en, this message translates to:
  /// **'Click the link in the email to verify your account.\nThis page will automatically update once verified.'**
  String get verificationInstructions;

  /// No description provided for @checkNow.
  ///
  /// In en, this message translates to:
  /// **'Check Now'**
  String get checkNow;

  /// No description provided for @resendVerification.
  ///
  /// In en, this message translates to:
  /// **'Resend Verification Email'**
  String get resendVerification;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String resendIn(int seconds);

  /// No description provided for @emailVerifiedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Email verified successfully!'**
  String get emailVerifiedSuccess;

  /// No description provided for @emailNotVerifiedYet.
  ///
  /// In en, this message translates to:
  /// **'Email not verified yet. Please check your inbox.'**
  String get emailNotVerifiedYet;

  /// No description provided for @verificationEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent! Check your inbox.'**
  String get verificationEmailSent;

  /// No description provided for @onboarding1Title.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Turjuman'**
  String get onboarding1Title;

  /// No description provided for @onboarding1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your real-time Arabic Sign Language translator, bridging communication for the deaf and hard-of-hearing community.'**
  String get onboarding1Subtitle;

  /// No description provided for @onboarding2Title.
  ///
  /// In en, this message translates to:
  /// **'Live Sign Recognition'**
  String get onboarding2Title;

  /// No description provided for @onboarding2Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Point your camera at sign language gestures and get instant Arabic text translations in real time.'**
  String get onboarding2Subtitle;

  /// No description provided for @onboarding3Title.
  ///
  /// In en, this message translates to:
  /// **'Accessible Meetings'**
  String get onboarding3Title;

  /// No description provided for @onboarding3Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Join video meetings with live captions and transcriptions so everyone can participate fully.'**
  String get onboarding3Subtitle;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back,'**
  String get welcomeBack;

  /// No description provided for @startMeeting.
  ///
  /// In en, this message translates to:
  /// **'Start a Meeting'**
  String get startMeeting;

  /// No description provided for @joinMeeting.
  ///
  /// In en, this message translates to:
  /// **'Join Meeting'**
  String get joinMeeting;

  /// No description provided for @connectInstantly.
  ///
  /// In en, this message translates to:
  /// **'Connect with your team instantly'**
  String get connectInstantly;

  /// No description provided for @startNow.
  ///
  /// In en, this message translates to:
  /// **'Start Now'**
  String get startNow;

  /// No description provided for @meetingNotFound.
  ///
  /// In en, this message translates to:
  /// **'Meeting not found'**
  String get meetingNotFound;

  /// No description provided for @meetingAlreadyEnded.
  ///
  /// In en, this message translates to:
  /// **'Meeting already ended'**
  String get meetingAlreadyEnded;

  /// No description provided for @enterMeetingId.
  ///
  /// In en, this message translates to:
  /// **'Enter Meeting ID'**
  String get enterMeetingId;

  /// No description provided for @inMeeting.
  ///
  /// In en, this message translates to:
  /// **'In meeting: {title}'**
  String inMeeting(String title);

  /// No description provided for @returnToMeeting.
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get returnToMeeting;

  /// No description provided for @couldNotCreateMeeting.
  ///
  /// In en, this message translates to:
  /// **'Could not create meeting. Check your connection and try again.'**
  String get couldNotCreateMeeting;

  /// No description provided for @pleaseSignIn.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to start a meeting.'**
  String get pleaseSignIn;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get appLanguage;

  /// No description provided for @meetingAccess.
  ///
  /// In en, this message translates to:
  /// **'Meeting Access'**
  String get meetingAccess;

  /// No description provided for @microphone.
  ///
  /// In en, this message translates to:
  /// **'Microphone (App)'**
  String get microphone;

  /// No description provided for @micSubtitle.
  ///
  /// In en, this message translates to:
  /// **'OFF disables mic in app. ON requests system permission.'**
  String get micSubtitle;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera (App)'**
  String get camera;

  /// No description provided for @cameraSubtitle.
  ///
  /// In en, this message translates to:
  /// **'OFF disables camera in app. ON requests system permission.'**
  String get cameraSubtitle;

  /// No description provided for @privacySecurity.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Security'**
  String get privacySecurity;

  /// No description provided for @secureScreen.
  ///
  /// In en, this message translates to:
  /// **'Secure Screen'**
  String get secureScreen;

  /// No description provided for @secureScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Prevents screenshots and screen recording during meetings.'**
  String get secureScreenSubtitle;

  /// No description provided for @micPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission needed'**
  String get micPermissionNeeded;

  /// No description provided for @cameraPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Camera permission needed'**
  String get cameraPermissionNeeded;

  /// No description provided for @permissionNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Permission was not granted. If it is permanently denied, enable it from system settings.'**
  String get permissionNotGranted;

  /// No description provided for @openSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'Open system settings'**
  String get openSystemSettings;

  /// No description provided for @systemSettings.
  ///
  /// In en, this message translates to:
  /// **'System settings'**
  String get systemSettings;

  /// No description provided for @logoutFailed.
  ///
  /// In en, this message translates to:
  /// **'Logout failed: {error}'**
  String logoutFailed(String error);

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// No description provided for @nameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Name is too short'**
  String get nameTooShort;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// No description provided for @errUserNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Error: user not logged in'**
  String get errUserNotLoggedIn;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @homeTab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTab;

  /// No description provided for @filesTab.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get filesTab;

  /// No description provided for @settingsTab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTab;

  /// No description provided for @transcripts.
  ///
  /// In en, this message translates to:
  /// **'Transcripts'**
  String get transcripts;

  /// No description provided for @transcriptsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your recorded meeting transcripts'**
  String get transcriptsSubtitle;

  /// No description provided for @notLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get notLoggedIn;

  /// No description provided for @meetingTranscript.
  ///
  /// In en, this message translates to:
  /// **'Meeting Transcript'**
  String get meetingTranscript;

  /// No description provided for @noTranscriptAvailable.
  ///
  /// In en, this message translates to:
  /// **'No transcript available'**
  String get noTranscriptAvailable;

  /// No description provided for @noTranscriptsYet.
  ///
  /// In en, this message translates to:
  /// **'No Transcripts Yet'**
  String get noTranscriptsYet;

  /// No description provided for @noTranscriptsDesc.
  ///
  /// In en, this message translates to:
  /// **'Enable the CC button during a meeting\nto record speech. Transcripts appear here.'**
  String get noTranscriptsDesc;

  /// No description provided for @deleteTranscript.
  ///
  /// In en, this message translates to:
  /// **'Delete Transcript'**
  String get deleteTranscript;

  /// No description provided for @deleteTranscriptConfirm.
  ///
  /// In en, this message translates to:
  /// **'This transcript will be permanently deleted for all participants. Continue?'**
  String get deleteTranscriptConfirm;

  /// No description provided for @failedToDelete.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete: {error}'**
  String failedToDelete(String error);

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get inProgress;

  /// No description provided for @downloadPdf.
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get downloadPdf;

  /// No description provided for @generating.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get generating;

  /// No description provided for @unknownSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Unknown Speaker'**
  String get unknownSpeaker;

  /// No description provided for @youSuffix.
  ///
  /// In en, this message translates to:
  /// **'{name} (You)'**
  String youSuffix(String name);

  /// No description provided for @transcriptMeta.
  ///
  /// In en, this message translates to:
  /// **'{date}  •  {entryCount} sentences  •  {speakerCount} speakers'**
  String transcriptMeta(String date, int entryCount, int speakerCount);

  /// No description provided for @meetingPrefix.
  ///
  /// In en, this message translates to:
  /// **'Meeting {id}...'**
  String meetingPrefix(String id);

  /// No description provided for @statSentences.
  ///
  /// In en, this message translates to:
  /// **'{count} sentences'**
  String statSentences(int count);

  /// No description provided for @statSpeakers.
  ///
  /// In en, this message translates to:
  /// **'{count} speakers'**
  String statSpeakers(int count);

  /// No description provided for @joiningMeeting.
  ///
  /// In en, this message translates to:
  /// **'Joining Meeting...'**
  String get joiningMeeting;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait while we connect you'**
  String get pleaseWait;

  /// No description provided for @unableToJoin.
  ///
  /// In en, this message translates to:
  /// **'Unable to Join'**
  String get unableToJoin;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection and tap Retry.'**
  String get networkError;

  /// No description provided for @needLoginFirst.
  ///
  /// In en, this message translates to:
  /// **'You need to log in first to join a meeting.'**
  String get needLoginFirst;

  /// No description provided for @meetingNotFoundLink.
  ///
  /// In en, this message translates to:
  /// **'Meeting not found. The link may be invalid or expired.'**
  String get meetingNotFoundLink;

  /// No description provided for @meetingHasEnded.
  ///
  /// In en, this message translates to:
  /// **'This meeting has already ended.'**
  String get meetingHasEnded;

  /// No description provided for @meetingFull.
  ///
  /// In en, this message translates to:
  /// **'This meeting is full. Maximum capacity reached.'**
  String get meetingFull;

  /// No description provided for @userProfileNotFound.
  ///
  /// In en, this message translates to:
  /// **'User profile not found. Please complete your profile.'**
  String get userProfileNotFound;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred.'**
  String get unknownError;

  /// No description provided for @camMicPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Camera/Microphone permission is required'**
  String get camMicPermissionRequired;

  /// No description provided for @meetingEnded.
  ///
  /// In en, this message translates to:
  /// **'Meeting ended'**
  String get meetingEnded;

  /// No description provided for @meetingEndedByHost.
  ///
  /// In en, this message translates to:
  /// **'The host has ended the meeting.'**
  String get meetingEndedByHost;

  /// No description provided for @accessRequired.
  ///
  /// In en, this message translates to:
  /// **'Access Required'**
  String get accessRequired;

  /// No description provided for @micAndCameraDisabled.
  ///
  /// In en, this message translates to:
  /// **'Microphone and Camera access are disabled in your settings. Please enable them to use meeting features.'**
  String get micAndCameraDisabled;

  /// No description provided for @micAccessDisabled.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is disabled in your settings. Please enable it to use audio.'**
  String get micAccessDisabled;

  /// No description provided for @cameraAccessDisabled.
  ///
  /// In en, this message translates to:
  /// **'Camera access is disabled in your settings. Please enable it to use video.'**
  String get cameraAccessDisabled;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @micDisabledInSettings.
  ///
  /// In en, this message translates to:
  /// **'Microphone is disabled in settings'**
  String get micDisabledInSettings;

  /// No description provided for @raiseHandForPermission.
  ///
  /// In en, this message translates to:
  /// **'Raise hand to request host permission'**
  String get raiseHandForPermission;

  /// No description provided for @micPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required'**
  String get micPermissionRequired;

  /// No description provided for @cameraDisabledInSettings.
  ///
  /// In en, this message translates to:
  /// **'Camera is disabled in settings'**
  String get cameraDisabledInSettings;

  /// No description provided for @cameraPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required'**
  String get cameraPermissionRequired;

  /// No description provided for @turnOnCameraFirst.
  ///
  /// In en, this message translates to:
  /// **'Turn on camera first'**
  String get turnOnCameraFirst;

  /// No description provided for @turnOnCameraForSign.
  ///
  /// In en, this message translates to:
  /// **'Turn on your camera first — sign recognition needs camera access'**
  String get turnOnCameraForSign;

  /// No description provided for @signAvatarEnabled.
  ///
  /// In en, this message translates to:
  /// **'Sign avatar enabled — captions will be translated to sign language'**
  String get signAvatarEnabled;

  /// No description provided for @signAvatarDisabled.
  ///
  /// In en, this message translates to:
  /// **'Sign avatar disabled'**
  String get signAvatarDisabled;

  /// No description provided for @handLowered.
  ///
  /// In en, this message translates to:
  /// **'Hand lowered'**
  String get handLowered;

  /// No description provided for @handRaised.
  ///
  /// In en, this message translates to:
  /// **'Hand raised'**
  String get handRaised;

  /// No description provided for @screenShareStopped.
  ///
  /// In en, this message translates to:
  /// **'Screen sharing stopped'**
  String get screenShareStopped;

  /// No description provided for @notAllowedToShare.
  ///
  /// In en, this message translates to:
  /// **'You are not allowed to share screen.\nAsk the host to grant permission.'**
  String get notAllowedToShare;

  /// No description provided for @screenShareLabel.
  ///
  /// In en, this message translates to:
  /// **'Screen Share'**
  String get screenShareLabel;

  /// No description provided for @shareMyScreen.
  ///
  /// In en, this message translates to:
  /// **'Share My Screen'**
  String get shareMyScreen;

  /// No description provided for @broadcastDesc.
  ///
  /// In en, this message translates to:
  /// **'Broadcast your screen to all participants'**
  String get broadcastDesc;

  /// No description provided for @disallowParticipantsShare.
  ///
  /// In en, this message translates to:
  /// **'Disallow Participants to Share'**
  String get disallowParticipantsShare;

  /// No description provided for @allowAllParticipantsShare.
  ///
  /// In en, this message translates to:
  /// **'Allow All Participants to Share'**
  String get allowAllParticipantsShare;

  /// No description provided for @participantsCanShare.
  ///
  /// In en, this message translates to:
  /// **'Participants can currently share their screen'**
  String get participantsCanShare;

  /// No description provided for @letParticipantsShare.
  ///
  /// In en, this message translates to:
  /// **'Let all participants share their screen'**
  String get letParticipantsShare;

  /// No description provided for @allParticipantsCanShare.
  ///
  /// In en, this message translates to:
  /// **'All participants can now share their screen'**
  String get allParticipantsCanShare;

  /// No description provided for @screenSharingDisabled.
  ///
  /// In en, this message translates to:
  /// **'Screen sharing disabled for participants'**
  String get screenSharingDisabled;

  /// No description provided for @failedToUpdatePermission.
  ///
  /// In en, this message translates to:
  /// **'Failed to update permission'**
  String get failedToUpdatePermission;

  /// No description provided for @startingScreenShare.
  ///
  /// In en, this message translates to:
  /// **'Starting screen share...'**
  String get startingScreenShare;

  /// No description provided for @screenSharingStarted.
  ///
  /// In en, this message translates to:
  /// **'Screen sharing started'**
  String get screenSharingStarted;

  /// No description provided for @failedToStartScreenShare.
  ///
  /// In en, this message translates to:
  /// **'Failed to start screen share'**
  String get failedToStartScreenShare;

  /// No description provided for @invitationCopied.
  ///
  /// In en, this message translates to:
  /// **'Invitation link copied to clipboard!'**
  String get invitationCopied;

  /// No description provided for @sendEmailInvitation.
  ///
  /// In en, this message translates to:
  /// **'Send Email Invitation'**
  String get sendEmailInvitation;

  /// No description provided for @enterParticipantEmailDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter the participant\'s email address. An invitation will be sent to them automatically.'**
  String get enterParticipantEmailDesc;

  /// No description provided for @enterEmailValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter an email address'**
  String get enterEmailValidation;

  /// No description provided for @enterValidEmailValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get enterValidEmailValidation;

  /// No description provided for @inviteParticipant.
  ///
  /// In en, this message translates to:
  /// **'Invite Participant'**
  String get inviteParticipant;

  /// No description provided for @copyInvitationLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Invitation Link'**
  String get copyInvitationLink;

  /// No description provided for @copyLinkManually.
  ///
  /// In en, this message translates to:
  /// **'Copy the link and share it manually'**
  String get copyLinkManually;

  /// No description provided for @sendInvitationByEmail.
  ///
  /// In en, this message translates to:
  /// **'Send Invitation by Email'**
  String get sendInvitationByEmail;

  /// No description provided for @sendToInbox.
  ///
  /// In en, this message translates to:
  /// **'Send the invitation directly to their inbox'**
  String get sendToInbox;

  /// No description provided for @invitationSentTo.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent to {email}'**
  String invitationSentTo(String email);

  /// No description provided for @failedToSendInvitation.
  ///
  /// In en, this message translates to:
  /// **'Failed to send invitation. Please try again.'**
  String get failedToSendInvitation;

  /// No description provided for @endMeeting.
  ///
  /// In en, this message translates to:
  /// **'End Meeting'**
  String get endMeeting;

  /// No description provided for @endMeetingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to end the meeting for everyone?'**
  String get endMeetingConfirm;

  /// No description provided for @leaveMeeting.
  ///
  /// In en, this message translates to:
  /// **'Leave Meeting'**
  String get leaveMeeting;

  /// No description provided for @leaveMeetingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave meeting?'**
  String get leaveMeetingConfirm;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @sharingChip.
  ///
  /// In en, this message translates to:
  /// **'Sharing'**
  String get sharingChip;

  /// No description provided for @youAreSharing.
  ///
  /// In en, this message translates to:
  /// **'You are sharing'**
  String get youAreSharing;

  /// No description provided for @screenShareBadge.
  ///
  /// In en, this message translates to:
  /// **'Screen share'**
  String get screenShareBadge;

  /// No description provided for @hostSuffix.
  ///
  /// In en, this message translates to:
  /// **'{name} (Host)'**
  String hostSuffix(String name);

  /// No description provided for @btnEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get btnEnd;

  /// No description provided for @btnLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get btnLeave;

  /// No description provided for @btnMic.
  ///
  /// In en, this message translates to:
  /// **'Mic'**
  String get btnMic;

  /// No description provided for @btnCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get btnCamera;

  /// No description provided for @btnFlip.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get btnFlip;

  /// No description provided for @btnHand.
  ///
  /// In en, this message translates to:
  /// **'Hand'**
  String get btnHand;

  /// No description provided for @btnCC.
  ///
  /// In en, this message translates to:
  /// **'CC'**
  String get btnCC;

  /// No description provided for @btnSign.
  ///
  /// In en, this message translates to:
  /// **'Sign'**
  String get btnSign;

  /// No description provided for @btnAvatar.
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get btnAvatar;

  /// No description provided for @btnStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get btnStop;

  /// No description provided for @btnShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get btnShare;

  /// No description provided for @participants.
  ///
  /// In en, this message translates to:
  /// **'Participants ({count})'**
  String participants(int count);

  /// No description provided for @invite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get invite;

  /// No description provided for @screenSharingOnForAll.
  ///
  /// In en, this message translates to:
  /// **'Screen sharing is ON for all participants'**
  String get screenSharingOnForAll;

  /// No description provided for @screenSharingOffForAll.
  ///
  /// In en, this message translates to:
  /// **'Screen sharing is OFF for participants'**
  String get screenSharingOffForAll;

  /// No description provided for @raisedHands.
  ///
  /// In en, this message translates to:
  /// **'Raised Hands'**
  String get raisedHands;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @roleHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get roleHost;

  /// No description provided for @roleParticipant.
  ///
  /// In en, this message translates to:
  /// **'Participant'**
  String get roleParticipant;

  /// No description provided for @meetingId.
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String meetingId(String id);

  /// No description provided for @analyzingSign.
  ///
  /// In en, this message translates to:
  /// **'Analyzing sign…'**
  String get analyzingSign;

  /// No description provided for @handsNotDetected.
  ///
  /// In en, this message translates to:
  /// **'Hands not detected — move into frame'**
  String get handsNotDetected;

  /// No description provided for @signRecognition.
  ///
  /// In en, this message translates to:
  /// **'Sign Recognition'**
  String get signRecognition;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
