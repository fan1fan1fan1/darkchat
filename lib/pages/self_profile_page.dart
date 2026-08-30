import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import 'chat_page.dart';
import 'moment_user_page.dart';
import 'profile_edit_page.dart';

/// 我的主页（通讯录点自己）：跟好友主页同构，可给自己发消息
class SelfProfilePage extends StatelessWidget {
  const SelfProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final me = s.me!;
    final p = me.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的主页'),
        actions: [
          PopupMenuButton<String>(
            color: kCard,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            icon: const Icon(Icons.more_vert, color: kTextSub),
            onSelected: (v) {
              if (v == 'edit') {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileEditPage()));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, color: kTextSub, size: 19),
                    SizedBox(width: 10),
                    Text('编辑个人资料',
                        style: TextStyle(color: kTextMain, fontSize: 14)),
                  ])),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        children: [
          Center(child: MAvatar(me.name, radius: 42, uid: me.id)),
          const SizedBox(height: 10),
          Center(
            child: Text(me.name,
                style: const TextStyle(
                    color: kTextMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ),
          if (p.signature.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Center(
                child: Text('「${p.signature}」',
                    style: TextStyle(
                        color: kTextSub.withOpacity(0.9), fontSize: 12)),
              ),
            ),
          const SizedBox(height: 22),
          // 给自己发消息（像微信的文件传输助手）
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChatPage.forUserId(me.id, me.name))),
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
          // 我的月痕入口
          DarkCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => MomentUserPage(userId: me.id))),
            child: const Row(
              children: [
                Icon(Icons.dark_mode_outlined, color: kAccent, size: 19),
                SizedBox(width: 12),
                Expanded(
                    child: Text('我的月痕',
                        style: TextStyle(color: kTextMain, fontSize: 14))),
                Icon(Icons.chevron_right, color: kTextSub, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
