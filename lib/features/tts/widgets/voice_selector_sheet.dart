import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../shared/models/voice_profile.dart';
import '../tts_controller.dart';

class VoiceSelectorSheet extends StatelessWidget {
  final TtsController controller;

  const VoiceSelectorSheet({super.key, required this.controller});

  Future<void> _handleImportVoice(BuildContext context) async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['wav'],
      );

      if (file == null || file.path == null) {
        return;
      }

      final path = file.path!;
      final defaultName = file.name.replaceAll(RegExp(r'\.wav$', caseSensitive: false), '');

      if (!context.mounted) return;

      final nameController = TextEditingController(text: defaultName);
      final descController = TextEditingController();

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Custom Voice'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Import a reference recording (.wav) to condition PocketTTS. The audio file stays entirely private on your device.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Voice Name',
                  hintText: 'e.g. Studio Narrator',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Optional Description',
                  hintText: 'e.g. Warm documentary style',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );

      if (confirmed == true && nameController.text.trim().isNotEmpty) {
        await controller.importCustomVoice(
          filePath: path,
          name: nameController.text.trim(),
          description: descController.text.trim(),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick voice file: $e')),
        );
      }
    }
  }

  void _showRenameCustomVoiceDialog(BuildContext context, VoiceProfile voice) {
    final textController = TextEditingController(text: voice.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Voice Profile'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Voice Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newName = textController.text.trim();
              if (newName.isNotEmpty) {
                controller.renameCustomVoice(voice.id, newName);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteCustomVoiceDialog(BuildContext context, VoiceProfile voice) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Voice Profile?'),
        content: Text('Delete "${voice.name}" and remove its reference recording?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              controller.deleteCustomVoice(voice.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final voices = controller.voices;
    final selectedVoice = controller.selectedVoice;
    final defaultVoiceId = controller.settings.defaultVoiceId;

    final bundled = voices.where((v) => !v.isCustom).toList();
    final custom = voices.where((v) => v.isCustom).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                    'Voice Profiles',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _handleImportVoice(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Import WAV'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    if (bundled.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'BUNDLED PROFILES',
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.2,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...bundled.map((voice) => _VoiceListTile(
                            voice: voice,
                            isSelected: selectedVoice?.id == voice.id,
                            isDefault: defaultVoiceId == voice.id,
                            onSelect: () {
                              controller.selectVoice(voice);
                              Navigator.pop(context);
                            },
                            onSetDefault: () => controller.setDefaultVoice(voice),
                            onPlaySample: () => controller.playAudio(voice.referenceAudioPath),
                          )),
                    ],
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'CUSTOM PROFILES',
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 1.2,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${custom.length} imported',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (custom.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Text(
                            'No custom voices imported yet.\nTap "Import WAV" above to add your own voice reference.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      ...custom.map((voice) => _VoiceListTile(
                            voice: voice,
                            isSelected: selectedVoice?.id == voice.id,
                            isDefault: defaultVoiceId == voice.id,
                            onSelect: () {
                              controller.selectVoice(voice);
                              Navigator.pop(context);
                            },
                            onSetDefault: () => controller.setDefaultVoice(voice),
                            onPlaySample: () => controller.playAudio(voice.referenceAudioPath),
                            onRename: () => _showRenameCustomVoiceDialog(context, voice),
                            onDelete: () => _showDeleteCustomVoiceDialog(context, voice),
                          )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VoiceListTile extends StatelessWidget {
  final VoiceProfile voice;
  final bool isSelected;
  final bool isDefault;
  final VoidCallback onSelect;
  final VoidCallback onSetDefault;
  final VoidCallback onPlaySample;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const _VoiceListTile({
    required this.voice,
    required this.isSelected,
    required this.isDefault,
    required this.onSelect,
    required this.onSetDefault,
    required this.onPlaySample,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: isSelected ? 1 : 0,
      color: isSelected
          ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.6)
          : theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: onSelect,
        leading: CircleAvatar(
          backgroundColor: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          foregroundColor: isSelected
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurfaceVariant,
          child: Icon(voice.isCustom ? Icons.person_outline : Icons.mic_none_rounded),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                voice.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            if (isDefault)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Default',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: voice.optionalDescription != null
            ? Text(
                voice.optionalDescription!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.volume_up_outlined, size: 20),
              tooltip: 'Listen to reference audio',
              onPressed: onPlaySample,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              onSelected: (action) {
                if (action == 'default') onSetDefault();
                if (action == 'rename') onRename?.call();
                if (action == 'delete') onDelete?.call();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'default',
                  child: Text('Set as Default'),
                ),
                if (voice.isCustom && onRename != null)
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('Rename'),
                  ),
                if (voice.isCustom && onDelete != null)
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
