// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get welcomeTitle => 'Welcome To Turjuman App';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get loginSubtitle => 'Welcome back! Login to your account';

  @override
  String get signUp => 'Sign Up';

  @override
  String get signUpSubtitle => 'Create an account to continue!';

  @override
  String get email => 'Email';

  @override
  String get emailHint => 'example@mail.com';

  @override
  String get password => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get fullName => 'Full Name';

  @override
  String get fullNameHint => 'Enter your full name';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get dontHaveAccount => 'Don\'t have an account? ';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get send => 'Send';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get retry => 'Retry';

  @override
  String get skip => 'Skip';

  @override
  String get next => 'Next';

  @override
  String get getStarted => 'Get Started';

  @override
  String get resetPassword => 'Reset Password';

  @override
  String get resetPasswordDesc =>
      'Enter your email address and we\'ll send you a link to reset your password.';

  @override
  String get sendResetLink => 'Send Reset Link';

  @override
  String get errEnterEmail => 'Please enter your email';

  @override
  String get errEnterPassword => 'Please enter your password';

  @override
  String get errEnterEmailAddress => 'Please enter your email address';

  @override
  String get errOccurred => 'An error occurred. Please try again.';

  @override
  String get errInvalidCredentials =>
      'Email or password is incorrect. Please check your credentials.';

  @override
  String get errInvalidEmail => 'The email address format is invalid.';

  @override
  String get errNoInternet =>
      'No internet connection. Please check your network.';

  @override
  String get errTooManyRequests =>
      'Too many failed attempts. Please try again later.';

  @override
  String get errWeakPassword =>
      'Password is too weak. Use at least 9 characters with mix of letters and numbers.';

  @override
  String get errEmailInUse =>
      'An account already exists with this email address.';

  @override
  String get errOperationNotAllowed =>
      'Email/password accounts are not enabled. Please contact support.';

  @override
  String get errRegistrationFailed =>
      'Registration failed. Please try again later.';

  @override
  String get errUnexpected => 'An unexpected error occurred. Please try again.';

  @override
  String get errNoAccountFound => 'No account found with this email address.';

  @override
  String get loginSuccess => 'Login successful! Welcome back';

  @override
  String get accountCreated =>
      'Account created successfully! Please verify your email';

  @override
  String get passwordResetSent => 'Password reset email sent! Check your inbox';

  @override
  String get valEnterName => 'Please enter your name';

  @override
  String get valNameTooShort => 'Name must be at least 2 characters';

  @override
  String get valNameTooLong => 'Name cannot exceed 20 characters';

  @override
  String get valNameStartsNumber => 'Name cannot start with a number';

  @override
  String get valEnterEmail => 'Please enter your email';

  @override
  String get valEmailSpace => 'Email cannot contain spaces';

  @override
  String get valEmailDots => 'Email cannot contain consecutive dots';

  @override
  String get valInvalidEmail => 'Please enter a valid email address';

  @override
  String get valInvalidDomain => 'Invalid email domain';

  @override
  String get valEnterPassword => 'Please enter a password';

  @override
  String get valPasswordShort => 'Password must be at least 9 characters';

  @override
  String get valPasswordLong => 'Password cannot exceed 20 characters';

  @override
  String get valPasswordLetters => 'Password must contain letters';

  @override
  String get valPasswordNumbers => 'Password must contain numbers';

  @override
  String get verifyEmail => 'Verify Your Email';

  @override
  String get verificationSentTo => 'We\'ve sent a verification link to:';

  @override
  String get verificationInstructions =>
      'Click the link in the email to verify your account.\nThis page will automatically update once verified.';

  @override
  String get checkNow => 'Check Now';

  @override
  String get resendVerification => 'Resend Verification Email';

  @override
  String resendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get emailVerifiedSuccess => 'Email verified successfully!';

  @override
  String get emailNotVerifiedYet =>
      'Email not verified yet. Please check your inbox.';

  @override
  String get verificationEmailSent =>
      'Verification email sent! Check your inbox.';

  @override
  String get onboarding1Title => 'Welcome to Turjuman';

  @override
  String get onboarding1Subtitle =>
      'Your real-time Arabic Sign Language translator, bridging communication for the deaf and hard-of-hearing community.';

  @override
  String get onboarding2Title => 'Live Sign Recognition';

  @override
  String get onboarding2Subtitle =>
      'Point your camera at sign language gestures and get instant Arabic text translations in real time.';

  @override
  String get onboarding3Title => 'Accessible Meetings';

  @override
  String get onboarding3Subtitle =>
      'Join video meetings with live captions and transcriptions so everyone can participate fully.';

  @override
  String get welcomeBack => 'Welcome back,';

  @override
  String get startMeeting => 'Start a Meeting';

  @override
  String get joinMeeting => 'Join Meeting';

  @override
  String get connectInstantly => 'Connect with your team instantly';

  @override
  String get startNow => 'Start Now';

  @override
  String get meetingNotFound => 'Meeting not found';

  @override
  String get meetingAlreadyEnded => 'Meeting already ended';

  @override
  String get enterMeetingId => 'Enter Meeting ID';

  @override
  String inMeeting(String title) {
    return 'In meeting: $title';
  }

  @override
  String get returnToMeeting => 'Return';

  @override
  String get couldNotCreateMeeting =>
      'Could not create meeting. Check your connection and try again.';

  @override
  String get pleaseSignIn => 'Please sign in to start a meeting.';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get appLanguage => 'App Language';

  @override
  String get meetingAccess => 'Meeting Access';

  @override
  String get microphone => 'Microphone (App)';

  @override
  String get micSubtitle =>
      'OFF disables mic in app. ON requests system permission.';

  @override
  String get camera => 'Camera (App)';

  @override
  String get cameraSubtitle =>
      'OFF disables camera in app. ON requests system permission.';

  @override
  String get privacySecurity => 'Privacy & Security';

  @override
  String get secureScreen => 'Secure Screen';

  @override
  String get secureScreenSubtitle =>
      'Prevents screenshots and screen recording during meetings.';

  @override
  String get micPermissionNeeded => 'Microphone permission needed';

  @override
  String get cameraPermissionNeeded => 'Camera permission needed';

  @override
  String get permissionNotGranted =>
      'Permission was not granted. If it is permanently denied, enable it from system settings.';

  @override
  String get openSystemSettings => 'Open system settings';

  @override
  String get systemSettings => 'System settings';

  @override
  String logoutFailed(String error) {
    return 'Logout failed: $error';
  }

  @override
  String get profile => 'Profile';

  @override
  String get name => 'Name';

  @override
  String get nameRequired => 'Name is required';

  @override
  String get nameTooShort => 'Name is too short';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get errUserNotLoggedIn => 'Error: user not logged in';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get homeTab => 'Home';

  @override
  String get filesTab => 'Files';

  @override
  String get settingsTab => 'Settings';

  @override
  String get transcripts => 'Transcripts';

  @override
  String get transcriptsSubtitle => 'Your recorded meeting transcripts';

  @override
  String get notLoggedIn => 'Not logged in';

  @override
  String get meetingTranscript => 'Meeting Transcript';

  @override
  String get noTranscriptAvailable => 'No transcript available';

  @override
  String get noTranscriptsYet => 'No Transcripts Yet';

  @override
  String get noTranscriptsDesc =>
      'Enable the CC button during a meeting\nto record speech. Transcripts appear here.';

  @override
  String get deleteTranscript => 'Delete Transcript';

  @override
  String get deleteTranscriptConfirm =>
      'This transcript will be permanently deleted for all participants. Continue?';

  @override
  String failedToDelete(String error) {
    return 'Failed to delete: $error';
  }

  @override
  String get completed => 'Completed';

  @override
  String get inProgress => 'In Progress';

  @override
  String get downloadPdf => 'Download PDF';

  @override
  String get generating => 'Generating...';

  @override
  String get unknownSpeaker => 'Unknown Speaker';

  @override
  String youSuffix(String name) {
    return '$name (You)';
  }

  @override
  String transcriptMeta(String date, int entryCount, int speakerCount) {
    return '$date  •  $entryCount sentences  •  $speakerCount speakers';
  }

  @override
  String meetingPrefix(String id) {
    return 'Meeting $id...';
  }

  @override
  String statSentences(int count) {
    return '$count sentences';
  }

  @override
  String statSpeakers(int count) {
    return '$count speakers';
  }

  @override
  String get joiningMeeting => 'Joining Meeting...';

  @override
  String get pleaseWait => 'Please wait while we connect you';

  @override
  String get unableToJoin => 'Unable to Join';

  @override
  String get goBack => 'Go Back';

  @override
  String get networkError =>
      'Network error. Please check your connection and tap Retry.';

  @override
  String get needLoginFirst => 'You need to log in first to join a meeting.';

  @override
  String get meetingNotFoundLink =>
      'Meeting not found. The link may be invalid or expired.';

  @override
  String get meetingHasEnded => 'This meeting has already ended.';

  @override
  String get meetingFull => 'This meeting is full. Maximum capacity reached.';

  @override
  String get userProfileNotFound =>
      'User profile not found. Please complete your profile.';

  @override
  String get unknownError => 'An unknown error occurred.';

  @override
  String get camMicPermissionRequired =>
      'Camera/Microphone permission is required';

  @override
  String get meetingEnded => 'Meeting ended';

  @override
  String get meetingEndedByHost => 'The host has ended the meeting.';

  @override
  String get accessRequired => 'Access Required';

  @override
  String get micAndCameraDisabled =>
      'Microphone and Camera access are disabled in your settings. Please enable them to use meeting features.';

  @override
  String get micAccessDisabled =>
      'Microphone access is disabled in your settings. Please enable it to use audio.';

  @override
  String get cameraAccessDisabled =>
      'Camera access is disabled in your settings. Please enable it to use video.';

  @override
  String get later => 'Later';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get micDisabledInSettings => 'Microphone is disabled in settings';

  @override
  String get raiseHandForPermission => 'Raise hand to request host permission';

  @override
  String get micPermissionRequired => 'Microphone permission is required';

  @override
  String get cameraDisabledInSettings => 'Camera is disabled in settings';

  @override
  String get cameraPermissionRequired => 'Camera permission is required';

  @override
  String get turnOnCameraFirst => 'Turn on camera first';

  @override
  String get turnOnCameraForSign =>
      'Turn on your camera first — sign recognition needs camera access';

  @override
  String get signAvatarEnabled =>
      'Sign avatar enabled — captions will be translated to sign language';

  @override
  String get signAvatarDisabled => 'Sign avatar disabled';

  @override
  String get handLowered => 'Hand lowered';

  @override
  String get handRaised => 'Hand raised';

  @override
  String get screenShareStopped => 'Screen sharing stopped';

  @override
  String get notAllowedToShare =>
      'You are not allowed to share screen.\nAsk the host to grant permission.';

  @override
  String get screenShareLabel => 'Screen Share';

  @override
  String get shareMyScreen => 'Share My Screen';

  @override
  String get broadcastDesc => 'Broadcast your screen to all participants';

  @override
  String get disallowParticipantsShare => 'Disallow Participants to Share';

  @override
  String get allowAllParticipantsShare => 'Allow All Participants to Share';

  @override
  String get participantsCanShare =>
      'Participants can currently share their screen';

  @override
  String get letParticipantsShare => 'Let all participants share their screen';

  @override
  String get allParticipantsCanShare =>
      'All participants can now share their screen';

  @override
  String get screenSharingDisabled =>
      'Screen sharing disabled for participants';

  @override
  String get failedToUpdatePermission => 'Failed to update permission';

  @override
  String get startingScreenShare => 'Starting screen share...';

  @override
  String get screenSharingStarted => 'Screen sharing started';

  @override
  String get failedToStartScreenShare => 'Failed to start screen share';

  @override
  String get invitationCopied => 'Invitation link copied to clipboard!';

  @override
  String get sendEmailInvitation => 'Send Email Invitation';

  @override
  String get enterParticipantEmailDesc =>
      'Enter the participant\'s email address. An invitation will be sent to them automatically.';

  @override
  String get enterEmailValidation => 'Please enter an email address';

  @override
  String get enterValidEmailValidation => 'Please enter a valid email address';

  @override
  String get inviteParticipant => 'Invite Participant';

  @override
  String get copyInvitationLink => 'Copy Invitation Link';

  @override
  String get copyLinkManually => 'Copy the link and share it manually';

  @override
  String get sendInvitationByEmail => 'Send Invitation by Email';

  @override
  String get sendToInbox => 'Send the invitation directly to their inbox';

  @override
  String invitationSentTo(String email) {
    return 'Invitation sent to $email';
  }

  @override
  String get failedToSendInvitation =>
      'Failed to send invitation. Please try again.';

  @override
  String get endMeeting => 'End Meeting';

  @override
  String get endMeetingConfirm =>
      'Are you sure you want to end the meeting for everyone?';

  @override
  String get leaveMeeting => 'Leave Meeting';

  @override
  String get leaveMeetingConfirm => 'Leave meeting?';

  @override
  String get leave => 'Leave';

  @override
  String get sharingChip => 'Sharing';

  @override
  String get youAreSharing => 'You are sharing';

  @override
  String get screenShareBadge => 'Screen share';

  @override
  String hostSuffix(String name) {
    return '$name (Host)';
  }

  @override
  String get btnEnd => 'End';

  @override
  String get btnLeave => 'Leave';

  @override
  String get btnMic => 'Mic';

  @override
  String get btnCamera => 'Camera';

  @override
  String get btnFlip => 'Flip';

  @override
  String get btnHand => 'Hand';

  @override
  String get btnCC => 'CC';

  @override
  String get btnSign => 'Sign';

  @override
  String get btnAvatar => 'Avatar';

  @override
  String get btnStop => 'Stop';

  @override
  String get btnShare => 'Share';

  @override
  String participants(int count) {
    return 'Participants ($count)';
  }

  @override
  String get invite => 'Invite';

  @override
  String get screenSharingOnForAll =>
      'Screen sharing is ON for all participants';

  @override
  String get screenSharingOffForAll => 'Screen sharing is OFF for participants';

  @override
  String get raisedHands => 'Raised Hands';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Reject';

  @override
  String get roleHost => 'Host';

  @override
  String get roleParticipant => 'Participant';

  @override
  String meetingId(String id) {
    return 'ID: $id';
  }

  @override
  String get analyzingSign => 'Analyzing sign…';

  @override
  String get handsNotDetected => 'Hands not detected — move into frame';

  @override
  String get signRecognition => 'Sign Recognition';
}
