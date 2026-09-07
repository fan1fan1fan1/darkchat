import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import 'add_friend_page.dart';
import 'chat_page.dart';
import 'create_group_page.dart';
import 'friend_profile_page.dart';
import 'moments_page.dart';
import 'personalize_page.dart';
import 'profile_edit_page.dart';
import 'requests_page.dart';
import 'self_profile_page.dart';
import 'settings_page.dart';
// publish_moment_page 由 moments_page 引用

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const ChatsTab(),
      const ContactsTab(),
      const MomentsTab(),
      const MeTab()
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dark Chat · 暗语'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: context.select<AppState, bool>((s) => s.isGuest)
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kAccentDim.withOpacity(0.6)),
                    ),
                    child: const Text('游客模式',
                        style: TextStyle(fontSize: 10, color: kAccent)),
                  )
                : context.select<AppState, ConnState>((s) => s.conn) ==
                        ConnState.connected
                    ? const Icon(Icons.circle,
                        size: 9, color: Color(0xFF34D399))
                    : const Icon(Icons.wifi_off, size: 16, color: kTextSub),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(key: ValueKey(_tab), child: tabs[_tab]),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: kSurface,
          indicatorColor: kAccent.withOpacity(0.18),
          labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 11, color: kTextSub, letterSpacing: 2)),
          iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
                color: s.contains(WidgetState.selected) ? kAccent : kTextSub,
              )),
        ),
        child: NavigationBar(
          height: 64,
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline), label: '消息'),
            NavigationDestination(
                icon: Icon(Icons.people_outline), label: '通讯录'),
            NavigationDestination(
                icon: Icon(Icons.dark_mode_outlined), label: '月痕'),
            NavigationDestination(
                icon: Icon(Icons.person_outline), label: '我的'),
          ],
        ),
      ),
    );
  }
}

// ================= 消息列表 =================
class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (s.me == null) return const SizedBox();

    final items = <({
      String conv,
      String title,
      bool isGroup,
      String otherId,
      String groupId
    })>[];
    for (final f in s.friends.values) {
      items.add((
        conv: convKeyForUser(s.me!.id, f.id),
        title: f.name,
        isGroup: false,
        otherId: f.id,
        groupId: '',
      ));
    }
    for (final g in s.groups.values) {
      items.add((
        conv: convKeyForGroup(g.id),
        title: g.name,
        isGroup: true,
        otherId: '',
        groupId: g.id,
      ));
    }
    // 游客模式：唯一会话 = 跟自己对话
    if (s.isGuest) {
      items.insert(
        0,
        (
          conv: convKeyForUser(s.me!.id, s.me!.id),
          title: '跟自己对话',
          isGroup: false,
          otherId: s.me!.id,
          groupId: '',
        ),
      );
    }
    final list = items
      ..sort((a, b) {
        final ta = s.msgsOf(a.conv).isEmpty ? 0 : s.msgsOf(a.conv).last.ts;
        final tb = s.msgsOf(b.conv).isEmpty ? 0 : s.msgsOf(b.conv).last.ts;
        return tb.compareTo(ta);
      });

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.nights_stay_outlined,
                size: 64, color: kTextSub.withOpacity(0.4)),
            const SizedBox(height: 12),
            const Text('夜还很静，去添加一位好友吧', style: TextStyle(color: kTextSub)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddFriendPage())),
              child: const Text('添加好友'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final e = list.elementAt(i);
        final msgs = s.msgsOf(e.conv);
        final last = msgs.isEmpty ? null : msgs.last;
        final unread = s.unread[e.conv] ?? 0;
        final preview = last == null
            ? '开始对话…'
            : last.type == 'image'
                ? '[图片]'
                : last.content;
        return DarkCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          onTap: () => _openChat(context, e),
          child: Row(
            children: [
              e.isGroup
                  ? CircleAvatar(
                      radius: 22,
                      backgroundColor: kAccentDim.withOpacity(0.3),
                      child: const Icon(Icons.group_outlined,
                          color: kAccent, size: 22),
                    )
                  : MAvatar(
                      e.otherId == s.me?.id ? (s.me?.name ?? '我') : e.title,
                      uid: e.otherId == s.me?.id ? s.me?.id : null),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(e.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: kTextMain,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                        ),
                        if (last != null)
                          Text(fmtTime(last.ts),
                              style: TextStyle(
                                  color: kTextSub.withOpacity(0.7),
                                  fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: kTextSub, fontSize: 13)),
                        ),
                        if (unread > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: kDanger,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('$unread',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openChat(
      BuildContext context,
      ({
        String conv,
        String title,
        bool isGroup,
        String otherId,
        String groupId
      }) e) {
    final s = context.read<AppState>();
    if (e.isGroup) {
      final g = s.groups[e.groupId];
      if (g != null) {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => ChatPage.forGroup(g)));
      }
    } else if (e.otherId == s.me?.id) {
      // 跟自己对话（游客模式 / 自己）
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatPage.forUserId(s.me!.id, e.title)));
    } else {
      final f = s.friends[e.otherId];
      if (f != null) {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => ChatPage.forUser(f)));
      }
    }
  }
}

