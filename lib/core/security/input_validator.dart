import 'validators/auth_validator.dart';
import 'validators/user_validator.dart';
import 'validators/chat_validator.dart';
import 'validators/report_validator.dart';
import 'validators/common_validator.dart';

class InputValidator {
  static String? email(String? v) => AuthValidator.email(v);
  static String? password(String? v) => AuthValidator.password(v);
  static String? otp(String? v) => AuthValidator.otp(v);

  static String? xparqName(String? v) => UserValidator.xparqName(v);
  static String? bio(String? v) => UserValidator.bio(v);

  static String? message(String? v) => ChatValidator.message(v);

  static String? reportDetail(String? v) => ReportValidator.detail(v);

  static String? phone(String? v) => CommonValidator.phoneNumber(v);
}