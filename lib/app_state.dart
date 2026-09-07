import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 全局 ScaffoldMessenger，用于应用内消息横幅
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// 官方服务器地址（固定，用户不可修改）
const String kServerUrl =
    'wss://reflected-calgary-infections-occurrence.trycloudflare.com';

/// 游客模式的本地用户 ID
const String kGuestId = 'guest';

// ---------- 数据模型 ----------

/// 把任意 Map 安全转成 Map<String, dynamic>
Map<String, dynamic> asStrMap(Object? v) => v is Map
    ? v.map((k, value) => MapEntry(k.toString(), value))
    : <String, dynamic>{};

class Profile {
  String gender, birth, constellation, mbti, location;
  String signature;
  // 拍一拍三段：「A "{verb}" B的 "{tail}" 并说 "{say}"」
  String pokeVerb, pokeTail, pokeSay;
  String avatar; // base64，空表示未设置
  Profile({
    this.gender = '',
    this.birth = '',
    this.constellation = '',
    this.mbti = '',
    this.location = '',
    this.signature = '',
    this.pokeVerb = '拍了拍',
    this.pokeTail = '的肩膀',
    this.pokeSay = '',
    this.avatar = '',
  });
  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        gender: (j['gender'] ?? '').toString(),
        birth: (j['birth'] ?? '').toString(),
        constellation: (j['constellation'] ?? '').toString(),
        mbti: (j['mbti'] ?? '').toString(),
        location: (j['location'] ?? '').toString(),
        signature: (j['signature'] ?? '').toString(),
        pokeVerb: (j['pokeVerb'] ?? '拍了拍').toString(),
        pokeTail: (j['pokeTail'] ?? '的肩膀').toString(),
        pokeSay: (j['pokeSay'] ?? '').toString(),
        avatar: (j['avatar'] ?? '').toString(),
      );
  Map<String, dynamic> toJson() => {
        'gender': gender,
        'birth': birth,
        'constellation': constellation,
        'mbti': mbti,
        'location': location,
        'signature': signature,
        'pokeVerb': pokeVerb,
        'pokeTail': pokeTail,
        'pokeSay': pokeSay,
        'avatar': avatar,
      };
}

class Settings {
  bool searchable;
  Settings({this.searchable = true});
  factory Settings.fromJson(Map<String, dynamic> j) =>
      Settings(searchable: j['searchable'] != false);
}

class Me {
  final String id;
  String name;
  Profile profile;
  Settings settings;
  Me(
      {required this.id,
      required this.name,
      required this.profile,
      required this.settings});
  factory Me.fromJson(Map<String, dynamic> j) => Me(
        id: j['id'].toString(),
        name: j['name'].toString(),
        profile: Profile.fromJson(asStrMap(j['profile'])),
        settings: Settings.fromJson(asStrMap(j['settings'])),
      );
}

class UserProfile {
  final String id;
  String name;
  Profile profile;
  UserProfile({required this.id, required this.name, Profile? profile})
      : profile = profile ?? Profile();
  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'].toString(),
        name: j['name'].toString(),
        profile: Profile.fromJson(asStrMap(j['profile'])),
      );
}

/// 好友的本地视图设置：星标 / 备注
class FriendMeta {
  bool star;
  String remark;
  FriendMeta({this.star = false, this.remark = ''});
  factory FriendMeta.fromJson(Map<String, dynamic> j) => FriendMeta(
        star: j['star'] == true,
        remark: (j['remark'] ?? '').toString(),
      );
  Map<String, dynamic> toJson() => {'star': star, 'remark': remark};
}

/// 黑名单条目
class BlockedUser {
  final String id, name;
  BlockedUser({required this.id, required this.name});
  factory BlockedUser.fromJson(Map<String, dynamic> j) => BlockedUser(
        id: j['id'].toString(),
        name: j['name'].toString(),
      );
}