// ================= 通讯录 =================
class ContactsTab extends StatelessWidget {
  const ContactsTab({super.key});

  /// 排序键：中文转拼音小写
  String _sortKey(String name) {
    try {
      final p = PinyinHelper.getPinyinE(name, separator: '', defPinyin: name);
      return p.toLowerCase();
    } catch (_) {
      return name.toLowerCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final friends = s.friends.values.toList()
      ..sort((a, b) {
        final sa = s.friendMeta[a.id]?.star == true ? 0 : 1;
        final sb = s.friendMeta[b.id]?.star == true ? 0 : 1;
        if (sa != sb) return sa.compareTo(sb); // 星标置顶
        return _sortKey(s.displayName(a.id))
            .compareTo(_sortKey(s.displayName(b.id)));
      });
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      children: [
        if (s.isGuest)
          DarkCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: kAccent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('游客模式',
                          style: TextStyle(color: kTextMain, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('添加好友、群聊等社交功能，登录或注册后即可使用',
                          style: TextStyle(
                              color: kTextSub, fontSize: 11, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          )
        else ...[
          _actionTile(context, Icons.person_add_alt_1_outlined, '添加好友',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddFriendPage()))),
          _actionTile(context, Icons.group_add_outlined, '创建群聊',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateGroupPage()))),
          _actionTile(context, Icons.notifications_outlined, '新的朋友',
              badge: s.requests.length,
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RequestsPage()))),
        ],
        const Padding(
          padding: EdgeInsets.fromLTRB(6, 18, 0, 8),
          child: Text('好友',
              style:
                  TextStyle(color: kTextSub, fontSize: 12, letterSpacing: 4)),
        ),
        if (friends.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Text(s.isGuest ? '游客模式下没有好友 · 登录后解锁社交' : '还没有好友 · 通过对方的账号添加',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: kTextSub.withOpacity(0.7), fontSize: 12)),
          ),
        ...friends.map((f) {
          final starred = s.friendMeta[f.id]?.star == true;
          final remark = s.friendMeta[f.id]?.remark ?? '';
          return DarkCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            margin: const EdgeInsets.only(bottom: 8),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => FriendProfilePage(userId: f.id))),
            child: Row(
              children: [
                MAvatar(s.displayName(f.id), uid: f.id),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(s.displayName(f.id),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: kTextMain, fontSize: 15)),
                      ),
                      if (remark.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text('(${f.name})',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: kTextSub.withOpacity(0.7),
                                fontSize: 11)),
                      ],
                    ],
                  ),
                ),
                if (starred)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(Icons.dark_mode, color: kAccent, size: 14),
                  ),
                Text('ID ${f.id}',
                    style: TextStyle(
                        color: kTextSub.withOpacity(0.6), fontSize: 11)),
              ],
            ),
          );
        }),
        // 自己：默认好友，排在好友栏末尾
        if (s.me != null)
          DarkCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            margin: const EdgeInsets.only(bottom: 8),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SelfProfilePage())),
            child: Row(
              children: [
                MAvatar(s.me!.name, uid: s.me!.id),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(s.me!.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kTextMain, fontSize: 15)),
                ),
                Text(s.isGuest ? '游客 · 本地资料' : '我自己 · ID ${s.me!.id}',
                    style: TextStyle(
                        color: kTextSub.withOpacity(0.6), fontSize: 11)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _actionTile(BuildContext context, IconData icon, String title,
      {VoidCallback? onTap, int badge = 0}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DarkCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: kAccent, size: 22),
            const SizedBox(width: 12),
            Expanded(
                child: Text(title,
                    style: const TextStyle(color: kTextMain, fontSize: 15))),
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: kDanger, borderRadius: BorderRadius.circular(10)),
                child: Text('$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
            const Icon(Icons.chevron_right, color: kTextSub, size: 20),
          ],
        ),
      ),
    );
  }
}

