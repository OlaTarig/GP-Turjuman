// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get welcomeTitle => 'مرحباً بك في تطبيق ترجمان';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get register => 'إنشاء حساب';

  @override
  String get loginSubtitle => 'مرحباً بعودتك! سجّل الدخول إلى حسابك';

  @override
  String get signUp => 'إنشاء حساب';

  @override
  String get signUpSubtitle => 'أنشئ حسابًا للمتابعة!';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get emailHint => 'example@mail.com';

  @override
  String get password => 'كلمة المرور';

  @override
  String get passwordHint => 'أدخل كلمة المرور';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get fullNameHint => 'أدخل اسمك الكامل';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get dontHaveAccount => 'ليس لديك حساب؟ ';

  @override
  String get alreadyHaveAccount => 'لديك حساب بالفعل؟ ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get ok => 'موافق';

  @override
  String get send => 'إرسال';

  @override
  String get save => 'حفظ';

  @override
  String get delete => 'حذف';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get skip => 'تخطي';

  @override
  String get next => 'التالي';

  @override
  String get getStarted => 'ابدأ الآن';

  @override
  String get resetPassword => 'إعادة تعيين كلمة المرور';

  @override
  String get resetPasswordDesc =>
      'أدخل بريدك الإلكتروني وسنرسل لك رابطاً لإعادة تعيين كلمة المرور.';

  @override
  String get sendResetLink => 'إرسال رابط الإعادة';

  @override
  String get errEnterEmail => 'يرجى إدخال بريدك الإلكتروني';

  @override
  String get errEnterPassword => 'يرجى إدخال كلمة المرور';

  @override
  String get errEnterEmailAddress => 'يرجى إدخال عنوان بريدك الإلكتروني';

  @override
  String get errOccurred => 'حدث خطأ. يرجى المحاولة مرة أخرى.';

  @override
  String get errInvalidCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة. يرجى التحقق من بياناتك.';

  @override
  String get errInvalidEmail => 'صيغة البريد الإلكتروني غير صحيحة.';

  @override
  String get errNoInternet => 'لا يوجد اتصال بالإنترنت. يرجى التحقق من شبكتك.';

  @override
  String get errTooManyRequests => 'محاولات فاشلة كثيرة. يرجى المحاولة لاحقاً.';

  @override
  String get errWeakPassword =>
      'كلمة المرور ضعيفة. استخدم 9 أحرف على الأقل تتضمن حروفاً وأرقاماً.';

  @override
  String get errEmailInUse => 'يوجد حساب مرتبط بهذا البريد الإلكتروني بالفعل.';

  @override
  String get errOperationNotAllowed =>
      'تسجيل الدخول بالبريد وكلمة المرور غير مفعّل. يرجى التواصل مع الدعم.';

  @override
  String get errRegistrationFailed => 'فشل التسجيل. يرجى المحاولة لاحقاً.';

  @override
  String get errUnexpected => 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';

  @override
  String get errNoAccountFound => 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني.';

  @override
  String get loginSuccess => 'تم تسجيل الدخول بنجاح! مرحباً بعودتك';

  @override
  String get accountCreated =>
      'تم إنشاء الحساب بنجاح! يرجى التحقق من بريدك الإلكتروني';

  @override
  String get passwordResetSent =>
      'تم إرسال رابط إعادة تعيين كلمة المرور! تحقق من صندوق الوارد';

  @override
  String get valEnterName => 'يرجى إدخال اسمك';

  @override
  String get valNameTooShort => 'يجب أن يكون الاسم حرفين على الأقل';

  @override
  String get valNameTooLong => 'لا يمكن أن يتجاوز الاسم 20 حرفاً';

  @override
  String get valNameStartsNumber => 'لا يمكن أن يبدأ الاسم برقم';

  @override
  String get valEnterEmail => 'يرجى إدخال بريدك الإلكتروني';

  @override
  String get valEmailSpace => 'لا يمكن أن يحتوي البريد الإلكتروني على مسافات';

  @override
  String get valEmailDots =>
      'لا يمكن أن يحتوي البريد الإلكتروني على نقاط متتالية';

  @override
  String get valInvalidEmail => 'يرجى إدخال بريد إلكتروني صحيح';

  @override
  String get valInvalidDomain => 'نطاق البريد الإلكتروني غير صالح';

  @override
  String get valEnterPassword => 'يرجى إدخال كلمة مرور';

  @override
  String get valPasswordShort => 'يجب أن تكون كلمة المرور 9 أحرف على الأقل';

  @override
  String get valPasswordLong => 'لا يمكن أن تتجاوز كلمة المرور 20 حرفاً';

  @override
  String get valPasswordLetters => 'يجب أن تحتوي كلمة المرور على حروف';

  @override
  String get valPasswordNumbers => 'يجب أن تحتوي كلمة المرور على أرقام';

  @override
  String get verifyEmail => 'تحقق من بريدك الإلكتروني';

  @override
  String get verificationSentTo => 'لقد أرسلنا رابط التحقق إلى:';

  @override
  String get verificationInstructions =>
      'انقر على الرابط في البريد الإلكتروني للتحقق من حسابك.\nسيتم تحديث هذه الصفحة تلقائياً عند التحقق.';

  @override
  String get checkNow => 'تحقق الآن';

  @override
  String get resendVerification => 'إعادة إرسال بريد التحقق';

  @override
  String resendIn(int seconds) {
    return 'إعادة الإرسال بعد $secondsث';
  }

  @override
  String get emailVerifiedSuccess => 'تم التحقق من البريد الإلكتروني بنجاح!';

  @override
  String get emailNotVerifiedYet =>
      'لم يتم التحقق بعد. يرجى مراجعة صندوق الوارد.';

  @override
  String get verificationEmailSent =>
      'تم إرسال بريد التحقق! تحقق من صندوق الوارد.';

  @override
  String get onboarding1Title => 'مرحباً بك في ترجمان';

  @override
  String get onboarding1Subtitle =>
      'مترجم لغة الإشارة العربية في الوقت الفعلي، يجسر التواصل لمجتمع الصم وضعاف السمع.';

  @override
  String get onboarding2Title => 'التعرف على الإشارات المباشرة';

  @override
  String get onboarding2Subtitle =>
      'وجّه الكاميرا نحو إشارات لغة الإشارة واحصل على ترجمات نصية عربية فورية.';

  @override
  String get onboarding3Title => 'اجتماعات شاملة للجميع';

  @override
  String get onboarding3Subtitle =>
      'انضم إلى مؤتمرات الفيديو مع التعليقات التوضيحية والنصوص الحية حتى يتمكن الجميع من المشاركة الكاملة.';

  @override
  String get welcomeBack => 'مرحباً بعودتك،';

  @override
  String get startMeeting => 'بدء اجتماع';

  @override
  String get joinMeeting => 'انضمام إلى اجتماع';

  @override
  String get connectInstantly => 'تواصل مع فريقك فوراً';

  @override
  String get startNow => 'ابدأ الآن';

  @override
  String get meetingNotFound => 'الاجتماع غير موجود';

  @override
  String get meetingAlreadyEnded => 'انتهى الاجتماع بالفعل';

  @override
  String get enterMeetingId => 'أدخل معرّف الاجتماع';

  @override
  String inMeeting(String title) {
    return 'في اجتماع: $title';
  }

  @override
  String get returnToMeeting => 'العودة';

  @override
  String get couldNotCreateMeeting =>
      'تعذّر إنشاء الاجتماع. تحقق من اتصالك وحاول مجدداً.';

  @override
  String get pleaseSignIn => 'يرجى تسجيل الدخول لبدء اجتماع.';

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get appLanguage => 'لغة التطبيق';

  @override
  String get meetingAccess => 'صلاحيات الاجتماع';

  @override
  String get microphone => 'الميكروفون (التطبيق)';

  @override
  String get micSubtitle =>
      'إيقاف: يعطّل الميكروفون في التطبيق. تشغيل: يطلب إذن النظام.';

  @override
  String get camera => 'الكاميرا (التطبيق)';

  @override
  String get cameraSubtitle =>
      'إيقاف: يعطّل الكاميرا في التطبيق. تشغيل: يطلب إذن النظام.';

  @override
  String get privacySecurity => 'الخصوصية والأمان';

  @override
  String get secureScreen => 'تأمين الشاشة';

  @override
  String get secureScreenSubtitle =>
      'يمنع لقطات الشاشة والتسجيل أثناء الاجتماعات.';

  @override
  String get micPermissionNeeded => 'مطلوب إذن الميكروفون';

  @override
  String get cameraPermissionNeeded => 'مطلوب إذن الكاميرا';

  @override
  String get permissionNotGranted =>
      'لم يُمنح الإذن. إذا كان محظوراً بشكل دائم، فعّله من إعدادات النظام.';

  @override
  String get openSystemSettings => 'فتح إعدادات النظام';

  @override
  String get systemSettings => 'إعدادات النظام';

  @override
  String logoutFailed(String error) {
    return 'فشل تسجيل الخروج: $error';
  }

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get name => 'الاسم';

  @override
  String get nameRequired => 'الاسم مطلوب';

  @override
  String get nameTooShort => 'الاسم قصير جداً';

  @override
  String get takePhoto => 'التقاط صورة';

  @override
  String get chooseFromGallery => 'اختيار من المعرض';

  @override
  String get errUserNotLoggedIn => 'خطأ: المستخدم غير مسجّل الدخول';

  @override
  String get profileUpdated => 'تم تحديث الملف الشخصي';

  @override
  String get homeTab => 'الرئيسية';

  @override
  String get filesTab => 'الملفات';

  @override
  String get settingsTab => 'الإعدادات';

  @override
  String get transcripts => 'النصوص';

  @override
  String get transcriptsSubtitle => 'نصوص اجتماعاتك المسجّلة';

  @override
  String get notLoggedIn => 'غير مسجّل الدخول';

  @override
  String get meetingTranscript => 'نص الاجتماع';

  @override
  String get noTranscriptAvailable => 'لا يوجد نص متاح';

  @override
  String get noTranscriptsYet => 'لا توجد نصوص بعد';

  @override
  String get noTranscriptsDesc =>
      'فعّل زر CC أثناء الاجتماع\nلتسجيل الكلام. ستظهر النصوص هنا.';

  @override
  String get deleteTranscript => 'حذف النص';

  @override
  String get deleteTranscriptConfirm =>
      'سيُحذف هذا النص نهائياً لجميع المشاركين. هل تريد المتابعة؟';

  @override
  String failedToDelete(String error) {
    return 'فشل الحذف: $error';
  }

  @override
  String get completed => 'مكتمل';

  @override
  String get inProgress => 'جارٍ';

  @override
  String get downloadPdf => 'تنزيل PDF';

  @override
  String get generating => 'جارٍ الإنشاء...';

  @override
  String get unknownSpeaker => 'متحدث مجهول';

  @override
  String youSuffix(String name) {
    return '$name (أنت)';
  }

  @override
  String transcriptMeta(String date, int entryCount, int speakerCount) {
    return '$date  •  $entryCount جملة  •  $speakerCount متحدث';
  }

  @override
  String meetingPrefix(String id) {
    return 'اجتماع $id...';
  }

  @override
  String statSentences(int count) {
    return '$count جملة';
  }

  @override
  String statSpeakers(int count) {
    return '$count متحدث';
  }

  @override
  String get joiningMeeting => 'جارٍ الانضمام...';

  @override
  String get pleaseWait => 'يرجى الانتظار حتى يكتمل الاتصال';

  @override
  String get unableToJoin => 'تعذّر الانضمام';

  @override
  String get goBack => 'رجوع';

  @override
  String get networkError =>
      'خطأ في الشبكة. تحقق من اتصالك واضغط إعادة المحاولة.';

  @override
  String get needLoginFirst => 'يجب تسجيل الدخول أولاً للانضمام إلى الاجتماع.';

  @override
  String get meetingNotFoundLink =>
      'الاجتماع غير موجود. قد يكون الرابط غير صالح أو منتهي الصلاحية.';

  @override
  String get meetingHasEnded => 'انتهى هذا الاجتماع بالفعل.';

  @override
  String get meetingFull => 'الاجتماع ممتلئ. تم الوصول للحد الأقصى.';

  @override
  String get userProfileNotFound =>
      'الملف الشخصي غير موجود. يرجى إكمال ملفك الشخصي.';

  @override
  String get unknownError => 'حدث خطأ غير معروف.';

  @override
  String get camMicPermissionRequired => 'مطلوب إذن الكاميرا/الميكروفون';

  @override
  String get meetingEnded => 'انتهى الاجتماع';

  @override
  String get meetingEndedByHost => 'أنهى المضيف الاجتماع.';

  @override
  String get accessRequired => 'مطلوب الوصول';

  @override
  String get micAndCameraDisabled =>
      'الميكروفون والكاميرا معطّلان في إعداداتك. يرجى تفعيلهما لاستخدام ميزات الاجتماع.';

  @override
  String get micAccessDisabled =>
      'الميكروفون معطّل في إعداداتك. يرجى تفعيله لاستخدام الصوت.';

  @override
  String get cameraAccessDisabled =>
      'الكاميرا معطّلة في إعداداتك. يرجى تفعيلها لاستخدام الفيديو.';

  @override
  String get later => 'لاحقاً';

  @override
  String get openSettings => 'فتح الإعدادات';

  @override
  String get micDisabledInSettings => 'الميكروفون معطّل في الإعدادات';

  @override
  String get raiseHandForPermission => 'ارفع يدك لطلب إذن المضيف';

  @override
  String get micPermissionRequired => 'مطلوب إذن الميكروفون';

  @override
  String get cameraDisabledInSettings => 'الكاميرا معطّلة في الإعدادات';

  @override
  String get cameraPermissionRequired => 'مطلوب إذن الكاميرا';

  @override
  String get turnOnCameraFirst => 'شغّل الكاميرا أولاً';

  @override
  String get turnOnCameraForSign =>
      'شغّل الكاميرا أولاً — يحتاج التعرف على الإشارات إلى الكاميرا';

  @override
  String get signAvatarEnabled =>
      'تم تفعيل الصورة الرمزية — ستُترجم التعليقات إلى لغة الإشارة';

  @override
  String get signAvatarDisabled => 'تم إيقاف الصورة الرمزية';

  @override
  String get handLowered => 'تم خفض اليد';

  @override
  String get handRaised => 'تم رفع اليد';

  @override
  String get screenShareStopped => 'توقّف مشاركة الشاشة';

  @override
  String get notAllowedToShare =>
      'غير مسموح لك بمشاركة الشاشة.\nاطلب من المضيف منح الإذن.';

  @override
  String get screenShareLabel => 'مشاركة الشاشة';

  @override
  String get shareMyScreen => 'مشاركة شاشتي';

  @override
  String get broadcastDesc => 'بث شاشتك لجميع المشاركين';

  @override
  String get disallowParticipantsShare => 'منع المشاركين من المشاركة';

  @override
  String get allowAllParticipantsShare => 'السماح لجميع المشاركين بالمشاركة';

  @override
  String get participantsCanShare => 'يستطيع المشاركون حالياً مشاركة شاشتهم';

  @override
  String get letParticipantsShare => 'اسمح لجميع المشاركين بمشاركة الشاشة';

  @override
  String get allParticipantsCanShare =>
      'يستطيع جميع المشاركين الآن مشاركة شاشتهم';

  @override
  String get screenSharingDisabled => 'تم إيقاف مشاركة الشاشة للمشاركين';

  @override
  String get failedToUpdatePermission => 'فشل تحديث الإذن';

  @override
  String get startingScreenShare => 'جارٍ بدء مشاركة الشاشة...';

  @override
  String get screenSharingStarted => 'بدأت مشاركة الشاشة';

  @override
  String get failedToStartScreenShare => 'فشل بدء مشاركة الشاشة';

  @override
  String get invitationCopied => 'تم نسخ رابط الدعوة!';

  @override
  String get sendEmailInvitation => 'إرسال دعوة بالبريد الإلكتروني';

  @override
  String get enterParticipantEmailDesc =>
      'أدخل البريد الإلكتروني للمشارك. سيُرسل إليه بريد دعوة تلقائياً.';

  @override
  String get enterEmailValidation => 'يرجى إدخال عنوان البريد الإلكتروني';

  @override
  String get enterValidEmailValidation => 'يرجى إدخال بريد إلكتروني صحيح';

  @override
  String get inviteParticipant => 'دعوة مشارك';

  @override
  String get copyInvitationLink => 'نسخ رابط الدعوة';

  @override
  String get copyLinkManually => 'انسخ الرابط وشاركه يدوياً';

  @override
  String get sendInvitationByEmail => 'إرسال الدعوة بالبريد الإلكتروني';

  @override
  String get sendToInbox => 'إرسال الدعوة مباشرة إلى صندوق الوارد';

  @override
  String invitationSentTo(String email) {
    return 'تم إرسال الدعوة إلى $email';
  }

  @override
  String get failedToSendInvitation =>
      'فشل إرسال الدعوة. يرجى المحاولة مرة أخرى.';

  @override
  String get endMeeting => 'إنهاء الاجتماع';

  @override
  String get endMeetingConfirm => 'هل أنت متأكد من إنهاء الاجتماع للجميع؟';

  @override
  String get leaveMeeting => 'مغادرة الاجتماع';

  @override
  String get leaveMeetingConfirm => 'مغادرة الاجتماع؟';

  @override
  String get leave => 'مغادرة';

  @override
  String get sharingChip => 'يُشارك';

  @override
  String get youAreSharing => 'أنت تشارك';

  @override
  String get screenShareBadge => 'مشاركة الشاشة';

  @override
  String hostSuffix(String name) {
    return '$name (المضيف)';
  }

  @override
  String get btnEnd => 'إنهاء';

  @override
  String get btnLeave => 'مغادرة';

  @override
  String get btnMic => 'ميكروفون';

  @override
  String get btnCamera => 'كاميرا';

  @override
  String get btnFlip => 'قلب';

  @override
  String get btnHand => 'يد';

  @override
  String get btnCC => 'ترجمة';

  @override
  String get btnSign => 'إشارة';

  @override
  String get btnAvatar => 'صورة';

  @override
  String get btnStop => 'إيقاف';

  @override
  String get btnShare => 'مشاركة';

  @override
  String participants(int count) {
    return 'المشاركون ($count)';
  }

  @override
  String get invite => 'دعوة';

  @override
  String get screenSharingOnForAll => 'مشاركة الشاشة مفعّلة لجميع المشاركين';

  @override
  String get screenSharingOffForAll => 'مشاركة الشاشة معطّلة للمشاركين';

  @override
  String get raisedHands => 'الأيدي المرفوعة';

  @override
  String get approve => 'موافقة';

  @override
  String get reject => 'رفض';

  @override
  String get roleHost => 'مضيف';

  @override
  String get roleParticipant => 'مشارك';

  @override
  String meetingId(String id) {
    return 'المعرّف: $id';
  }

  @override
  String get analyzingSign => 'جارٍ تحليل الإشارة...';

  @override
  String get handsNotDetected => 'لم يتم رصد اليدين — أعِد تأطيرهما';

  @override
  String get signRecognition => 'التعرف على الإشارات';

  @override
  String get signRecognitionStopped => 'تم إيقاف التعرف على الإشارات';

  @override
  String get coachSignTitle => 'التعرف على الإشارات';

  @override
  String get coachSignDesc =>
      'اضغط هذا الزر لبدء ترجمة إشاراتك اليدوية إلى نصوص عربية في الوقت الفعلي.';

  @override
  String get coachAvatarTitle => 'الصورة الرمزية للإشارة';

  @override
  String get coachAvatarDesc =>
      'اضغط هذا الزر لترجمة الكلام المنطوق إلى حركات لغة الإشارة بواسطة صورة رمزية.';

  @override
  String get coachNext => 'التالي';

  @override
  String get coachGotIt => 'فهمت';
}
