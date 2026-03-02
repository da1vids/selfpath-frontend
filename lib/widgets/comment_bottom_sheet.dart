import 'package:flutter/material.dart';
import '../../services/post_service.dart';
import '../../providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/theme.dart';

class CommentBottomSheet extends StatefulWidget {
  final int postId;
  final VoidCallback? onCommentPosted;
  final VoidCallback? onCommentDeleted;

  const CommentBottomSheet({
    super.key,
    required this.postId,
    this.onCommentPosted,
    this.onCommentDeleted,
  });

  @override
  _CommentBottomSheetState createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
  List<Map<String, dynamic>> _comments = [];
  final TextEditingController _controller = TextEditingController();
  final bool _showEmoji = false;
  int? _replyTo;
  int _offset = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final int _limit = 10;
  final ScrollController _scrollController = ScrollController();
  final Set<int> _likeBusy = {}; // comment/reply ids currently toggling
  final Set<int> _pulse = {}; // ids to show a quick heart pulse (optional)

  Color _getColorForString(String input) {
    final hash = input.hashCode;
    final colorIndex = hash % Colors.primaries.length;
    return Colors.primaries[colorIndex].shade400;
  }

  Widget _buildAvatar(Map<String, dynamic> user) {
    final imageUrl = user['profile_picture'];
    final username = user['username'] ?? '';
    final firstLetter = username.isNotEmpty ? username[0].toUpperCase() : '?';

    if (imageUrl != null && imageUrl.toString().trim().isNotEmpty) {
      return CircleAvatar(backgroundImage: NetworkImage(imageUrl));
    } else {
      final bgColor = _getColorForString(username);
      return CircleAvatar(
        backgroundColor: bgColor,
        child: Text(
          firstLetter,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadComments();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 100 &&
          !_isLoadingMore &&
          _hasMore) {
        _loadComments(loadMore: true);
      }
    });
  }

