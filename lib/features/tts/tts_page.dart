import 'package:flutter/material.dart';
import '../../shared/widgets/model_download_view.dart';
import 'tts_controller.dart';
import 'widgets/audio_result_card.dart';
import 'widgets/generation_progress_dialog.dart';
import 'widgets/script_stats_bar.dart';
import 'widgets/settings_bottom_sheet.dart';
import 'widgets/voice_selector_sheet.dart';

class TtsPage extends StatefulWidget {
  final TtsController controller;

  const TtsPage({super.key, required this.controller});

  @override
  State<TtsPage> createState() => _TtsPageState();
}

class _TtsPageState extends State<TtsPage> {
  final TextEditingController _scriptTextController = TextEditingController();
  final FocusNode _scriptFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Default helpful starter template for YouTube narration
    _scriptTextController.text =
        'Welcome back to the channel!\n\n'
        'Today we are looking at something truly incredible that will change how you think about narration.\n\n'
        'Everything you hear right now is synthesized 100% locally and completely offline on this device using PocketTTS.';

    _scriptTextController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _scriptTextController.dispose();
    _scriptFocusNode.dispose();
    super.dispose();
  }

  String? _getSelectedText() {
    final sel = _scriptTextController.selection;
    if (sel.isValid && sel.start != sel.end) {
      final start = sel.start < sel.end ? sel.start : sel.end;
      final end = sel.start < sel.end ? sel.end : sel.start;
      return _scriptTextController.text.substring(start, end);
    }
    return null;
  }

  void _handlePreview() {
    final selected = _getSelectedText();
    widget.controller.generatePreview(
      _scriptTextController.text,
      selectedSentence: selected,
    );
  }

  void _handleGenerateWav() {
    widget.controller.generateNarration(_scriptTextController.text);
  }

  void _openVoiceSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoiceSelectorSheet(controller: widget.controller),
    );
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SettingsBottomSheet(controller: widget.controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);

    // Listen for errors
    if (controller.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(controller.errorMessage!),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        controller.clearErrorMessage();
      });
    }

    if (!controller.isModelInstalled) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pocket Voice', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: false,
        ),
        body: ModelDownloadView(controller: controller),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.waves_rounded, size: 24),
            const SizedBox(width: 8),
            const Text('Pocket Voice', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'OFFLINE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth >= 720;
              if (isTablet) {
                return _buildTabletLayout(context);
              } else {
                return _buildPhoneLayout(context);
              }
            },
          ),
          if (controller.isGenerating || controller.isPreviewGenerating)
            GenerationProgressDialog(
              progress: controller.currentProgress,
              isPreview: controller.isPreviewGenerating,
              onCancel: controller.cancelGeneration,
            ),
        ],
      ),
    );
  }

  Widget _buildPhoneLayout(BuildContext context) {
    final controller = widget.controller;
    final selectedVoice = controller.selectedVoice;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildEditorCard(context, minLines: 10),
                const SizedBox(height: 12),
                ScriptStatsBar(
                  scriptText: _scriptTextController.text,
                  sentencePauseMs: controller.settings.sentencePauseMs,
                  paragraphPauseMs: controller.settings.paragraphPauseMs,
                ),
                const SizedBox(height: 16),
                _buildVoiceSelectorTile(context, selectedVoice),
                const SizedBox(height: 16),
                _buildActionButtons(context),
                if (controller.currentNarration != null) ...[
                  const SizedBox(height: 20),
                  AudioResultCard(
                    narration: controller.currentNarration!,
                    controller: controller,
                    onDismiss: () => controller.setCurrentNarration(null),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    final controller = widget.controller;
    final selectedVoice = controller.selectedVoice;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: Script Editor
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildEditorCard(context, minLines: 20),
                ),
                const SizedBox(height: 12),
                ScriptStatsBar(
                  scriptText: _scriptTextController.text,
                  sentencePauseMs: controller.settings.sentencePauseMs,
                  paragraphPauseMs: controller.settings.paragraphPauseMs,
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Right column: Voice Selection & Action Controls
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildVoiceSelectorTile(context, selectedVoice),
                  const SizedBox(height: 20),
                  _buildActionButtons(context),
                  const SizedBox(height: 24),
                  if (controller.currentNarration != null) ...[
                    Text(
                      'Generated Output',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                    ),
                    const SizedBox(height: 8),
                    AudioResultCard(
                      narration: controller.currentNarration!,
                      controller: controller,
                      onDismiss: () => controller.setCurrentNarration(null),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorCard(BuildContext context, {int minLines = 10}) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      color: theme.colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _scriptTextController,
          focusNode: _scriptFocusNode,
          maxLines: null,
          minLines: minLines,
          keyboardType: TextInputType.multiline,
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.6,
            fontSize: 16,
          ),
          decoration: const InputDecoration(
            hintText: 'Paste or type your video narration script here...\n\nSupports paragraphs and optional markup tags like [normal], [excited].',
            border: InputBorder.none,
            isDense: true,
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceSelectorTile(BuildContext context, dynamic selectedVoice) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: _openVoiceSelector,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              child: const Icon(Icons.mic_rounded),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Voice Profile',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    selectedVoice != null ? selectedVoice.name : 'Select Voice',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final hasText = _scriptTextController.text.trim().isNotEmpty;
    final isGenerating = widget.controller.isGenerating || widget.controller.isPreviewGenerating;

    return Row(
      children: [
        // Preview button
        Expanded(
          flex: 4,
          child: OutlinedButton.icon(
            onPressed: (!hasText || isGenerating) ? null : _handlePreview,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Preview'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Generate WAV button
        Expanded(
          flex: 6,
          child: FilledButton.icon(
            onPressed: (!hasText || isGenerating) ? null : _handleGenerateWav,
            icon: const Icon(Icons.audiotrack_rounded),
            label: const Text('Generate WAV'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }
}
