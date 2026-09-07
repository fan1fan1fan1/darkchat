import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import 'blocked_page.dart';

/// 设置：消息通知、隐私、通用
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('设 置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        children: [
          _section('消息通知'),
          DarkCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _switchTile(
                  '消息弹窗通知',
                  '收到新消息时在顶部弹横幅提醒',
                  s.notifyEnabled,
                  (v) => s.setNotifyEnabled(v),
                ),
              ],
            ),
          ),
          if (!s.isGuest) ...[
            _section('隐私'),
            DarkCard(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _switchTile(
                    '允许通过账号搜索到我',
                    '关闭后其他人无法搜索添加你，你仍可主动加人',
                    s.me?.settings.searchable ?? true,
                    (v) async {
                      try {
                        await s.updateSettings(searchable: v);
                      } catch (e) {
                        if (context.mounted) {
                          toast(context, friendlyError(e), error: true);
                        }
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('黑名单', style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                        s.blocked.isEmpty ? '暂无黑名单用户' : '${s.blocked.length} 人',
                        style: TextStyle(color: kTextSub, fontSize: 11)),
                    trailing:
                        Icon(Icons.chevron_right, color: kTextSub, size: 20),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BlockedPage())),
                  ),
                ],
              ),
            ),
          ],
          _section('通用'),
          DarkCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('清空本地聊天记录', style: const TextStyle(fontSize: 14)),
                  subtitle: Text(s.isGuest ? '清除本机保存的对话记录' : '不影响服务器保存的记录',
                      style: TextStyle(color: kTextSub, fontSize: 11)),
                  trailing:
                      Icon(Icons.chevron_right, color: kTextSub, size: 20),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('清空本地聊天记录'),
                        content: Text('仅清除本机缓存的消息，重新登录会从服务器恢复。',
                            style: const TextStyle(fontSize: 13)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('取消')),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('清空')),
                        ],
                      ),
                    );
                    if (ok == true && context.mounted) {
                      s.clearLocalHistory();
                      toast(context, '已清空本地记录');
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('关于', style: const TextStyle(fontSize: 14)),
                  subtitle: Text('Dark Chat · 暗语 v1.0',
                      style: TextStyle(color: kTextSub, fontSize: 11)),
                  trailing:
                      Icon(Icons.chevron_right, color: kTextSub, size: 20),
                  onTap: () => toast(context, '小樊赠言：黑夜中的低语，只有该听见的人听见'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(text,
            style: TextStyle(color: kTextSub, fontSize: 12, letterSpacing: 2)),
      );

  Widget _switchTile(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(color: kTextSub, fontSize: 11)),
      value: value,
      activeColor: kAccent,
      onChanged: onChanged,
    );
  }
}
