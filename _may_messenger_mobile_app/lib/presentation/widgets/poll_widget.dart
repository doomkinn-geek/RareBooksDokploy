import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/poll_model.dart';
import '../../core/themes/app_theme.dart';

/// Widget for displaying a poll in a message bubble
class PollWidget extends ConsumerStatefulWidget {
  final Poll poll;
  final bool isFromMe;
  final Function(List<String> optionIds)? onVote;
  final Function(List<String> optionIds)? onRetract;
  final VoidCallback? onClose;
  final bool canClose;

  const PollWidget({
    super.key,
    required this.poll,
    required this.isFromMe,
    this.onVote,
    this.onRetract,
    this.onClose,
    this.canClose = false,
  });

  @override
  ConsumerState<PollWidget> createState() => _PollWidgetState();
}

class _PollWidgetState extends ConsumerState<PollWidget> {
  Set<String> _selectedOptions = {};
  bool _isVoting = false;

  @override
  void initState() {
    super.initState();
    _selectedOptions = widget.poll.myVotes.toSet();
  }

  @override
  void didUpdateWidget(PollWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.poll.myVotes != widget.poll.myVotes) {
      _selectedOptions = widget.poll.myVotes.toSet();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poll = widget.poll;
    final hasVoted = poll.hasVoted;
    final isClosed = poll.isClosed;
    
    // Use theme colors for proper visibility
    final primaryTextColor = widget.isFromMe 
        ? theme.outgoingTextColor 
        : theme.incomingTextColor;
    final secondaryTextColor = widget.isFromMe 
        ? theme.outgoingTextColor.withOpacity(0.7) 
        : theme.incomingTextColor.withOpacity(0.7);
    final accentColor = widget.isFromMe 
        ? theme.outgoingTextColor 
        : theme.colorScheme.primary;

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poll question
          Row(
            children: [
              Icon(
                Icons.poll,
                size: 20,
                color: accentColor.withOpacity(0.8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  poll.question,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: primaryTextColor,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Poll type info
          if (poll.allowMultipleAnswers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Можно выбрать несколько',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: secondaryTextColor,
                ),
              ),
            ),
          
          // Options
          ...poll.options.map((option) => _buildOption(context, option, hasVoted, isClosed)),
          
          const SizedBox(height: 8),
          
          // Vote count & status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getVotersText(poll.totalVoters),
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryTextColor,
                ),
              ),
              if (isClosed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Завершено',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: accentColor,
                    ),
                  ),
                ),
              if (poll.isAnonymous && !isClosed)
                Text(
                  'Анонимное',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: secondaryTextColor,
                  ),
                ),
            ],
          ),
          
          // Vote button for multiple choice (always show when poll is open and has selections or changes)
          if (!isClosed && poll.allowMultipleAnswers && _selectedOptions.isNotEmpty && _hasChanges())
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isVoting ? null : _submitVote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isFromMe 
                        ? Colors.white.withOpacity(0.2) 
                        : theme.colorScheme.primary,
                    foregroundColor: widget.isFromMe 
                        ? Colors.white 
                        : Colors.white,
                  ),
                  child: _isVoting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(hasVoted ? 'Изменить голос' : 'Голосовать'),
                ),
              ),
            ),
          
          // Hint for users who voted (multiple choice)
          if (!isClosed && hasVoted && poll.allowMultipleAnswers)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Можно изменить выбор до завершения голосования',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          
          // Close poll button (for creator)
          if (!isClosed && widget.canClose && widget.onClose != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton(
                onPressed: widget.onClose,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  foregroundColor: theme.colorScheme.error,
                ),
                child: const Text('Завершить голосование', style: TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, PollOption option, bool hasVoted, bool isClosed) {
    final theme = Theme.of(context);
    final isSelected = _selectedOptions.contains(option.id);
    // Show results only when poll is closed (not just when user voted)
    final showResults = isClosed;
    
    // Use theme colors
    final primaryTextColor = widget.isFromMe 
        ? theme.outgoingTextColor 
        : theme.incomingTextColor;
    final accentColor = widget.isFromMe 
        ? theme.outgoingTextColor 
        : theme.colorScheme.primary;
    
    return GestureDetector(
      onTap: isClosed ? null : () => _toggleOption(option.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Stack(
          children: [
            // Progress bar background (only when poll is closed)
            if (showResults)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: option.percentage / 100,
                  minHeight: 40,
                  backgroundColor: accentColor.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    accentColor.withOpacity(isSelected ? 0.4 : 0.2),
                  ),
                ),
              ),
            
            // Option content
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: !showResults ? Border.all(
                  color: accentColor.withOpacity(isSelected ? 0.8 : 0.3),
                  width: isSelected ? 2 : 1,
                ) : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // Checkbox or radio (always shown when poll is open)
                  if (!isClosed)
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        shape: widget.poll.allowMultipleAnswers 
                            ? BoxShape.rectangle 
                            : BoxShape.circle,
                        borderRadius: widget.poll.allowMultipleAnswers 
                            ? BorderRadius.circular(4) 
                            : null,
                        border: Border.all(
                          color: accentColor.withOpacity(0.8),
                          width: 2,
                        ),
                        color: isSelected 
                            ? accentColor
                            : Colors.transparent,
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              size: 14,
                              color: widget.isFromMe 
                                  ? (theme.brightness == Brightness.dark 
                                      ? theme.colorScheme.primary 
                                      : theme.colorScheme.surface)
                                  : Colors.white,
                            )
                          : null,
                    ),
                  
                  // Option text
                  Expanded(
                    child: Text(
                      option.text,
                      style: TextStyle(
                        fontSize: 14,
                        color: primaryTextColor,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  
                  // Percentage and count (only when poll is closed)
                  if (showResults)
                    Text(
                      '${option.percentage}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  
                  // Vote count hint (when poll is open and user has voted)
                  if (!isClosed && hasVoted)
                    Text(
                      '${option.voteCount}',
                      style: TextStyle(
                        fontSize: 12,
                        color: primaryTextColor.withOpacity(0.6),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleOption(String optionId) {
    if (widget.poll.isClosed) return;
    
    setState(() {
      if (widget.poll.allowMultipleAnswers) {
        // Multiple choice - toggle selection
        if (_selectedOptions.contains(optionId)) {
          _selectedOptions.remove(optionId);
        } else {
          _selectedOptions.add(optionId);
        }
      } else {
        // Single choice - submit immediately (allows changing vote)
        _selectedOptions = {optionId};
        _submitVote();
      }
    });
  }

  /// Check if current selection differs from existing votes
  bool _hasChanges() {
    final currentVotes = widget.poll.myVotes.toSet();
    return _selectedOptions.length != currentVotes.length ||
           !_selectedOptions.every((id) => currentVotes.contains(id));
  }

  Future<void> _submitVote() async {
    if (_selectedOptions.isEmpty || widget.onVote == null) return;
    
    setState(() => _isVoting = true);
    
    try {
      await widget.onVote!(_selectedOptions.toList());
    } finally {
      if (mounted) {
        setState(() => _isVoting = false);
      }
    }
  }

  String _getVotersText(int count) {
    if (count == 0) return 'Нет голосов';
    if (count == 1) return '1 голос';
    if (count >= 2 && count <= 4) return '$count голоса';
    return '$count голосов';
  }
}

