import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'pages/root_page.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const DarkChatApp());
}

class DarkChatApp extends StatelessWidget {
  const DarkChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: MaterialApp(
        title: 'Dark Chat · 暗语',
        debugShowCheckedModeBanner: false,
        theme: darkTheme,
        scaffoldMessengerKey: appMessengerKey,
        builder: (context, child) => AppBackground(child: child!),
        home: const RootPage(),
      ),
    );
  }
}
