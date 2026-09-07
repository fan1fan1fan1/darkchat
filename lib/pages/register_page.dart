import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _account = TextEditingController();
  final _invite = TextEditingController();
  final _pwd = TextEditingController();
  final _pwd2 = TextEditingController();
  bool _busy = false;
  bool _hidePwd = true;

  Future<void> _register() async {
    if (_busy) return;
    final account = _account.text.trim();
    if (!RegExp(r'^[\u4e00-\u9fa5a-zA-Z0-9]{2,16}$').hasMatch(account))
      return toast(context, '账号需为 2-16 位中文、字母或数字', error: true);
    if (_invite.text.trim().isEmpty)
      return toast(context, '请输入邀请码', error: true);
    if (_pwd.text.length < 6) return toast(context, '密码至少 6 位', error: true);
    if (_pwd.text != _pwd2.text) return toast(context, '两次密码不一致', error: true);
    setState(() => _busy = true);
    try {
      final s = context.read<AppState>();
      await s.registerAndLogin(
        account: account,
        password: _pwd.text,
        invite: _invite.text.trim(),
      );
      // 成功后 RootPage 自动进入主页
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注 册')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          children: [
            Text('凭邀请码创建你的暗语身份',
                style:
                    TextStyle(color: kTextSub, fontSize: 13, letterSpacing: 4)),
            const SizedBox(height: 24),
            TextField(
              controller: _account,
              keyboardType: TextInputType.visiblePassword,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'[\u4e00-\u9fa5a-zA-Z0-9]')),
              ],
              maxLength: 16,
              style: const TextStyle(color: kTextMain, letterSpacing: 2),
              decoration: const InputDecoration(
                hintText: '账号（字母或数字，2-16 位）',
                counterText: '',
                prefixIcon:
                    Icon(Icons.person_outline, color: kTextSub, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _invite,
              keyboardType: TextInputType.number,
              maxLength: 5,
              style: const TextStyle(color: kTextMain, letterSpacing: 6),
              decoration: const InputDecoration(
                hintText: '邀请码',
                counterText: '',
                prefixIcon:
                    Icon(Icons.shield_outlined, color: kTextSub, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pwd,
              obscureText: _hidePwd,
              style: const TextStyle(color: kTextMain),
              decoration: InputDecoration(
                hintText: '设置密码（至少 6 位）',
                prefixIcon:
                    const Icon(Icons.lock_outline, color: kTextSub, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(_hidePwd ? Icons.visibility_off : Icons.visibility,
                      color: kTextSub, size: 20),
                  onPressed: () => setState(() => _hidePwd = !_hidePwd),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pwd2,
              obscureText: true,
              style: const TextStyle(color: kTextMain),
              decoration: const InputDecoration(
                hintText: '确认密码',
                prefixIcon: Icon(Icons.lock_outline, color: kTextSub, size: 20),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _busy ? null : _register,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('注 册 并 进 入'),
            ),
            const SizedBox(height: 10),
            Text('· 注册需要有效邀请码，账号即你的唯一 ID，他人可凭账号添加你\n· 密码请自行牢记',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 11, color: kTextSub.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}
