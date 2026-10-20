import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/constants/app_info.dart';
import '../../../shared/utils/duration_formatter.dart';
import '../../../shared/utils/update_checker.dart';
import '../model_manager.dart';
import '../tts_controller.dart';

class SettingsBottomSheet extends StatefulWidget {
  final TtsController controller;

  const SettingsBottomSheet({super.key, required this.controller});

  @override
  State<SettingsBottomSheet> createState() => _SettingsBottomSheetState();
}

class _SettingsBottomSheetState extends State<SettingsBottomSheet> {
  late int _sentencePauseMs;
  late int _paragraphPauseMs;
  late int _numThreads;
  late bool _keepScreenAwake;
  late bool _paragraphMode;
  late int _maxReferenceAudioLen;
  int _installedModelSizeBytes = 0;
  bool _isCheckingForUpdates = false;
  String? _updateStatus;

  @override
  void initState() {
    super.initState();
    final s = widget.controller.settings;
    _sentencePauseMs = s.sentencePauseMs;
    _paragraphPauseMs = s.paragraphPauseMs;
    _numThreads = s.numThreads;
    _keepScreenAwake = s.keepScreenAwake;
    _paragraphMode = s.paragraphMode;
    _maxReferenceAudioLen = s.maxReferenceAudioLen;
    _loadModelSize();
  }

  Future<void> _loadModelSize() async {
    final size = await widget.controller.modelManager.getInstalledModelSizeBytes();
    if (mounted) {
      setState(() {
        _installedModelSizeBytes = size;
      });
    }
  }

  void _saveSettings() {
    final updated = widget.controller.settings.copyWith(
      sentencePauseMs: _sentencePauseMs,
      paragraphPauseMs: _paragraphPauseMs,
      numThreads: _numThreads,
      keepScreenAwake: _keepScreenAwake,
      maxReferenceAudioLen: _maxReferenceAudioLen,
      paragraphMode: _paragraphMode,
    );
    widget.controller.updateSettings(updated);
  }

