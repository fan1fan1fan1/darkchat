import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'home_page.dart';
import 'welcome_page.dart';

/// 登录前显示欢迎/登录页，登录后进入主界面
class RootPage extends StatelessWidget {
  const RootPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: state.me == null
          ? const WelcomePage(key: ValueKey('welcome'))
          : const HomePage(key: ValueKey('home')),
    );
  }
}
