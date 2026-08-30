import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

/// 黑名单管理
class BlockedPage extends StatelessWidget {
  const BlockedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('黑 名 单')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        children: [
          if (s.blocked.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Text('黑名单是空的',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: kTextSub.withOpacity(0.7), fontSize: 12)),
            ),
          ...s.blocked.map((b) => DarkCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    MAvatar(b.name, uid: b.id),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(b.name,
                            style: const TextStyle(
                                color: kTextMain, fontSize: 15))),
                    OutlinedButton(
                      onPressed: () async {
                        try {
                          await s.setBlock(id: b.id, block: false);
                          if (context.mounted) toast(context, '已移出黑名单');
                        } catch (e) {
                          if (context.mounted) {
                            toast(context, friendlyError(e), error: true);
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kTextSub,
                        side: BorderSide(color: kBorder),
                        minimumSize: const Size(72, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: const Text('移除', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          Text('被拉黑的人无法给你发消息，也无法添加你为好友。',
              textAlign: TextAlign.center,
              style: TextStyle(color: kTextSub.withOpacity(0.6), fontSize: 11)),
        ],
      ),
    );
  }
}
