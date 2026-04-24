import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_lo.dart';
import 'app_localizations_ms.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_th.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_uk.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

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
    Locale('bn'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('id'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('lo'),
    Locale('ms'),
    Locale('pt'),
    Locale('ru'),
    Locale('th'),
    Locale('tr'),
    Locale('uk'),
    Locale('vi'),
    Locale('zh')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'XPARQ'**
  String get appTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @themeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeTitle;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @orbitTab.
  ///
  /// In en, this message translates to:
  /// **'Orbit'**
  String get orbitTab;

  /// No description provided for @radarTab.
  ///
  /// In en, this message translates to:
  /// **'Radar'**
  String get radarTab;

  /// No description provided for @signalTab.
  ///
  /// In en, this message translates to:
  /// **'Signal'**
  String get signalTab;

  /// No description provided for @planetTab.
  ///
  /// In en, this message translates to:
  /// **'Planet'**
  String get planetTab;

  /// No description provided for @alertsTab.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alertsTab;

  /// No description provided for @appearanceSection.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSection;

  /// No description provided for @accountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountSection;

  /// No description provided for @dobTitle.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dobTitle;

  /// No description provided for @dobSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to update (requires re-verification)'**
  String get dobSubtitle;

  /// No description provided for @safetySection.
  ///
  /// In en, this message translates to:
  /// **'Safety & Privacy'**
  String get safetySection;

  /// No description provided for @nsfwTitle.
  ///
  /// In en, this message translates to:
  /// **'Black Hole Zone'**
  String get nsfwTitle;

  /// No description provided for @nsfwSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show sensitive content (18+)'**
  String get nsfwSubtitle;

  /// No description provided for @safetyModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Safety Mode Active'**
  String get safetyModeTitle;

  /// No description provided for @safetyModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Galactic Cadet protection enabled.'**
  String get safetyModeSubtitle;

  /// No description provided for @ghostModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Ghost Mode'**
  String get ghostModeTitle;

  /// No description provided for @ghostModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide your planet from Radar and nearby searches'**
  String get ghostModeSubtitle;

  /// No description provided for @blockedUsersTitle.
  ///
  /// In en, this message translates to:
  /// **'Blocked Xparqs'**
  String get blockedUsersTitle;

  /// No description provided for @accountingSection.
  ///
  /// In en, this message translates to:
  /// **'Accounting'**
  String get accountingSection;

  /// No description provided for @shareCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Share Code'**
  String get shareCodeTitle;

  /// No description provided for @appInfoSection.
  ///
  /// In en, this message translates to:
  /// **'App Info'**
  String get appInfoSection;

  /// No description provided for @signOutButton.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutButton;

  /// No description provided for @settingsViewAccount.
  ///
  /// In en, this message translates to:
  /// **'View My Account'**
  String get settingsViewAccount;

  /// No description provided for @settingsMyAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'My Account'**
  String get settingsMyAccountTitle;

  /// No description provided for @settingsMyAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Password, security, account data'**
  String get settingsMyAccountSubtitle;

  /// No description provided for @settingsPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Safety'**
  String get settingsPrivacyTitle;

  /// No description provided for @settingsPrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ghost mode, Black Hole Zone, blocked users'**
  String get settingsPrivacySubtitle;

  /// No description provided for @settingsSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurityTitle;

  /// No description provided for @settingsSecuritySubtitle.
  ///
  /// In en, this message translates to:
  /// **'2FA, active devices, login alerts'**
  String get settingsSecuritySubtitle;

  /// No description provided for @settingsNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotificationsTitle;

  /// No description provided for @settingsNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Likes, comments, signals, quiet hours'**
  String get settingsNotificationsSubtitle;

  /// No description provided for @settingsDisplayTitle.
  ///
  /// In en, this message translates to:
  /// **'Content & Display'**
  String get settingsDisplayTitle;

  /// No description provided for @settingsDisplaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme, language, feed preferences'**
  String get settingsDisplaySubtitle;

  /// No description provided for @settingsMediaTitle.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get settingsMediaTitle;

  /// No description provided for @settingsMediaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload quality, auto-save, data saver'**
  String get settingsMediaSubtitle;

  /// No description provided for @settingsFamilyTitle.
  ///
  /// In en, this message translates to:
  /// **'Family Center'**
  String get settingsFamilyTitle;

  /// No description provided for @settingsFamilySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Parental controls, screen time'**
  String get settingsFamilySubtitle;

  /// No description provided for @settingsHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get settingsHelpTitle;

  /// No description provided for @settingsHelpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help center, report, about Xparq'**
  String get settingsHelpSubtitle;

  /// No description provided for @nsfwDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Black Hole Zone'**
  String get nsfwDialogTitle;

  /// No description provided for @nsfwDialogContent.
  ///
  /// In en, this message translates to:
  /// **'As an Explorer (18+), you can opt into adult content in the Black Hole Zone.\n\nThis includes sensitive messages and profiles. You can change this anytime in Settings.'**
  String get nsfwDialogContent;

  /// No description provided for @nsfwDialogEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable Black Hole Zone'**
  String get nsfwDialogEnable;

  /// No description provided for @nsfwDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Keep it clean for now'**
  String get nsfwDialogCancel;

  /// No description provided for @languagePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get languagePickerTitle;

  /// No description provided for @languageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @languageTh.
  ///
  /// In en, this message translates to:
  /// **'ภาษาไทย'**
  String get languageTh;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Safe Galactic Social'**
  String get welcomeSubtitle;

  /// No description provided for @continuePhone.
  ///
  /// In en, this message translates to:
  /// **'Continue with Phone'**
  String get continuePhone;

  /// No description provided for @continueEmail.
  ///
  /// In en, this message translates to:
  /// **'Continue with Email'**
  String get continueEmail;

  /// No description provided for @enterGuest.
  ///
  /// In en, this message translates to:
  /// **'Enter as Guest (Offline Only)'**
  String get enterGuest;

  /// No description provided for @termsPolicy.
  ///
  /// In en, this message translates to:
  /// **'By joining, you agree to our Privacy Policy.\nMinimum age: 13 years.'**
  String get termsPolicy;

  /// No description provided for @joinGalaxy.
  ///
  /// In en, this message translates to:
  /// **'Join the Galaxy'**
  String get joinGalaxy;

  /// No description provided for @enterPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get enterPhone;

  /// No description provided for @sendPhoneOtpDesc.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send you a verification code.'**
  String get sendPhoneOtpDesc;

  /// No description provided for @phonePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Phone Number (+66...)'**
  String get phonePlaceholder;

  /// No description provided for @phoneErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get phoneErrorEmpty;

  /// No description provided for @phoneErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Include country code (e.g. +66)'**
  String get phoneErrorInvalid;

  /// No description provided for @enterOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP code'**
  String get enterOtp;

  /// No description provided for @otpPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'8-digit code'**
  String get otpPlaceholder;

  /// No description provided for @otpError.
  ///
  /// In en, this message translates to:
  /// **'Enter the 8-digit code'**
  String get otpError;

  /// No description provided for @phoneVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification Code'**
  String get phoneVerificationCode;

  /// No description provided for @sendOtpBtn.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get sendOtpBtn;

  /// No description provided for @verifyContinueBtn.
  ///
  /// In en, this message translates to:
  /// **'Verify & Continue'**
  String get verifyContinueBtn;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInTitle;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, Xparq!'**
  String get welcomeBack;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createAccount;

  /// No description provided for @forgotPasswordBtn.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordBtn;

  /// No description provided for @emailPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailPlaceholder;

  /// No description provided for @emailError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get emailError;

  /// No description provided for @passwordPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordPlaceholder;

  /// No description provided for @passwordError.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordError;

  /// No description provided for @loginBtn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get loginBtn;

  /// No description provided for @signUpBtn.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUpBtn;

  /// No description provided for @selectAuthMethodTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Method'**
  String get selectAuthMethodTitle;

  /// No description provided for @authMethodPhone.
  ///
  /// In en, this message translates to:
  /// **'Continue with Phone'**
  String get authMethodPhone;

  /// No description provided for @authMethodEmail.
  ///
  /// In en, this message translates to:
  /// **'Continue with Email'**
  String get authMethodEmail;

  /// No description provided for @authMethodOther.
  ///
  /// In en, this message translates to:
  /// **'Other (Coming Soon)'**
  String get authMethodOther;

  /// No description provided for @registerBtn.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerBtn;

  /// No description provided for @newXparqPromo.
  ///
  /// In en, this message translates to:
  /// **'New Xparq? Register here'**
  String get newXparqPromo;

  /// No description provided for @alreadyXparqPromo.
  ///
  /// In en, this message translates to:
  /// **'Already an Xparq? Sign in'**
  String get alreadyXparqPromo;

  /// No description provided for @dobScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dobScreenTitle;

  /// No description provided for @dobQuestion.
  ///
  /// In en, this message translates to:
  /// **'When were you born?'**
  String get dobQuestion;

  /// No description provided for @dobSafetyDesc.
  ///
  /// In en, this message translates to:
  /// **'We use this to keep the galaxy safe.\nYou must be at least 13 years old.'**
  String get dobSafetyDesc;

  /// No description provided for @dobPickerHelp.
  ///
  /// In en, this message translates to:
  /// **'Select your date of birth'**
  String get dobPickerHelp;

  /// No description provided for @dobSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Select date of birth'**
  String get dobSelectHint;

  /// No description provided for @dobContinueBtn.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get dobContinueBtn;

  /// No description provided for @dobEncryptedNote.
  ///
  /// In en, this message translates to:
  /// **'🔒 Your date of birth is encrypted and never shared.'**
  String get dobEncryptedNote;

  /// No description provided for @galacticCadet.
  ///
  /// In en, this message translates to:
  /// **'Galactic Cadet'**
  String get galacticCadet;

  /// No description provided for @galacticCadetDesc.
  ///
  /// In en, this message translates to:
  /// **'Safe mode — content filtered for your protection'**
  String get galacticCadetDesc;

  /// No description provided for @interstellarExplorer.
  ///
  /// In en, this message translates to:
  /// **'Interstellar Explorer'**
  String get interstellarExplorer;

  /// No description provided for @interstellarExplorerDesc.
  ///
  /// In en, this message translates to:
  /// **'Full access — you can opt into adult content'**
  String get interstellarExplorerDesc;

  /// No description provided for @planetCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Your Planet'**
  String get planetCreateTitle;

  /// No description provided for @planetDesignTitle.
  ///
  /// In en, this message translates to:
  /// **'Design your planet'**
  String get planetDesignTitle;

  /// No description provided for @planetDesignDesc.
  ///
  /// In en, this message translates to:
  /// **'This is how other Xparqs will see you.'**
  String get planetDesignDesc;

  /// No description provided for @tapToAddAvatar.
  ///
  /// In en, this message translates to:
  /// **'Tap to add avatar'**
  String get tapToAddAvatar;

  /// No description provided for @iXparqNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Xparq Name'**
  String get iXparqNameLabel;

  /// No description provided for @iXparqNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. StarDrifter42'**
  String get iXparqNameHint;

  /// No description provided for @iXparqNameErrorLen.
  ///
  /// In en, this message translates to:
  /// **'Xparq Name must be at least 3 characters'**
  String get iXparqNameErrorLen;

  /// No description provided for @iXparqNameErrorMax.
  ///
  /// In en, this message translates to:
  /// **'Max 24 characters'**
  String get iXparqNameErrorMax;

  /// No description provided for @bioLabel.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bioLabel;

  /// No description provided for @iXparqBioHint.
  ///
  /// In en, this message translates to:
  /// **'Tell the galaxy about yourself...'**
  String get iXparqBioHint;

  /// No description provided for @bioHint.
  ///
  /// In en, this message translates to:
  /// **'Tell the galaxy about yourself...'**
  String get bioHint;

  /// No description provided for @constellationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Constellations (pick up to 5)'**
  String get constellationsLabel;

  /// No description provided for @launchPlanetBtn.
  ///
  /// In en, this message translates to:
  /// **'Launch My Planet'**
  String get launchPlanetBtn;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get verifyEmailTitle;

  /// No description provided for @emailOtpSentDesc.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to your email. Enter it below to continue.'**
  String get emailOtpSentDesc;

  /// No description provided for @verifyEmailBtn.
  ///
  /// In en, this message translates to:
  /// **'Verify Email'**
  String get verifyEmailBtn;

  /// No description provided for @emailOtpPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get emailOtpPlaceholder;

  /// No description provided for @forgotPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordHint;

  /// No description provided for @forgotPasswordEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent. Please check your inbox.'**
  String get forgotPasswordEmailSent;

  /// No description provided for @authErrorInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone number. Please check and try again.'**
  String get authErrorInvalidPhone;

  /// No description provided for @authErrorInvalidOtp.
  ///
  /// In en, this message translates to:
  /// **'Incorrect OTP code. Please try again.'**
  String get authErrorInvalidOtp;

  /// No description provided for @authErrorEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered. Please sign in.'**
  String get authErrorEmailInUse;

  /// No description provided for @authErrorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak. Use at least 8 characters.'**
  String get authErrorWeakPassword;

  /// No description provided for @authErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password.'**
  String get authErrorInvalidCredentials;

  /// No description provided for @authErrorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait and try again.'**
  String get authErrorTooManyRequests;

  /// No description provided for @authErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again.'**
  String get authErrorGeneric;

  /// No description provided for @authErrorNameTaken.
  ///
  /// In en, this message translates to:
  /// **'This Xparq Name is already taken. Try another one.'**
  String get authErrorNameTaken;

  /// No description provided for @authErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error occurred. Please check your connection.'**
  String get authErrorNetwork;

  /// No description provided for @authErrorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address format.'**
  String get authErrorInvalidEmail;

  /// No description provided for @authResendOtp.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get authResendOtp;

  /// No description provided for @authConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get authConfirm;

  /// No description provided for @authOtpInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid OTP. Please try again.'**
  String get authOtpInvalid;

  /// No description provided for @authSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get authSendOtp;

  /// No description provided for @forgotPasswordEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to receive a password reset link.'**
  String get forgotPasswordEmailHint;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailHint;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Set New Password'**
  String get resetPasswordTitle;

  /// No description provided for @newPasswordPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPasswordPlaceholder;

  /// No description provided for @confirmPasswordPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmPasswordPlaceholder;

  /// No description provided for @confirmPasswordBtn.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordBtn;

  /// No description provided for @resetPasswordSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your password has been changed successfully.'**
  String get resetPasswordSuccess;

  /// No description provided for @okBtn.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get okBtn;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String error(Object message);

  /// No description provided for @stellarIdentityLabel.
  ///
  /// In en, this message translates to:
  /// **'Stellar Identity'**
  String get stellarIdentityLabel;

  /// No description provided for @selectIdentityTitle.
  ///
  /// In en, this message translates to:
  /// **'Select {title}'**
  String selectIdentityTitle(String title);

  /// No description provided for @tagMusic.
  ///
  /// In en, this message translates to:
  /// **'🎵 Music'**
  String get tagMusic;

  /// No description provided for @tagGaming.
  ///
  /// In en, this message translates to:
  /// **'🎮 Gaming'**
  String get tagGaming;

  /// No description provided for @tagBooks.
  ///
  /// In en, this message translates to:
  /// **'📚 Books'**
  String get tagBooks;

  /// No description provided for @tagArt.
  ///
  /// In en, this message translates to:
  /// **'🎨 Art'**
  String get tagArt;

  /// No description provided for @tagSports.
  ///
  /// In en, this message translates to:
  /// **'🏃 Sports'**
  String get tagSports;

  /// No description provided for @tagFood.
  ///
  /// In en, this message translates to:
  /// **'🍜 Food'**
  String get tagFood;

  /// No description provided for @tagTravel.
  ///
  /// In en, this message translates to:
  /// **'✈️ Travel'**
  String get tagTravel;

  /// No description provided for @tagTech.
  ///
  /// In en, this message translates to:
  /// **'💻 Tech'**
  String get tagTech;

  /// No description provided for @tagMovies.
  ///
  /// In en, this message translates to:
  /// **'🎬 Movies'**
  String get tagMovies;

  /// No description provided for @tagNature.
  ///
  /// In en, this message translates to:
  /// **'🌿 Nature'**
  String get tagNature;

  /// No description provided for @labelMbti.
  ///
  /// In en, this message translates to:
  /// **'MBTI'**
  String get labelMbti;

  /// No description provided for @labelEnneagram.
  ///
  /// In en, this message translates to:
  /// **'Enneagram'**
  String get labelEnneagram;

  /// No description provided for @labelZodiac.
  ///
  /// In en, this message translates to:
  /// **'Zodiac'**
  String get labelZodiac;

  /// No description provided for @labelBloodType.
  ///
  /// In en, this message translates to:
  /// **'Blood Type'**
  String get labelBloodType;

  /// No description provided for @enneagram1.
  ///
  /// In en, this message translates to:
  /// **'The Reformer'**
  String get enneagram1;

  /// No description provided for @enneagram2.
  ///
  /// In en, this message translates to:
  /// **'The Helper'**
  String get enneagram2;

  /// No description provided for @enneagram3.
  ///
  /// In en, this message translates to:
  /// **'The Achiever'**
  String get enneagram3;

  /// No description provided for @enneagram4.
  ///
  /// In en, this message translates to:
  /// **'The Individualist'**
  String get enneagram4;

  /// No description provided for @enneagram5.
  ///
  /// In en, this message translates to:
  /// **'The Investigator'**
  String get enneagram5;

  /// No description provided for @enneagram6.
  ///
  /// In en, this message translates to:
  /// **'The Loyalist'**
  String get enneagram6;

  /// No description provided for @enneagram7.
  ///
  /// In en, this message translates to:
  /// **'The Enthusiast'**
  String get enneagram7;

  /// No description provided for @enneagram8.
  ///
  /// In en, this message translates to:
  /// **'The Challenger'**
  String get enneagram8;

  /// No description provided for @enneagram9.
  ///
  /// In en, this message translates to:
  /// **'The Peacemaker'**
  String get enneagram9;

  /// No description provided for @zodiacAries.
  ///
  /// In en, this message translates to:
  /// **'Aries'**
  String get zodiacAries;

  /// No description provided for @zodiacTaurus.
  ///
  /// In en, this message translates to:
  /// **'Taurus'**
  String get zodiacTaurus;

  /// No description provided for @zodiacGemini.
  ///
  /// In en, this message translates to:
  /// **'Gemini'**
  String get zodiacGemini;

  /// No description provided for @zodiacCancer.
  ///
  /// In en, this message translates to:
  /// **'Cancer'**
  String get zodiacCancer;

  /// No description provided for @zodiacLeo.
  ///
  /// In en, this message translates to:
  /// **'Leo'**
  String get zodiacLeo;

  /// No description provided for @zodiacVirgo.
  ///
  /// In en, this message translates to:
  /// **'Virgo'**
  String get zodiacVirgo;

  /// No description provided for @zodiacLibra.
  ///
  /// In en, this message translates to:
  /// **'Libra'**
  String get zodiacLibra;

  /// No description provided for @zodiacScorpio.
  ///
  /// In en, this message translates to:
  /// **'Scorpio'**
  String get zodiacScorpio;

  /// No description provided for @zodiacSagittarius.
  ///
  /// In en, this message translates to:
  /// **'Sagittarius'**
  String get zodiacSagittarius;

  /// No description provided for @zodiacCapricorn.
  ///
  /// In en, this message translates to:
  /// **'Capricorn'**
  String get zodiacCapricorn;

  /// No description provided for @zodiacAquarius.
  ///
  /// In en, this message translates to:
  /// **'Aquarius'**
  String get zodiacAquarius;

  /// No description provided for @zodiacPisces.
  ///
  /// In en, this message translates to:
  /// **'Pisces'**
  String get zodiacPisces;

  /// No description provided for @bloodA.
  ///
  /// In en, this message translates to:
  /// **'Type A'**
  String get bloodA;

  /// No description provided for @bloodB.
  ///
  /// In en, this message translates to:
  /// **'Type B'**
  String get bloodB;

  /// No description provided for @bloodAB.
  ///
  /// In en, this message translates to:
  /// **'Type AB'**
  String get bloodAB;

  /// No description provided for @bloodO.
  ///
  /// In en, this message translates to:
  /// **'Type O'**
  String get bloodO;

  /// No description provided for @offlineMeshStarted.
  ///
  /// In en, this message translates to:
  /// **'Mesh services restarted'**
  String get offlineMeshStarted;

  /// No description provided for @offlineWaitingPeer.
  ///
  /// In en, this message translates to:
  /// **'Waiting for peer to connect...'**
  String get offlineWaitingPeer;

  /// No description provided for @offlinePeerOffline.
  ///
  /// In en, this message translates to:
  /// **'Peer is offline. Cannot send.'**
  String get offlinePeerOffline;

  /// No description provided for @offlineTypeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get offlineTypeMessage;

  /// No description provided for @offlineSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline Settings'**
  String get offlineSettingsTitle;

  /// No description provided for @offlineAnonTitle.
  ///
  /// In en, this message translates to:
  /// **'Anonymous Mode'**
  String get offlineAnonTitle;

  /// No description provided for @offlineAnonSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hides your identity on Radar'**
  String get offlineAnonSubtitle;

  /// No description provided for @offlineClearCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Local Chat Cache'**
  String get offlineClearCacheTitle;

  /// No description provided for @offlineClearCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deletes all offline messages'**
  String get offlineClearCacheSubtitle;

  /// No description provided for @offlineResetAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear All Cache (Reset Account)'**
  String get offlineResetAccountTitle;

  /// No description provided for @offlineResetAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deletes friends, chats, and your offline identity.'**
  String get offlineResetAccountSubtitle;

  /// No description provided for @offlineExitMode.
  ///
  /// In en, this message translates to:
  /// **'Exit Offline Mode'**
  String get offlineExitMode;

  /// No description provided for @offlineOnboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'OFFLINE MESH'**
  String get offlineOnboardingTitle;

  /// No description provided for @offlineStellarIdentity.
  ///
  /// In en, this message translates to:
  /// **'Stellar Identity'**
  String get offlineStellarIdentity;

  /// No description provided for @offlineEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name to register...'**
  String get offlineEnterName;

  /// No description provided for @offlineDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get offlineDisplayNameLabel;

  /// No description provided for @offlineDisplayNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. StarTraveler'**
  String get offlineDisplayNameHint;

  /// No description provided for @offlineAccessContinue.
  ///
  /// In en, this message translates to:
  /// **'Allow Access & Continue'**
  String get offlineAccessContinue;

  /// No description provided for @offlineConnectionRequest.
  ///
  /// In en, this message translates to:
  /// **'Connection Request'**
  String get offlineConnectionRequest;

  /// No description provided for @offlineConnectionRequestDesc.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to connect via Offline Mesh.'**
  String offlineConnectionRequestDesc(Object name);

  /// No description provided for @offlineAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get offlineAccept;

  /// No description provided for @offlineDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get offlineDecline;

  /// No description provided for @offlineAddedPeer.
  ///
  /// In en, this message translates to:
  /// **'Added {name} as a peer!'**
  String offlineAddedPeer(String name);

  /// No description provided for @offlineReconnected.
  ///
  /// In en, this message translates to:
  /// **'Reconnected with {name}'**
  String offlineReconnected(String name);

  /// No description provided for @offlineOnboardingDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose how you appear to others in the mesh network. No internet required.'**
  String get offlineOnboardingDesc;

  /// No description provided for @offlineDisplayNameHintIdentity.
  ///
  /// In en, this message translates to:
  /// **'Enter your identity name...'**
  String get offlineDisplayNameHintIdentity;

  /// No description provided for @offlineStayAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Stay Anonymous'**
  String get offlineStayAnonymous;

  /// No description provided for @offlineStayAnonymousDesc.
  ///
  /// In en, this message translates to:
  /// **'Hide your real name from others.'**
  String get offlineStayAnonymousDesc;

  /// No description provided for @offlineLaunchIdentity.
  ///
  /// In en, this message translates to:
  /// **'Launch Identity'**
  String get offlineLaunchIdentity;

  /// No description provided for @offlineHistoryCleared.
  ///
  /// In en, this message translates to:
  /// **'Offline history cleared.'**
  String get offlineHistoryCleared;

  /// No description provided for @offlineClearConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear history?'**
  String get offlineClearConfirmTitle;

  /// No description provided for @offlineClearConfirmDesc.
  ///
  /// In en, this message translates to:
  /// **'This will delete all offline messages.'**
  String get offlineClearConfirmDesc;

  /// No description provided for @offlineCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get offlineCancel;

  /// No description provided for @offlineClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get offlineClear;

  /// No description provided for @offlineResetConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset EVERYTHING?'**
  String get offlineResetConfirmTitle;

  /// No description provided for @offlineResetConfirmDesc.
  ///
  /// In en, this message translates to:
  /// **'This will delete your identity, messages, and all offline data. This cannot be undone.'**
  String get offlineResetConfirmDesc;

  /// No description provided for @offlineReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get offlineReset;

  /// No description provided for @offlineRadarTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline Radar'**
  String get offlineRadarTitle;

  /// No description provided for @offlineMeshActive.
  ///
  /// In en, this message translates to:
  /// **'Mesh Active'**
  String get offlineMeshActive;

  /// No description provided for @offlineConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get offlineConnecting;

  /// No description provided for @offlineSearchingNeighbors.
  ///
  /// In en, this message translates to:
  /// **'Searching for neighbors...'**
  String get offlineSearchingNeighbors;

  /// No description provided for @offlineEnableServices.
  ///
  /// In en, this message translates to:
  /// **'Ensure Bluetooth & Wi-Fi are enabled'**
  String get offlineEnableServices;

  /// No description provided for @offlineConnectedMesh.
  ///
  /// In en, this message translates to:
  /// **'Connected via Offline Mesh'**
  String get offlineConnectedMesh;

  /// No description provided for @offlineDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected / Reconnecting...'**
  String get offlineDisconnected;

  /// No description provided for @offlineBackToOnline.
  ///
  /// In en, this message translates to:
  /// **'Back to Online Mode'**
  String get offlineBackToOnline;

  /// No description provided for @offlinePermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline Mode'**
  String get offlinePermissionTitle;

  /// No description provided for @offlinePermissionDesc.
  ///
  /// In en, this message translates to:
  /// **'To discover and message nearby Xparq users without internet, we need access to your device\'s Bluetooth and Location services. We do not track your location in this mode.'**
  String get offlinePermissionDesc;

  /// No description provided for @offlinePermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Permissions are required to use Offline Mode.'**
  String get offlinePermissionRequired;

  /// No description provided for @offlineRadarStatus.
  ///
  /// In en, this message translates to:
  /// **'• DISCOVERING & BROADCASTING •'**
  String get offlineRadarStatus;

  /// No description provided for @offlinePeerFoundNow.
  ///
  /// In en, this message translates to:
  /// **'Found right now'**
  String get offlinePeerFoundNow;

  /// No description provided for @offlineSignalTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline Signals'**
  String get offlineSignalTitle;

  /// No description provided for @offlineNoSignals.
  ///
  /// In en, this message translates to:
  /// **'No offline signals discovered yet.'**
  String get offlineNoSignals;

  /// No description provided for @offlineLastSignalAt.
  ///
  /// In en, this message translates to:
  /// **'Last signal at {time}'**
  String offlineLastSignalAt(Object time);

  /// No description provided for @offlinePeerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Peer is currently offline or out of range.'**
  String get offlinePeerUnavailable;

  /// No description provided for @offlineProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline Planet'**
  String get offlineProfileTitle;

  /// No description provided for @offlineNameSaved.
  ///
  /// In en, this message translates to:
  /// **'Offline name saved!'**
  String get offlineNameSaved;

  /// No description provided for @offlineNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'@YOUR NAME?'**
  String get offlineNamePlaceholder;

  /// No description provided for @offlineSaveName.
  ///
  /// In en, this message translates to:
  /// **'Save Name'**
  String get offlineSaveName;

  /// No description provided for @offlineAnonEditDisabled.
  ///
  /// In en, this message translates to:
  /// **'Name editing is disabled while Anonymous Mode is active in Settings.'**
  String get offlineAnonEditDisabled;

  /// No description provided for @offlineFriendsSection.
  ///
  /// In en, this message translates to:
  /// **'YOUR OFFLINE FRIENDS'**
  String get offlineFriendsSection;

  /// No description provided for @offlineNoFriends.
  ///
  /// In en, this message translates to:
  /// **'No friends added yet.\nGo to Radar to find peers!'**
  String get offlineNoFriends;

  /// No description provided for @offlineRemoveFriendTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Friend?'**
  String get offlineRemoveFriendTitle;

  /// No description provided for @offlineRemoveFriendDesc.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove {name} from your offline friends?'**
  String offlineRemoveFriendDesc(Object name);

  /// No description provided for @offlineFriendRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} removed'**
  String offlineFriendRemoved(Object name);

  /// No description provided for @offlineUnknownPeer.
  ///
  /// In en, this message translates to:
  /// **'Stranger'**
  String get offlineUnknownPeer;

  /// No description provided for @profileMenuViewIdentity.
  ///
  /// In en, this message translates to:
  /// **'View Identity'**
  String get profileMenuViewIdentity;

  /// No description provided for @profileMenuModifyEssence.
  ///
  /// In en, this message translates to:
  /// **'Modify Essence'**
  String get profileMenuModifyEssence;

  /// No description provided for @profileMenuTransmitSignal.
  ///
  /// In en, this message translates to:
  /// **'Transmit Signal'**
  String get profileMenuTransmitSignal;

  /// No description provided for @profileMenuExtractArtifact.
  ///
  /// In en, this message translates to:
  /// **'Extract Artifact'**
  String get profileMenuExtractArtifact;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'EDIT PROFILE'**
  String get editProfileTitle;

  /// No description provided for @editProfileEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editProfileEdit;

  /// No description provided for @editProfileSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get editProfileSave;

  /// No description provided for @editProfileSectionMedia.
  ///
  /// In en, this message translates to:
  /// **'AVATAR & COVER'**
  String get editProfileSectionMedia;

  /// No description provided for @editProfileSectionIdentity.
  ///
  /// In en, this message translates to:
  /// **'STELLAR IDENTITY'**
  String get editProfileSectionIdentity;

  /// No description provided for @editProfileNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Xparq NAME (Display Name)'**
  String get editProfileNameLabel;

  /// No description provided for @editProfileNameHint.
  ///
  /// In en, this message translates to:
  /// **'How people will see you'**
  String get editProfileNameHint;

  /// No description provided for @editProfileHandleLabel.
  ///
  /// In en, this message translates to:
  /// **'Username (@handle)'**
  String get editProfileHandleLabel;

  /// No description provided for @editProfileHandleCooldown.
  ///
  /// In en, this message translates to:
  /// **'Available to change again in {days} days'**
  String editProfileHandleCooldown(Object days);

  /// No description provided for @editProfileHandleLockNote.
  ///
  /// In en, this message translates to:
  /// **'Setting a username locks it for 90 days.'**
  String get editProfileHandleLockNote;

  /// No description provided for @editProfileSectionBio.
  ///
  /// In en, this message translates to:
  /// **'BIOGRAPHY'**
  String get editProfileSectionBio;

  /// No description provided for @editProfileShortBioLabel.
  ///
  /// In en, this message translates to:
  /// **'Short Bio (Visible to all)'**
  String get editProfileShortBioLabel;

  /// No description provided for @editProfileShortBioHint.
  ///
  /// In en, this message translates to:
  /// **'A catchy introduction...'**
  String get editProfileShortBioHint;

  /// No description provided for @editProfileExtendedBioLabel.
  ///
  /// In en, this message translates to:
  /// **'Extended Bio (Optional)'**
  String get editProfileExtendedBioLabel;

  /// No description provided for @editProfileExtendedBioHint.
  ///
  /// In en, this message translates to:
  /// **'Tell your story in detail...'**
  String get editProfileExtendedBioHint;

  /// No description provided for @editProfileSectionPersona.
  ///
  /// In en, this message translates to:
  /// **'PERSONA DETAILS'**
  String get editProfileSectionPersona;

  /// No description provided for @editProfileGenderLabel.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get editProfileGenderLabel;

  /// No description provided for @editProfileGenderHint.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get editProfileGenderHint;

  /// No description provided for @editProfileOccupationLabel.
  ///
  /// In en, this message translates to:
  /// **'Occupation'**
  String get editProfileOccupationLabel;

  /// No description provided for @editProfileOccupationHint.
  ///
  /// In en, this message translates to:
  /// **'What you do'**
  String get editProfileOccupationHint;

  /// No description provided for @editProfileLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get editProfileLocationLabel;

  /// No description provided for @editProfileLocationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Bangkok, TH'**
  String get editProfileLocationHint;

  /// No description provided for @editProfileSectionLinks.
  ///
  /// In en, this message translates to:
  /// **'TRANSMISSION LINKS (MAX 3)'**
  String get editProfileSectionLinks;

  /// No description provided for @editProfileLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Link {n}'**
  String editProfileLinkLabel(Object n);

  /// No description provided for @editProfileLink1Hint.
  ///
  /// In en, this message translates to:
  /// **'Linktree, Website...'**
  String get editProfileLink1Hint;

  /// No description provided for @editProfileLink2Hint.
  ///
  /// In en, this message translates to:
  /// **'OnlyFans, Patreon...'**
  String get editProfileLink2Hint;

  /// No description provided for @editProfileLink3Hint.
  ///
  /// In en, this message translates to:
  /// **'TikTok, IG, YT...'**
  String get editProfileLink3Hint;

  /// No description provided for @editProfileSectionDecor.
  ///
  /// In en, this message translates to:
  /// **'STELLAR DECOR'**
  String get editProfileSectionDecor;

  /// No description provided for @editProfileMbtiLabel.
  ///
  /// In en, this message translates to:
  /// **'MBTI'**
  String get editProfileMbtiLabel;

  /// No description provided for @editProfileMbtiHint.
  ///
  /// In en, this message translates to:
  /// **'INFJ, ENTP...'**
  String get editProfileMbtiHint;

  /// No description provided for @editProfileZodiacLabel.
  ///
  /// In en, this message translates to:
  /// **'Zodiac'**
  String get editProfileZodiacLabel;

  /// No description provided for @editProfileZodiacHint.
  ///
  /// In en, this message translates to:
  /// **'Leo, Libra...'**
  String get editProfileZodiacHint;

  /// No description provided for @editProfileBloodLabel.
  ///
  /// In en, this message translates to:
  /// **'Blood'**
  String get editProfileBloodLabel;

  /// No description provided for @editProfileBloodHint.
  ///
  /// In en, this message translates to:
  /// **'O, A, B...'**
  String get editProfileBloodHint;

  /// No description provided for @editProfileInterestsLabel.
  ///
  /// In en, this message translates to:
  /// **'Cosmic Interests ({count}/5)'**
  String editProfileInterestsLabel(Object count);

  /// No description provided for @editProfileSectionProfessional.
  ///
  /// In en, this message translates to:
  /// **'PROFESSIONAL & ACADEMIC'**
  String get editProfileSectionProfessional;

  /// No description provided for @editProfileWorkLabel.
  ///
  /// In en, this message translates to:
  /// **'Workplace / Company'**
  String get editProfileWorkLabel;

  /// No description provided for @editProfileWorkHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Google, SpaceX...'**
  String get editProfileWorkHint;

  /// No description provided for @editProfileEducationLabel.
  ///
  /// In en, this message translates to:
  /// **'Education / School'**
  String get editProfileEducationLabel;

  /// No description provided for @editProfileEducationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Stanford University...'**
  String get editProfileEducationHint;

  /// No description provided for @editProfileExperienceLabel.
  ///
  /// In en, this message translates to:
  /// **'Key Experience'**
  String get editProfileExperienceLabel;

  /// No description provided for @editProfileExperienceHint.
  ///
  /// In en, this message translates to:
  /// **'Briefly describe your roles or achievements...'**
  String get editProfileExperienceHint;

  /// No description provided for @editProfileSkillsLabel.
  ///
  /// In en, this message translates to:
  /// **'Professional Skills ({count})'**
  String editProfileSkillsLabel(Object count);

  /// No description provided for @editProfileReposition.
  ///
  /// In en, this message translates to:
  /// **'REPOSITION'**
  String get editProfileReposition;

  /// No description provided for @editProfileRepositionDone.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get editProfileRepositionDone;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Out?'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out from the galaxy?'**
  String get signOutConfirmMessage;

  /// No description provided for @signOutConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutConfirmButton;

  /// No description provided for @settingsBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settingsBackupTitle;

  /// No description provided for @settingsBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Secure your chats to IPFS'**
  String get settingsBackupSubtitle;

  /// No description provided for @backupDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'IPFS Signal Backup'**
  String get backupDialogTitle;

  /// No description provided for @backupPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Backup Password'**
  String get backupPasswordLabel;

  /// No description provided for @backupPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Min 8 characters'**
  String get backupPasswordHint;

  /// No description provided for @backupWarning.
  ///
  /// In en, this message translates to:
  /// **'WARNING: If you lose this password, your signals are lost forever. We cannot recover it.'**
  String get backupWarning;

  /// No description provided for @backupCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create Cloud Backup'**
  String get backupCreateButton;

  /// No description provided for @backupRestoreButton.
  ///
  /// In en, this message translates to:
  /// **'Restore from IPFS'**
  String get backupRestoreButton;

  /// No description provided for @appLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get appLanguageTitle;

  /// No description provided for @feedOrbitSection.
  ///
  /// In en, this message translates to:
  /// **'Feed & Orbit'**
  String get feedOrbitSection;

  /// No description provided for @autoplayVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-play Video'**
  String get autoplayVideoTitle;

  /// No description provided for @autoplayVideoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play videos automatically as you scroll'**
  String get autoplayVideoSubtitle;

  /// No description provided for @manageTopicsTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Topics'**
  String get manageTopicsTitle;

  /// No description provided for @manageTopicsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose what appears more or less in your Orbit'**
  String get manageTopicsSubtitle;

  /// No description provided for @videoResolutionTitle.
  ///
  /// In en, this message translates to:
  /// **'Video Resolution'**
  String get videoResolutionTitle;

  /// No description provided for @videoResolutionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust upload quality for videos'**
  String get videoResolutionSubtitle;

  /// No description provided for @vanishingMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Vanishing Messages'**
  String get vanishingMessagesTitle;

  /// No description provided for @vanishingOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get vanishingOff;

  /// No description provided for @vanishing30Sec.
  ///
  /// In en, this message translates to:
  /// **'30 Seconds'**
  String get vanishing30Sec;

  /// No description provided for @vanishing5Min.
  ///
  /// In en, this message translates to:
  /// **'5 Minutes'**
  String get vanishing5Min;

  /// No description provided for @vanishing1Hour.
  ///
  /// In en, this message translates to:
  /// **'1 Hour'**
  String get vanishing1Hour;

  /// No description provided for @vanishing1Day.
  ///
  /// In en, this message translates to:
  /// **'1 Day'**
  String get vanishing1Day;

  /// No description provided for @vanishing1Week.
  ///
  /// In en, this message translates to:
  /// **'1 Week'**
  String get vanishing1Week;

  /// No description provided for @sensitiveContentCadet.
  ///
  /// In en, this message translates to:
  /// **'🔒 Sensitive content. Not visible in Cadet mode.'**
  String get sensitiveContentCadet;

  /// No description provided for @sensitiveTapToReveal.
  ///
  /// In en, this message translates to:
  /// **'Sensitive — tap to reveal'**
  String get sensitiveTapToReveal;

  /// No description provided for @sensitiveTapToHide.
  ///
  /// In en, this message translates to:
  /// **'Tap to hide'**
  String get sensitiveTapToHide;

  /// No description provided for @unsendSignalTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsend Signal?'**
  String get unsendSignalTitle;

  /// No description provided for @unsendSignalBody.
  ///
  /// In en, this message translates to:
  /// **'This message will be permanently deleted for everyone.'**
  String get unsendSignalBody;

  /// No description provided for @unsendButton.
  ///
  /// In en, this message translates to:
  /// **'Unsend'**
  String get unsendButton;

  /// No description provided for @messageDeleted.
  ///
  /// In en, this message translates to:
  /// **'🚫 This message was deleted'**
  String get messageDeleted;

  /// No description provided for @radarSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Quick search'**
  String get radarSearchHint;

  /// No description provided for @radarModeMeshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch to Mesh Mode'**
  String get radarModeMeshTooltip;

  /// No description provided for @radarModeOnlineTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch to Online Mode'**
  String get radarModeOnlineTooltip;

  /// No description provided for @radarXparqsCount.
  ///
  /// In en, this message translates to:
  /// **'Xparqs'**
  String get radarXparqsCount;

  /// No description provided for @radarRadiusGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get radarRadiusGlobal;

  /// No description provided for @radarRadiusLabel.
  ///
  /// In en, this message translates to:
  /// **'radius'**
  String get radarRadiusLabel;

  /// No description provided for @radarBluetoothRange.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth range'**
  String get radarBluetoothRange;

  /// No description provided for @radarNoNearby.
  ///
  /// In en, this message translates to:
  /// **'No Xparqs nearby'**
  String get radarNoNearby;

  /// No description provided for @radarExpandRadius.
  ///
  /// In en, this message translates to:
  /// **'Expand Radius'**
  String get radarExpandRadius;

  /// No description provided for @radarNoUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found.'**
  String get radarNoUsersFound;

  /// No description provided for @orbitTitle.
  ///
  /// In en, this message translates to:
  /// **'Orbit'**
  String get orbitTitle;

  /// No description provided for @orbitSupernovaMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Supernova to Orbit'**
  String get orbitSupernovaMenuTitle;

  /// No description provided for @orbitNewPulse.
  ///
  /// In en, this message translates to:
  /// **'New Pulse'**
  String get orbitNewPulse;

  /// No description provided for @orbitQuickPhoto.
  ///
  /// In en, this message translates to:
  /// **'Quick Photo'**
  String get orbitQuickPhoto;

  /// No description provided for @orbitQuickVideo.
  ///
  /// In en, this message translates to:
  /// **'Quick Video'**
  String get orbitQuickVideo;

  /// No description provided for @orbitStarlight.
  ///
  /// In en, this message translates to:
  /// **'Starlight'**
  String get orbitStarlight;

  /// No description provided for @orbitSupernova.
  ///
  /// In en, this message translates to:
  /// **'Supernova'**
  String get orbitSupernova;

  /// No description provided for @orbitPulseLive.
  ///
  /// In en, this message translates to:
  /// **'Pulse Live'**
  String get orbitPulseLive;

  /// No description provided for @orbitFlash.
  ///
  /// In en, this message translates to:
  /// **'Flash'**
  String get orbitFlash;

  /// No description provided for @orbitComingSoon.
  ///
  /// In en, this message translates to:
  /// **'{feature}: Coming soon to Xparq Galaxy!'**
  String orbitComingSoon(Object feature);

  /// No description provided for @orbitEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'The galaxy is quiet...'**
  String get orbitEmptyTitle;

  /// No description provided for @orbitEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Be the first to launch a Pulse!'**
  String get orbitEmptySubtitle;

  /// No description provided for @orbitSignalLost.
  ///
  /// In en, this message translates to:
  /// **'Signal lost: {error}'**
  String orbitSignalLost(Object error);

  /// No description provided for @chatListTitle.
  ///
  /// In en, this message translates to:
  /// **'Signal'**
  String get chatListTitle;

  /// No description provided for @chatListSavedMe.
  ///
  /// In en, this message translates to:
  /// **'Saved (Me)'**
  String get chatListSavedMe;

  /// No description provided for @chatListCreateChat.
  ///
  /// In en, this message translates to:
  /// **'Create Chat'**
  String get chatListCreateChat;

  /// No description provided for @chatListTabXparqs.
  ///
  /// In en, this message translates to:
  /// **'Xparqs'**
  String get chatListTabXparqs;

  /// No description provided for @chatListTabGroups.
  ///
  /// In en, this message translates to:
  /// **'Group Signals'**
  String get chatListTabGroups;

  /// No description provided for @chatListTabUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get chatListTabUnread;

  /// No description provided for @chatListOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Signal Lost'**
  String get chatListOfflineTitle;

  /// No description provided for @chatListOfflineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t connect to the relay. Please check your data connection.'**
  String get chatListOfflineSubtitle;

  /// No description provided for @chatListRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry Connection'**
  String get chatListRetry;

  /// No description provided for @chatListReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting to Signal Relay…'**
  String get chatListReconnecting;

  /// No description provided for @chatListEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No signals yet'**
  String get chatListEmptyTitle;

  /// No description provided for @chatListEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Invite an Xparq with a QR code\n(in the sidebar) to begin!'**
  String get chatListEmptySubtitle;

  /// No description provided for @chatListRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Signal Requests'**
  String get chatListRequestsTitle;

  /// No description provided for @chatListRequestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} messages from non-friends'**
  String chatListRequestsSubtitle(Object count);

  /// No description provided for @chatListGroupDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Group Signal'**
  String get chatListGroupDefaultName;

  /// No description provided for @chatListStartConversation.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation'**
  String get chatListStartConversation;

  /// No description provided for @chatListEncryptedMessage.
  ///
  /// In en, this message translates to:
  /// **'🔒 Encrypted message'**
  String get chatListEncryptedMessage;

  /// No description provided for @profileErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading profile: {error}'**
  String profileErrorLoading(Object error);

  /// No description provided for @profileGuestMode.
  ///
  /// In en, this message translates to:
  /// **'Guest Mode'**
  String get profileGuestMode;

  /// No description provided for @profileStandardView.
  ///
  /// In en, this message translates to:
  /// **'Standard View'**
  String get profileStandardView;

  /// No description provided for @profileSocialLayout.
  ///
  /// In en, this message translates to:
  /// **'Social Layout (Full)'**
  String get profileSocialLayout;

  /// No description provided for @profileViewIdentity.
  ///
  /// In en, this message translates to:
  /// **'View Identity'**
  String get profileViewIdentity;

  /// No description provided for @profileRepositionIdentity.
  ///
  /// In en, this message translates to:
  /// **'Reposition Identity'**
  String get profileRepositionIdentity;

  /// No description provided for @profileCaptureIdentity.
  ///
  /// In en, this message translates to:
  /// **'Capture New Identity'**
  String get profileCaptureIdentity;

  /// No description provided for @profileTransmitPhoto.
  ///
  /// In en, this message translates to:
  /// **'Transmit Photo'**
  String get profileTransmitPhoto;

  /// No description provided for @profileModifyProfile.
  ///
  /// In en, this message translates to:
  /// **'Modify Stellar Profile'**
  String get profileModifyProfile;

  /// No description provided for @profileAlignment.
  ///
  /// In en, this message translates to:
  /// **'Stellar Position (Alignment)'**
  String get profileAlignment;

  /// No description provided for @profileRemoveIdentity.
  ///
  /// In en, this message translates to:
  /// **'Remove Identity'**
  String get profileRemoveIdentity;

  /// No description provided for @profileAlignmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Stellar Position'**
  String get profileAlignmentTitle;

  /// No description provided for @profileLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get profileLeft;

  /// No description provided for @profileCenter.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get profileCenter;

  /// No description provided for @profileRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get profileRight;

  /// No description provided for @profileErrorUpdateAlignment.
  ///
  /// In en, this message translates to:
  /// **'Error updating alignment: {error}'**
  String profileErrorUpdateAlignment(Object error);

  /// No description provided for @profileErrorRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Error removing profile photo: {error}'**
  String profileErrorRemovePhoto(Object error);

  /// No description provided for @profileAddCover.
  ///
  /// In en, this message translates to:
  /// **'Add Interstellar Cover'**
  String get profileAddCover;

  /// No description provided for @profileCaptureCover.
  ///
  /// In en, this message translates to:
  /// **'Capture New Cover'**
  String get profileCaptureCover;

  /// No description provided for @profileRepositionCover.
  ///
  /// In en, this message translates to:
  /// **'Reposition Cover'**
  String get profileRepositionCover;

  /// No description provided for @profileRemoveCover.
  ///
  /// In en, this message translates to:
  /// **'Remove Cover Photo'**
  String get profileRemoveCover;

  /// No description provided for @profileErrorRemoveCover.
  ///
  /// In en, this message translates to:
  /// **'Error removing cover: {error}'**
  String profileErrorRemoveCover(Object error);

  /// No description provided for @profileErrorSavePosition.
  ///
  /// In en, this message translates to:
  /// **'Error saving position: {error}'**
  String profileErrorSavePosition(Object error);

  /// No description provided for @profileUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated successfully!'**
  String get profileUpdateSuccess;

  /// No description provided for @profileErrorSavingPosition.
  ///
  /// In en, this message translates to:
  /// **'Error saving position: {error}'**
  String profileErrorSavingPosition(Object error);

  /// No description provided for @profilePictureUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated successfully!'**
  String get profilePictureUpdateSuccess;

  /// No description provided for @profileErrorUpdatingPicture.
  ///
  /// In en, this message translates to:
  /// **'Error updating profile picture: {error}'**
  String profileErrorUpdatingPicture(Object error);

  /// No description provided for @profileDragCover.
  ///
  /// In en, this message translates to:
  /// **'Drag Cover to Reposition'**
  String get profileDragCover;

  /// No description provided for @profileDragAvatar.
  ///
  /// In en, this message translates to:
  /// **'Drag Avatar to Reposition'**
  String get profileDragAvatar;

  /// No description provided for @savePosition.
  ///
  /// In en, this message translates to:
  /// **'Save Position'**
  String get savePosition;

  /// No description provided for @profileErrorOpeningChat.
  ///
  /// In en, this message translates to:
  /// **'Error opening chat: {error}'**
  String profileErrorOpeningChat(Object error);

  /// No description provided for @requestContact.
  ///
  /// In en, this message translates to:
  /// **'Request Contact'**
  String get requestContact;

  /// No description provided for @contactRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Contact request sent'**
  String get contactRequestSent;

  /// No description provided for @spark.
  ///
  /// In en, this message translates to:
  /// **'Spark'**
  String get spark;

  /// No description provided for @signals.
  ///
  /// In en, this message translates to:
  /// **'Signals'**
  String get signals;

  /// No description provided for @lightYears.
  ///
  /// In en, this message translates to:
  /// **'Light-Years'**
  String get lightYears;

  /// No description provided for @planets.
  ///
  /// In en, this message translates to:
  /// **'Planets'**
  String get planets;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @pulses.
  ///
  /// In en, this message translates to:
  /// **'Pulses'**
  String get pulses;

  /// No description provided for @warps.
  ///
  /// In en, this message translates to:
  /// **'Warps'**
  String get warps;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @extendedBio.
  ///
  /// In en, this message translates to:
  /// **'Extended Bio'**
  String get extendedBio;

  /// No description provided for @basicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic Info'**
  String get basicInfo;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @tel.
  ///
  /// In en, this message translates to:
  /// **'Tel'**
  String get tel;

  /// No description provided for @professionalAcademic.
  ///
  /// In en, this message translates to:
  /// **'Professional & Academic'**
  String get professionalAcademic;

  /// No description provided for @occupation.
  ///
  /// In en, this message translates to:
  /// **'Occupation'**
  String get occupation;

  /// No description provided for @workplace.
  ///
  /// In en, this message translates to:
  /// **'Workplace'**
  String get workplace;

  /// No description provided for @education.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get education;

  /// No description provided for @experience.
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get experience;

  /// No description provided for @editProfileContactInfo.
  ///
  /// In en, this message translates to:
  /// **'CONTACT INFO'**
  String get editProfileContactInfo;

  /// No description provided for @editProfileContactInfoDesc.
  ///
  /// In en, this message translates to:
  /// **'This info is only visible on your profile (with eye-toggle) and shared via contact requests.'**
  String get editProfileContactInfoDesc;

  /// No description provided for @editProfileContactEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact Email'**
  String get editProfileContactEmailLabel;

  /// No description provided for @editProfileContactPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get editProfileContactPhoneLabel;

  /// No description provided for @editProfileSelectGender.
  ///
  /// In en, this message translates to:
  /// **'SELECT GENDER'**
  String get editProfileSelectGender;

  /// No description provided for @editProfileSelectMbti.
  ///
  /// In en, this message translates to:
  /// **'SELECT MBTI'**
  String get editProfileSelectMbti;

  /// No description provided for @editProfileSelectZodiac.
  ///
  /// In en, this message translates to:
  /// **'SELECT ZODIAC'**
  String get editProfileSelectZodiac;

  /// No description provided for @editProfileSelectBloodType.
  ///
  /// In en, this message translates to:
  /// **'SELECT BLOOD TYPE'**
  String get editProfileSelectBloodType;

  /// No description provided for @editProfileChangeImage.
  ///
  /// In en, this message translates to:
  /// **'Change Image'**
  String get editProfileChangeImage;

  /// No description provided for @editProfileDeleteImage.
  ///
  /// In en, this message translates to:
  /// **'Delete Image'**
  String get editProfileDeleteImage;

  /// No description provided for @pulseSentSignal.
  ///
  /// In en, this message translates to:
  /// **'Pulse sent to Signal 📡'**
  String get pulseSentSignal;

  /// No description provided for @pulseNoQRCode.
  ///
  /// In en, this message translates to:
  /// **'No QR code found in image'**
  String get pulseNoQRCode;

  /// No description provided for @pulseScannedCode.
  ///
  /// In en, this message translates to:
  /// **'Scanned: {code}'**
  String pulseScannedCode(Object code);

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon ✨'**
  String get comingSoon;

  /// No description provided for @errorSavingProfile.
  ///
  /// In en, this message translates to:
  /// **'Error saving profile: {error}'**
  String errorSavingProfile(Object error);

  /// No description provided for @errorGettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Error getting location: {error}'**
  String errorGettingLocation(Object error);

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get locationPermissionDenied;

  /// No description provided for @locationUpdated.
  ///
  /// In en, this message translates to:
  /// **'Location updated to {province}'**
  String locationUpdated(Object province);

  /// No description provided for @locationProvinceError.
  ///
  /// In en, this message translates to:
  /// **'Could not determine Thailand province'**
  String get locationProvinceError;

  /// No description provided for @daysCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String daysCount(num count);

  /// No description provided for @messagesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 message} other{{count} messages}}'**
  String messagesCount(num count);

  /// No description provided for @pulseUnwarp.
  ///
  /// In en, this message translates to:
  /// **'Unwarp from Profile'**
  String get pulseUnwarp;

  /// No description provided for @pulseWarp.
  ///
  /// In en, this message translates to:
  /// **'Warp to Profile'**
  String get pulseWarp;

  /// No description provided for @pulseRemoveWarpDesc.
  ///
  /// In en, this message translates to:
  /// **'Remove this pulse from your profile'**
  String get pulseRemoveWarpDesc;

  /// No description provided for @pulseAddWarpDesc.
  ///
  /// In en, this message translates to:
  /// **'Show this pulse on your profile'**
  String get pulseAddWarpDesc;

  /// No description provided for @pulseSendInSignal.
  ///
  /// In en, this message translates to:
  /// **'Send in Signal (Warp to Xparqs)'**
  String get pulseSendInSignal;

  /// No description provided for @pulseShareFriendsDesc.
  ///
  /// In en, this message translates to:
  /// **'Share to your friends or Saved (Me)'**
  String get pulseShareFriendsDesc;

  /// No description provided for @pulseWarpedSuccess.
  ///
  /// In en, this message translates to:
  /// **'🚀 Pulse warped!'**
  String get pulseWarpedSuccess;

  /// No description provided for @pulseWarpRemoved.
  ///
  /// In en, this message translates to:
  /// **'↩️ Warp removed'**
  String get pulseWarpRemoved;

  /// No description provided for @pulseWarpToTitle.
  ///
  /// In en, this message translates to:
  /// **'Warp to...'**
  String get pulseWarpToTitle;

  /// No description provided for @pulseWarpMeMeDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep this pulse for yourself'**
  String get pulseWarpMeMeDesc;

  /// No description provided for @pulseWarpInviteFriends.
  ///
  /// In en, this message translates to:
  /// **'Invite friends to see them here!'**
  String get pulseWarpInviteFriends;

  /// No description provided for @pulseWarpMessage.
  ///
  /// In en, this message translates to:
  /// **'🚀 I warped a pulse from @{author}:\n\n\"{content}\"'**
  String pulseWarpMessage(Object author, Object content);

  /// No description provided for @pulseDeletePulse.
  ///
  /// In en, this message translates to:
  /// **'Delete Pulse'**
  String get pulseDeletePulse;

  /// No description provided for @pulseReportPulse.
  ///
  /// In en, this message translates to:
  /// **'Report Pulse'**
  String get pulseReportPulse;

  /// No description provided for @pulseEditPulse.
  ///
  /// In en, this message translates to:
  /// **'Edit Pulse'**
  String get pulseEditPulse;

  /// No description provided for @pulseEditHint.
  ///
  /// In en, this message translates to:
  /// **'Edit your pulse...'**
  String get pulseEditHint;

  /// No description provided for @pulseDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Pulse?'**
  String get pulseDeleteConfirmTitle;

  /// No description provided for @pulseDeleteConfirmDesc.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get pulseDeleteConfirmDesc;

  /// No description provided for @pulseRevealTitle.
  ///
  /// In en, this message translates to:
  /// **'Reveal Black Hole Content?'**
  String get pulseRevealTitle;

  /// No description provided for @pulseRevealDesc.
  ///
  /// In en, this message translates to:
  /// **'This pulse contains sensitive content. Are you sure you want to view it?'**
  String get pulseRevealDesc;

  /// No description provided for @reveal.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get reveal;

  /// No description provided for @scannerNoQRFound.
  ///
  /// In en, this message translates to:
  /// **'No QR code found in image'**
  String get scannerNoQRFound;

  /// No description provided for @scannerErrorAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Error analyzing image: {error}'**
  String scannerErrorAnalyzing(Object error);

  /// No description provided for @scannerLaunchError.
  ///
  /// In en, this message translates to:
  /// **'Could not launch {code}'**
  String scannerLaunchError(Object code);

  /// No description provided for @scannerInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Signal Invite'**
  String get scannerInviteTitle;

  /// No description provided for @scannerInviteDesc.
  ///
  /// In en, this message translates to:
  /// **'Do you want to start a secure signal with {uid}?\n\nSignals from non-friends will appear in your Signal Requests folder.'**
  String scannerInviteDesc(Object uid);

  /// No description provided for @scannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scannerTitle;

  /// No description provided for @scannerGalleryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pick from Gallery'**
  String get scannerGalleryTooltip;

  /// No description provided for @scannerPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required'**
  String get scannerPermissionRequired;

  /// No description provided for @scannerGrantAccess.
  ///
  /// In en, this message translates to:
  /// **'Grant Access'**
  String get scannerGrantAccess;

  /// No description provided for @scannerCameraError.
  ///
  /// In en, this message translates to:
  /// **'Camera Error: {error}'**
  String scannerCameraError(Object error);

  /// No description provided for @scannerRealDeviceRequired.
  ///
  /// In en, this message translates to:
  /// **'Make sure you are on a real device\nwith a working camera.'**
  String get scannerRealDeviceRequired;

  /// No description provided for @scannerAlignFrame.
  ///
  /// In en, this message translates to:
  /// **'Align QR code within the frame'**
  String get scannerAlignFrame;

  /// No description provided for @scannerScannedCode.
  ///
  /// In en, this message translates to:
  /// **'Scanned: {code}'**
  String scannerScannedCode(Object code);

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorPrefix(Object message);

  /// No description provided for @failedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Failed: {message}'**
  String failedPrefix(Object message);

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @requests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get requests;

  /// No description provided for @orbiting.
  ///
  /// In en, this message translates to:
  /// **'Orbiting'**
  String get orbiting;

  /// No description provided for @requested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get requested;

  /// No description provided for @orbit.
  ///
  /// In en, this message translates to:
  /// **'Orbit'**
  String get orbit;

  /// No description provided for @orbitWantsToWithYou.
  ///
  /// In en, this message translates to:
  /// **'wants to Orbit with you'**
  String get orbitWantsToWithYou;

  /// No description provided for @pulseSavedGallery.
  ///
  /// In en, this message translates to:
  /// **'Saved to Gallery!'**
  String get pulseSavedGallery;

  /// No description provided for @pulseSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String pulseSaveFailed(Object error);

  /// No description provided for @pulseUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String pulseUploadFailed(Object error);

  /// No description provided for @disconnectConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect?'**
  String get disconnectConfirmTitle;

  /// No description provided for @appVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get appVersionLabel;

  /// No description provided for @orbitConnectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Orbit Connections'**
  String get orbitConnectionsTitle;

  /// No description provided for @orbiters.
  ///
  /// In en, this message translates to:
  /// **'Orbiters'**
  String get orbiters;

  /// No description provided for @orbitNoRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending requests.'**
  String get orbitNoRequests;

  /// No description provided for @orbitNoIncoming.
  ///
  /// In en, this message translates to:
  /// **'No incoming signals.'**
  String get orbitNoIncoming;

  /// No description provided for @orbitAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get orbitAccepted;

  /// No description provided for @orbitDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get orbitDeclined;

  /// No description provided for @orbitNoOrbiters.
  ///
  /// In en, this message translates to:
  /// **'No orbiters yet.'**
  String get orbitNoOrbiters;

  /// No description provided for @orbitNotOrbiting.
  ///
  /// In en, this message translates to:
  /// **'Not orbiting anyone.'**
  String get orbitNotOrbiting;

  /// No description provided for @orbitDisconnectDesc.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove {name} from your Orbit? This will remove the connection for both of you.'**
  String orbitDisconnectDesc(Object name);

  /// No description provided for @loadingProfile.
  ///
  /// In en, this message translates to:
  /// **'Loading profile...'**
  String get loadingProfile;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Safety'**
  String get privacyTitle;

  /// No description provided for @privacySecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get privacySecurity;

  /// No description provided for @privacyScreenLock.
  ///
  /// In en, this message translates to:
  /// **'Screen Lock'**
  String get privacyScreenLock;

  /// No description provided for @privacyScreenLockDesc.
  ///
  /// In en, this message translates to:
  /// **'Require biometrics to unlock Xparq'**
  String get privacyScreenLockDesc;

  /// No description provided for @privacyScreenLockConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm to enable/disable Screen Lock'**
  String get privacyScreenLockConfirm;

  /// No description provided for @privacyBiometricsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Biometrics not available on this device'**
  String get privacyBiometricsNotAvailable;

  /// No description provided for @privacyVisibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get privacyVisibility;

  /// No description provided for @privacyGhostModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Hide your presence from Radar and online status'**
  String get privacyGhostModeDesc;

  /// No description provided for @privacyWhoCanSeeProfile.
  ///
  /// In en, this message translates to:
  /// **'Who can see my profile'**
  String get privacyWhoCanSeeProfile;

  /// No description provided for @privacyWhoCanSeeProfileDesc.
  ///
  /// In en, this message translates to:
  /// **'Public · Friends · Private'**
  String get privacyWhoCanSeeProfileDesc;

  /// No description provided for @privacyOnlineStatus.
  ///
  /// In en, this message translates to:
  /// **'Online status'**
  String get privacyOnlineStatus;

  /// No description provided for @privacyOnlineStatusDesc.
  ///
  /// In en, this message translates to:
  /// **'Show when you\'re active'**
  String get privacyOnlineStatusDesc;

  /// No description provided for @privacyContentFiltering.
  ///
  /// In en, this message translates to:
  /// **'Content Filtering'**
  String get privacyContentFiltering;

  /// No description provided for @privacyAdultOnly.
  ///
  /// In en, this message translates to:
  /// **'Available for users aged 18+'**
  String get privacyAdultOnly;

  /// No description provided for @privacyNsfwOn.
  ///
  /// In en, this message translates to:
  /// **'On · Sensitive content may appear'**
  String get privacyNsfwOn;

  /// No description provided for @privacyNsfwOff.
  ///
  /// In en, this message translates to:
  /// **'Off · Sensitive content is hidden'**
  String get privacyNsfwOff;

  /// No description provided for @privacyHiddenWords.
  ///
  /// In en, this message translates to:
  /// **'Hidden words'**
  String get privacyHiddenWords;

  /// No description provided for @privacyHiddenWordsDesc.
  ///
  /// In en, this message translates to:
  /// **'Filter offensive words from comments'**
  String get privacyHiddenWordsDesc;

  /// No description provided for @privacyInteractions.
  ///
  /// In en, this message translates to:
  /// **'Interactions'**
  String get privacyInteractions;

  /// No description provided for @privacyWhoCanDM.
  ///
  /// In en, this message translates to:
  /// **'Who can DM me'**
  String get privacyWhoCanDM;

  /// No description provided for @privacyWhoCanDMDesc.
  ///
  /// In en, this message translates to:
  /// **'Everyone · Orbits only · No one'**
  String get privacyWhoCanDMDesc;

  /// No description provided for @privacyWhoCanComment.
  ///
  /// In en, this message translates to:
  /// **'Who can comment'**
  String get privacyWhoCanComment;

  /// No description provided for @privacyWhoCanCommentDesc.
  ///
  /// In en, this message translates to:
  /// **'Everyone · Orbits only · No one'**
  String get privacyWhoCanCommentDesc;

  /// No description provided for @privacyNsfwConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Black Hole Zone'**
  String get privacyNsfwConfirmTitle;

  /// No description provided for @privacyNsfwConfirmDesc.
  ///
  /// In en, this message translates to:
  /// **'You must be 18+ to enable this mode.\n\nWhen enabled, you may see content inappropriate for minors.\n\nConfirm you are 18+ and accept such content?'**
  String get privacyNsfwConfirmDesc;

  /// No description provided for @privacyNsfwConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm · Open 18+'**
  String get privacyNsfwConfirmButton;

  /// No description provided for @chatDeleteSignal.
  ///
  /// In en, this message translates to:
  /// **'Delete Signal?'**
  String get chatDeleteSignal;

  /// No description provided for @chatProfileLoading.
  ///
  /// In en, this message translates to:
  /// **'Profile still loading. Please wait.'**
  String get chatProfileLoading;

  /// No description provided for @chatFailedSend.
  ///
  /// In en, this message translates to:
  /// **'Failed to send message: {error}'**
  String chatFailedSend(Object error);

  /// No description provided for @groupNew.
  ///
  /// In en, this message translates to:
  /// **'New Group'**
  String get groupNew;

  /// No description provided for @groupEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a group name'**
  String get groupEnterName;

  /// No description provided for @groupSelectParticipant.
  ///
  /// In en, this message translates to:
  /// **'Select at least one participant'**
  String get groupSelectParticipant;

  /// No description provided for @groupAddFriends.
  ///
  /// In en, this message translates to:
  /// **'Add friends to start a group!'**
  String get groupAddFriends;

  /// No description provided for @offlineDashboard.
  ///
  /// In en, this message translates to:
  /// **'Go to Offline Dashboard'**
  String get offlineDashboard;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @readRequest.
  ///
  /// In en, this message translates to:
  /// **'Read request?'**
  String get readRequest;

  /// No description provided for @deleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete Forever'**
  String get deleteForever;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get deleteAccount;

  /// No description provided for @vanishingMessages.
  ///
  /// In en, this message translates to:
  /// **'Vanishing Messages'**
  String get vanishingMessages;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group Name'**
  String get groupName;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for your signal group'**
  String get groupNameHint;

  /// No description provided for @groupSelectParticipants.
  ///
  /// In en, this message translates to:
  /// **'Select Participants'**
  String get groupSelectParticipants;

  /// No description provided for @groupCreate.
  ///
  /// In en, this message translates to:
  /// **'CREATE'**
  String get groupCreate;

  /// No description provided for @blockedXparqs.
  ///
  /// In en, this message translates to:
  /// **'Blocked Xparqs'**
  String get blockedXparqs;

  /// No description provided for @noBlockedXparqs.
  ///
  /// In en, this message translates to:
  /// **'No blocked Xparqs'**
  String get noBlockedXparqs;

  /// No description provided for @blockedSparqs.
  ///
  /// In en, this message translates to:
  /// **'Blocked Xparqs'**
  String get blockedSparqs;

  /// No description provided for @noBlockedSparqs.
  ///
  /// In en, this message translates to:
  /// **'No blocked Xparqs'**
  String get noBlockedSparqs;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @unblockConfirmDesc.
  ///
  /// In en, this message translates to:
  /// **'This Xparq will be able to see your profile and send you signals again.'**
  String get unblockConfirmDesc;

  /// No description provided for @read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// No description provided for @blocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get blocked;

  /// No description provided for @radarOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline Mode is now available via'**
  String get radarOfflineTitle;

  /// No description provided for @radarOfflineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'the Offline Dashboard'**
  String get radarOfflineSubtitle;

  /// No description provided for @pulseDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard Pulse?'**
  String get pulseDiscardTitle;

  /// No description provided for @pulseDiscardDesc.
  ///
  /// In en, this message translates to:
  /// **'If you go back now, your capture will be discarded.'**
  String get pulseDiscardDesc;

  /// No description provided for @pulseKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get pulseKeep;

  /// No description provided for @pulseDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get pulseDiscard;

  /// No description provided for @pulseSupernova.
  ///
  /// In en, this message translates to:
  /// **'SUPERNOVA'**
  String get pulseSupernova;

  /// No description provided for @pulseWarpGearActive.
  ///
  /// In en, this message translates to:
  /// **'WARP GEAR ACTIVE'**
  String get pulseWarpGearActive;

  /// No description provided for @pulsePreview.
  ///
  /// In en, this message translates to:
  /// **'PREVIEW'**
  String get pulsePreview;

  /// No description provided for @pulseOrbitQuestion.
  ///
  /// In en, this message translates to:
  /// **'What\'s in your orbit?'**
  String get pulseOrbitQuestion;

  /// No description provided for @pulseSupernovaHint.
  ///
  /// In en, this message translates to:
  /// **'Add a story to your Supernova...'**
  String get pulseSupernovaHint;

  /// No description provided for @pulseNebula.
  ///
  /// In en, this message translates to:
  /// **'NEBULA'**
  String get pulseNebula;

  /// No description provided for @pulsePostToOrbit.
  ///
  /// In en, this message translates to:
  /// **'POST TO ORBIT'**
  String get pulsePostToOrbit;

  /// No description provided for @pulseLaunchSupernova.
  ///
  /// In en, this message translates to:
  /// **'ADD TO SUPERNOVA'**
  String get pulseLaunchSupernova;

  /// No description provided for @orbitWarpGearTitle.
  ///
  /// In en, this message translates to:
  /// **'WARP GEAR'**
  String get orbitWarpGearTitle;

  /// No description provided for @orbitNewPulseTitle.
  ///
  /// In en, this message translates to:
  /// **'NEW PULSE'**
  String get orbitNewPulseTitle;

  /// No description provided for @cosmicAlbums.
  ///
  /// In en, this message translates to:
  /// **'COSMIC ALBUMS'**
  String get cosmicAlbums;

  /// No description provided for @profileAlbum.
  ///
  /// In en, this message translates to:
  /// **'ASTRONAUT\nPROFILE'**
  String get profileAlbum;

  /// No description provided for @coverAlbum.
  ///
  /// In en, this message translates to:
  /// **'NEBULA\nCOVERS'**
  String get coverAlbum;

  /// No description provided for @pulseAlbum.
  ///
  /// In en, this message translates to:
  /// **'PULSE\nMEMORIES'**
  String get pulseAlbum;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'ar',
        'bn',
        'de',
        'en',
        'es',
        'fr',
        'hi',
        'id',
        'it',
        'ja',
        'ko',
        'lo',
        'ms',
        'pt',
        'ru',
        'th',
        'tr',
        'uk',
        'vi',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'bn':
      return AppLocalizationsBn();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'id':
      return AppLocalizationsId();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'lo':
      return AppLocalizationsLo();
    case 'ms':
      return AppLocalizationsMs();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'th':
      return AppLocalizationsTh();
    case 'tr':
      return AppLocalizationsTr();
    case 'uk':
      return AppLocalizationsUk();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
