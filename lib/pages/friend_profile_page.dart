import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import 'chat_page.dart';
import 'moment_user_page.dart';

/// 好友主页：头像名称 + 发消息 + TA的月痕 + 右上角三点（月标/备注/拉黑/删除）
class FriendProfilePage extends StatelessWidget {
  final String userId;
  const FriendProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final f = s.friends[userId];
    if (f == null) {
      return const Scaffold(
          body: Center(
              child: Text('对方已不是你的好友', style: TextStyle(color: kTextSub))));
    }
    final meta = s.friendMeta[userId] ?? FriendMeta();
    final p = f.profile;
    final blocked = s.blocked.any((b) => b.id == userId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('主页'),
        actions: [
          PopupMenuButton<String>(
            color: kCard,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            icon: const Icon(Icons.more_vert, color: kTextSub),
            onSelected: (v) async {
              switch (v) {
                case 'star':
                  try {
                    await s.setFriendMeta(to: userId, star: !meta.star);
                    if (context.mounted) {
                      toast(context, meta.star ? '已取消月标' : '已设为月标好友');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      toast(context, friendlyError(e), error: true);
                    }
                  }
                case 'remark':
                  _editRemark(context, s, meta.remark);
                case 'block':
                  try {
                    await s.setBlock(id: userId, block: !blocked);
                    if (context.mounted) {
                      toast(context, blocked ? '已取消拉黑' : '已拉黑');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      toast(context, friendlyError(e), error: true);
                    }
                  }
                case 'remove':
                  _removeFriend(context, s);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'star',
                  child: Row(children: [
                    Icon(meta.star ? Icons.dark_mode : Icons.dark_mode_outlined,
                        color: meta.star ? kAccent : kTextSub, size: 19),
                    const SizedBox(width: 10),
                    Text(meta.star ? '取消月标好友' : '设为月标好友',
                        style: const TextStyle(color: kTextMain, fontSize: 14)),
                  ])),
              PopupMenuItem(
                  value: 'remark',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, color: kTextSub, size: 19),
                    const SizedBox(width: 10),
                    Text(meta.remark.isEmpty ? '设置备注' : '修改备注',
                        style: const TextStyle(color: kTextMain, fontSize: 14)),
                  ])),
              PopupMenuItem(
                  value: 'block',
                  child: Row(children: [
                    Icon(Icons.block_outlined,
                        color: blocked ? kDanger : kTextSub, size: 19),
                    const SizedBox(width: 10),
                    Text(blocked ? '取消拉黑' : '拉黑',
                        style: TextStyle(
                            color: blocked ? kDanger : kTextMain,
                            fontSize: 14)),
                  ])),
              PopupMenuItem(
                  value: 'remove',
                  child: Row(children: [
                    Icon(Icons.person_remove_outlined,
                        color: kDanger, size: 19),
                    const SizedBox(width: 10),
                    Text('删除好友',
                        style: TextStyle(color: kDanger, fontSize: 14)),
                  ])),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        children: [
          Center(
              child: MAvatar(meta.remark.isNotEmpty ? meta.remark : f.name,
                  radius: 42, uid: userId)),
          const SizedBox(height: 10),
          Center(
            child: Text(meta.remark.isNotEmpty ? meta.remark : f.name,
                style: const TextStyle(
                    color: kTextMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ),
          // 个性签名
          if (p.signature.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Center(
                child: Text('「${p.signature}」',
                    style: TextStyle(
                        color: kTextSub.withOpacity(0.9), fontSize: 12)),
              ),
            ),
          if (meta.star)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.dark_mode, color: kAccent, size: 14),
                  const SizedBox(width: 4),
                  Text('月标好友', style: TextStyle(color: kAccent, fontSize: 11)),
                ]),
              ),
            ),
          const SizedBox(height: 22),
          // 发消息
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChatPage.forUserId(
                    userId, meta.remark.isNotEmpty ? meta.remark : f.name))),
            icon: const Icon(Icons.chat_bubble_outline, size: 17),
            label: const Text('发 消 息',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 10),
          // TA 的月痕入口
          DarkCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => MomentUserPage(userId: userId))),
            child: Row(
              children: [
                Icon(Icons.dark_mode_outlined, color: kAccent, size: 19),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('TA 的月痕',
                      style: const TextStyle(color: kTextMain, fontSize: 14)),
                ),
                const Icon(Icons.chevron_right, color: kTextSub, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  void _editRemark(BuildContext context, AppState s, String current) {
    final c = TextEditingController(text: current);
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置备注'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 16,
          decoration: const InputDecoration(hintText: '备注名（留空清除）'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('保存')),
        ],
      ),
    ).then((remark) async {
      if (remark == null) return;
      try {
        await s.setFriendMeta(to: userId, remark: remark);
      } catch (e) {
        if (context.mounted) toast(context, friendlyError(e), error: true);
      }
    });
  }

  void _removeFriend(BuildContext context, AppState s) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除好友'),
        content: const Text('删除后你们将不再是好友，双方好友列表都会移除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    ).then((ok) async {
      if (ok != true) return;
      try {
        await s.removeFriend(userId);
        if (context.mounted) {
          toast(context, '已删除');
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (context.mounted) toast(context, friendlyError(e), error: true);
      }
    });
  }
}