  Future<void> _toggleLike(Map<String, dynamic> item) async {
    final int id = item['id'] as int;
    if (_likeBusy.contains(id)) return;
    _likeBusy.add(id);
    setState(() {});

    try {
      final result = await PostService.toggleCommentLike(id.toString());
      if (result['success']) {
        final data = result['data'];
        setState(() {
          item['liked'] = data['liked'];
          item['likes'] = data['likesCount'];
          // quick pulse when it's a "like"
          if (item['liked'] == true) {
            _pulse.add(id);
          }
        });
        // hide pulse after a moment
        Future.delayed(const Duration(milliseconds: 550), () {
          if (!mounted) return;
          setState(() { _pulse.remove(id); });
        });
      }
    } finally {
      _likeBusy.remove(id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadComments({bool loadMore = false}) async {
    if (_isLoadingMore) return;
    _isLoadingMore = true;

    try {
      final newComments = await PostService.fetchComments(
        widget.postId,
        offset: _offset,
        limit: _limit,
      );

      setState(() {
        if (loadMore) {
          _comments.addAll(newComments);
        } else {
          _comments = newComments;
        }

        _offset += _limit;
        _hasMore = newComments.length == _limit;
      });
    } finally {
      _isLoadingMore = false;
    }
  }

  void _postComment() async {
    if (_controller.text.trim().isEmpty) return;

    final result = await PostService.postComment(
      postId: widget.postId,
      content: _controller.text.trim(),
      parentId: _replyTo,
    );

    if (result['success']) {
      _controller.clear();
      _replyTo = null;
      FocusScope.of(context).unfocus();
      widget.onCommentPosted?.call();

      // 🧠 Reset offset + comments before reloading
      _offset = 0;
      _hasMore = true;
      _comments.clear();
      await _loadComments(); // force reload from start
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                height: 5,
                width: 50,
                margin: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    final comment = _comments[index];
                    final replies = List<Map<String, dynamic>>.from(
                      comment['replies'] ?? [],
                    );
                    final currentUser =
                        Provider.of<UserProvider>(context, listen: false).user;
                    final isMyComment =
                        comment['user']?['id'] == currentUser?.id;
                    final showAllReplies = comment['showAllReplies'] == true;
                    final visibleReplies =
                        showAllReplies ? replies : replies.take(2).toList();

                    return Dismissible(
                      key: Key(comment['id'].toString()),
                      direction:
                          isMyComment
                              ? DismissDirection.endToStart
                              : DismissDirection.none,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder:
                              (ctx) => AlertDialog(
                                title: Text('Delete comment?'),
                                content: Text(
                                  'This will also delete all replies.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                        );
                        if (confirm == true) {
                          final result = await PostService.deleteComment(
                            comment['id'],
                          );
                          if (result['success']) {
                            setState(() {
                              _comments.removeAt(index);
                            });
                            widget.onCommentDeleted?.call();
                          }
                        }
                        return false;
                      },
                      child: Container(
                        margin: EdgeInsets.fromLTRB(12, 0, 12, 10),
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white, // ✅ Pure white background
                          borderRadius: BorderRadius.circular(12),
                        ),

                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildAvatar(comment['user']),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                GestureDetector(
                                                  behavior: HitTestBehavior.opaque,
                                                  onDoubleTap: () => _toggleLike(comment),
                                                  child: Container(
                                                    width: double.infinity, // 👈 ensures full width
                                                    padding: const EdgeInsets.all(10),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[200],
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          '@${comment['user']['username']}',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          comment['content'],
                                                          style: const TextStyle(color: Colors.black),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),

                                                // ❤️ optional pulse overlay
                                                AnimatedOpacity(
                                                  opacity: _pulse.contains(comment['id']) ? 1.0 : 0.0,
                                                  duration: const Duration(milliseconds: 150),
                                                  child: const Icon(Icons.favorite, size: 64),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      SizedBox(height: 6),

                                      // actions row (Reply, Like, Time) stays white
                                      Row(
                                        children: [
                                          Text(
                                            timeago.format(
                                              DateTime.parse(
                                                comment['created_at'],
                                              ),
                                            ),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _controller.text =
                                                    '@${comment['user']['username']} ';
                                                _replyTo = comment['id'];
                                                FocusScope.of(
                                                  context,
                                                ).requestFocus(FocusNode());
                                              });
                                            },
                                            child: Text(
                                              'Reply',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.accentColor,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          GestureDetector(
                                            onTap: () async {
                                              final result =
                                                  await PostService.toggleCommentLike(
                                                    comment['id'].toString(),
                                                  );
                                              if (result['success']) {
                                                final data = result['data'];
                                                setState(() {
                                                  comment['liked'] = data['liked'];
                                                  comment['likes'] = data['likesCount'];
                                                });
                                              }
                                            },
                                            child: Row(
                                              children: [
                                                AnimatedSwitcher(
                                                  duration: Duration(
                                                    milliseconds: 300,
                                                  ),
                                                  child: Icon(
                                                    comment['liked'] == true
                                                        ? Icons.favorite
                                                        : Icons.favorite_border,
                                                    key: ValueKey(
                                                      comment['liked'],
                                                    ),
                                                    size: 14,
                                                    color:
                                                        comment['liked'] == true
                                                            ? AppTheme
                                                                .likeColor
                                                            : Colors.grey,
                                                  ),
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  '${comment['likes'] ?? 0}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isMyComment) ...[
                                            Spacer(),
                                            GestureDetector(
                                              onTap: () async {
                                                final confirm = await showDialog<
                                                  bool
                                                >(
                                                  context: context,
                                                  builder:
                                                      (ctx) => AlertDialog(
                                                        title: Text(
                                                          'Delete comment?',
                                                        ),
                                                        content: Text(
                                                          'This will also delete all replies.',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed:
                                                                () =>
                                                                    Navigator.pop(
                                                                      ctx,
                                                                      false,
                                                                    ),
                                                            child: Text(
                                                              'Cancel',
                                                            ),
                                                          ),
                                                          TextButton(
                                                            onPressed:
                                                                () =>
                                                                    Navigator.pop(
                                                                      ctx,
                                                                      true,
                                                                    ),
                                                            child: Text(
                                                              'Delete',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                );
                                                if (confirm == true) {
                                                  final result =
                                                      await PostService.deleteComment(
                                                        comment['id'],
                                                      );
                                                  if (result['success']) {
                                                    setState(
                                                      () => _comments.removeAt(
                                                        index,
                                                      ),
                                                    );
                                                    widget.onCommentDeleted
                                                        ?.call();
                                                  }
                                                }
                                              },
                                              child: Icon(
                                                Icons.delete_outline,
                                                size: 16,
                                                color: Colors.black,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            ...visibleReplies.map((reply) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  left: 16.0,
                                  right: 12.0,
                                  top: 4,
                                  bottom: 0,
                                ),
                                child: Dismissible(
                                  key: Key('reply_${reply['id']}'),
                                  direction:
                                      (reply['user']['id'] == currentUser?.id)
                                          ? DismissDirection.endToStart
                                          : DismissDirection.none,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: EdgeInsets.only(right: 20),
                                    color: Colors.red,
                                    child: Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                    ),
                                  ),
                                  confirmDismiss: (_) async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder:
                                          (ctx) => AlertDialog(
                                            title: Text('Delete reply?'),
                                            content: Text(
                                              'Are you sure you want to delete this reply?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      ctx,
                                                      false,
                                                    ),
                                                child: Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      ctx,
                                                      true,
                                                    ),
                                                child: Text('Delete'),
                                              ),
                                            ],
                                          ),
                                    );

                                    if (confirm == true) {
                                      final result =
                                          await PostService.deleteComment(
                                            reply['id'],
                                          );
                                      if (result['success']) {
                                        setState(() {
                                          comment['replies'].removeWhere(
                                            (r) => r['id'] == reply['id'],
                                          );
                                        });
                                        widget.onCommentDeleted?.call();
                                      }
                                    }

                                    return false;
                                  },

                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white, // White outer container
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildAvatar(reply['user']),
                                            SizedBox(width: 10),
                                            Expanded(
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  GestureDetector(
                                                    behavior: HitTestBehavior.opaque,
                                                    onDoubleTap: () => _toggleLike(reply),
                                                    child: Container(
                                                      width: double.infinity,
                                                      padding: const EdgeInsets.all(10),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[200],
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text('@${reply['user']['username']}',
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 13,
                                                                color: Colors.black,
                                                              )),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            reply['content'],
                                                            style: const TextStyle(fontSize: 13, color: Colors.black),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  AnimatedOpacity(
                                                    opacity: _pulse.contains(reply['id']) ? 1.0 : 0.0,
                                                    duration: const Duration(milliseconds: 150),
                                                    child: const Icon(Icons.favorite, size: 56),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 6),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 46.0,
                                          ),
                                          child: Row(
                                            children: [
                                              Text(
                                                timeago.format(
                                                  DateTime.parse(
                                                    reply['created_at'],
                                                  ),
                                                ),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              GestureDetector(
                                                onTap: () async {
                                                  final result =
                                                      await PostService.toggleCommentLike(
                                                        reply['id'].toString(),
                                                      );
                                                  if (result['success']) {
                                                    final data = result['data'];
                                                    setState(() {
                                                      reply['liked'] = data['liked'];
                                                      reply['likes'] = data['likesCount'];
                                                    });
                                                  }
                                                },
                                                child: Row(
                                                  children: [
                                                    AnimatedSwitcher(
                                                      duration: Duration(
                                                        milliseconds: 300,
                                                      ),
                                                      transitionBuilder:
                                                          (child, animation) =>
                                                              ScaleTransition(
                                                                scale:
                                                                    animation,
                                                                child: child,
                                                              ),
                                                      child: Icon(
                                                        reply['liked'] == true
                                                            ? Icons.favorite
                                                            : Icons
                                                                .favorite_border,
                                                        key: ValueKey(
                                                          reply['liked'],
                                                        ),
                                                        color:
                                                            reply['liked'] ==
                                                                    true
                                                                ? AppTheme
                                                                    .likeColor
                                                                : Colors.grey,
                                                        size: 16,
                                                      ),
                                                    ),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      '${reply['likes'] ?? 0}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _controller.text =
                                                        '@${reply['user']['username']} ';
                                                    _replyTo = comment['id'];
                                                    FocusScope.of(
                                                      context,
                                                    ).requestFocus(FocusNode());
                                                  });
                                                },
                                                child: Text(
                                                  'Reply',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppTheme.accentColor,
                                                  ),
                                                ),
                                              ),
                                              if (reply['user']['id'] ==
                                                  currentUser?.id) ...[
                                                Spacer(),
                                                GestureDetector(
                                                  onTap: () async {
                                                    final confirm = await showDialog<
                                                      bool
                                                    >(
                                                      context: context,
                                                      builder:
                                                          (ctx) => AlertDialog(
                                                            title: Text(
                                                              'Delete reply?',
                                                            ),
                                                            content: Text(
                                                              'Are you sure you want to delete this reply?',
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed:
                                                                    () =>
                                                                        Navigator.pop(
                                                                          ctx,
                                                                          false,
                                                                        ),
                                                                child: Text(
                                                                  'Cancel',
                                                                ),
                                                              ),
                                                              TextButton(
                                                                onPressed:
                                                                    () =>
                                                                        Navigator.pop(
                                                                          ctx,
                                                                          true,
                                                                        ),
                                                                child: Text(
                                                                  'Delete',
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                    );

                                                    if (confirm == true) {
                                                      final result =
                                                          await PostService.deleteComment(
                                                            reply['id'],
                                                          );
                                                      if (result['success']) {
                                                        setState(() {
                                                          comment['replies']
                                                              .removeWhere(
                                                                (r) =>
                                                                    r['id'] ==
                                                                    reply['id'],
                                                              );
                                                        });
                                                        widget.onCommentDeleted
                                                            ?.call();
                                                      }
                                                    }
                                                  },
                                                  child: Icon(
                                                    Icons.delete_outline,
                                                    size: 16,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                            if (replies.length > 2 && !showAllReplies)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 72.0,
                                  bottom: 8,
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      comment['showAllReplies'] = true;
                                    });
                                  },
                                  child: Text(
                                    'Show more replies...',
                                    style: TextStyle(
                                      color: AppTheme.accentColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey[400]!),
                        ),
                        padding: EdgeInsets.fromLTRB(15, 0, 0, 0),
                        child: TextField(
                          controller: _controller,
                          textCapitalization: TextCapitalization.sentences,
                          cursorColor: Colors.grey[600],
                          style: TextStyle(
                            color: Colors.grey[800],
                          ),
                          decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  Icons.send,
                                  color: Colors.grey[800],
                              ),
                              onPressed: _postComment,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
