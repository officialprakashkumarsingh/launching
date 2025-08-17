import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models.dart';

/* ----------------------------------------------------------
   THREAD SELECTOR - Shows available threads and main chat
---------------------------------------------------------- */
class ThreadSelector extends StatelessWidget {
  final List<MessageThread> threads;
  final String? currentThreadId;
  final VoidCallback onMainThreadTap;
  final Function(String threadId) onThreadTap;
  final Function(String threadId, String newName)? onThreadRename;
  final Function(String threadId)? onThreadDelete;

  const ThreadSelector({
    super.key,
    required this.threads,
    required this.currentThreadId,
    required this.onMainThreadTap,
    required this.onThreadTap,
    this.onThreadRename,
    this.onThreadDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF4F3F0),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE0DED9),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.forum_outlined,
                  color: Color(0xFF000000),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Conversations',
                  style: TextStyle(
                    color: Color(0xFF000000),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${threads.length + 1}',
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Main thread
          _ThreadItem(
            icon: Icons.home_outlined,
            title: 'Main Chat',
            isSelected: currentThreadId == null,
            messageCount: null,
            onTap: () {
              HapticFeedback.lightImpact();
              onMainThreadTap();
            },
          ),
          
          // Thread list
          if (threads.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Divider(
                color: Color(0xFFE0DED9),
                height: 1,
              ),
            ),
            ...threads.map((thread) => _ThreadItem(
              icon: Icons.alt_route_outlined,
              title: thread.name,
              isSelected: currentThreadId == thread.id,
              messageCount: thread.messageCount,
              onTap: () {
                HapticFeedback.lightImpact();
                onThreadTap(thread.id);
              },
              onLongPress: () => _showThreadOptions(context, thread),
            )),
          ],
        ],
      ),
    );
  }

  void _showThreadOptions(BuildContext context, MessageThread thread) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ThreadOptionsSheet(
        thread: thread,
        onRename: onThreadRename != null ? (newName) => onThreadRename!(thread.id, newName) : null,
        onDelete: onThreadDelete != null ? () => onThreadDelete!(thread.id) : null,
      ),
    );
  }
}

/* ----------------------------------------------------------
   THREAD ITEM - Individual thread in the list
---------------------------------------------------------- */
class _ThreadItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final int? messageCount;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ThreadItem({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.messageCount,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEAE9E5) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF000000) : const Color(0xFF666666),
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF000000) : const Color(0xFF333333),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (messageCount != null && messageCount! > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF000000) : const Color(0xFFC4C4C4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  messageCount.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF666666),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/* ----------------------------------------------------------
   THREAD OPTIONS SHEET - Rename and delete options
---------------------------------------------------------- */
class _ThreadOptionsSheet extends StatefulWidget {
  final MessageThread thread;
  final Function(String newName)? onRename;
  final VoidCallback? onDelete;

  const _ThreadOptionsSheet({
    required this.thread,
    this.onRename,
    this.onDelete,
  });

  @override
  State<_ThreadOptionsSheet> createState() => _ThreadOptionsSheetState();
}

class _ThreadOptionsSheetState extends State<_ThreadOptionsSheet> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.thread.name;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFE0DED9),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.alt_route_outlined,
                  color: Color(0xFF000000),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Thread Options',
                    style: TextStyle(
                      color: Color(0xFF000000),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF666666),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          
          // Options
          if (widget.onRename != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rename Thread',
                    style: TextStyle(
                      color: Color(0xFF000000),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Enter thread name',
                      filled: true,
                      fillColor: const Color(0xFFF4F3F0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    style: const TextStyle(
                      color: Color(0xFF000000),
                      fontSize: 14,
                    ),
                    maxLength: 50,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  ),
                ],
              ),
            ),
          ],
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (widget.onRename != null) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final newName = _controller.text.trim();
                        if (newName.isNotEmpty && newName != widget.thread.name) {
                          widget.onRename!(newName);
                        }
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF000000),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Rename',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (widget.onDelete != null) const SizedBox(width: 12),
                ],
                if (widget.onDelete != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showDeleteConfirmation(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF4F3F0),
                        foregroundColor: const Color(0xFF000000),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: Color(0xFFE0DED9),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete Thread',
          style: TextStyle(
            color: Color(0xFF000000),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.thread.name}"? This action cannot be undone.',
          style: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF666666),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF000000),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}