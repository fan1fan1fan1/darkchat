import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

/// 固定聊天背景（app.jpg）
const _chatBgDecoration = BoxDecoration(
  image: DecorationImage(
    image: AssetImage('assets/images/chat_bg.jpg'),
    fit: BoxFit.cover,
  ),
);

class ChatPage extends StatefulWidget {
  final String title;
  final String? toUser;
  final String? toGroup;
  final String? subtitle;

  const ChatPage._({
    required this.title,
    this.toUser,
    this.toGroup,
    this.subtitle,
  });

  factory ChatPage.forUser(UserProfile f) => ChatPage.forUserId(f.id, f.name);

  factory ChatPage.forUserId(String id, String name) {
    return ChatPage._(
      title: name,
      subtitle: 'ID $id',
      toUser: id,
    );
  }

  factory ChatPage.forGroup(GroupInfo g) {
    return ChatPage._(
      title: g.name,
      subtitle: '${g.members.length} 人',
      toGroup: g.id,
    );
  }

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _scrollKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().clearUnread(conv);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String get conv {
    final me = context.read<AppState>().me!;
    if (widget.toGroup != null) return convKeyForGroup(widget.toGroup!);
    return convKeyForUser(me.id, widget.toUser!);
  }

  void _sendText() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    try {
      await context.read<AppState>().sendText(
            toUser: widget.toUser,
            toGroup: widget.toGroup,
            text: text,
          );
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  void _sendImage() async {
    try {
      await context.read<AppState>().sendImage(
            toUser: widget.toUser,
            toGroup: widget.toGroup,
          );
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  // ---------- 右上角设置：月标 / 拉黑 / 删除 ----------
  void _toggleStar() async {
    final s = context.read<AppState>();
    try {
      await s.setFriendMeta(
          to: widget.toUser!, star: s.friendMeta[widget.toUser]?.star != true);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  void _toggleBlock() async {
    final s = context.read<AppState>();
    final blocked = s.blocked.any((b) => b.id == widget.toUser);
    try {
      await s.setBlock(id: widget.toUser!, block: !blocked);
      if (mounted) toast(context, blocked ? '已取消拉黑' : '已拉黑');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  void _confirmRemove() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除该联系人'),
        content: const Text('删除后你们将不再是好友，双方好友列表都会移除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除', style: TextStyle(color: kDanger))),
        ],
      ),
    ).then((ok) async {
      if (ok != true) return;
      try {
        await context.read<AppState>().removeFriend(widget.toUser!);
        if (mounted) {
          toast(context, '已删除');
          Navigator.of(context).pop(); // 删除后退出聊天
        }
      } catch (e) {
        if (mounted) toast(context, friendlyError(e), error: true);
      }
    });
  }

  /// 拍一拍：双击对方头像触发
  /// content 编码 — 私聊 'verb|tail|say'；群聊 'targetName|verb|tail|say'
  void _poke(Msg m) {
    final s = context.read<AppState>();
    if (m.from == s.me?.id) return; // 不能拍自己
    final p = s.me?.profile;
    final verb = (p?.pokeVerb.isNotEmpty ?? false) ? p!.pokeVerb : '拍了拍';
    final tail = p?.pokeTail ?? '的肩膀';
    final say = p?.pokeSay ?? '';
    if (widget.toGroup != null) {
      s.sendPoke(
          toGroup: widget.toGroup, content: '${m.fromName}|$verb|$tail|$say');
    } else {
      s.sendPoke(toUser: widget.toUser, content: '$verb|$tail|$say');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final me = s.me!;
    final msgs = s.msgsOf(conv);
    final isGroup = widget.toGroup != null;
    final peerId = widget.toUser;
    // 私聊标题 = 备注名 > 原名
    String title = widget.title;
    if (peerId != null) title = s.displayName(peerId);
    final isBlocked = peerId != null && s.blocked.any((b) => b.id == peerId);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(title, overflow: TextOverflow.ellipsis),
                ),
                if (peerId != null && s.friendMeta[peerId]?.star == true) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.dark_mode, color: kAccent, size: 14),
                ],
              ],
            ),
            if (widget.subtitle != null)
              Text(widget.subtitle!,
                  style: TextStyle(
                      fontSize: 10,
                      color: kTextSub.withOpacity(0.8),
                      letterSpacing: 2)),
          ],
        ),
        actions: [
          if (!isGroup && peerId != s.me?.id) ...[
            IconButton(
              tooltip: '月标好友',
              icon: Icon(
                s.friendMeta[peerId]?.star == true
                    ? Icons.dark_mode
                    : Icons.dark_mode_outlined,
                color: s.friendMeta[peerId]?.star == true ? kAccent : kTextSub,
                size: 20,
              ),
              onPressed: () async {
                try {
                  await s.setFriendMeta(
                      to: peerId!, star: s.friendMeta[peerId]?.star != true);
                } catch (e) {
                  if (mounted) toast(context, friendlyError(e), error: true);
                }
              },
            ),
            PopupMenuButton<String>(
              color: kCard,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              icon: const Icon(Icons.more_vert, color: kTextSub, size: 20),
              onSelected: (v) {
                switch (v) {
                  case 'star':
                    _toggleStar();
                  case 'block':
                    _toggleBlock();
                  case 'remove':
                    _confirmRemove();
                }
              },
              itemBuilder: (_) {
                final starred = s.friendMeta[peerId]?.star == true;
                final blockedNow = s.blocked.any((b) => b.id == peerId);
                return [
                  PopupMenuItem(
                      value: 'star',
                      child: Row(children: [
                        Icon(
                            starred
                                ? Icons.dark_mode
                                : Icons.dark_mode_outlined,
                            color: starred ? kAccent : kTextSub,
                            size: 19),
                        const SizedBox(width: 10),
                        Text(starred ? '取消月标好友' : '添加为月标好友',
                            style: const TextStyle(
                                color: kTextMain, fontSize: 14)),
                      ])),
                  PopupMenuItem(
                      value: 'block',
                      child: Row(children: [
                        Icon(Icons.block_outlined,
                            color: blockedNow ? kDanger : kTextSub, size: 19),
                        const SizedBox(width: 10),
                        Text(blockedNow ? '取消拉黑' : '拉黑',
                            style: TextStyle(
                                color: blockedNow ? kDanger : kTextMain,
                                fontSize: 14)),
                      ])),
                  PopupMenuItem(
                      value: 'remove',
                      child: Row(children: [
                        const Icon(Icons.person_remove_outlined,
                            color: kDanger, size: 19),
                        const SizedBox(width: 10),
                        Text('删除该联系人',
                            style:
                                const TextStyle(color: kDanger, fontSize: 14)),
                      ])),
                ];
              },
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: Container(
        decoration: _chatBgDecoration,
        child: Column(
          children: [
            if (isBlocked)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: kDanger.withOpacity(0.15),
                child: Text('已拉黑：TA 无法给你发消息，你也无法发给 TA',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kDanger, fontSize: 11)),
              ),
            Expanded(
              child: msgs.isEmpty
                  ? Center(
                      child: Text('从这里开始你们的对话',
                          style: TextStyle(
                              color: kTextSub.withOpacity(0.6),
                              fontSize: 12,
                              letterSpacing: 2)))
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ListView.builder(
                        key: _scrollKey,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        itemCount: msgs.length,
                        itemBuilder: (context, i) {
                          final m = msgs[msgs.length - 1 - i];
                          return _bubble(context, m, m.from == me.id, isGroup);
                        },
                      ),
                    ),
            ),
            SafeArea(
              top: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: kSurface,
                  border: Border(top: BorderSide(color: kBorder)),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _sendImage,
                      icon: const Icon(Icons.image_outlined, color: kTextSub),
                      tooltip: '发送图片',
                    ),
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendText(),
                        style: const TextStyle(color: kTextMain, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: '说点什么…',
                          filled: true,
                          fillColor: kCard,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: const BorderSide(color: kBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: const BorderSide(color: kBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: const BorderSide(color: kAccent),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 21,
                      backgroundColor: kAccent,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 19),
                        onPressed: _sendText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pokeLine(String text) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        alignment: Alignment.center,
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(color: kTextSub.withOpacity(0.9), fontSize: 12)),
      );

  Widget _bubble(BuildContext context, Msg m, bool isMe, bool isGroup) {
    // 拍一拍：居中灰色小字，格式 A "{verb}" B的 "{tail}" 并说 "{say}"
    if (m.type == 'poke') {
      final parts = m.content.split('|');
      String verb, tail, say = '';
      if (isGroup) {
        if (parts.length >= 4) {
          verb = parts[1];
          tail = parts[2];
          say = parts[3];
        } else {
          verb = '拍了拍';
          tail = parts.length > 1 ? parts[1] : '';
        }
        final target = parts[0];
        String base = target.isEmpty
            ? '${m.fromName} "$verb"'
            : '${m.fromName} "$verb" ${target}的 "$tail"';
        if (say.isNotEmpty) base = '$base 并说 "$say"';
        return _pokeLine(base);
      }
      if (parts.length >= 3) {
        verb = parts[0];
        tail = parts[1];
        say = parts[2];
      } else {
        verb = '拍了拍';
        tail = m.content;
      }
      final who = isMe ? widget.title : '你';
      String base = tail.isEmpty
          ? '${isMe ? '你' : m.fromName} "$verb" $who'
          : '${isMe ? '你' : m.fromName} "$verb" ${who}的 "$tail"';
      if (say.isNotEmpty) base = '$base 并说 "$say"';
      return _pokeLine(base);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (isGroup && !isMe)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 4),
              child: Text(m.fromName,
                  style: TextStyle(
                      color: kTextSub.withOpacity(0.8), fontSize: 11)),
            ),
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isMe)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(fmtTime(m.ts),
                      style: TextStyle(
                          color: kTextSub.withOpacity(0.5), fontSize: 10)),
                ),
              if (isMe) MAvatar(m.fromName, radius: 15, uid: m.from),
              const SizedBox(width: 8),
              Flexible(
                child: m.type == 'image'
                    ? _imageBubble(m)
                    : m.type == 'voice'
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 9),
                            decoration: BoxDecoration(
                              color: kBubbleOther,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.volume_up,
                                    color: kTextSub, size: 15),
                                const SizedBox(width: 6),
                                Text('[语音消息]',
                                    style: TextStyle(
                                        color: kTextSub, fontSize: 13)),
                              ],
                            ),
                          )
                        : _textBubble(m, isMe),
              ),
              const SizedBox(width: 8),
              if (!isMe)
                GestureDetector(
                  onDoubleTap: () => _poke(m),
                  child: MAvatar(m.fromName, radius: 15, uid: m.from),
                ),
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(fmtTime(m.ts),
                      style: TextStyle(
                          color: kTextSub.withOpacity(0.5), fontSize: 10)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _textBubble(Msg m, bool isMe) {
    final s = context.watch<AppState>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.62),
      decoration: BoxDecoration(
        color: isMe ? kBubbleMine : kBubbleOther,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 16),
        ),
      ),
      child: Text(
        m.content,
        style: TextStyle(
            color: kTextMain, fontSize: 15 * s.fontScale, height: 1.4),
      ),
    );
  }

  Widget _imageBubble(Msg m) {
    Widget img;
    try {
      img = Image.memory(
        base64Decode(m.content),
        width: 190,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kBubbleOther,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          child: const Text('[图片加载失败]',
              style: TextStyle(color: kTextSub, fontSize: 12)),
        ),
      );
    } catch (_) {
      img = const Text('[图片]', style: TextStyle(color: kTextSub));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: kBorder)),
        child: GestureDetector(
          onTap: () => _showImage(m),
          child: img,
        ),
      ),
    );
  }

  void _showImage(Msg m) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            child: Image.memory(base64Decode(m.content), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
