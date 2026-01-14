import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/poll_model.dart';
import '../../core/themes/app_theme.dart';
import '../../core/constants/api_constants.dart';

/// Widget for displaying a poll in a message bubble
class PollWidget extends ConsumerStatefulWidget {
  final Poll poll;
  final bool isFromMe;
  final Function(List<String> optionIds)? onVote;
  final Function(List<String> optionIds)? onRetract;
  final VoidCallback? onClose;
  final bool canClose;
  final Future<List<PollOption>> Function()? onGetVoters;

  const PollWidget({
    super.key,
    required this.poll,
    required this.isFromMe,
    this.onVote,
    this.onRetract,
    this.onClose,
    this.canClose = false,
    this.onGetVoters,
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
              // Show "Who voted" button for non-anonymous polls
              if (!poll.isAnonymous && poll.totalVoters > 0 && widget.onGetVoters != null)
                GestureDetector(
                  onTap: () => _showVotersBottomSheet(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getVotersText(poll.totalVoters),
                        style: TextStyle(
                          fontSize: 12,
                          color: accentColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.people_outline,
                        size: 14,
                        color: accentColor,
                      ),
                    ],
                  ),
                )
              else
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
  
  /// Show bottom sheet with voters for non-anonymous polls
  Future<void> _showVotersBottomSheet(BuildContext context) async {
    if (widget.onGetVoters == null) return;
    
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _VotersBottomSheet(
        poll: widget.poll,
        onGetVoters: widget.onGetVoters!,
      ),
    );
  }
}

/// Bottom sheet widget to display voters for each option
class _VotersBottomSheet extends StatefulWidget {
  final Poll poll;
  final Future<List<PollOption>> Function() onGetVoters;

  const _VotersBottomSheet({
    required this.poll,
    required this.onGetVoters,
  });

  @override
  State<_VotersBottomSheet> createState() => _VotersBottomSheetState();
}

class _VotersBottomSheetState extends State<_VotersBottomSheet> {
  List<PollOption>? _optionsWithVoters;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVoters();
  }

  Future<void> _loadVoters() async {
    try {
      final options = await widget.onGetVoters();
      if (mounted) {
        setState(() {
          _optionsWithVoters = options;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Не удалось загрузить голоса';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Кто проголосовал',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const Divider(height: 1),
            
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, 
                                color: theme.colorScheme.error,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(_error!, 
                                style: TextStyle(color: theme.colorScheme.error),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _optionsWithVoters?.length ?? 0,
                          itemBuilder: (context, index) {
                            final option = _optionsWithVoters![index];
                            return _buildOptionVoters(context, option);
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOptionVoters(BuildContext context, PollOption option) {
    final theme = Theme.of(context);
    final voters = option.voters ?? [];
    
    return ExpansionTile(
      title: Row(
        children: [
          Expanded(
            child: Text(
              option.text,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${option.voteCount}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      initiallyExpanded: voters.isNotEmpty,
      children: voters.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Нет голосов',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ]
          : voters.map((voter) => _buildVoterTile(context, voter)).toList(),
    );
  }

  Widget _buildVoterTile(BuildContext context, Voter voter) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: voter.avatarUrl != null
            ? NetworkImage('${ApiConstants.baseUrl}${voter.avatarUrl}')
            : null,
        child: voter.avatarUrl == null
            ? Text(voter.displayName.isNotEmpty 
                ? voter.displayName[0].toUpperCase() 
                : '?')
            : null,
      ),
      title: Text(
        voter.displayName,
        style: TextStyle(
          fontSize: 14,
          color: theme.colorScheme.onSurface,
        ),
      ),
      dense: true,
    );
  }
}

