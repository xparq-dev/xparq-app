// lib/core/utils/mbti_helper.dart

class MbtiHelper {
  static String getIcon(String mbti) {
    final upperMbti = mbti.toUpperCase().trim();
    switch (upperMbti) {
      // Analysts
      case 'INTJ':
        return '🧠';
      case 'INTP':
        return '🧪';
      case 'ENTJ':
        return '🔱';
      case 'ENTP':
        return '💡';
      // Diplomats
      case 'INFJ':
        return '🕯️';
      case 'INFP':
        return '🦋';
      case 'ENFJ':
        return '🤝';
      case 'ENFP':
        return '✨';
      // Sentinels
      case 'ISTJ':
        return '📜';
      case 'ISFJ':
        return '🌺';
      case 'ESTJ':
        return '⚖️';
      case 'ESFJ':
        return '🍎';
      // Explorers
      case 'ISTP':
        return '🛠️';
      case 'ISFP':
        return '🎨';
      case 'ESTP':
        return '⚡';
      case 'ESFP':
        return '🎤';
      default:
        return '🌌'; // Default galaxy icon if not found
    }
  }

  static String getWithIcon(String mbti) {
    if (mbti.isEmpty) return '';
    return '${getIcon(mbti)} $mbti';
  }
}
