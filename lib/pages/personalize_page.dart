import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

/// 个性化：字体大小
class PersonalizePage extends StatefulWidget {
  const PersonalizePage({super.key});

  @override
  State<PersonalizePage> createState() => _PersonalizePageState();
}

class _PersonalizePageState extends State<PersonalizePage> {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('个 性 化')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        children: [
          _section('字体大小'),
          DarkCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // 预览气泡
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: kBubbleOther,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '黑暗中的低语（预览）',
                      style: TextStyle(
                          color: kTextMain, fontSize: 13 * s.fontScale),
                    ),
                  ),
                ),
                Slider(
                  value: s.fontScale,
                  min: 0.85,
                  max: 1.3,
                  divisions: 9,
                  activeColor: kAccent,
                  onChanged: (v) => s.setFontScale(v),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('小', style: TextStyle(color: kTextSub, fontSize: 11)),
                    Text('${(s.fontScale * 100).round()}%',
                        style: TextStyle(color: kAccent, fontSize: 12)),
                    Text('大', style: TextStyle(color: kTextSub, fontSize: 15)),
                  ],
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
}
