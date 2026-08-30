import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import 'moment_user_page.dart';
import '../widgets/moment_card.dart';
import 'publish_moment_page.dart';

/// 月痕：好友动态（类似朋友圈）
class MomentsTab extends StatefulWidget {
  const MomentsTab({super.key});

  @override
  State<MomentsTab> createState() => _MomentsTabState();
}

class _MomentsTabState extends State<MomentsTab> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => context.read<AppState>().loadMoments().catchError((_) {}));
  }

  Future<void> _refresh() async {
    try {
      await context.read<AppState>().loadMoments();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return RefreshIndicator(
      color: kAccent,
      backgroundColor: kSurface,
      onRefresh: _refresh,
      child: Column(
        children: [
          // 顶部扁横幅：月亮标 + 描述 + 留痕按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: DarkCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kAccent.withOpacity(0.12),
                      border: Border.all(
                          color: kAccentDim.withOpacity(0.6), width: 1),
                    ),
                    child: Icon(Icons.dark_mode_outlined,
                        color: kAccent, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.moments.isEmpty ? '月痕还空着' : '月 痕',
                            style: TextStyle(
                                color: kTextMain,
                                fontSize: 13,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                            s.moments.isEmpty
                                ? '留一句话或一张图，好友都能看见'
                                : '你和好友们在黑暗里留下的痕迹',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: kTextSub, fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 62,
                    height: 30,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const PublishMomentPage())),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccent,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9)),
                      ),
                      child: const Text('留痕',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 我的月痕入口（像朋友圈的个人主页）
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: DarkCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MomentUserPage(userId: s.me?.id ?? ''))),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  MAvatar(s.me?.name ?? '我', radius: 15, uid: s.me?.id),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('我的月痕',
                        style: TextStyle(color: kTextMain, fontSize: 13)),
                  ),
                  Text('个人主页',
                      style: TextStyle(
                          color: kTextSub.withOpacity(0.7), fontSize: 11)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: kTextSub, size: 18),
                ],
              ),
            ),
          ),
          Expanded(
            child: s.moments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.nights_stay_outlined,
                            size: 56, color: kTextSub.withOpacity(0.35)),
                        const SizedBox(height: 10),
                        Text('夜空还空着，等你的第一道痕迹',
                            style: TextStyle(
                                color: kTextSub.withOpacity(0.8),
                                fontSize: 13)),
                      ],
                    ),
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    children: [
                      ...s.moments.map((m) => MomentCard(
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
        ],
      ),
    );
  }
}
