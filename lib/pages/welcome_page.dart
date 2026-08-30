import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import 'register_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _server = TextEditingController();
  final _account = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidePwd = true;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _server.text = s.serverUrl;
    _account.text = s.savedAccount ?? '';
    _password.text = s.savedPassword ?? '';
  }

  Future<void> _login() async {
    if (_busy) return;
    setState(() => _busy = true);
    final s = context.read<AppState>();
    try {
      await s.saveServerUrl(_server.text.trim());
      await s.connectAndLogin(_account.text.trim(), _password.text, save: true);
      // RootPage 会自动切换到主页
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final conn = context.select<AppState, ConnState>((s) => s.conn);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      kAccent.withOpacity(0.35),
                      kAccent.withOpacity(0.05)
                    ]),
                    border: Border.all(color: kAccent.withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                          color: kAccent.withOpacity(0.25), blurRadius: 40)
                    ],
                  ),
                  child: const Icon(Icons.nightlight_round,
                      color: kTextMain, size: 40),
                ),
                const SizedBox(height: 18),
                const Text('DARK CHAT',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 8,
                        color: kTextMain)),
                const SizedBox(height: 6),
                Text('夜色之下 · 只言片语',
                    style: TextStyle(
                        fontSize: 13, letterSpacing: 6, color: kTextSub)),
                const SizedBox(height: 40),
                _field(_server, '服务器地址  ws://192.168.x.x:8080',
                    icon: Icons.dns_outlined),
                const SizedBox(height: 14),
                _field(_account, '账号', icon: Icons.person_outline),
                const SizedBox(height: 14),
                _field(_password, '密码',
                    icon: Icons.lock_outline,
                    obscure: _hidePwd,
                    suffix: IconButton(
                      icon: Icon(
                          _hidePwd ? Icons.visibility_off : Icons.visibility,
                          color: kTextSub,
                          size: 20),
                      onPressed: () => setState(() => _hidePwd = !_hidePwd),
                    )),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      conn == ConnState.connected
                          ? Icons.circle
                          : conn == ConnState.connecting
                              ? Icons.circle_outlined
                              : Icons.circle,
                      size: 8,
                      color: conn == ConnState.connected
                          ? Color(0xFF34D399)
                          : kTextSub,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      conn == ConnState.connected
                          ? '已连接服务器'
                          : conn == ConnState.connecting
                              ? '连接中…'
                              : '未连接 · 电脑运行 server 后填入其局域网地址',
                      style: const TextStyle(fontSize: 12, color: kTextSub),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: _busy ? null : _login,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('进  入'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  ),
                  child: const Text('首次使用？注册新账号 →',
                      style: TextStyle(letterSpacing: 2)),
                ),
                const SizedBox(height: 8),
                Text('与电脑处于同一 WiFi · 电脑运行 dart run server/server.dart',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11, color: kTextSub.withOpacity(0.7))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint,
      {IconData? icon, bool obscure = false, Widget? suffix}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      style: const TextStyle(color: kTextMain, letterSpacing: 1),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon, color: kTextSub, size: 20),
        suffixIcon: suffix,
      ),
    );
  }
}
