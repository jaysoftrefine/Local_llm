import 'package:flutter/foundation.dart';

import '../../../core/config/app_env.dart';
import '../../mail/models/email_message.dart';
import '../../mail/services/gmail_service.dart';
import '../services/local_model_service.dart';

class MailChatTurn {
  const MailChatTurn({required this.text, required this.isUser});
  final String text;
  final bool isUser;
}

class MailChatController extends ChangeNotifier {
  final LocalModelService _model = LocalModelService();
  final GmailService _gmail = GmailService();

  final List<EmailMessage> emails = [];
  final List<MailChatTurn> turns = [];
  bool isPreparing = false;
  bool isAsking = false;
  bool modelReady = false;
  bool isSyncing = false;
  double downloadProgress = 0;
  String? error;
  String? status;

  String get modelName => AppEnv.llmModelName;
  bool get chatReady => modelReady;

  Future<void> prepare(String accessToken) async {
    if (isPreparing) return;
    isPreparing = true;
    error = null;
    status = 'Checking for the on-device model…';
    notifyListeners();
    try {
      if (!await _model.isDownloaded) {
        status = 'Downloading the on-device model. Keep the app open.';
        notifyListeners();
        await _model.download(
          onProgress: (progress) {
            downloadProgress = progress;
            notifyListeners();
          },
        );
      }
      status = 'Loading the model into memory…';
      notifyListeners();
      await _model.load();
      modelReady = true;
      status = 'Model ready. Syncing your recent Gmail messages…';
      notifyListeners();
      await syncMail(accessToken);
      if (error == null) {
        status = 'Ready. ${emails.length} emails are available to chat about.';
      }
    } catch (e) {
      error = e.toString();
      status = null;
    } finally {
      isPreparing = false;
      notifyListeners();
    }
  }

  Future<void> syncMail(String accessToken) async {
    if (isSyncing) return;
    isSyncing = true;
    error = null;
    notifyListeners();
    try {
      final latest = await _gmail.fetchRecentMessages(accessToken);
      emails
        ..clear()
        ..addAll(latest);
      status =
          'Synced ${emails.length} recent emails. Their content stays on this device.';
    } catch (e) {
      error = e.toString();
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> ask(String question) async {
    final prompt = question.trim();
    if (prompt.isEmpty || !modelReady || isAsking) return;
    turns.add(MailChatTurn(text: prompt, isUser: true));
    isAsking = true;
    error = null;
    notifyListeners();
    try {
      final answer = await _model.answer(prompt, emails);
      turns.add(
        MailChatTurn(
          text: answer.isEmpty
              ? 'I could not create an answer. Please try asking another way.'
              : answer,
          isUser: false,
        ),
      );
    } catch (e) {
      error = e.toString();
    } finally {
      isAsking = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }
}
