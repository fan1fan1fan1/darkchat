import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import 'chat_page.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _name = TextEditingController();
  final _selected = <String>{};
  bool _busy = false;

  Future<void> _create() async {
    if (_busy) return;
    if (_name.text.trim().isEmpty)
      return toast(context, '给群起个名字吧', error: true);
    if (_selected.isEmpty) return toast(context, '请至少选择 1 位好友', error: true);
    setState(() => _busy = true);
    try {
      final g = await context.read<AppState>().createGroup(
            _name.text.trim(),
            _selected.toList(),
          );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ChatPage.forGroup(g)),
        );
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final friends = s.friends.values.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('创建群聊')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
            child: TextField(
              controller: _name,
              style: const TextStyle(color: kTextMain),
              decoration: const InputDecoration(
                hintText: '群名称',
                prefixIcon:
                    Icon(Icons.groups_outlined, color: kTextSub, size: 20),
              ),
            ),
          ),
          Expanded(
            child: friends.isEmpty
                ? Center(
                    child: Text('先去添加好友，才能建群',
                        style: TextStyle(
                            color: kTextSub.withOpacity(0.7), fontSize: 13)))
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    itemCount: friends.length,
                    itemBuilder: (context, i) {
                      final f = friends[i];
                      final checked = _selected.contains(f.id);
                      return ListTile(
                        leading: MAvatar(f.name, radius: 20, uid: f.id),
                        title: Text(f.name,
                            style: const TextStyle(
                                color: kTextMain, fontSize: 15)),
                        subtitle: Text('ID ${f.id}',
                            style:
                                const TextStyle(color: kTextSub, fontSize: 11)),
                        trailing: Checkbox(
                          value: checked,
                          activeColor: kAccent,
                          checkColor: Colors.white,
                          side: const BorderSide(color: kBorder),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(f.id);
                            } else {
                              _selected.remove(f.id);
                            }
                          }),
                        ),
                        onTap: () => setState(() {
                          if (checked) {
                            _selected.remove(f.id);
                          } else {
                            _selected.add(f.id);
                          }
                        }),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: ElevatedButton(
                onPressed: _busy ? null : _create,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('创建群聊（已选 ${_selected.length} 人）'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
