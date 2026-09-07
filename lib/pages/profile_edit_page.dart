import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import 'avatar_crop_page.dart';

const _constellations = [
  '白羊座',
  '金牛座',
  '双子座',
  '巨蟹座',
  '狮子座',
  '处女座',
  '天秤座',
  '天蝎座',
  '射手座',
  '摩羯座',
  '水瓶座',
  '双鱼座',
];
const _mbtis = [
  'INTJ',
  'INTP',
  'ENTJ',
  'ENTP',
  'INFJ',
  'INFP',
  'ENFJ',
  'ENFP',
  'ISTJ',
  'ISFJ',
  'ESTJ',
  'ESFJ',
  'ISTP',
  'ISFP',
  'ESTP',
  'ESFP',
];

/// 个人中心：编辑昵称与资料、修改密码
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _signature;
  late final TextEditingController _location;
  late final TextEditingController _pokeVerb;
  late final TextEditingController _pokeTail;
  late final TextEditingController _pokeSay;
  late String _gender;
  late String _constellation;
  late String _mbti;
  DateTime? _birth;
  bool _busy = false;

  // 修改密码
  final _oldPwd = TextEditingController();
  final _newPwd = TextEditingController();
  final _newPwd2 = TextEditingController();
  bool _pwdBusy = false;

  @override
  void initState() {
    super.initState();
    final me = context.read<AppState>().me!;
    final p = me.profile;
    _name = TextEditingController(text: me.name);
    _signature = TextEditingController(text: p.signature);
    _location = TextEditingController(text: p.location);
    _pokeVerb = TextEditingController(text: p.pokeVerb);
    _pokeTail = TextEditingController(text: p.pokeTail);
    _pokeSay = TextEditingController(text: p.pokeSay);
    _gender = p.gender;
    _constellation = p.constellation;
    _mbti = p.mbti;
    if (p.birth.isNotEmpty) {
      _birth = DateTime.tryParse(p.birth);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _signature.dispose();
    _location.dispose();
    _pokeVerb.dispose();
    _pokeTail.dispose();
    _pokeSay.dispose();
    _oldPwd.dispose();
    _newPwd.dispose();
    _newPwd2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final name = _name.text.trim();
    if (name.isEmpty) return toast(context, '名称不能为空', error: true);
    setState(() => _busy = true);
    try {
      final s = context.read<AppState>();
      await s.updateProfile(
        name: name,
        profile: Profile(
          gender: _gender,
          birth: _birth == null
              ? ''
              : '${_birth!.year}-${_birth!.month.toString().padLeft(2, '0')}-${_birth!.day.toString().padLeft(2, '0')}',
          constellation: _constellation,
          mbti: _mbti,
          location: _location.text.trim(),
          signature: _signature.text.trim(),
          pokeVerb: _pokeVerb.text.trim(),
          pokeTail: _pokeTail.text.trim(),
          pokeSay: _pokeSay.text.trim(),
        ),
      );
      if (mounted) toast(context, '资料已保存');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _changePwd() async {
    if (_pwdBusy) return;
    if (_oldPwd.text.isEmpty) return toast(context, '请输入原密码', error: true);
    if (_newPwd.text.length < 6)
      return toast(context, '新密码至少 6 位', error: true);
    if (_newPwd.text != _newPwd2.text) {
      return toast(context, '两次新密码不一致', error: true);
    }
    setState(() => _pwdBusy = true);
    try {
      await context
          .read<AppState>()
          .changePassword(oldPwd: _oldPwd.text, newPwd: _newPwd.text);
      if (mounted) {
        toast(context, '密码已修改');
        _oldPwd.clear();
        _newPwd.clear();
        _newPwd2.clear();
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      _pwdBusy = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final me = s.me!;
    return Scaffold(
      appBar: AppBar(title: const Text('个人中心')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        children: [
          Center(
            child: GestureDetector(
              onTap: () async {
                try {
                  final x = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1600,
                      maxHeight: 1600,
                      imageQuality: 90);
                  if (x == null) return;
                  if (!mounted) return;
                  // 进入裁剪页，确定后返回 base64
                  final b64 = await AvatarCropPage.push(context, x.path);
                  if (b64 == null || b64.isEmpty) return;
                  await s.updateProfile(
                    name: me.name,
                    profile: Profile.fromJson({
                      ...me.profile.toJson(),
                      'avatar': b64,
                    }),
                  );
                  if (mounted) toast(context, '头像已更新');
                } catch (e) {
                  if (mounted) {
                    toast(context, friendlyError(e), error: true);
                  }
                }
              },
              child: Stack(
                children: [
                  MAvatar(me.name, radius: 42, uid: me.id),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kAccent,
                        border: Border.all(color: kSurface, width: 2),
                      ),
                      child:
                          Icon(Icons.camera_alt, size: 12, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
              child: Text('点击头像更换',
                  style: TextStyle(color: kTextSub, fontSize: 11))),
          const SizedBox(height: 8),
          Center(
            child: Text(s.isGuest ? '游客 · 资料仅保存在本机' : '账号 ${me.id}',
                style: TextStyle(color: kTextSub, fontSize: 12)),
          ),
          const SizedBox(height: 20),
          _label('名称'),
          _field(_name, '给自己起个名字', maxLength: 16),
          _label('个性签名'),
          _field(_signature, '写一句让别人记住你的话', maxLength: 30),
          _label('性别'),
          Row(
            children: [
              for (final g in const ['男', '女', '保密'])
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    label: Text(g),
                    selected: _gender == g,
                    onSelected: (_) => setState(() => _gender = g),
                  ),
                ),
            ],
          ),
          _label('出生日期'),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              final now = DateTime.now();
              final d = await showDatePicker(
                context: context,
                initialDate:
                    _birth ?? DateTime(now.year - 18, now.month, now.day),
                firstDate: DateTime(1900),
                lastDate: now,
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: Theme.of(ctx)
                        .colorScheme
                        .copyWith(primary: kAccent, surface: kCard),
                  ),
                  child: child!,
                ),
              );
              if (d != null) setState(() => _birth = d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _birth == null
                          ? '选择出生日期'
                          : '${_birth!.year}-${_birth!.month.toString().padLeft(2, '0')}-${_birth!.day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                          color: _birth == null
                              ? kTextSub.withOpacity(0.5)
                              : kTextMain,
                          fontSize: 14),
                    ),
                  ),
                  Icon(Icons.calendar_today_outlined,
                      color: kTextSub, size: 17),
                ],
              ),
            ),
          ),
          _label('星座'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _constellations)
                ChoiceChip(
                  label: Text(c, style: const TextStyle(fontSize: 12)),
                  selected: _constellation == c,
                  onSelected: (_) => setState(() => _constellation = c),
                ),
            ],
          ),
          _label('MBTI'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _mbtis)
                ChoiceChip(
                  label: Text(m, style: const TextStyle(fontSize: 12)),
                  selected: _mbti == m,
                  onSelected: (_) => setState(() => _mbti = m),
                ),
            ],
          ),
          _label('所在地'),
          _field(_location, '例如：杭州', maxLength: 20),
          _label('拍一拍设置'),
          DarkCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '格式：你 "动词" 对方的 "部位" 并说 "一句话"',
                  style:
                      TextStyle(color: kTextSub.withOpacity(0.7), fontSize: 10),
                ),
                const SizedBox(height: 8),
                _field(_pokeVerb, '动词（如：拍了拍 / 亲了一口）', maxLength: 10),
                const SizedBox(height: 8),
                _field(_pokeTail, '部位（如：的脑袋 / 的肩膀）', maxLength: 12),
                const SizedBox(height: 8),
                _field(_pokeSay, '附言，可留空（如：快去睡觉）', maxLength: 20),
                const SizedBox(height: 10),
                // 实时预览
                Builder(builder: (ctx) {
                  final verb = _pokeVerb.text.trim().isEmpty
                      ? '拍了拍'
                      : _pokeVerb.text.trim();
                  final tail = _pokeTail.text.trim();
                  final say = _pokeSay.text.trim();
                  String preview =
                      '你 "$verb" 对方的${tail.isEmpty ? '' : ' "$tail"'}';
                  if (say.isNotEmpty) preview = '$preview 并说 "$say"';
                  return Text(preview,
                      style: TextStyle(
                          color: kAccent.withOpacity(0.85), fontSize: 11));
                }),
              ],
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保 存 资 料'),
          ),
          if (!s.isGuest) ...[
            const SizedBox(height: 28),
            _label('修改密码'),
            DarkCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  _pwdField(_oldPwd, '原密码'),
                  const Divider(height: 1),
                  _pwdField(_newPwd, '新密码（至少 6 位）'),
                  const Divider(height: 1),
                  _pwdField(_newPwd2, '确认新密码'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: _pwdBusy ? null : _changePwd,
              style: OutlinedButton.styleFrom(
                foregroundColor: kAccent,
                side: const BorderSide(color: kAccentDim),
                minimumSize: const Size.fromHeight(46),
              ),
              child: const Text('确认修改密码'),
            ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(text,
            style: TextStyle(color: kTextSub, fontSize: 12, letterSpacing: 2)),
      );

  Widget _field(TextEditingController c, String hint,
      {TextInputType? keyboardType, int? maxLength}) {
    return TextField(
      controller: c,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: const TextStyle(color: kTextMain),
      decoration: InputDecoration(hintText: hint, counterText: ''),
    );
  }

  Widget _pwdField(TextEditingController c, String hint) {
    return TextField(
      controller: c,
      obscureText: true,
      style: const TextStyle(color: kTextMain),
      decoration: InputDecoration(hintText: hint, border: InputBorder.none),
    );
  }
}
