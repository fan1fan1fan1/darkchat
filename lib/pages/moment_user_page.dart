import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/moment_card.dart';
import 'moments_page.dart';
import 'publish_moment_page.dart';

/// 个人月痕主页：显示某人发的全部月痕（像朋友圈主页）
class MomentUserPage extends StatefulWidget {
  final String userId;
  const MomentUserPage({super.key, required this.userId});

  @override
  State<MomentUserPage> createState() => _MomentUserPageState();
}

class _MomentUserPageState extends State<MomentUserPage> {
  @override
  void initState() {
    super.initState();
    context.read<AppState>().loadMoments().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final isMe = widget.userId == s.me?.id;
    if (!isMe && s.friends[widget.userId] == null) {
      return Scaffold(
          body: const Center(
              child: Text('TA 还不是你的好友', style: TextStyle(color: kTextSub))));
    }
    final name = isMe ? s.me!.name : s.displayName(widget.userId);
    final profile = isMe ? s.me!.profile : s.friends[widget.userId]!.profile;
    final mine = s.moments.where((m) => m.from == widget.userId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(isMe ? '我的月痕' : '$name 的月痕'),
      ),
      body: RefreshIndicator(
        color: kAccent,
        backgroundColor: kSurface,
        onRefresh: () => s.loadMoments(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            // 个人信息头
            Row(
              children: [
                MAvatar(name, radius: 26, uid: widget.userId),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: kTextMain,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      if (profile.signature.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(profile.signature,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: kTextSub.withOpacity(0.9),
                                  fontSize: 11)),
                        ),
                    ],
                  ),
                ),
                Text('共 ${mine.length} 道',
                    style: TextStyle(
                        color: kTextSub.withOpacity(0.6), fontSize: 11)),
              ],
            ),
            const SizedBox(height: 12),
            if (mine.isEmpty)
              _emptyGuide(isMe: isMe)
            else
              ...mine.map((m) => MomentCard(
                    m: m,
                    showDelete: m.from == s.me?.id,
                    onDelete: () async {
                      try {
                        await s.deleteMoment(m.id);
                      } catch (e) {
                        if (context.mounted) {
                          toast(context, friendlyError(e), error: true);
                        }
                      }
                    },
                    onLike: () async {
                      try {
                        await s.likeMoment(m.id);
                      } catch (e) {
                        if (context.mounted) {
                          toast(context, friendlyError(e), error: true);
                        }
                      }
                    },
                    onComment: (text) async {
                      try {
                        await s.commentMoment(m.id, text: text);
                      } catch (e) {
                        if (context.mounted) {
                          toast(context, friendlyError(e), error: true);
                        }
                      }
                    },
                    likedByMe: m.likes.contains(s.me?.id),
                  )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// 空月痕引导卡（完整复刻）
  Widget _emptyGuide({required bool isMe}) {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: DarkCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kAccent.withOpacity(0.12),
                border: Border.all(color: kAccentDim, width: 1),
              ),
              child: Icon(Icons.dark_mode_outlined, color: kAccent, size: 32),
            ),
            const SizedBox(height: 16),
            Text('月 痕 还 空 着',
                style: TextStyle(
                    color: kTextMain,
                    fontSize: 15,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text('把此刻的心情、想说的话、看到的风景\n留在这里——就像夜空下的脚印\n你的好友都能看到，也能为你点上一盏月',
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextSub, fontSize: 12, height: 1.7)),
            if (isMe) ...[
              const SizedBox(height: 22),
              SizedBox(
                width: 180,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PublishMomentPage())),
                  icon: Icon(Icons.edit_outlined, size: 15),
                  label: Text('留下第一道痕迹',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 14),
              Text('等 TA 留下第一道痕迹',
                  style: TextStyle(
                      color: kTextSub.withOpacity(0.7), fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}
