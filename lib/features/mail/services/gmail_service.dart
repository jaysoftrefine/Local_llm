import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/email_message.dart';

class GmailService {
  final http.Client _client;

  GmailService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<EmailMessage>> fetchRecentMessages(
    String accessToken, {
    int limit = 100,
  }) async {
    final messages = <EmailMessage>[];
    String? pageToken;

    while (messages.length < limit) {
      final query = <String, String>{
        'maxResults': '${(limit - messages.length).clamp(1, 100)}',
        'q': 'in:anywhere -in:spam -in:trash newer_than:2y',
      };
      if (pageToken != null) query['pageToken'] = pageToken;

      final listResponse = await _get(
        Uri.https('gmail.googleapis.com', '/gmail/v1/users/me/messages', query),
        accessToken,
      );
      final list = jsonDecode(listResponse.body) as Map<String, dynamic>;
      final ids = (list['messages'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => item['id'] as String?)
          .whereType<String>()
          .toList();

      for (var start = 0; start < ids.length; start += 5) {
        final batch = ids.skip(start).take(5);
        final fetched = await Future.wait(
          batch.map((id) => _fetchMessage(id, accessToken)),
        );
        messages.addAll(fetched.whereType<EmailMessage>());
      }

      pageToken = list['nextPageToken'] as String?;
      if (pageToken == null || ids.isEmpty) break;
    }

    messages.sort((a, b) => b.date.compareTo(a.date));
    return messages;
  }

  Future<EmailMessage?> _fetchMessage(String id, String token) async {
    final uri = Uri.https(
      'gmail.googleapis.com',
      '/gmail/v1/users/me/messages/$id',
      {'format': 'full'},
    );
    final response = await _get(uri, token);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final payload = data['payload'] as Map<String, dynamic>? ?? const {};
    final headers = (payload['headers'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();
    String header(String name) =>
        headers.firstWhere(
              (item) => (item['name'] as String?)?.toLowerCase() == name,
              orElse: () => const {},
            )['value']
            as String? ??
        '';

    final body = _findPlainText(payload);
    return EmailMessage(
      id: id,
      threadId: data['threadId'] as String? ?? id,
      from: header('from'),
      subject: header('subject').isEmpty ? '(no subject)' : header('subject'),
      date: DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(data['internalDate'] as String? ?? '') ?? 0,
      ),
      body: body.isEmpty ? (data['snippet'] as String? ?? '') : body,
    );
  }

  Future<http.Response> _get(Uri uri, String token) async {
    final response = await _client
        .get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 401) {
      throw GmailException(
        'Gmail authorization expired. Sign out and sign in again.',
      );
    }
    if (response.statusCode == 403) {
      throw GmailException(
        'Google has blocked Gmail access. Add this account as an OAuth test user and confirm Gmail API access is enabled.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GmailException('Gmail returned HTTP ${response.statusCode}.');
    }
    return response;
  }

  String _findPlainText(Map<String, dynamic> part) {
    final mimeType = part['mimeType'] as String? ?? '';
    final body = part['body'] as Map<String, dynamic>? ?? const {};
    final data = body['data'] as String?;
    if (mimeType == 'text/plain' && data != null) {
      try {
        return utf8.decode(base64Url.decode(base64Url.normalize(data)));
      } catch (_) {
        return '';
      }
    }
    for (final child in part['parts'] as List<dynamic>? ?? const []) {
      if (child is Map<String, dynamic>) {
        final text = _findPlainText(child);
        if (text.isNotEmpty) return text;
      }
    }
    return '';
  }
}

class GmailException implements Exception {
  const GmailException(this.message);
  final String message;

  @override
  String toString() => message;
}
