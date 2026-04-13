// lib/core/constants/language_data.dart

class LanguageData {
  final String name;
  final String localName;
  final String code;

  const LanguageData({
    required this.name,
    required this.localName,
    required this.code,
  });
}

const List<LanguageData> allLanguages = [
  LanguageData(name: 'English', localName: 'English', code: 'en'),
  LanguageData(name: 'Thai', localName: 'ไทย', code: 'th'),
  LanguageData(name: 'Chinese', localName: '中文', code: 'zh'),
  LanguageData(name: 'Japanese', localName: '日本語', code: 'ja'),
  LanguageData(name: 'Korean', localName: '한국어', code: 'ko'),
  LanguageData(name: 'Russian', localName: 'Русский', code: 'ru'),
  LanguageData(name: 'Ukrainian', localName: 'Українська', code: 'uk'),
  LanguageData(name: 'Arabic', localName: 'العربية', code: 'ar'),
  LanguageData(name: 'Bengali', localName: 'বাংলা', code: 'bn'),
  LanguageData(name: 'French', localName: 'Français', code: 'fr'),
  LanguageData(name: 'German', localName: 'Deutsch', code: 'de'),
  LanguageData(name: 'Hindi', localName: 'हिन्दी', code: 'hi'),
  LanguageData(name: 'Indonesian', localName: 'Bahasa Indonesia', code: 'id'),
  LanguageData(name: 'Italian', localName: 'Italiano', code: 'it'),
  LanguageData(name: 'Malay', localName: 'Bahasa Melayu', code: 'ms'),
  LanguageData(name: 'Portuguese', localName: 'Português', code: 'pt'),
  LanguageData(name: 'Spanish', localName: 'Español', code: 'es'),
  LanguageData(name: 'Turkish', localName: 'Türkçe', code: 'tr'),
  LanguageData(name: 'Vietnamese', localName: 'Tiếng Việt', code: 'vi'),
  LanguageData(name: 'Lao', localName: 'ລາວ', code: 'lo'),
  // Cambodian (km) is excluded as per request
];

List<LanguageData> getSortedLanguages() {
  // English, Thai, Chinese, Japanese first
  final priorityCodes = ['en', 'th', 'zh', 'ja'];

  final priorityList =
      allLanguages.where((l) => priorityCodes.contains(l.code)).toList()..sort(
        (a, b) => priorityCodes
            .indexOf(a.code)
            .compareTo(priorityCodes.indexOf(b.code)),
      );

  final othersList =
      allLanguages.where((l) => !priorityCodes.contains(l.code)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  return [...priorityList, ...othersList];
}
