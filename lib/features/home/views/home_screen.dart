import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../features/auth/controllers/auth_controller.dart';
import '../../chat/controllers/mail_chat_controller.dart';
import '../../auth/views/oauth_config_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MailChatController _chat = MailChatController();
  final TextEditingController _prompt = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _chat.dispose();
    _prompt.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final token = context.read<AuthController>().currentUser?.accessToken;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your Gmail session expired. Sign out and sign in again.',
          ),
        ),
      );
      return;
    }
    await _chat.prepare(token);
  }

  Future<void> _sync() async {
    final token = context.read<AuthController>().currentUser?.accessToken;
    if (token != null && token.isNotEmpty) await _chat.syncMail(token);
  }

  Future<void> _send() async {
    final value = _prompt.text;
    _prompt.clear();
    await _chat.ask(value);
    if (_scroll.hasClients) {
      await _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    return ChangeNotifierProvider.value(
      value: _chat,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const Row(
            children: [
              Icon(Icons.mark_email_unread_rounded, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Mail Chat', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            if (_chat.chatReady)
              IconButton(
                tooltip: 'Sync Gmail',
                onPressed: _chat.isSyncing ? null : _sync,
                icon: _chat.isSyncing
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
              ),
            IconButton(
              tooltip: 'Google OAuth settings',
              onPressed: () => OAuthConfigDialog.show(context),
              icon: const Icon(Icons.key_rounded),
            ),
            IconButton(
              tooltip: 'Sign out',
              onPressed: auth.isLoading ? null : auth.signOut,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _chat,
            builder: (context, _) => _chat.chatReady
                ? _chatView(user?.displayName ?? 'there')
                : _setupView(user?.displayName ?? 'there'),
          ),
        ),
      ),
    );
  }

  Widget _setupView(String name) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const SizedBox(height: 26),
        const CircleAvatar(
          radius: 38,
          backgroundColor: AppColors.surface,
          child: Icon(
            Icons.mark_email_unread_rounded,
            size: 38,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Hi, $name',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Set up private mail chat on this device.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 28),
        _setupStep(
          Icons.download_rounded,
          '1. Download the local AI model',
          'The model is downloaded once and runs on your phone. It may use several hundred MB of data and storage.',
        ),
        const SizedBox(height: 14),
        _setupStep(
          Icons.mail_outline_rounded,
          '2. Sync recent Gmail',
          'Mail Chat reads up to 100 recent messages that you authorized. Message content stays on this device.',
        ),
        const SizedBox(height: 14),
        _setupStep(
          Icons.chat_bubble_outline_rounded,
          '3. Ask questions about your mail',
          'Ask things like “What did Sam say about the meeting?” or “Summarize my recent travel emails.”',
        ),
        const SizedBox(height: 28),
        if (_chat.isPreparing) ...[
          LinearProgressIndicator(
            value: _chat.downloadProgress > 0 ? _chat.downloadProgress : null,
          ),
          const SizedBox(height: 12),
          Text(
            _chat.downloadProgress > 0 && _chat.downloadProgress < 1
                ? 'Downloading ${(100 * _chat.downloadProgress).round()}%'
                : (_chat.status ?? 'Preparing Mail Chat…'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
        ] else ...[
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                _chat.modelReady
                    ? 'Sync Gmail and open chat'
                    : 'Download model and sync Gmail',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Model: ${_chat.modelName}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
        if (_chat.status != null && !_chat.isPreparing) ...[
          const SizedBox(height: 14),
          Text(
            _chat.status!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
        if (_chat.error != null) ...[
          const SizedBox(height: 18),
          _errorBox(_chat.error!),
        ],
        const SizedBox(height: 26),
        const Text(
          'Mail content is processed by the downloaded model on your device. Google is used to retrieve authorized Gmail messages; chat prompts and mail content are not sent to an AI server.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _setupStep(IconData icon, String title, String detail) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatView(String name) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.surface,
          child: Row(
            children: [
              const Icon(
                Icons.mail_outline_rounded,
                color: AppColors.success,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_chat.emails.length} emails synced · processed on this device',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              TextButton(
                onPressed: _chat.isSyncing ? null : _sync,
                child: const Text('Sync'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _chat.turns.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          color: AppColors.primary,
                          size: 48,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Ask about your emails, $name',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your messages are searched on-device and used as context for the local model.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  itemCount: _chat.turns.length + (_chat.isAsking ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _chat.turns.length) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    final turn = _chat.turns[index];
                    return Align(
                      alignment: turn.isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 340),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: turn.isUser
                              ? AppColors.primaryDark
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SelectableText(
                          turn.text,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_chat.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: _errorBox(_chat.error!),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _prompt,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Ask about your emails…',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _chat.isAsking ? null : _send,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorBox(String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.error.withAlpha(28),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.error.withAlpha(90)),
    ),
    child: Text(
      message,
      style: const TextStyle(color: AppColors.textPrimary, height: 1.4),
    ),
  );
}
