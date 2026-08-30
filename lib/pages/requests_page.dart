import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

class RequestsPage extends StatelessWidget {
  const RequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('新的朋友')),
      body: s.requests.isEmpty
          ? Center(
              child: Text('暂无好友申请',
                  style: TextStyle(
                      color: kTextSub.withOpacity(0.7),
                      fontSize: 13,
                      letterSpacing: 2)))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: s.requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = s.requests[i];
                return DarkCard(
                  child: Row(
                    children: [
                      MAvatar(r.fromName, radius: 24, uid: r.from),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.fromName,
                                style: const TextStyle(
                                    color: kTextMain,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('ID ${r.from} · ${fmtTime(r.ts)}',
                                style: const TextStyle(
                                    color: kTextSub, fontSize: 11)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _respond(context, r.from, false),
                        child:
                            const Text('拒绝', style: TextStyle(color: kTextSub)),
                      ),
                      ElevatedButton(
                        onPressed: () => _respond(context, r.from, true),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(60, 38),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        child: const Text('同意'),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _respond(BuildContext context, String from, bool accept) async {
    try {
      await context.read<AppState>().respondFriend(from, accept);
      if (context.mounted) toast(context, accept ? '已添加好友' : '已拒绝');
    } catch (e) {
      if (context.mounted) {
        toast(context, friendlyError(e), error: true);
      }
    }
  }
}
