import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

class AddFriendPage extends StatefulWidget {
  const AddFriendPage({super.key});

  @override
  State<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  final _kw = TextEditingController();
  UserProfile? _found;
  String? _hint;
  bool _busy = false;

  Future<void> _search() async {
    if (_kw.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _found = null;
      _hint = null;
    });
    try {
      final s = context.read<AppState>();
      final u = await s.searchUser(_kw.text);
      setState(() {
        if (u == null) {
          _hint = '未找到该用户 · 请确认对方账号';
        } else if (u.id == s.me?.id) {
          _hint = '这是你自己 :)';
        } else {
          _found = u;
        }
      });
    } catch (e) {
      setState(() => _hint = friendlyError(e));
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final u = _found!;
    try {
      await context.read<AppState>().addFriend(u.id);
      if (mounted) {
        toast(context, '好友申请已发送，等待对方验证');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加好友')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          Text('通过对方的账号 ID 或手机号精准查找',
              style:
                  TextStyle(color: kTextSub, fontSize: 12, letterSpacing: 2)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _kw,
                  onSubmitted: (_) => _search(),
                  style: const TextStyle(color: kTextMain, letterSpacing: 2),
                  decoration: const InputDecoration(
                    hintText: '对方账号',
                    prefixIcon: Icon(Icons.search, color: kTextSub, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                width: 76,
                child: ElevatedButton(
                  onPressed: _busy ? null : _search,
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('搜索',
                          style: TextStyle(fontSize: 14, letterSpacing: 2)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_hint != null)
            Center(
                child: Text(_hint!,
                    style: const TextStyle(color: kTextSub, fontSize: 13))),
          if (_found != null)
            DarkCard(
              child: Row(
                children: [
                  MAvatar(_found!.name, radius: 26, uid: _found!.id),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_found!.name,
                            style: const TextStyle(
                                color: kTextMain,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('ID ${_found!.id}',
                            style:
                                const TextStyle(color: kTextSub, fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _add,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(72, 38),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: const Text('加好友'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