/// 月痕动态
class Moment {
  final String id;
  final String from, name, text;
  final List<String> images;
  final int ts;
  final List<String> likes;
  final List<Map<String, dynamic>> comments;
  Moment({
    required this.id,
    required this.from,
    required this.name,
    required this.text,
    required this.images,
    required this.ts,
    required this.likes,
    this.comments = const [],
  });
  factory Moment.fromJson(Map<String, dynamic> j) => Moment(
        id: j['id'].toString(),
        from: j['from'].toString(),
        name: j['name'].toString(),
        text: (j['text'] ?? '').toString(),
        images:
            ((j['images'] as List?) ?? []).map((e) => e.toString()).toList(),
        ts: (j['ts'] as num?)?.toInt() ?? 0,
        likes: ((j['likes'] as List?) ?? []).map((e) => e.toString()).toList(),
        comments: ((j['comments'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
      );

  /// 本地持久化用（游客模式）
  Map<String, dynamic> toJson() => {
        'id': id,
        'from': from,
        'name': name,
        'text': text,
        'images': images,
        'ts': ts,
        'likes': likes,
        'comments': comments,
      };
}

class GroupInfo {
  final String id, name, owner;
  final List<String> members;
  GroupInfo(
      {required this.id,
      required this.name,
      required this.owner,
      required this.members});
  factory GroupInfo.fromJson(Map<String, dynamic> j) => GroupInfo(
        id: j['id'].toString(),
        name: j['name'].toString(),
        owner: j['owner'].toString(),
        members:
            ((j['members'] as List?) ?? []).map((e) => e.toString()).toList(),
      );
}

class FriendReq {
  final String from, fromName;
  final int ts;
  FriendReq({required this.from, required this.fromName, required this.ts});
  factory FriendReq.fromJson(Map<String, dynamic> j) => FriendReq(
        from: j['from'].toString(),
        fromName: (j['fromName'] ?? '').toString(),
        ts: (j['ts'] as num?)?.toInt() ?? 0,
      );
}

class Msg {
  final String id, from, fromName, type, content;
  final String? to, group;
  final int ts;
  Msg({
    required this.id,
    required this.from,
    required this.fromName,
    required this.type,
    required this.content,
    required this.ts,
    this.to,
    this.group,
  });
  factory Msg.fromJson(Map<String, dynamic> j) => Msg(
        id: j['id'].toString(),
        from: j['from'].toString(),
        fromName: (j['fromName'] ?? '').toString(),
        to: j['to']?.toString(),
        group: j['group']?.toString(),
        type: (j['type'] ?? 'text').toString(),
        content: (j['content'] ?? '').toString(),
        ts: (j['ts'] as num?)?.toInt() ?? 0,
      );

  /// 会话 key：私聊 u_<minId>-<maxId>，群聊 g_<id>（与服务端一致）
  String get conv =>
      group != null ? 'g_$group' : 'u_${_pairKey(from, to ?? '')}';

  /// 本地持久化用（游客模式）
  Map<String, dynamic> toJson() => {
        'id': id,
        'from': from,
        'fromName': fromName,
        'type': type,
        'content': content,
        'ts': ts,
        if (to != null) 'to': to,
        if (group != null) 'group': group,
      };
}

String _pairKey(String a, String b) =>
    a.compareTo(b) <= 0 ? 'u_$a-$b' : 'u_$b-$a';

/// 供页面构造会话 key
String convKeyForUser(String a, String b) => 'u_${_pairKey(a, b)}';
String convKeyForGroup(String gid) => 'g_$gid';

enum ConnState { disconnected, connecting, connected }

/// 把底层异常转成用户能看懂的中文提示
String friendlyError(Object e) {
  final s = e.toString();
  if (e is TimeoutException || s.contains('TimeoutException')) {
    return '连接服务器超时，请检查手机网络后重试';
  }
  if (s.contains('Connection refused') ||
      s.contains('SocketException') ||
      s.contains('Network is unreachable') ||
      s.contains('Connection timed out') ||
      s.contains('WebSocket')) {
    return '无法连接服务器，请检查网络后重试';
  }
  return s.replaceFirst('Exception: ', '');
}

// ---------- 全局状态 ----------
class AppState extends ChangeNotifier {
  WebSocketChannel? _channel;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  int _reqId = 0;

  ConnState conn = ConnState.disconnected;

  /// 服务器地址固定为官方云端地址
  String serverUrl = kServerUrl;

  /// 是否为游客模式（离线本地模式，不连接服务器）
  bool isGuest = false;

  Me? me;
  final friends = <String, UserProfile>{};
  final groups = <String, GroupInfo>{};
  final requests = <FriendReq>[];
  final history = <String, List<Msg>>{};
  final unread = <String, int>{};
  String? savedAccount;
  String? savedPassword;

  /// 应用内通知开关（本地偏好）
  bool notifyEnabled = true;

  /// 个性化：字体缩放
  double fontScale = 1.0;

  /// 好友视图设置（星标/备注）与黑名单
  final Map<String, FriendMeta> friendMeta = {};
  final List<BlockedUser> blocked = [];

  /// 月痕动态缓存
  final List<Moment> moments = [];

  /// 好友显示名：自己 > 备注 > 好友名 > id
  String displayName(String fid) {
    if (me != null && fid == me!.id) return me!.name;
    final r = friendMeta[fid]?.remark ?? '';
    if (r.isNotEmpty) return r;
    return friends[fid]?.name ?? fid;
  }

  /// 用户的头像 base64（自己或好友），无则空串
  String avatarOf(String uid) {
    if (me != null && uid == me!.id) return me!.profile.avatar;
    return friends[uid]?.profile.avatar ?? '';
  }

  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    savedAccount = sp.getString('account');
    savedPassword = sp.getString('password');
    notifyEnabled = sp.getBool('notify') ?? true;
    fontScale = sp.getDouble('fontScale') ?? 1.0;
    if (savedAccount != null && savedPassword != null) {
      try {
        await connectAndLogin(savedAccount!, savedPassword!);
      } catch (_) {
        // 自动登录失败则停留在登录页
      }
    }
  }

  Future<void> setNotifyEnabled(bool v) async {
    notifyEnabled = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('notify', v);
    notifyListeners();
  }

  Future<void> setFontScale(double v) async {
    fontScale = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble('fontScale', v);
    notifyListeners();
  }

  Future<bool> connectAndLogin(String account, String password,
      {bool save = false}) async {
    isGuest = false;
    conn = ConnState.connecting;
    notifyListeners();
    final uri = Uri.tryParse(serverUrl);
    if (uri == null || !uri.hasScheme) {
      conn = ConnState.disconnected;
      notifyListeners();
      throw Exception('服务器地址无效，示例: ws://192.168.1.100:8080');
    }
    try {
      final channel = WebSocketChannel.connect(uri);
      await channel.ready.timeout(const Duration(seconds: 8));
      _channel = channel;
      channel.stream
          .listen(_onData, onDone: _onClose, onError: (_) => _onClose());
      conn = ConnState.connected;
      notifyListeners();

      final res =
          await request('login', {'account': account, 'password': password});
      me = Me.fromJson(res['me']);
      friends
        ..clear()
        ..addEntries(((res['friends'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .map((e) => MapEntry(e['id'].toString(), UserProfile.fromJson(e))));
      friendMeta
        ..clear()
        ..addEntries((asStrMap(res['friendMeta']).entries.map(
            (e) => MapEntry(e.key, FriendMeta.fromJson(asStrMap(e.value))))))
        ..removeWhere((k, v) => !friends.containsKey(k));
      blocked
        ..clear()
        ..addAll(((res['blocked'] as List?) ?? [])
            .map((e) => BlockedUser.fromJson(Map<String, dynamic>.from(e))));
      groups
        ..clear()
        ..addEntries(((res['groups'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .map((e) => MapEntry(e['id'].toString(), GroupInfo.fromJson(e))));
      requests
        ..clear()
        ..addAll(((res['requests'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .map(FriendReq.fromJson));
      // 恢复历史聊天记录
      ((res['history'] as Map?) ?? {}).forEach((key, value) {
        final list = history.putIfAbsent(key.toString(), () => <Msg>[]);
        for (final m in (value as List)) {
          final msg = Msg.fromJson(Map<String, dynamic>.from(m));
          if (!list.any((e) => e.id == msg.id)) list.add(msg);
        }
      });
      // 离线消息会在 login 应答后由服务端主动推送，无需在此处理
      if (save) {
        final sp = await SharedPreferences.getInstance();
        await sp.setString('server', serverUrl);
        await sp.setString('account', account);
        await sp.setString('password', password);
        savedAccount = account;
        savedPassword = password;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _onClose();
      rethrow;
    }
  }

  Future<void> registerAndLogin({
    required String account,
    required String password,
    required String invite,
  }) async {
    if (_channel == null) {
      // 未连接时先建立连接
      final uri = Uri.tryParse(serverUrl);
      if (uri == null || !uri.hasScheme) {
        throw Exception('服务器地址无效，请稍后重试');
      }
      final channel = WebSocketChannel.connect(uri);
      try {
        await channel.ready.timeout(const Duration(seconds: 8));
      } catch (_) {
        conn = ConnState.disconnected;
        notifyListeners();
        throw Exception('无法连接服务器（8 秒无响应）\n请检查手机网络后重试');
      }
      _channel = channel;
      channel.stream
          .listen(_onData, onDone: _onClose, onError: (_) => _onClose());
      conn = ConnState.connected;
    }
    Map<String, dynamic>? res;
    try {
      res = await request('register', {
        'account': account,
        'password': password,
        'invite': invite,
      });
    } catch (e) {
      // 注册失败时丢弃临时连接，保证下次重试是全新连接
      try {
        await _channel?.sink.close();
      } catch (_) {}
      _channel = null;
      conn = ConnState.disconnected;
      notifyListeners();
      rethrow;
    }
    final accountId = res['id'].toString();
    notifyListeners();
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    await connectAndLogin(accountId, password, save: true);
  }

  // ---------- 游客模式（离线本地，不连接服务器） ----------

  /// 进入游客模式：生成本地身份，数据只存本机
  Future<void> enterGuest() async {
    isGuest = true;
    conn = ConnState.disconnected;
    me = Me(
      id: kGuestId,
      name: '游客',
      profile: Profile(),
      settings: Settings(),
    );
    friends.clear();
    groups.clear();
    requests.clear();
    history.clear();
    unread.clear();
    blocked.clear();
    friendMeta.clear();
    moments.clear();
    await _guestLoad();
    notifyListeners();
  }

  /// 退出游客模式（去登录/注册）
  Future<void> exitGuest() async {
    isGuest = false;
    me = null;
    friends.clear();
    groups.clear();
    requests.clear();
    history.clear();
    unread.clear();
    blocked.clear();
    friendMeta.clear();
    moments.clear();
    notifyListeners();
  }

  Future<SharedPreferences> get _sp => SharedPreferences.getInstance();

  /// 游客数据持久化
  Future<void> _guestSave() async {
    if (!isGuest || me == null) return;
    final sp = await _sp;
    await sp.setString(
        'guest_me',
        jsonEncode({
          'id': me!.id,
          'name': me!.name,
          'profile': me!.profile.toJson(),
        }));
    await sp.setString(
        'guest_moments', jsonEncode(moments.map((m) => m.toJson()).toList()));
    await sp.setString(
        'guest_history',
        jsonEncode(history
            .map((k, v) => MapEntry(k, v.map((m) => m.toJson()).toList()))));
  }

  Future<void> _guestLoad() async {
    final sp = await _sp;
    final meRaw = sp.getString('guest_me');
    if (meRaw != null && me != null) {
      try {
        final j = jsonDecode(meRaw) as Map<String, dynamic>;
        me = Me(
          id: kGuestId,
          name: (j['name'] ?? '游客').toString(),
          profile: Profile.fromJson(asStrMap(j['profile'])),
          settings: Settings(),
        );
      } catch (_) {}
    }
    try {
      moments
        ..clear()
        ..addAll(((jsonDecode(sp.getString('guest_moments') ?? '[]') as List)
            .map((e) => Moment.fromJson(Map<String, dynamic>.from(e)))));
    } catch (_) {}
    try {
      final h = jsonDecode(sp.getString('guest_history') ?? '{}') as Map;
      history.clear();
      h.forEach((key, value) {
        final list = history.putIfAbsent(key.toString(), () => <Msg>[]);
        for (final m in (value as List)) {
          list.add(Msg.fromJson(Map<String, dynamic>.from(m)));
        }
      });
    } catch (_) {}
  }

  /// 游客模式：修改本地资料（名称、签名、头像等）
  Future<void> guestUpdateProfile(
      {required String name, required Profile profile}) async {
    if (me == null) return;
    me = Me(id: me!.id, name: name, profile: profile, settings: me!.settings);
    // 同步更新本地月痕/消息里显示的名字
    for (var i = 0; i < moments.length; i++) {
      final m = moments[i];
      moments[i] = Moment(
        id: m.id,
        from: m.from,
        name: name,
        text: m.text,
        images: m.images,
        ts: m.ts,
        likes: m.likes,
        comments: m.comments.map((c) {
          if (c['from'] == kGuestId) {
            return {...c, 'name': name};
          }
          return c;
        }).toList(),
      );
    }
    // 自言自语消息里的名字也同步
    final selfConv = convKeyForUser(kGuestId, kGuestId);
    final selfMsgs = history[selfConv];
    if (selfMsgs != null) {
      history[selfConv] = selfMsgs
          .map((m) => Msg(
                id: m.id,
                from: m.from,
                fromName: name,
                to: m.to,
                group: m.group,
                type: m.type,
                content: m.content,
                ts: m.ts,
              ))
          .toList();
    }
    await _guestSave();
    notifyListeners();
  }

  // ---------- 资料 / 密码 / 设置 / 拍一拍 ----------
  Future<void> updateProfile(
      {required String name, required Profile profile}) async {
    if (isGuest) return guestUpdateProfile(name: name, profile: profile);
    final res = await request(
        'update_profile', {'name': name, 'profile': profile.toJson()});
    me = Me.fromJson(Map<String, dynamic>.from(res['me']));
    notifyListeners();
  }

  Future<void> changePassword(
      {required String oldPwd, required String newPwd}) async {
    await request('change_password', {'old': oldPwd, 'new': newPwd});
    final sp = await SharedPreferences.getInstance();
    if (savedAccount != null) {
      await sp.setString('password', newPwd);
      savedPassword = newPwd;
    }
  }

  Future<void> updateSettings({bool? searchable}) async {
    if (me == null) return;
    if (searchable != null) me!.settings.searchable = searchable;
    notifyListeners();
    if (isGuest) {
      await _guestSave();
      return;
    }
    final res = await request('update_settings', {
      'settings': {'searchable': me!.settings.searchable}
    });
    me!.settings =
        Settings.fromJson(Map<String, dynamic>.from(res['settings'] ?? {}));
    notifyListeners();
  }

  /// 拍一拍：type=poke 走通用消息通道，双方与历史记录都能看到
  /// 私聊 content = 拍一拍文案；群聊 content = '目标昵称|文案'
  Future<void> sendPoke(
      {String? toUser, String? toGroup, String content = ''}) async {
    await request('send_msg', {
      'toUser': toUser,
      'toGroup': toGroup,
      'type': 'poke',
      'content': content,
    });
  }

  // ---------- 星标 / 备注 / 删除 / 拉黑 ----------
  Future<void> setFriendMeta(
      {required String to, bool? star, String? remark}) async {
    final res = await request('set_friend_meta', {
      'to': to,
      if (star != null) 'star': star,
      if (remark != null) 'remark': remark,
    });
    final meta = asStrMap(res['meta']);
    friendMeta
      ..clear()
      ..addEntries(meta.entries
          .map((e) => MapEntry(e.key, FriendMeta.fromJson(asStrMap(e.value)))));
    notifyListeners();
  }

  Future<void> removeFriend(String id) async {
    await request('remove_friend', {'to': id});
    friends.remove(id);
    friendMeta.remove(id);
    notifyListeners();
  }

  Future<void> setBlock({required String id, required bool block}) async {
    await request('block_user', {'to': id, 'block': block});
    blocked.removeWhere((b) => b.id == id);
    if (block) {
      blocked.add(BlockedUser(id: id, name: friends[id]?.name ?? id));
    }
    notifyListeners();
  }

  // ---------- 月痕 ----------
  Future<void> loadMoments() async {
    if (isGuest) {
      await _guestLoad();
      notifyListeners();
      return;
    }
    final res = await request('moments_feed', {});
    moments
      ..clear()
      ..addAll(((res['feed'] as List?) ?? [])
          .map((e) => Moment.fromJson(Map<String, dynamic>.from(e))));
    notifyListeners();
  }

  Future<void> postMoment(
      {required String text, required List<String> imagesB64}) async {
    if (isGuest) {
      moments.insert(
        0,
        Moment(
          id: 'local_${DateTime.now().millisecondsSinceEpoch}',
          from: kGuestId,
          name: me?.name ?? '游客',
          text: text,
          images: imagesB64,
          ts: DateTime.now().millisecondsSinceEpoch,
          likes: const [],
          comments: const [],
        ),
      );
      await _guestSave();
      notifyListeners();
      return;
    }
    final res =
        await request('post_moment', {'text': text, 'images': imagesB64});
    moments.insert(
        0, Moment.fromJson(Map<String, dynamic>.from(res['moment'])));
    notifyListeners();
  }

  Future<void> deleteMoment(String id) async {
    if (isGuest) {
      moments.removeWhere((m) => m.id == id);
      await _guestSave();
      notifyListeners();
      return;
    }
    await request('delete_moment', {'id': id});
    moments.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  /// 给自己的月痕点月 / 取消点月（游客只能给自己点）
  Future<void> likeMoment(String id) async {
    if (isGuest) {
      final idx = moments.indexWhere((m) => m.id == id);
      if (idx < 0) return;
      final old = moments[idx];
      final likes = List<String>.from(old.likes);
      if (likes.contains(kGuestId)) {
        likes.remove(kGuestId);
      } else {
        likes.add(kGuestId);
      }
      moments[idx] = Moment(
        id: old.id,
        from: old.from,
        name: old.name,
        text: old.text,
        images: old.images,
        ts: old.ts,
        likes: likes,
        comments: old.comments,
      );
      await _guestSave();
      notifyListeners();
      return;
    }
    final res = await request('like_moment', {'id': id});
    final likes =
        ((res['likes'] as List?) ?? []).map((e) => e.toString()).toList();
    final idx = moments.indexWhere((m) => m.id == id);
    if (idx >= 0) {
      final old = moments[idx];
      moments[idx] = Moment(
          id: old.id,
          from: old.from,
          name: old.name,
          text: old.text,
          images: old.images,
          ts: old.ts,
          likes: likes,
          comments: old.comments);
      notifyListeners();
    }
  }

  /// 评论月痕（游客只能给自己的月痕评论，即自言自语）
  Future<void> commentMoment(String id, {required String text}) async {
    if (isGuest) {
      final idx = moments.indexWhere((m) => m.id == id);
      if (idx < 0) return;
      final old = moments[idx];
      final comments = List<Map<String, dynamic>>.from(old.comments);
      comments.add({
        'from': kGuestId,
        'name': me?.name ?? '游客',
        'text': text,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
      moments[idx] = Moment(
        id: old.id,
        from: old.from,
        name: old.name,
        text: old.text,
        images: old.images,
        ts: old.ts,
        likes: old.likes,
        comments: comments,
      );
      await _guestSave();
      notifyListeners();
      return;
    }
    final res = await request('comment_moment', {'id': id, 'text': text});
    final updated = Moment.fromJson(Map<String, dynamic>.from(res['moment']));
    final idx = moments.indexWhere((m) => m.id == id);
    if (idx >= 0) moments[idx] = updated;
    notifyListeners();
  }

  // ---------- 好友 / 群 ----------
  Future<UserProfile?> searchUser(String keyword) async {
    final res = await request('search', {'keyword': keyword.trim()});
    final u = res['user'];
    return u == null
        ? null
        : UserProfile.fromJson(Map<String, dynamic>.from(u));
  }

  Future<void> addFriend(String to) => request('add_friend', {'to': to});

  Future<void> respondFriend(String from, bool accept) async {
    final res =
        await request('respond_friend', {'from': from, 'accept': accept});
    requests.removeWhere((r) => r.from == from);
    if (accept && res['friend'] != null) {
      final f = UserProfile.fromJson(Map<String, dynamic>.from(res['friend']));
      friends[f.id] = f;
    }
    notifyListeners();
  }

  Future<GroupInfo> createGroup(String name, List<String> members) async {
    final res =
        await request('create_group', {'name': name, 'members': members});
    final g = GroupInfo.fromJson(Map<String, dynamic>.from(res['group']));
    groups[g.id] = g;
    notifyListeners();
    return g;
  }

  // ---------- 发送消息 ----------
  Future<void> sendText(
      {String? toUser, String? toGroup, required String text}) async {
    if (text.trim().isEmpty) return;
    if (isGuest) {
      // 游客：只能跟自己对话（本地记录）
      _guestAppendMsg(type: 'text', content: text.trim());
      return;
    }
    await request('send_msg', {
      'toUser': toUser,
      'toGroup': toGroup,
      'type': 'text',
      'content': text.trim(),
    });
  }

  Future<void> sendImage({String? toUser, String? toGroup}) async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 55,
      maxWidth: 1280,
    );
    if (x == null) return;
    final bytes = await File(x.path).readAsBytes();
    final b64 = base64Encode(bytes);
    if (b64.length > 3 * 1024 * 1024) {
      throw Exception('图片过大，请换一张小图（<3MB）');
    }
    if (isGuest) {
      _guestAppendMsg(type: 'image', content: b64);
      return;
    }
    await request('send_msg', {
      'toUser': toUser,
      'toGroup': toGroup,
      'type': 'image',
      'content': b64,
    });
  }

  /// 游客模式：往「跟自己的对话」里追加一条本地消息
  void _guestAppendMsg({required String type, required String content}) {
    if (me == null) return;
    final conv = convKeyForUser(kGuestId, kGuestId);
    final list = history.putIfAbsent(conv, () => <Msg>[]);
    list.add(Msg(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}_${list.length}',
      from: kGuestId,
      fromName: me!.name,
      to: kGuestId,
      type: type,
      content: content,
      ts: DateTime.now().millisecondsSinceEpoch,
    ));
    _guestSave();
    notifyListeners();
  }

  List<Msg> msgsOf(String conv) => history[conv] ?? const [];

  void clearUnread(String conv) {
    if (unread[conv] != null && unread[conv]! > 0) {
      unread[conv] = 0;
      notifyListeners();
    }
  }

  // ---------- 底层收发 ----------
  Future<Map<String, dynamic>> request(
      String action, Map<String, dynamic> data) async {
    final channel = _channel;
    if (channel == null) throw Exception('尚未连接服务器');
    final id = ++_reqId;
    final c = Completer<Map<String, dynamic>>();
    _pending[id] = c;
    channel.sink.add(jsonEncode({'action': action, 'data': data, 'reqId': id}));
    final res =
        await c.future.timeout(const Duration(seconds: 15), onTimeout: () {
      _pending.remove(id);
      throw Exception('服务器无响应');
    });
    if (res['ok'] != true) throw Exception((res['msg'] ?? '操作失败').toString());
    return res;
  }

  void _onData(dynamic raw) {
    Map<String, dynamic> m;
    try {
      m = jsonDecode(raw.toString()) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (m['event']) {
      case 'resp':
        final c = _pending.remove(m['reqId']);
        if (c != null && !c.isCompleted) c.complete(m);
      case 'msg':
        final msg = Msg.fromJson(Map<String, dynamic>.from(m['data']));
        final list = history.putIfAbsent(msg.conv, () => <Msg>[]);
        if (!list.any((e) => e.id == msg.id)) {
          list.add(msg);
          if (me != null && msg.from != me!.id) {
            unread[msg.conv] = (unread[msg.conv] ?? 0) + 1;
            if (notifyEnabled) _showBanner(msg);
          }
          notifyListeners();
        }
      case 'friend_request':
        final r = FriendReq.fromJson(Map<String, dynamic>.from(m['data']));
        if (!requests.any((e) => e.from == r.from)) requests.add(r);
        notifyListeners();
      case 'friend_accepted':
        final f = UserProfile.fromJson(Map<String, dynamic>.from(m['data']));
        friends[f.id] = f;
        notifyListeners();
      case 'friend_updated':
        final f = UserProfile.fromJson(Map<String, dynamic>.from(m['data']));
        if (friends.containsKey(f.id)) friends[f.id] = f;
        notifyListeners();
      case 'friend_removed':
        final data = asStrMap(m['data']);
        final rid = (data['id'] ?? '').toString();
        friends.remove(rid);
        friendMeta.remove(rid);
        notifyListeners();
      case 'group_created':
        final g = GroupInfo.fromJson(Map<String, dynamic>.from(m['data']));
        groups[g.id] = g;
        notifyListeners();
    }
  }

  /// 应用内消息横幅（前台时模拟系统通知）
  void _showBanner(Msg msg) {
    final messenger = appMessengerKey.currentState;
    if (messenger == null) return;
    final preview = msg.type == 'image' ? '[图片]' : msg.content;
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      backgroundColor: const Color(0xFF14141F),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: const Color(0xFF4C3585).withOpacity(0.4))),
      content: Text('${msg.fromName}: $preview',
          style: const TextStyle(color: Color(0xFFEAEAF2))),
    ));
  }

  void _onClose() {
    _channel = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(Exception('连接已断开'));
    }
    _pending.clear();
    if (conn != ConnState.disconnected) {
      conn = ConnState.disconnected;
      notifyListeners();
    }
  }

  /// 清空本地缓存的聊天记录（不影响服务器）
  void clearLocalHistory() {
    history.clear();
    unread.clear();
    if (isGuest) _guestSave();
    notifyListeners();
  }

  Future<void> logout({bool clearSaved = true}) async {
    if (isGuest) {
      await exitGuest();
      return;
    }
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _onClose();
    me = null;
    friends.clear();
    groups.clear();
    requests.clear();
    history.clear();
    unread.clear();
    savedAccount = null;
    savedPassword = null;
    if (clearSaved) {
      final sp = await SharedPreferences.getInstance();
      await sp.remove('account');
      await sp.remove('password');
    }
    notifyListeners();
  }
}
