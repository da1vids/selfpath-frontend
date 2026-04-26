// Full HomePostsScreen with tiered unlock logic
import 'package:flutter/material.dart';
import '../../providers/user_provider.dart';
import 'package:provider/provider.dart';
import '../../services/post_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';
import '../../theme/theme.dart';
import '../../widgets/comment_bottom_sheet.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';

class HomePostsScreen extends StatefulWidget {
  final int? creatorId;
  final String? tag;

  const HomePostsScreen({super.key, this.creatorId, this.tag});

  @override
  _HomePostsScreenState createState() => _HomePostsScreenState();
}

class _HomePostsScreenState extends State<HomePostsScreen>
    with WidgetsBindingObserver {
  final Set<int> _expandedPosts = {};
  int? _currentPlayingIndex;
  VideoPlayerController? _videoController;
  final PageController _pageController = PageController();

  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  int _offset = 0;
  final int _limit = 10;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _isPageTransitioning = false;
  final Map<int, VideoPlayerController> _preloadedControllers = {};
  bool _isSearching = false;
  String _searchQuery = '';

  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;

  void _onSearchChanged(String query) {
    _searchQuery = query;

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (query.trim().length < 2) {
        if (!mounted) return;
        setState(() => _searchResults = []);
        return;
      }
      try {
        final response = await PostService.searchPosts(query);
        if (!mounted) return;
        setState(() => _searchResults = response);
      } catch (e) {
        if (!mounted) return;
        setState(() => _searchResults = []);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPosts();
  }

  void _loadPosts({bool append = false}) async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final result = await PostService.getPosts(
        offset: _offset,
        limit: _limit,
        creatorId: widget.creatorId,
        tag: widget.tag,
      );
      final newPosts = result['posts'] as List<Map<String, dynamic>>;

      setState(() {
        if (append) {
          _posts.addAll(newPosts);
        } else {
          _posts = newPosts;
          _isLoading = false; // ✅ This is the line you MUST add
        }

        _offset += _limit;
        _hasMore = result['hasMore'];
      });

      // Automatically load video for first visible post
      if (_posts.isNotEmpty && !append) {
        _handlePageChanged(0);
      }
    } catch (e) {
      print('Error loading posts: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
        _isLoading = false; // ✅ Also valid and safe here
      });
    }
  }

  Future<void> _preloadVideo(int index) async {
    if (_preloadedControllers.containsKey(index) ||
        index < 0 ||
        index >= _posts.length) {
      return;
    }

    final post = _posts[index];
    if (post['asset'].toString().endsWith('.mp4')) {
      final controller = post['asset'].toString().startsWith('http')
          ? VideoPlayerController.networkUrl(Uri.parse(post['asset']))
          : VideoPlayerController.asset(post['asset']);

      try {
        await controller.initialize();
        controller.setLooping(true);
        _preloadedControllers[index] = controller;
      } catch (e) {
        print('Preload failed for index $index: $e');
      }
    }
  }

  void _handlePageChanged(int index) async {
    if (_isPageTransitioning) return;
    _isPageTransitioning = true;

    final post = _posts[index];
    final isVideo = post['asset'].toString().endsWith('.mp4');

    // Dispose current controller
    if (_videoController != null) {
      await _videoController!.pause();
      await _videoController!.dispose();
      _preloadedControllers.remove(_currentPlayingIndex);
      _videoController = null;
    }

    _currentPlayingIndex = null;

    // Use preloaded controller if available and initialized
    if (isVideo && _preloadedControllers.containsKey(index)) {
      final controller = _preloadedControllers[index];
      if (controller != null && controller.value.isInitialized) {
        _videoController = controller;
        _currentPlayingIndex = index;
        await _videoController!.play();
      }
    }
    // Otherwise, create a new one
    else if (isVideo) {
      final controller =
          post['asset'].toString().startsWith('http')
              ? VideoPlayerController.networkUrl(Uri.parse(post['asset']))
              : VideoPlayerController.asset(post['asset']);

      try {
        try {
          await controller.initialize();
          controller.setLooping(true);
          await controller.play();

          if (!mounted) return;

          _videoController = controller;
          _currentPlayingIndex = index;

          setState(() {});
        } catch (e) {
          print("Video init error: $e");
        }

        _videoController = controller;

        _preloadedControllers.forEach((i, ctrl) {
          if (i != index) ctrl.dispose();
        });
        _preloadedControllers.removeWhere((i, _) => i != index);

        _currentPlayingIndex = index;
      } catch (e) {
        print('Video error: $e');
      }
    }

    // Preload next and previous
    // Temporarily remove this preloading
    // It causes memory bloat without strong benefit on mobile
    /* _preloadVideo(index + 1);
    _preloadVideo(index - 1); */

    if (!mounted) return;
    setState(() {});
    _isPageTransitioning = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _videoController?.dispose();
    _videoController = null;

    for (var controller in _preloadedControllers.values) {
      controller.dispose();
    }
    _preloadedControllers.clear();

    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_videoController == null) return;

    final isInitialized = _videoController!.value.isInitialized;
    final hasError = _videoController!.value.hasError;

    if (state == AppLifecycleState.paused && isInitialized && !hasError) {
      _videoController!.pause();
    } else if (state == AppLifecycleState.resumed &&
        isInitialized &&
        !hasError) {
      _videoController!.play();
    }
  }

  void _handleUnlock(
    BuildContext context,
    Map<String, dynamic> post,
    int index,
  ) {
    if (post['tiers'] == null || post['tiers'].length <= 1) {
      _unlockTier(context, post, index, post['tiers'][0]);
    } else {
      _showUnlockOptions(context, post, index);
    }
  }

  void _showUnlockOptions(
    BuildContext context,
    Map<String, dynamic> post,
    int index,
  ) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userCredits = userProvider.credits;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final tiers = post['tiers'] as List<dynamic>;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// 🔝 Credits row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Unlock Options",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$userCredits credits',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              /// 🔓 Tier list
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: tiers.length,
                itemBuilder: (context, i) {
                  final tier = tiers[i];
                  final isUnlocked = tier['unlocked'] == true;

                  return ListTile(
                    title: Text(
                      tier['label'],
                      style: TextStyle(
                        color: isUnlocked ? Colors.grey : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      tier['description'],
                      style: TextStyle(
                        color: isUnlocked ? Colors.grey[500] : Colors.black54,
                      ),
                    ),
                    trailing:
                        isUnlocked
                            ? Icon(Icons.check_circle, color: Colors.green)
                            : Text(
                              "${tier['credits']} credits",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                    onTap: () {
                      Navigator.pop(context);
                      _unlockTier(context, post, index, tier);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _unlockTier(
      BuildContext context,
      Map<String, dynamic> post,
      int index,
      Map<String, dynamic> tier,
      ) async {
    // Cache things that read the widget tree BEFORE any awaits
    final messenger = ScaffoldMessenger.of(context);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    final int cost = tier['credits'] as int;
    final int tierId = tier['id'] as int;
    final int postId = post['id'] as int;
    final bool isUnlocked = tier['unlocked'] == true;

    // Early return uses cached messenger (safe)
    if (!isUnlocked && userProvider.credits < cost) {
      messenger.showSnackBar(const SnackBar(content: Text('Not enough credits!')));
      return;
    }

    try {
      final result = await PostService.unlockTier(postId: postId, tierId: tierId);

      if (!mounted) return; // widget might have been disposed while awaiting

      if (result['success'] == true) {
        final String asset = result['asset'] as String;

        userProvider.updateCredits(result['credits']);

        // if (!isUnlocked) {
        //   userProvider.updateCredits(userProvider.credits - cost);
        // }

        if (!mounted) return;
        if (index >= 0 && index < _posts.length) {
          setState(() {
            _posts[index]['locked'] = false;
            _posts[index]['asset'] = asset;
          });
        }

        // If currently playing, rewire the controller
        if (_currentPlayingIndex == index && asset.endsWith('.mp4')) {
          final oldPosition = _videoController?.value.position ?? Duration.zero;

          // Pause/dispose old controller
          await _videoController?.pause();
          await _videoController?.dispose();

          // Create new controller
          final isNetwork = asset.startsWith('http');
          _videoController = isNetwork
              ? VideoPlayerController.networkUrl(Uri.parse(asset)) // ✅ Uri.parse
              : VideoPlayerController.asset(asset);

          await _videoController!.initialize();

          if (oldPosition < _videoController!.value.duration) {
            await _videoController!.seekTo(oldPosition);
          }
          _videoController!.setLooping(true);
          await _videoController!.play();

          if (!mounted) return;
          setState(() {}); // reflect the new controller state
        }

        messenger.showSnackBar(
          SnackBar(content: Text(result['message'])),
          // SnackBar(content: Text(isUnlocked ? 'Asset loaded' : 'Unlocked for $cost credits')),
        );
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('Unlock failed.')));
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }


  void _showCommentsSheet(BuildContext context, int postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: CommentBottomSheet(
            postId: postId,
            onCommentPosted: () {
              setState(() {
                final postIndex = _posts.indexWhere((p) => p['id'] == postId);
                if (postIndex != -1) {
                  _posts[postIndex]['comments'] =
                      (_posts[postIndex]['comments'] ?? 0) + 1;
                }
              });
            },
            onCommentDeleted: () {
              setState(() {
                final postIndex = _posts.indexWhere((p) => p['id'] == postId);
                if (postIndex != -1) {
                  _posts[postIndex]['comments'] =
                      (_posts[postIndex]['comments'] ?? 1) - 1;
                }
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildPostFeed() {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      physics: const BouncingScrollPhysics(), // Add this
      onPageChanged: (int index) {
        _handlePageChanged(index);

        if (index >= _posts.length - 3 && _hasMore && !_isLoadingMore) {
          _loadPosts(append: true);
        }
      },
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        final isUnlocked = post['locked'] == false;
        final imagePath = post['asset'] ?? '';

        final profilePath = post['profileImage'];

        final isAssetImage = !imagePath.toString().startsWith('http');
        final isAssetProfile = !profilePath.toString().startsWith('http');

        Widget mediaWidget;

        if (post['asset'].toString().endsWith('.mp4')) {
          if (_currentPlayingIndex == index &&
              _videoController != null &&
              _videoController!.value.isInitialized &&
              !_videoController!.value.hasError) {
            try {
              mediaWidget = AspectRatio(
                aspectRatio: 9 / 16,
                child: GestureDetector(
                  onTap: () {
                    if (_videoController != null &&
                        _videoController!.value.isInitialized) {
                      setState(() {
                        if (_videoController!.value.isPlaying) {
                          _videoController!.pause();
                        } else {
                          _videoController!.play();
                        }
                      });
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      VideoPlayer(_videoController!),
                      if (!_videoController!.value.isPlaying)
                        Center(
                          child: Icon(
                            Icons.play_arrow,
                            size: 64,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            } catch (e) {
              mediaWidget = Center(
                child: Text(
                  'Video error',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }
          } else {
            mediaWidget = Center(child: CircularProgressIndicator());
          }
        } else {
          // ✅ Handle images here
          final isAssetImage = !imagePath.toString().startsWith('http');
          mediaWidget =
              isAssetImage
                  ? Image.asset(imagePath, fit: BoxFit.cover)
                  : mediaWidget = AspectRatio(
                    aspectRatio: 9 / 16,
                    child:
                        isAssetImage
                            ? Image.asset(imagePath, fit: BoxFit.cover)
                            : CachedNetworkImage(
                              imageUrl: imagePath,
                              fit: BoxFit.cover,
                              placeholder:
                                  (_, _) => Center(
                                    child: CircularProgressIndicator(),
                                  ),
                              errorWidget:
                                  (_, _, _) =>
                                      Icon(Icons.error, color: Colors.white),
                            ),
                  );
        }

        final ImageProvider profileImageProvider =
            isAssetProfile
                ? AssetImage(profilePath)
                : NetworkImage(profilePath);

        return GestureDetector(
          onTap: () {
            if (_videoController != null &&
                _videoController!.value.isInitialized) {
              setState(() {
                if (_videoController!.value.isPlaying) {
                  _videoController!.pause();
                } else {
                  _videoController!.play();
                }
              });
            }
          },
          child: Stack(
            children: [
              // ✅ Force 9:16 full-width layout
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: mediaWidget,
                  ),
                ),
              ),

              // ✅ Overlay to darken video/image
              Positioned.fill(
                child: Container(color: Colors.black.withValues(alpha: 0.3)),
              ),

              // Bottom left: Text info
              Positioned(
                left: 16,
                bottom: 20,
                right: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '@${post['username']}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '•',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        SizedBox(width: 6),
                        Text(
                          post['date'],
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Builder(
                      builder: (_) {
                        final isExpanded = _expandedPosts.contains(index);
                        final fullText = post['text'];
                        final tags = post['tags'] ?? '';
                        final combinedText = '$fullText ${tags.trim()}'.trim();
                        final shouldTruncate = fullText.length > 50;

                        String displayText = combinedText;
                        if (shouldTruncate && !isExpanded) {
                          displayText = '${combinedText.substring(0, 50)}... ';
                        }

                        return GestureDetector(
                          onTap: () {
                            if (shouldTruncate) {
                              setState(() {
                                if (isExpanded) {
                                  _expandedPosts.remove(index);
                                } else {
                                  _expandedPosts.add(index);
                                }
                              });
                            }
                          },
                          child: RichText(
                            text: TextSpan(
                              text: displayText,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              children:
                                  shouldTruncate && !isExpanded
                                      ? [
                                        TextSpan(
                                          text: 'Read more',
                                          style: TextStyle(
                                            color: AppTheme.readMoreColor,
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ]
                                      : [],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Bottom right: Profile and icons
              Positioned(
                right: 16,
                bottom: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 👁 Eye (Views / Unlocks)
                    if (post['tiers'] != null && post['tiers'].length > 1)
                      GestureDetector(
                        onTap: () {
                          _handleUnlock(context, post, index);
                        },
                        child: Column(
                          children: [
                            SvgPicture.asset(
                              'assets/icons/eye.svg',
                              height: 24,
                              colorFilter: ColorFilter.mode(
                                post['locked'] == false ? AppTheme.eyeColor : Colors.white,
                                BlendMode.srcIn,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${post['views'] ?? 0}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 16),

                    GestureDetector(
                      onTap: () async {
                        // cache before any await
                        final messenger = ScaffoldMessenger.of(context);

                        final postId = post['id'] as int;
                        final isLiked = post['liked'] == true;

                        // optimistic update
                        setState(() {
                          post['liked'] = !isLiked;
                          post['likes'] = isLiked
                              ? (post['likes'] ?? 1) - 1
                              : (post['likes'] ?? 0) + 1;
                        });

                        final result = await PostService.toggleLike(postId: postId);
                        if (!mounted) return; // widget might have been disposed

                        final success = result['success'] as bool? ?? false;
                        if (!success) {
                          // revert if failed
                          if (!mounted) return;
                          setState(() {
                            post['liked'] = isLiked;
                            post['likes'] = isLiked
                                ? (post['likes'] ?? 0) + 1
                                : (post['likes'] ?? 1) - 1;
                          });

                          // use cached messenger (no ancestor lookup after await)
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Failed to update like.')),
                          );
                        }
                      },
                      child: Column(
                        children: [
                          SvgPicture.asset(
                            'assets/icons/like.svg',
                            height: 26,
                            colorFilter: ColorFilter.mode(
                              post['liked'] == true ? AppTheme.likeColor : Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${post['likes'] ?? 0}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // 💬 Comments
                    GestureDetector(
                      onTap: () {
                        _showCommentsSheet(context, post['id']);
                      },
                      child: Column(
                        children: [
                          SvgPicture.asset(
                            'assets/icons/comment.svg',
                            height: 24,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${post['comments'] ?? 0}',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // 🔖 Bookmarks
                    GestureDetector(
                      onTap: () async {
                        // cache before any await
                        final messenger = ScaffoldMessenger.of(context);

                        final int postId = post['id'] as int;
                        final bool isBookmarked = post['bookmarked'] == true;

                        // Optimistic update
                        setState(() {
                          post['bookmarked'] = !isBookmarked;
                          post['bookmarks'] = isBookmarked
                              ? (post['bookmarks'] ?? 1) - 1
                              : (post['bookmarks'] ?? 0) + 1;
                        });

                        final result = await PostService.toggleBookmark(postId: postId);
                        if (!mounted) return;

                        final bool success = result['success'] as bool? ?? false;
                        if (!success) {
                          if (!mounted) return;
                          // Revert if failed
                          setState(() {
                            post['bookmarked'] = isBookmarked;
                            post['bookmarks'] = isBookmarked
                                ? (post['bookmarks'] ?? 0) + 1
                                : (post['bookmarks'] ?? 1) - 1;
                          });

                          // use cached messenger (no ancestor lookup after await)
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Failed to update bookmark.')),
                          );
                        }
                      },
                      child: Column(
                        children: [
                          SvgPicture.asset(
                            'assets/icons/bookmark.svg',
                            height: 22,
                            colorFilter: ColorFilter.mode(
                              post['bookmarked'] == true ? AppTheme.bookmarkColor : Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${post['bookmarks'] ?? 0}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32),
                    Container(
                      padding: EdgeInsets.all(
                        2,
                      ), // space between border and avatar
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.accentColor,
                          width: 1, // 1px border
                        ),
                      ),
                      child: CircleAvatar(
                        backgroundImage: profileImageProvider,
                        radius: 20,
                      ),
                    ),
                  ],
                ),
              ),
              if (post['asset'].toString().endsWith('.mp4') &&
                  _currentPlayingIndex == index &&
                  _videoController != null &&
                  _videoController!.value.isInitialized)
                Positioned(
                  bottom: 0,
                  left: 4,
                  right: 4,
                  child:
                      _videoController != null
                          ? ValueListenableBuilder<VideoPlayerValue>(
                            valueListenable: _videoController!,
                            builder: (context, value, child) {
                              final totalDuration =
                                  value.duration.inMilliseconds;
                              final currentPosition =
                                  value.position.inMilliseconds;

                              // Avoid NaN/overflow
                              if (totalDuration == 0) return SizedBox.shrink();

                              return SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                  overlayShape: RoundSliderOverlayShape(
                                    overlayRadius: 12,
                                  ),
                                ),
                                child: Slider(
                                  value: currentPosition.toDouble().clamp(
                                    0,
                                    totalDuration.toDouble(),
                                  ),
                                  min: 0,
                                  max: totalDuration.toDouble(),
                                  activeColor: AppTheme.accentColor,
                                  inactiveColor: Colors.white24,
                                  onChanged: (newValue) {
                                    final newDuration = Duration(
                                      milliseconds: newValue.toInt(),
                                    );
                                    _videoController!.seekTo(newDuration);
                                  },
                                ),
                              );
                            },
                          )
                          : SizedBox.shrink(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    print(_searchResults);
    if (_searchQuery.length < 2) {
      return Center(
        child: Text(
          "Type to search...",
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          "No results found",
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final post = _searchResults[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage:
                post['user'] != null && post['user']['profile_picture'] != null
                    ? NetworkImage(post['user']['profile_picture'])
                    : AssetImage('assets/images/default_avatar.png')
                        as ImageProvider,
          ),
          title: Text(
            '@${post['user']?['username'] ?? 'unknown'}',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            post['text'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white70),
          ),
          onTap: () {
            final selectedPostId = post['id'];
            final targetIndex = _posts.indexWhere(
              (p) => p['id'] == selectedPostId,
            );

            if (targetIndex != -1) {
              setState(() {
                _isSearching = false;
                _searchQuery = '';
                _searchResults.clear();
              });

              _pageController.animateToPage(
                targetIndex,
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
              _handlePageChanged(targetIndex); // preload video if needed
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Post not found in current feed')),
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _isSearching ? _buildSearchResults() : _buildPostFeed(),

          // 🔍 Floating Search Icon (top-right)
          Positioned(
            top: 40,
            right: 16,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isSearching = !_isSearching;
                  _searchResults.clear();
                  if (!_isSearching) _searchQuery = '';
                });
              },
              child: Icon(
                _isSearching ? Icons.close : Icons.search,
                size: 32,
                color: Colors.white,
              ),
            ),
          ),

          // 🔎 Input field (shown only when searching)
          if (_isSearching)
            Positioned(
              top: 40,
              left: 16,
              right: 64, // leave space for the icon
              child: TextField(
                autofocus: true,
                onChanged: (value) => _onSearchChanged(value),
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black54,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