  void _showMarkupGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.code_rounded),
            SizedBox(width: 8),
            Text('Script Markup Guide'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pocket Voice supports optional markup tags in your script:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              '[normal]\nThis is standard narration.\n\n[excited]\nThat damage is ridiculous!\n\n[whisper]\nKeep your voice down.',
              style: TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
            SizedBox(height: 16),
            Text(
              'Note: In v1, tags are preserved by the parser for future voice/style mapping, and stripped from the audio output so they are never read aloud.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showDeleteModelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Model Files?'),
        content: const Text(
          'This will delete the offline PocketTTS model (~200 MB unpacked) from device storage. You will need an internet connection to re-download it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close bottom sheet
              await widget.controller.deleteModel();
            },
            child: const Text('Delete Model'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Settings',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline_rounded),
                    tooltip: 'Script Markup Guide',
                    onPressed: () => _showMarkupGuide(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    Text(
                      'AUDIO GENERATION PAUSES',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Sentence Pause Slider
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Sentence Pause', style: TextStyle(fontWeight: FontWeight.w600)),
                                Text('$_sentencePauseMs ms', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Slider(
                              value: _sentencePauseMs.toDouble(),
                              min: 0,
                              max: 1000,
                              divisions: 100,
                              label: '$_sentencePauseMs ms',
                              onChanged: (val) {
                                setState(() => _sentencePauseMs = val.round());
                                _saveSettings();
                              },
                            ),
                            Text(
                              'Silence inserted between sentences in the same paragraph (default: 180 ms).',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Paragraph Pause Slider
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Paragraph Pause', style: TextStyle(fontWeight: FontWeight.w600)),
                                Text('$_paragraphPauseMs ms', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Slider(
                              value: _paragraphPauseMs.toDouble(),
                              min: 0,
                              max: 2000,
                              divisions: 200,
                              label: '$_paragraphPauseMs ms',
                              onChanged: (val) {
                                setState(() => _paragraphPauseMs = val.round());
                                _saveSettings();
                              },
                            ),
                            Text(
                              'Silence inserted between paragraph breaks (default: 400 ms).',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      tileColor: theme.colorScheme.surfaceContainerLow,
                      title: const Text('Paragraph mode', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                        'Generates each paragraph in one pass so the voice stays steadier. Sentence pauses are then not used; paragraph pauses still apply. Very long paragraphs may drift.',
                      ),
                      value: _paragraphMode,
                      onChanged: (val) {
                        setState(() => _paragraphMode = val);
                        _saveSettings();
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'DEVICE & DISPLAY',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      tileColor: theme.colorScheme.surfaceContainerLow,
                      title: const Text('Keep screen awake while generating', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Prevents sleep or screen dimming during long script generation.'),
                      value: _keepScreenAwake,
                      onChanged: (val) {
                        setState(() => _keepScreenAwake = val);
                        _saveSettings();
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ADVANCED INFERENCE ENGINE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('CPU Inference Threads', style: TextStyle(fontWeight: FontWeight.w600)),
                                Text('$_numThreads threads', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Slider(
                              value: _numThreads.toDouble(),
                              min: 1,
                              max: 8,
                              divisions: 7,
                              label: '$_numThreads',
                              onChanged: (val) {
                                setState(() => _numThreads = val.round());
                                _saveSettings();
                              },
                            ),
                            Text(
                              'Number of CPU cores used for PocketTTS ONNX inference (recommended: 2 - 4 on mobile/tablet).',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'OFFLINE MODEL & STORAGE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Model Package', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              ModelManager.modelDirName,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Status:'),
                                Text(
                                  widget.controller.isModelInstalled ? 'Installed (Offline Ready)' : 'Not Installed',
                                  style: TextStyle(
                                    color: widget.controller.isModelInstalled ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (_installedModelSizeBytes > 0) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Storage size:'),
                                  Text(
                                    DurationFormatter.formatFileSize(_installedModelSizeBytes),
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            if (widget.controller.isModelInstalled)
                              OutlinedButton.icon(
                                onPressed: () => _showDeleteModelDialog(context),
                                icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                label: Text('Delete Model Files', style: TextStyle(color: theme.colorScheme.error)),
                              )
                            else
                              FilledButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  widget.controller.downloadModel();
                                },
                                icon: const Icon(Icons.download_rounded),
                                label: const Text('Download Model (~94 MB)'),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'APPLICATION INFORMATION',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('App Version', style: TextStyle(fontWeight: FontWeight.w600)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'v${AppInfo.appVersion} (${AppInfo.buildNumber})',
                                    style: TextStyle(
                                      color: theme.colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            _buildInfoRow('Engine', AppInfo.inferenceEngine),
                            const SizedBox(height: 8),
                            _buildInfoRow('Architecture', 'PocketTTS INT8 Offline'),
                            const SizedBox(height: 8),
                            _buildInfoRow('Audio Output', AppInfo.audioFormat),
                            const SizedBox(height: 8),
                            _buildInfoRow('Studio Voices', '18 Included (8 Female, 10 Male)'),
                            const Divider(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.tonalIcon(
                                onPressed: _isCheckingForUpdates ? null : _checkForUpdates,
                                icon: _isCheckingForUpdates
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.system_update_alt),
                                label: Text(_isCheckingForUpdates ? 'Checking...' : 'Check for updates'),
                              ),
                            ),
                            if (_updateStatus != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _updateStatus!,
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Asks GitHub for the latest release and reports whether it is newer than this build.
  Future<void> _checkForUpdates() async {
    setState(() {
      _isCheckingForUpdates = true;
      _updateStatus = null;
    });

    try {
      final result = await UpdateChecker.check(currentVersion: AppInfo.appVersion);
      if (!mounted) return;

      if (result.isUpdateAvailable) {
        setState(() => _updateStatus = 'Version ${result.latestVersion} is available.');
        await _showUpdateDialog(result);
      } else {
        setState(() => _updateStatus = 'You are on the latest version (v${AppInfo.appVersion}).');
      }
    } on UpdateCheckException catch (e) {
      if (mounted) setState(() => _updateStatus = e.message);
    } finally {
      if (mounted) setState(() => _isCheckingForUpdates = false);
    }
  }

  Future<void> _showUpdateDialog(UpdateCheckResult result) async {
    final openRelease = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update available'),
        content: Text(
          'Pocket Voice ${result.latestVersion} is available. You have v${result.currentVersion}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open GitHub'),
          ),
        ],
      ),
    );

    if (openRelease != true) return;
    final launched = await launchUrl(
      Uri.parse(result.releaseUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      setState(() => _updateStatus = 'Could not open ${result.releaseUrl}');
    }
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
