import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/narration_item.dart';
import '../../../shared/utils/duration_formatter.dart';
import '../tts_controller.dart';

class AudioResultCard extends StatelessWidget {
  final NarrationItem narration;
  final TtsController controller;
  final VoidCallback? onDismiss;

  const AudioResultCard({
    super.key,
    required this.narration,
    required this.controller,
    this.onDismiss,
  });

  void _showRenameDialog(BuildContext context) {
    final textController = TextEditingController(text: narration.title);
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
            onPressed: () {
              final newName = textController.text.trim();
              if (newName.isNotEmpty) {
                controller.renameNarration(narration, newName);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Narration?'),
        content: Text('Are you sure you want to delete "${narration.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              controller.deleteNarration(narration);
              Navigator.pop(ctx);
              onDismiss?.call();
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
    final isCurrentPlaying = controller.currentlyPlayingPath == narration.filePath && controller.isPlaying;
    final isCurrentTrack = controller.currentlyPlayingPath == narration.filePath;

    final currentPosition = isCurrentTrack ? controller.playbackPosition : Duration.zero;
    final totalDuration = Duration(milliseconds: (narration.durationSeconds * 1000).toInt());

    final formattedDate = DateFormat.yMMMd().add_jm().format(narration.createdAt);
    final formattedSize = DurationFormatter.formatFileSize(narration.fileSizeBytes);
    final formattedDuration = DurationFormatter.formatSeconds(narration.durationSeconds);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.audiotrack_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        narration.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$formattedDate · Voice: ${narration.voiceName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Rename',
                  onPressed: () => _showRenameDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Playback seek bar
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: (currentPosition.inMilliseconds / (totalDuration.inMilliseconds > 0 ? totalDuration.inMilliseconds : 1))
                    .clamp(0.0, 1.0),
                onChanged: (val) {
                  final seekMs = (val * totalDuration.inMilliseconds).toInt();
                  controller.seekAudio(Duration(milliseconds: seekMs));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DurationFormatter.formatDuration(currentPosition),
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Text(
                    formattedDuration,
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Metadata chips
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  labelPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.data_usage_rounded, size: 14),
                  label: Text(' $formattedSize'),
                ),
                Chip(
                  labelPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.graphic_eq_rounded, size: 14),
                  label: const Text(' 24 kHz WAV'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Actions
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => controller.playAudio(narration.filePath),
                  icon: Icon(isCurrentPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  label: Text(isCurrentPlaying ? 'Pause' : 'Play'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => controller.shareNarration(narration),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share'),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                  tooltip: 'Delete',
                  onPressed: () => _showDeleteDialog(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
