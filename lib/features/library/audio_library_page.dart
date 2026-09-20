import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../shared/models/narration_item.dart';
import '../../shared/utils/duration_formatter.dart';
import '../tts/tts_controller.dart';
import '../tts/widgets/audio_result_card.dart';

class AudioLibraryPage extends StatefulWidget {
  final TtsController controller;

  const AudioLibraryPage({super.key, required this.controller});

  @override
  State<AudioLibraryPage> createState() => _AudioLibraryPageState();
}

class _AudioLibraryPageState extends State<AudioLibraryPage> {
  List<NarrationItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    setState(() => _isLoading = true);
    final items = await widget.controller.libraryService.getSavedNarrations();
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  void _showRenameDialog(NarrationItem item) {
    final textController = TextEditingController(text: item.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Narration'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'File Name',
            hintText: 'narration.wav',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = textController.text.trim();
              if (newName.isNotEmpty) {
                await widget.controller.renameNarration(item, newName);
                await _loadLibrary();
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(NarrationItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Narration?'),
        content: Text('Delete "${item.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              await widget.controller.deleteNarration(item);
              await _loadLibrary();
              if (ctx.mounted) Navigator.pop(ctx);
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
    final controller = widget.controller;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Narration Library', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadLibrary,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmptyState(context)
              : Column(
                  children: [
                    if (controller.currentNarration != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: AudioResultCard(
                          narration: controller.currentNarration!,
                          controller: controller,
                          onDismiss: () => controller.setCurrentNarration(null),
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final isCurrent = controller.currentlyPlayingPath == item.filePath;
                          final isPlaying = isCurrent && controller.isPlaying;
                          final formattedDate = DateFormat.yMMMd().format(item.createdAt);
                          final formattedDuration = DurationFormatter.formatSeconds(item.durationSeconds);
                          final formattedSize = DurationFormatter.formatFileSize(item.fileSizeBytes);

                          return Card(
                            elevation: isCurrent ? 1 : 0,
                            color: isCurrent
                                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                                : theme.colorScheme.surfaceContainerLow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isCurrent
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              onTap: () {
                                controller.setCurrentNarration(item);
                                controller.playAudio(item.filePath);
                              },
                              leading: CircleAvatar(
                                backgroundColor: isCurrent
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.surfaceContainerHighest,
                                foregroundColor: isCurrent
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurfaceVariant,
                                child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                              ),
                              title: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '$formattedDuration · $formattedSize · Voice: ${item.voiceName}\n$formattedDate',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded),
                                onSelected: (action) {
                                  if (action == 'play') {
                                    controller.setCurrentNarration(item);
                                    controller.playAudio(item.filePath);
                                  } else if (action == 'share') {
                                    controller.shareNarration(item);
                                  } else if (action == 'rename') {
                                    _showRenameDialog(item);
                                  } else if (action == 'delete') {
                                    _showDeleteDialog(item);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(
                                    value: 'play',
                                    child: Row(
                                      children: [
                                        Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 18),
                                        const SizedBox(width: 8),
                                        Text(isPlaying ? 'Pause' : 'Play'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'share',
                                    child: Row(
                                      children: [
                                        Icon(Icons.share_outlined, size: 18),
                                        SizedBox(width: 8),
                                        Text('Share to App'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'rename',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18),
                                        SizedBox(width: 8),
                                        Text('Rename'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                                        const SizedBox(width: 8),
                                        Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.library_music_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Saved Narrations Yet',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate narration in the Studio tab. Your 24 kHz WAV files will appear here for easy playback and export.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
