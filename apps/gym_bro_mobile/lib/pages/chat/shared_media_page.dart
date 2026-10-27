import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/chat.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/open_url.dart';
import '../../widgets/social_widgets.dart';
import 'chat_attachments.dart';
import 'chat_widgets.dart';

/// Everything shared in a conversation: Media (photos+videos grid), Files
/// and Audio.
class SharedMediaPage extends StatelessWidget {
  final String conversationId;
  final String? title;

  const SharedMediaPage({super.key, required this.conversationId, this.title});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title ?? l10n.chatSharedMedia),
          bottom: TabBar(tabs: [
            Tab(text: l10n.chatTabMedia),
            Tab(text: l10n.chatTabFiles),
            Tab(text: l10n.chatTabAudio),
          ]),
        ),
        body: TabBarView(children: [
          _SharedTab(conversationId: conversationId, type: 'media'),
          _SharedTab(conversationId: conversationId, type: 'file'),
          _SharedTab(conversationId: conversationId, type: 'audio'),
        ]),
      ),
    );
  }
}

class _SharedTab extends StatefulWidget {
  final String conversationId;
  final String type;

  const _SharedTab({required this.conversationId, required this.type});

  @override
  State<_SharedTab> createState() => _SharedTabState();
}

class _SharedTabState extends State<_SharedTab> with AutomaticKeepAliveClientMixin {
  static const _pageSize = 60;
  final _api = ApiService();
  final _items = <SharedMedia>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 0;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final items = await _api.getSharedMedia(token, widget.conversationId, type: widget.type);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _page = 1;
        _hasMore = items.length >= _pageSize;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = chatErrorText(e);
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final items = await _api.getSharedMedia(token, widget.conversationId, type: widget.type, page: _page);
      if (!mounted) return;
      setState(() {
        final ids = _items.map((e) => e.id).toSet();
        _items.addAll(items.where((e) => !ids.contains(e.id)));
        _page++;
        _hasMore = items.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.extentAfter < 400) _loadMore();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ChatErrorState(
        message: _error!,
        onRetry: () {
          setState(() {
            _loading = true;
            _error = null;
          });
          _load();
        },
      );
    }
    if (_items.isEmpty) {
      return ChatEmptyState(
        icon: switch (widget.type) {
          'media' => Icons.photo_library_outlined,
          'audio' => Icons.audiotrack_outlined,
          _ => Icons.folder_open_outlined,
        },
        title: switch (widget.type) {
          'media' => l10n.chatNoMedia,
          'audio' => l10n.chatNoAudio,
          _ => l10n.chatNoFiles,
        },
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: RefreshIndicator(
        onRefresh: _load,
        child: widget.type == 'media' ? _grid() : _list(),
      ),
    );
  }

  Widget _grid() {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
      itemCount: _items.length,
      itemBuilder: (context, i) {
        final m = _items[i];
        final url = m.url;
        final isVideo = m.type == AttachmentType.video;
        return Semantics(
          button: true,
          label: isVideo ? context.l10n.chatVideoMessage : context.l10n.chatPhotoMessage,
          child: GestureDetector(
            onTap: url == null ? null : () => MediaViewerPage.open(context, url: url, isVideo: isVideo),
            child: isVideo
                ? Stack(fit: StackFit.expand, children: [
                    Container(color: Colors.black),
                    const Center(child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 36)),
                    if (m.durationMs != null) Positioned(left: 4, bottom: 4, child: DurationBadge(ms: m.durationMs!)),
                  ])
                : url == null
                    ? ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHigh)
                    : MediaImage(url: url),
          ),
        );
      },
    );
  }

  Widget _list() {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final m = _items[i];
        final date = chatDayLabel(l10n, m.createdAt);
        if (widget.type == 'audio') {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              AudioAttachment(url: m.url, durationMs: m.durationMs, mine: false),
              const SizedBox(width: 12),
              Expanded(child: Text(date, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant))),
            ]),
          );
        }
        final url = m.url;
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(10)),
            child: Icon(fileIconFor(m.mimeType, m.fileName), color: cs.onSurfaceVariant),
          ),
          title: Text(m.fileName ?? l10n.chatMediaFile, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${formatBytes(m.sizeBytes)} · $date'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: url == null ? null : () => openExternalUrl(context, url),
        );
      },
    );
  }
}
