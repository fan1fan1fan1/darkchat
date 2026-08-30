import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

/// 发布月痕：文字 + 最多 9 张图
class PublishMomentPage extends StatefulWidget {
  const PublishMomentPage({super.key});

  @override
  State<PublishMomentPage> createState() => _PublishMomentPageState();
}

class _PublishMomentPageState extends State<PublishMomentPage> {
  final _text = TextEditingController();
  final List<String> _images = <String>[]; // base64
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final picker = ImagePicker();
      final remain = 9 - _images.length;
      if (remain <= 0) return toast(context, '最多 9 张', error: true);
      final list = await picker.pickMultiImage(imageQuality: 70);
      for (final x in list.take(remain)) {
        final bytes = await x.readAsBytes();
        if (bytes.length > 3 * 1024 * 1024) {
          if (mounted) toast(context, '有图片超过 3MB，已跳过', error: true);
          continue;
        }
        setState(() => _images.add(base64Encode(bytes)));
      }
    } catch (e) {
      if (mounted) toast(context, '选图失败：$e', error: true);
    }
  }

  Future<void> _publish() async {
    if (_busy) return;
    if (_text.text.trim().isEmpty && _images.isEmpty) {
      return toast(context, '总得写点什么', error: true);
    }
    setState(() => _busy = true);
    try {
      await context.read<AppState>().postMoment(
            text: _text.text.trim(),
            imagesB64: List<String>.from(_images),
          );
      if (mounted) {
        toast(context, '已留下痕迹');
        Navigator.of(context).pop();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('留 痕'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _busy ? null : _publish,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('发布',
                      style: TextStyle(
                          color: kAccent, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        children: [
          TextField(
            controller: _text,
            maxLines: 6,
            maxLength: 2000,
            style: const TextStyle(color: kTextMain, fontSize: 15, height: 1.5),
            decoration: const InputDecoration(
              hintText: '这一刻的想法…',
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _images.length; i++)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        base64Decode(_images[i]),
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _images.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              topRight: Radius.circular(10),
                            ),
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_images.length < 9)
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kBorder),
                      color: kSurface.withOpacity(0.6),
                    ),
                    child: Icon(Icons.add_photo_alternate_outlined,
                        color: kTextSub, size: 26),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text('谁可以看 · 你的好友',
              style: TextStyle(color: kTextSub.withOpacity(0.7), fontSize: 11)),
        ],
      ),
    );
  }
}
