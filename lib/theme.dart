import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';

// ---------- 暗黑神秘风配色 ----------
const kBg = Color(0xFF06060A);
const kSurface = Color(0xFF0D0D15);
const kCard = Color(0xFF14141F);
const kBorder = Color(0xFF242433);
const kAccent = Color(0xFF8B5CF6);
const kAccentDim = Color(0xFF4C3585);
const kTextMain = Color(0xFFE9E9F2);
const kTextSub = Color(0xFF7E7E95);
const kBubbleOther = Color(0xFF171724);
const kBubbleMine = Color(0xFF2A2140);
const kDanger = Color(0xFFE4576E);

final darkTheme = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  scaffoldBackgroundColor: kBg,
  colorScheme: const ColorScheme.dark(
    primary: kAccent,
    secondary: kAccent,
    surface: kSurface,
    error: kDanger,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      color: kTextMain,
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: 2,
    ),
    iconTheme: IconThemeData(color: kTextMain),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: kCard,
    hintStyle: const TextStyle(color: kTextSub, fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kAccent, width: 1.2),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kAccent,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 4),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: kAccent),
  ),
  dividerTheme: const DividerThemeData(color: kBorder, thickness: 0.5),
);

// ---------- 通用组件 ----------

/// 全局背景：纯黑 + 顶部幽紫光晕
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.6, -0.9),
          radius: 1.4,
          colors: [Color(0xFF1A1030), kBg],
          stops: [0.0, 0.55],
        ),
      ),
      child: child,
    );
  }
}

class DarkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  const DarkCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.margin,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

const _avatarColors = [
  Color(0xFF6D4DF6),
  Color(0xFF2E7DF6),
  Color(0xFF0FA98E),
  Color(0xFFB657D4),
  Color(0xFFD4684F),
  Color(0xFF3F8F5C),
];

class MAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final String? uid; // 传入用户 id 时显示其头像图片（若有）
  const MAvatar(this.name, {super.key, this.radius = 22, this.uid});

  @override
  Widget build(BuildContext context) {
    final color = _avatarColors[
        name.isEmpty ? 0 : name.codeUnitAt(0) % _avatarColors.length];
    String avatarB64 = '';
    if (uid != null) {
      try {
        avatarB64 = context.watch<AppState>().avatarOf(uid!);
      } catch (_) {}
    }
    if (avatarB64.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: color.withOpacity(0.25),
        backgroundImage: _imageProvider(avatarB64),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withOpacity(0.25),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: radius * 0.9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

ImageProvider? _imageProvider(String b64) {
  try {
    return MemoryImage(base64Decode(b64));
  } catch (_) {
    return null;
  }
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(color: kTextMain)),
    backgroundColor: error ? const Color(0xFF3A1520) : const Color(0xFF1C1633),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: kBorder)),
    duration: const Duration(seconds: 2),
  ));
}

String fmtTime(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  final now = DateTime.now();
  final hm =
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  if (d.year == now.year && d.month == now.month && d.day == now.day) return hm;
  return '${d.month}/${d.day} $hm';
}
