import 'dart:convert';

import 'package:http/http.dart' as http;

class RiskAnalysisResult {
  const RiskAnalysisResult({
    required this.riskLevel,
    required this.aiScore,
  });

  final String riskLevel;
  final int aiScore;
}

const String _aiRiskServiceBaseUrl = 'http://127.0.0.1:8000';

const List<String> _highRiskKeywords = [
  'kan',
  'kaniyor',
  'yarali',
  'araba carpti',
  'hareket etmiyor',
  'nefes alamiyor',
  'olmek uzere',
  'acil',
  'kirik',
  'baygin',
];

const List<String> _mediumRiskKeywords = [
  'hasta',
  'ac',
  'susuz',
  'bitkin',
  'zayif',
  'usuyor',
  'kayboldu',
  'halsiz',
  'terk edilmis',
];

RiskAnalysisResult analyzeReportRisk(String descriptionRaw) {
  final text = _normalize(descriptionRaw);
  var score = 0;

  for (final keyword in _highRiskKeywords) {
    if (text.contains(keyword)) score += 30;
  }
  for (final keyword in _mediumRiskKeywords) {
    if (text.contains(keyword)) score += 15;
  }

  final riskLevel = switch (score) {
    >= 60 => 'Yüksek Risk',
    >= 25 => 'Orta Risk',
    _ => 'Düşük Risk',
  };

  return RiskAnalysisResult(riskLevel: riskLevel, aiScore: score);
}

Future<RiskAnalysisResult> analyzeRiskWithAI(String descriptionRaw) async {
  final fallback = analyzeReportRisk(descriptionRaw);
  final description = descriptionRaw.trim();
  if (description.isEmpty) {
    return const RiskAnalysisResult(riskLevel: 'Belirlenmedi', aiScore: 0);
  }

  try {
    final uri = Uri.parse('$_aiRiskServiceBaseUrl/predict-risk');
    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'description': description}),
        )
        .timeout(const Duration(seconds: 4));

    if (response.statusCode != 200) return fallback;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return fallback;
    final map = Map<String, dynamic>.from(decoded);

    final riskLevelRaw = map['risk_level']?.toString().trim();
    final scoreRaw = map['score'];
    final score = scoreRaw is num
        ? scoreRaw.toInt()
        : int.tryParse(scoreRaw?.toString() ?? '');
    if (riskLevelRaw == null || riskLevelRaw.isEmpty || score == null) {
      return fallback;
    }

    return RiskAnalysisResult(riskLevel: riskLevelRaw, aiScore: score);
  } catch (_) {
    return fallback;
  }
}

String _normalize(String input) {
  return input
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('Ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('Ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('Ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('Ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll('Ç', 'c');
}
