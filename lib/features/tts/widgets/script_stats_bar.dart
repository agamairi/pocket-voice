import 'package:flutter/material.dart';
import '../../../shared/utils/duration_formatter.dart';
import '../../../shared/utils/text_segmenter.dart';

class ScriptStatsBar extends StatelessWidget {
  final String scriptText;
  final int sentencePauseMs;
  final int paragraphPauseMs;

  const ScriptStatsBar({
    super.key,
    required this.scriptText,
    required this.sentencePauseMs,
    required this.paragraphPauseMs,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wordCount = TextSegmenter.countWords(scriptText);
    final charCount = TextSegmenter.countCharacters(scriptText);
    final estimatedSeconds = TextSegmenter.estimateDuration(
      scriptText,
      sentencePauseMs: sentencePauseMs,
      paragraphPauseMs: paragraphPauseMs,
    );
    final formattedDuration = DurationFormatter.formatSeconds(estimatedSeconds);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _StatItem(
            icon: Icons.article_outlined,
            label: '$wordCount ${wordCount == 1 ? 'word' : 'words'}',
          ),
          _StatItem(
            icon: Icons.text_fields_outlined,
            label: '$charCount chars',
          ),
          _StatItem(
            icon: Icons.timer_outlined,
            label: '~$formattedDuration estimated',
            highlight: true,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _StatItem({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = highlight
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
