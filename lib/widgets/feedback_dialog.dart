import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../services/feedback_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';

/// Opens the in-app feedback dialog. On a successful send, shows a "thanks"
/// snackbar. Does nothing if the feedback service is unavailable (no Firebase
/// project configured) — callers should also hide their entry point in that
/// case, but this guards against races.
Future<void> showFeedbackDialog(
  BuildContext context,
  FeedbackTrigger trigger,
) async {
  if (!FeedbackService.instance.isAvailable) return;

  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);

  final sent = await showDialog<bool>(
    context: context,
    builder: (_) => _FeedbackDialog(trigger: trigger),
  );

  if (sent == true && context.mounted) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(l10n.feedbackThanks),
      ),
    );
  }
}

class _FeedbackDialog extends ConsumerStatefulWidget {
  const _FeedbackDialog({required this.trigger});

  final FeedbackTrigger trigger;

  @override
  ConsumerState<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends ConsumerState<_FeedbackDialog> {
  final _controller = TextEditingController();
  bool _sending = false;
  bool _error = false;
  bool _empty = true;
  FeedbackRating? _rating;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final empty = _controller.text.trim().isEmpty;
      if (empty != _empty) setState(() => _empty = empty);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_empty || _sending) return;
    setState(() {
      _sending = true;
      _error = false;
    });
    try {
      await FeedbackService.instance.submit(
        message: _controller.text,
        trigger: widget.trigger,
        locale: Localizations.localeOf(context).toString(),
        rating: _rating,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = ref.watch(tunerThemeProvider);

    return AlertDialog(
      // Scrollable so the title + content scroll as one unit when the keyboard
      // shrinks the available height — otherwise the rating rows + text field
      // overflow on shorter screens.
      scrollable: true,
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        l10n.feedbackTitle,
        style: theme.sans(20, weight: FontWeight.w600, color: theme.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Optional satisfaction rating ────────────────────────────────
          // Emoji faces in a single row (compact); the selected face's label
          // shows on the reserved line below, so long localized labels never
          // need to fit four-across.
          Text(
            l10n.feedbackRatingQuestion,
            style: theme.sans(14, color: theme.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final option in _ratingOptions)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _RatingFace(
                      emoji: option.emoji,
                      label: option.label(l10n),
                      selected: _rating == option.rating,
                      theme: theme,
                      onTap: _sending
                          ? null
                          : () => setState(() => _rating = option.rating),
                    ),
                  ),
                ),
            ],
          ),
          // Reserved-height line for the selected label (avoids layout jump).
          SizedBox(
            height: 20,
            child: Center(
              child: Text(
                _rating == null
                    ? ''
                    : _ratingOptions
                        .firstWhere((o) => o.rating == _rating)
                        .label(l10n),
                style: theme.sans(13,
                    weight: FontWeight.w600, color: theme.inTune),
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_sending,
            minLines: 2,
            maxLines: 5,
            maxLength: 2000,
            style: theme.sans(16, color: theme.textPrimary),
            cursorColor: theme.inTune,
            decoration: InputDecoration(
              hintText: l10n.feedbackHint,
              hintStyle: theme.sans(16, color: theme.textDim),
              // Enforced silently; the live counter just adds vertical clutter.
              counterText: '',
              filled: true,
              fillColor: theme.surfaceHi,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.surfaceRim),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.surfaceRim),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.inTune, width: 1.5),
              ),
            ),
          ),
          if (_error)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.feedbackError,
                style: theme.sans(13, color: theme.sharp),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: Text(
            l10n.feedbackCancelBtn,
            style: theme.sans(15, color: theme.textSecondary),
          ),
        ),
        TextButton(
          onPressed: (_empty || _sending) ? null : _send,
          child: _sending
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(theme.inTune),
                  ),
                )
              : Text(
                  l10n.feedbackSendBtn,
                  style: theme.sans(15,
                      weight: FontWeight.w700,
                      color: _empty ? theme.textDim : theme.inTune),
                ),
        ),
      ],
    );
  }
}

/// Describes one selectable satisfaction level: its enum value, the emoji
/// shown, and how to resolve its localized label. Ordered best-first to match
/// [FeedbackRating.score].
class _RatingOption {
  const _RatingOption(this.rating, this.emoji, this.label);

  final FeedbackRating rating;
  final String emoji;
  final String Function(AppLocalizations) label;
}

final _ratingOptions = <_RatingOption>[
  _RatingOption(FeedbackRating.loveIt, '😀', (l) => l.feedbackRatingLoveIt),
  _RatingOption(FeedbackRating.fine, '🙂', (l) => l.feedbackRatingFine),
  _RatingOption(FeedbackRating.needsWork, '😕', (l) => l.feedbackRatingNeedsWork),
  _RatingOption(
      FeedbackRating.frustrating, '😞', (l) => l.feedbackRatingFrustrating),
];

/// A single tappable emoji face with a selected state. The label is exposed
/// only to screen readers; the visible label lives on the shared line below
/// the row.
class _RatingFace extends StatelessWidget {
  const _RatingFace({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final TunerThemeData theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? theme.inTune.withValues(alpha: 0.12)
            : theme.surfaceHi,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? theme.inTune : theme.surfaceRim,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
        ),
      ),
    );
  }
}