// ================= 我的 =================
class MeTab extends StatelessWidget {
  const MeTab({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final s = context.read<AppState>();
    if (s.isGuest) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('退出游客模式'),
          content: const Text(
              '游客数据仅保存在本机，下次以游客进入仍会保留。\n退出后可登录或注册账号，解锁聊天、加好友等社交功能。',
              style: TextStyle(fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('再逛逛'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('退出游客模式'),
            ),
          ],
        ),
      );
      if (ok == true) await s.logout();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('你要退出还是切换账号？', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'switch'),
            child: const Text('登录其他账号'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'logout'),
            child: const Text('仅退出'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    // 仅退出：保留自动登录；切换账号：清除记住的账号密码
    await s.logout(clearSaved: choice == 'switch');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final me = s.me;
    if (me == null) return const SizedBox();
    final p = me.profile;
    String? birthAge;
    if (p.birth.isNotEmpty) {
      final b = DateTime.tryParse(p.birth);
      if (b != null) {
        final now = DateTime.now();
        var age = now.year - b.year;
        if (now.month < b.month || (now.month == b.month && now.day < b.day))
          age--;
        if (age >= 0 && age < 200) birthAge = '$age岁';
      }
    }
    final tags = <String>[
      if (p.gender.isNotEmpty) p.gender,
      if (birthAge != null) birthAge,
      if (p.constellation.isNotEmpty) p.constellation,
      if (p.mbti.isNotEmpty) p.mbti,
      if (p.location.isNotEmpty) p.location,
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      children: [
        // 顶部：头像 + 名称
        DarkCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                MAvatar(me.name, radius: 32, uid: me.id),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(me.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: kTextMain,
                              fontSize: 19,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 5),
                      Text(s.isGuest ? '游客模式 · 资料仅保存在本机' : '账号 ${me.id}',
                          style: TextStyle(color: kTextSub, fontSize: 12)),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final t in tags)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: kAccent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(t,
                                    style: TextStyle(
                                        color: kAccent, fontSize: 11)),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        DarkCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              _entry(
                  Icons.person_outline,
                  '个人中心',
                  s.isGuest
                      ? '名称 · 签名 · 头像 · 性别 · 星座'
                      : '名称 · 性别 · 星座 · MBTI · 密码', () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfileEditPage()));
              }),
              const Divider(height: 1),
              _entry(Icons.palette_outlined, '个性化', '聊天背景 · 字体大小', () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PersonalizePage()));
              }),
              const Divider(height: 1),
              _entry(Icons.settings_outlined, '设置', '通知 · 隐私 · 黑名单', () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()));
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => _confirmLogout(context),
          icon: Icon(s.isGuest ? Icons.login : Icons.logout, size: 18),
          label: Text(s.isGuest ? '退出游客模式 / 去登录' : '退出登录'),
          style: OutlinedButton.styleFrom(
            foregroundColor: kDanger,
            side: BorderSide(color: kDanger.withOpacity(0.4)),
            minimumSize: const Size.fromHeight(46),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _entry(
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 58,
        child: Row(
          children: [
            Icon(icon, color: kTextSub, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: kTextMain, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: kTextSub, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kTextSub, size: 20),
          ],
        ),
      ),
    );
  }
}
