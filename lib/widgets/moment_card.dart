import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

/// 月痕动态卡片（feed 与好友主页共用）
class MomentCard extends StatelessWidget {
  final Moment m;
  final bool showDelete;
  final VoidCallback onDelete;
  final VoidCallback onLike;
  final Future<void> Function(String text)? onComment;
  final bool likedByMe;

  const MomentCard({
    super.key,
    required this.m,
    required this.showDelete,
    required this.onDelete,
    required this.onLike,
    required this.likedByMe,
    this.onComment,
  });

  String _fmt(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final name =
        s.displayName(m.from) == m.from ? m.name : s.displayName(m.from);
    return DarkCard(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MAvatar(name, radius: 16, uid: m.from),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: kTextMain,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text(_fmt(m.ts),
                        style: TextStyle(
                            color: kTextSub.withOpacity(0.6), fontSize: 10)),
                  ],
                ),
              ),
              if (showDelete)
                GestureDetector(
                  onTap: onDelete,
                  child: Icon(Icons.delete_outline, color: kTextSub, size: 18),
                ),
            ],
          ),
          if (m.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(m.text,
                  style: const TextStyle(
                      color: kTextMain, fontSize: 14, height: 1.45)),
            ),
          if (m.images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final img in m.images)
                    GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: InteractiveViewer(
                                child: Image.memory(base64Decode(img),
                                    fit: BoxFit.contain)),
                          ),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(img),
                          width: 92,
                          height: 92,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 92,
                            height: 92,
                            color: kBubbleMine,
                            child: const Icon(Icons.broken_image_outlined,
                                color: kTextSub, size: 20),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (m.likes.isNotEmpty) ...[
                Icon(Icons.dark_mode,
                    color: kAccent.withOpacity(0.8), size: 13),
                const SizedBox(width: 4),
                // 点月人名单（点赞显示用户姓名）
                Expanded(
                  child: Builder(builder: (ctx) {
                    final s = ctx.watch<AppState>();
                    final names =
                        m.likes.map((id) => s.displayName(id)).toList();
                    return Text(names.join('、'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: kTextSub.withOpacity(0.9), fontSize: 11));
                  }),
                ),
              ] else
                const Spacer(),
              GestureDetector(
                onTap: onComment != null
                    ? () async {
                        final ctrl = TextEditingController();
                        final text = await showDialog<String>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: kCard,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                    color: kAccentDim.withOpacity(0.5))),
                            title: Text('评论这条痕迹',
                                style:
                                    TextStyle(color: kTextMain, fontSize: 15)),
                            content: TextField(
                              controller: ctrl,
                              autofocus: true,
                              maxLength: 200,
                              style: TextStyle(color: kTextMain, fontSize: 14),
                              decoration: InputDecoration(
                                  hintText: '说点什么…',
                                  hintStyle: TextStyle(
                                      color: kTextSub.withOpacity(0.5))),
                            ),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text('取消',
                                      style: TextStyle(color: kTextSub))),
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, ctrl.text.trim()),
                                  child: Text('发送',
                                      style: TextStyle(
                                          color: kAccent,
                                          fontWeight: FontWeight.w600))),
                            ],
                          ),
                        );
                        if (text != null && text.isNotEmpty) {
                          await onComment!(text);
                        }
                      }
                    : null,
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, color: kTextSub, size: 14),
                    const SizedBox(width: 3),
                    Text(m.comments.isEmpty ? '评论' : '${m.comments.length}',
                        style: TextStyle(color: kTextSub, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: onLike,
                child: Row(
                  children: [
                    Icon(
                      likedByMe ? Icons.dark_mode : Icons.dark_mode_outlined,
                      color: likedByMe ? kAccent : kTextSub,
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Text(likedByMe ? '已点月' : '点月',
                        style: TextStyle(
                            color: likedByMe ? kAccent : kTextSub,
                            fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          // 评论列表
          if (m.comments.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder.withOpacity(0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final c in m.comments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: c['name']?.toString() ?? '用户',
                              style: TextStyle(
                                  color: kAccent.withOpacity(0.9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                          TextSpan(
                              text: '：${c['text']}',
                              style: TextStyle(color: kTextSub, fontSize: 11)),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
