// lib/core/utils/stellar_identity_helper.dart

import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class StellarIdentityHelper {
  static List<Map<String, String>> getMbtiTypes() {
    return const [
      {'type': 'INTJ', 'icon': '🧙‍♂️'},
      {'type': 'INTP', 'icon': '🧪'},
      {'type': 'ENTJ', 'icon': '👨‍💼'},
      {'type': 'ENTP', 'icon': '🎤'},
      {'type': 'INFJ', 'icon': '🛡️'},
      {'type': 'INFP', 'icon': '🎨'},
      {'type': 'ENFJ', 'icon': '🗣️'},
      {'type': 'ENFP', 'icon': '🎈'},
      {'type': 'ISTJ', 'icon': '📏'},
      {'type': 'ISFJ', 'icon': '🫂'},
      {'type': 'ESTJ', 'icon': '📋'},
      {'type': 'ESFJ', 'icon': '🤝'},
      {'type': 'ISTP', 'icon': '⚙️'},
      {'type': 'ISFP', 'icon': '🖌️'},
      {'type': 'ESTP', 'icon': '⚡'},
      {'type': 'ESFP', 'icon': '🎭'},
    ];
  }

  static List<Map<String, String>> getEnneagramTypes(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      {'type': '1', 'name': l10n.enneagram1, 'icon': '⚖️'},
      {'type': '2', 'name': l10n.enneagram2, 'icon': '🤝'},
      {'type': '3', 'name': l10n.enneagram3, 'icon': '🏆'},
      {'type': '4', 'name': l10n.enneagram4, 'icon': '🎨'},
      {'type': '5', 'name': l10n.enneagram5, 'icon': '🔬'},
      {'type': '6', 'name': l10n.enneagram6, 'icon': '🛡️'},
      {'type': '7', 'name': l10n.enneagram7, 'icon': '🎈'},
      {'type': '8', 'name': l10n.enneagram8, 'icon': '👊'},
      {'type': '9', 'name': l10n.enneagram9, 'icon': '🕊️'},
    ];
  }

  static List<Map<String, String>> getZodiacTypes(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      {'type': 'Aries', 'name': l10n.zodiacAries, 'icon': '♈'},
      {'type': 'Taurus', 'name': l10n.zodiacTaurus, 'icon': '♉'},
      {'type': 'Gemini', 'name': l10n.zodiacGemini, 'icon': '♊'},
      {'type': 'Cancer', 'name': l10n.zodiacCancer, 'icon': '♋'},
      {'type': 'Leo', 'name': l10n.zodiacLeo, 'icon': '♌'},
      {'type': 'Virgo', 'name': l10n.zodiacVirgo, 'icon': '♍'},
      {'type': 'Libra', 'name': l10n.zodiacLibra, 'icon': '♎'},
      {'type': 'Scorpio', 'name': l10n.zodiacScorpio, 'icon': '♏'},
      {'type': 'Sagittarius', 'name': l10n.zodiacSagittarius, 'icon': '♐'},
      {'type': 'Capricorn', 'name': l10n.zodiacCapricorn, 'icon': '♑'},
      {'type': 'Aquarius', 'name': l10n.zodiacAquarius, 'icon': '♒'},
      {'type': 'Pisces', 'name': l10n.zodiacPisces, 'icon': '♓'},
    ];
  }

  static List<Map<String, String>> getBloodTypes(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      {'type': 'A', 'name': l10n.bloodA, 'icon': '🅰️'},
      {'type': 'B', 'name': l10n.bloodB, 'icon': '🅱️'},
      {'type': 'AB', 'name': l10n.bloodAB, 'icon': '🆎'},
      {'type': 'O', 'name': l10n.bloodO, 'icon': '🅾️'},
    ];
  }

  static String getIconForMbti(String? mbti) {
    if (mbti == null) return '🧠';
    return getMbtiTypes().firstWhere(
      (m) => m['type'] == mbti,
      orElse: () => {'icon': '🧠'},
    )['icon']!;
  }

  static String getIconForZodiac(String? zodiac) {
    if (zodiac == null) return '✨';
    try {
      // Find by type (name in English)
      return const [
        {'type': 'Aries', 'icon': '♈'},
        {'type': 'Taurus', 'icon': '♉'},
        {'type': 'Gemini', 'icon': '♊'},
        {'type': 'Cancer', 'icon': '♋'},
        {'type': 'Leo', 'icon': '♌'},
        {'type': 'Virgo', 'icon': '♍'},
        {'type': 'Libra', 'icon': '♎'},
        {'type': 'Scorpio', 'icon': '♏'},
        {'type': 'Sagittarius', 'icon': '♐'},
        {'type': 'Capricorn', 'icon': '♑'},
        {'type': 'Aquarius', 'icon': '♒'},
        {'type': 'Pisces', 'icon': '♓'},
      ].firstWhere((m) => m['type'] == zodiac, orElse: () => {'icon': '✨'})['icon']!;
    } catch (_) {
      return '✨';
    }
  }

  static String getIconForBloodType(String? bloodType) {
    if (bloodType == null) return '🩸';
    return const [
      {'type': 'A', 'icon': '🅰️'},
      {'type': 'B', 'icon': '🅱️'},
      {'type': 'AB', 'icon': '🆎'},
      {'type': 'O', 'icon': '🅾️'},
    ].firstWhere((m) => m['type'] == bloodType, orElse: () => {'icon': '🩸'})['icon']!;
  }
}
