// Dark Chat 服务端 —— 零依赖，直接 `dart run server.dart` 启动
// 功能：注册(绑定手机号)、登录、加好友、建群、单聊/群聊(文字+图片)、离线消息
import 'dart:convert';
import 'dart:io';
import 'dart:math';

const int port = 8080;
final rng = Random();
final startedAt = DateTime.now();

// ---------- 数据库（JSON 文件持久化，位于脚本目录 data/db.json） ----------
final dataDir = Directory('data');
final dbFile = File('${dataDir.path}/db.json');
Map<String, dynamic> db = {
  'users':
      {}, // id(=账号) -> {id,name,password,friends:[],friendMeta:{},blocked:[]}
  'groups': {}, // id -> {id,name,owner,members:[]}
  'requests': [], // [{from,fromName,to,ts}]
  'history': {}, // 'u_100001' / 'g_800001' -> [msg]
  'undelivered': {}, // userId -> [msg]
  'moments': [], // [{id,from,name,text,images:[b64],ts,likes:[]}]
};

Map<String, dynamic> asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v; // 已是目标类型，返回原引用（保证可写）
  return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
}

void loadDb() {
  Map<String, dynamic> raw = {};
  if (dbFile.existsSync()) {
    try {
      raw = jsonDecode(dbFile.readAsStringSync()) as Map<String, dynamic>;
    } catch (e) {
      stderr.writeln('数据库损坏，使用全新数据库: $e');
    }
  }
  final users = <String, dynamic>{};
  asMap(raw['users']).forEach((k, v) => users[k.toString()] = asMap(v));
  final groups = <String, dynamic>{};
  asMap(raw['groups']).forEach((k, v) => groups[k.toString()] = asMap(v));
  db = {
    'users': users,
    'groups': groups,
    'requests': (raw['requests'] as List?) ?? [],
    'history': asMap(raw['history']),
    'undelivered': asMap(raw['undelivered']),
    'moments': (raw['moments'] as List?) ?? [],
  };
}

void saveDb() {
  dataDir.createSync(recursive: true);
  dbFile.writeAsStringSync(jsonEncode(db));
}

// ---------- 在线连接 ----------
final online = <String, WebSocket>{}; // userId -> ws

void deliver(String userId, Map<String, dynamic> payload) {
  final ws = online[userId];
  if (ws != null && ws.readyState == WebSocket.open) {
    ws.add(jsonEncode(payload));
  } else {
    final list = (db['undelivered'][userId] as List?) ?? [];
    list.add(payload);
    db['undelivered'][userId] = list;
    if (list.length > 500) list.removeRange(0, list.length - 500);
  }
}

void broadcastMembers(List<dynamic> memberIds, Map<String, dynamic> payload) {
  for (final id in memberIds) {
    deliver(id.toString(), payload);
  }
}

Map<String, dynamic> defaultProfile() => {
      'gender': '',
      'age': '',
      'constellation': '',
      'mbti': '',
      'location': '',
      'poke': '的肩膀',
    };

Map<String, dynamic> defaultSettings() => {'searchable': true};

/// 兼容旧数据：缺 profile/settings 的补默认值
void normalizeUser(Map<String, dynamic> u) {
  final p = defaultProfile();
  p.addAll(((u['profile'] as Map?) ?? {}).cast<String, dynamic>());
  u['profile'] = p;
  final s = defaultSettings();
  s.addAll(((u['settings'] as Map?) ?? {}).cast<String, dynamic>());
  u['settings'] = s;
  u['friendMeta'] ??= <String, dynamic>{};
  u['blocked'] ??= <dynamic>[];
}

Map<String, dynamic> userBrief(Map<String, dynamic> u) {
  normalizeUser(u);
  return {
    'id': u['id'],
    'name': u['name'],
    'profile': u['profile'],
    'settings': u['settings'],
  };
}

/// 资料变更后广播给所有好友
void broadcastProfile(Map<String, dynamic> me) {
  final brief = userBrief(me);
  for (final fid in (me['friends'] as List)) {
    deliver(fid.toString(), {'event': 'friend_updated', 'data': brief});
  }
}

Map<String, dynamic> groupBrief(Map<String, dynamic> g) => {
      'id': g['id'],
      'name': g['name'],
      'owner': g['owner'],
      'members': g['members']
    };

// 固定邀请码：只有持有它的人才能注册
const String inviteCodeFixed = '84562';

String newId(int digits) {
  final min = pow(10, digits - 1).toInt();
  return (min + rng.nextInt(pow(10, digits).toInt() - min)).toString();
}

void normalizeConv(Map<String, dynamic> m) {
  if (m['group'] != null) {
    m['conv'] = 'g_${m['group']}';
    return;
  }
  final a = m['from'].toString(), b = (m['to'] ?? '').toString();
  final key = (a.compareTo(b) <= 0) ? 'u_$a-$b' : 'u_$b-$a';
  m['conv'] = key;
}

void pushHistory(Map<String, dynamic> m) {
  normalizeConv(m);
  final list = (db['history'][m['conv']] as List?) ?? [];
  list.add(m);
  if (list.length > 300) list.removeRange(0, list.length - 300);
  db['history'][m['conv']] = list;
}

// ---------- HTTP / WebSocket ----------
void main() async {
  loadDb();
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('Dark Chat 服务端已启动: ws://<本机IP>:$port  ($startedAt)');
  final interfaces = await NetworkInterface.list();
  for (final it in interfaces) {
    for (final addr in it.addresses) {
      if (addr.type == InternetAddressType.IPv4) {
        stdout.writeln('  -> 建议手机端填入: ws://${addr.address}:$port');
      }
    }
  }
  await for (final req in server) {
    final from = req.connectionInfo?.remoteAddress.address ?? '?';
    if (WebSocketTransformer.isUpgradeRequest(req)) {
      stdout.writeln('[连接] $from 正在接入 WebSocket...');
      final ws = await WebSocketTransformer.upgrade(req);
      handleSocket(ws);
    } else {
      stdout.writeln('[探测] $from 通过浏览器访问了服务器');
      req.response.statusCode = 200;
      req.response.write('Dark Chat server running');
      await req.response.close();
    }
  }
}

void handleSocket(WebSocket ws) {
  String? uid;
  ws.listen(
    (data) {
      try {
        final req = jsonDecode(data.toString()) as Map<String, dynamic>;
        final action = req['action'] as String?;
        final reqId = req['reqId'];
        final d = (req['data'] as Map<String, dynamic>?) ?? {};
        final reply = (Map<String, dynamic> res) {
          res['event'] = 'resp';
          res['action'] = action;
          if (reqId != null) res['reqId'] = reqId;
          ws.add(jsonEncode(res));
        };
        final err = (String msg) => reply({'ok': false, 'msg': msg});

        switch (action) {
          case 'register':
            {
              final account = (d['account'] ?? '').toString().trim();
              final password = (d['password'] ?? '').toString();
              final invite = (d['invite'] ?? '').toString().trim();
              if (invite != inviteCodeFixed) return err('邀请码错误');
              if (!RegExp(r'^[\u4e00-\u9fa5a-zA-Z0-9]{2,16}$')
                  .hasMatch(account)) {
                return err('账号需为 2-16 位中文、字母或数字');
              }
              if (password.length < 6) return err('密码至少 6 位');
              final users = asMap(db['users']);
              if (users.containsKey(account)) return err('该账号已被注册');
              users[account] = {
                'id': account,
                'name': account,
                'password': password,
                'friends': <dynamic>[],
                'friendMeta': <String, dynamic>{},
                'blocked': <dynamic>[],
                'profile': defaultProfile(),
                'settings': defaultSettings(),
              };
              saveDb();
              stdout.writeln('新用户注册: $account');
              reply({'ok': true, 'id': account, 'name': account});
            }
          case 'login':
            {
              final account = (d['account'] ?? '').toString().trim();
              final password = (d['password'] ?? '').toString();
              final users = asMap(db['users']);
              final u = users[account];
              normalizeUser(u);
              if (u == null) return err('账号不存在');
              if (u['password'] != password) return err('密码错误');
              final myId = u['id'] as String;
              online[myId] = ws;
              // 标记 uid 后续事件用它
              uid = myId;
              final friends = <Map<String, dynamic>>[];
              for (final fid in (u['friends'] as List)) {
                final f = users[fid.toString()];
                if (f != null) friends.add(userBrief(f));
              }
              final groups = <Map<String, dynamic>>[];
              for (final g in asMap(db['groups']).values) {
                if ((g['members'] as List).contains(myId)) {
                  groups.add(groupBrief(g));
                }
              }
              final myRequests = (db['requests'] as List)
                  .where((r) => r['to'] == myId)
                  .toList();
              final undelivered = (db['undelivered'][myId] as List?) ?? [];
              db['undelivered'][myId] = <dynamic>[];
              // 只下发与我相关的最近聊天记录
              final myGroupIds = groups.map((g) => g['id'].toString()).toSet();
              final myHistory = <String, dynamic>{};
              asMap(db['history']).forEach((key, value) {
                final relevant = key.startsWith('g_')
                    ? myGroupIds.contains(key.substring(2))
                    : key.substring(2).split('-').contains(myId);
                if (relevant) {
                  final all = value as List;
                  myHistory[key] =
                      all.length > 100 ? all.sublist(all.length - 100) : all;
                }
              });
              saveDb();
              final blockedBrief = <Map<String, dynamic>>[];
              for (final bid in (u['blocked'] as List)) {
                final bu = users[bid.toString()];
                if (bu != null) {
                  blockedBrief.add({'id': bu['id'], 'name': bu['name']});
                }
              }
              reply({
                'ok': true,
                'me': userBrief(u),
                'friends': friends,
                'friendMeta': u['friendMeta'],
                'blocked': blockedBrief,
                'groups': groups,
                'requests': myRequests,
                'history': myHistory,
                'offline': undelivered,
              });
              // 直接补发离线消息（undelivered 中存的是完整载荷）
              for (final p in undelivered) {
                ws.add(jsonEncode(p));
              }
            }
          case 'search':
            {
              final kw = (d['keyword'] ?? '').toString().trim();
              final users = asMap(db['users']);
              Map<String, dynamic>? found;
              for (final cand in users.values) {
                normalizeUser(cand);
                if (cand['id'] == kw &&
                    cand['settings']['searchable'] == true) {
                  found = cand;
                }
              }
              reply({
                'ok': true,
                'user': found == null ? null : userBrief(found)
              });
            }
          case 'add_friend':
            {
              final me = asMap(db['users'])[uid];
              if (me == null) return err('请先登录');
              final to = (d['to'] ?? '').toString();
              final users = asMap(db['users']);
              final target = users[to];
              if (target == null) return err('用户不存在');
              normalizeUser(target);
              if ((target['blocked'] as List).contains(uid)) {
                return err('对方已开启隐私保护，无法添加');
              }
              if (to == uid) return err('不能添加自己');
              if ((me['friends'] as List).contains(to)) return err('已经是好友了');
              final reqs = db['requests'] as List;
              if (reqs.any((r) => r['from'] == uid && r['to'] == to)) {
                return err('已发送过申请，等待对方验证');
              }
              reqs.add({
                'from': uid,
                'fromName': me['name'],
                'to': to,
                'ts': DateTime.now().millisecondsSinceEpoch,
              });
              saveDb();
              deliver(to, {
                'event': 'friend_request',
                'data': {
                  'from': uid,
                  'fromName': me['name'],
                  'ts': DateTime.now().millisecondsSinceEpoch
                },
              });
              reply({'ok': true, 'msg': '申请已发送'});
            }
          case 'respond_friend':
            {
              final me = asMap(db['users'])[uid];
              if (me == null) return err('请先登录');
              final from = (d['from'] ?? '').toString();
              final accept = d['accept'] == true;
              final reqs = db['requests'] as List;
              reqs.removeWhere((r) => r['from'] == from && r['to'] == uid);
              final users = asMap(db['users']);
              final other = users[from];
              if (other == null) return err('对方账号不存在');
              if (accept) {
                if (!(me['friends'] as List).contains(from))
                  (me['friends'] as List).add(from);
                if (!(other['friends'] as List).contains(uid))
                  (other['friends'] as List).add(uid);
                saveDb();
                final brief = userBrief(other);
                deliver(from, {'event': 'friend_accepted', 'data': brief});
                reply({'ok': true, 'friend': brief, 'msg': '已添加好友'});
              } else {
                saveDb();
                deliver(
                    from, {'event': 'friend_rejected', 'data': userBrief(me)});
                reply({'ok': true, 'msg': '已拒绝'});
              }
            }
          case 'create_group':
            {
              final me = asMap(db['users'])[uid];
              if (me == null) return err('请先登录');
              final name = (d['name'] ?? '').toString().trim();
              final members = ((d['members'] as List?) ?? [])
                  .map((e) => e.toString())
                  .toSet()
                  .toList();
              if (name.isEmpty) return err('请输入群名称');
              members.removeWhere((m) => m == uid);
              if (members.isEmpty) return err('请至少选择 1 位好友');
              final groups = asMap(db['groups']);
              final gid = newId(6);
              final g = {
                'id': gid,
                'name': name,
                'owner': uid,
                'members': [uid, ...members]
              };
              groups[gid] = g;
              saveDb();
              final brief = groupBrief(g);
              for (final m in members) {
                deliver(m, {'event': 'group_created', 'data': brief});
              }
              reply({'ok': true, 'group': brief});
            }
          case 'send_msg':
            {
              final me = asMap(db['users'])[uid];
              if (me == null) return err('请先登录');
              final type = (d['type'] ?? 'text').toString();
              final content = (d['content'] ?? '').toString();
              final toUser = d['toUser']?.toString();
              final toGroup = d['toGroup']?.toString();
              final msg = {
                'id': '${DateTime.now().millisecondsSinceEpoch}_${newId(4)}',
                'from': uid,
                'fromName': me['name'],
                'to': toUser,
                'group': toGroup,
                'type': type,
                'content': content,
                'ts': DateTime.now().millisecondsSinceEpoch,
              };
              if (type == 'text' && content.trim().isEmpty) {
                return err('消息不能为空');
              }
              if (content.length > 4 * 1024 * 1024)
                return err('内容过大（图片请控制在 3MB 内）');
              if (toUser != null) {
                final tu = asMap(db['users'])[toUser];
                if (tu == null) return err('用户不存在');
                normalizeUser(tu);
                if ((tu['blocked'] as List).contains(uid)) {
                  return err('消息已发出，但被对方拒收了');
                }
              }
              pushHistory(msg);
              saveDb();
              if (toGroup != null) {
                final g = asMap(db['groups'])[toGroup];
                if (g == null) return err('群不存在');
                for (final m in (g['members'] as List)) {
                  deliver(m.toString(), {'event': 'msg', 'data': msg});
                }
              } else if (toUser != null) {
                deliver(toUser, {'event': 'msg', 'data': msg});
                // 回显给自己，保证多端一致（自己发给自己的消息只投递一次）
                if (toUser != uid) {
                  deliver(uid!, {'event': 'msg', 'data': msg});
                }
              }
              reply({'ok': true, 'msg': msg});
            }
          case 'set_friend_meta':
            {
              // 星标好友 / 好友备注（仅影响自己的视图）
              final me = asMap(db['users'])[uid];
              if (me == null) return err('请先登录');
              normalizeUser(me);
              final to = (d['to'] ?? '').toString();
              if (!(me['friends'] as List).contains(to)) {
                return err('对方不是你的好友');
              }
              final meta = asMap(me['friendMeta']);
              final m = asMap(meta[to]);
              if (d['star'] is bool) m['star'] = d['star'];
              if (d['remark'] is String) {
                final remark = (d['remark'] as String).trim();
                if (remark.isEmpty) {
                  m.remove('remark'); // 清空备注
                } else {
                  m['remark'] =
                      remark.length > 16 ? remark.substring(0, 16) : remark;
                }
              }
              meta[to] = m;
              me['friendMeta'] = meta;
              saveDb();
              reply({'ok': true, 'meta': meta});
            }
          case 'remove_friend':
            {
              // 双向删除好友
              final me = asMap(db['users'])[uid];
              if (me == null) return err('请先登录');
              final to = (d['to'] ?? '').toString();
              final users = asMap(db['users']);
              final other = users[to];
              if (other == null) return err('用户不存在');
              (me['friends'] as List).remove(to);
              asMap(me['friendMeta']).remove(to);
              (other['friends'] as List).remove(uid);
              normalizeUser(other);
              asMap(other['friendMeta']).remove(uid);
              saveDb();
              deliver(to, {
                'event': 'friend_removed',
                'data': {'id': uid}
              });
              reply({'ok': true});
            }
          case 'block_user':
            {
              // 拉黑 / 取消拉黑
              final me = asMap(db['users'])[uid];
              if (me == null) return err('请先登录');
              normalizeUser(me);
              final to = (d['to'] ?? '').toString();
              final block = d['block'] == true;
              final users = asMap(db['users']);
              if (users[to] == null) return err('用户不存在');
              if (block) {
                if (!(me['blocked'] as List).contains(to)) {
                  (me['blocked'] as List).add(to);
                }
              } else {
                (me['blocked'] as List).remove(to);
              }
              saveDb();
              reply({
                'ok': true,
                'blocked': (me['blocked'] as List).contains(to)
              });
            }
          case 'blocked_list':
            {
              final me = asMap(db['users'])[uid];
              if (me == null) return err('请先登录');
              normalizeUser(me);
              final users = asMap(db['users']);
              final list = <Map<String, dynamic>>[];
              for (final bid in (me['blocked'] as List)) {
                final bu = users[bid.toString()];
                if (bu != null) list.add({'id': bu['id'], 'name': bu['name']});
              }
              reply({'ok': true, 'list': list});
            }
          case 'post_moment':
            {
              // 月痕：发布动态（文字 + 最多 9 张图）
              final me = asMap(db['users'])[uid];
              if (me == null) return err('请先登录');
              final text = (d['text'] ?? '').toString().trim();
              final images = (d['images'] as List?) ?? [];
              if (text.isEmpty && images.isEmpty) return err('总得写点什么');
              if (text.length > 2000) return err('文字太长了');
              if (images.length > 9) return err('图片最多 9 张');
              final moment = {
                'id': '${DateTime.now().millisecondsSinceEpoch}_${newId(4)}',
                'from': uid,
                'name': me['name'],
                'text': text,
                'images': images.take(9).toList(),
                'ts': DateTime.now().millisecondsSinceEpoch,
                'likes': <dynamic>[],
              };
              final moments = db['moments'] as List;
              moments.insert(0, moment);
              if (moments.length > 500)
                moments.removeRange(500, moments.length);
              saveDb();
              reply({'ok': true, 'moment': moment});
            }
          case 'moments_feed':
            {
              // 自己 + 好友的动态
              final me = asMap(db['users'])[uid];
              if (me == null) return err('请先登录');
              normalizeUser(me);
              final visible = <dynamic>{uid, ...(me['friends'] as List)};
              final feed = (db['moments'] as List)
                  .where((m) => visible.contains(m['from']))
                  .take(100)
                  .toList();
              reply({'ok': true, 'feed': feed});
            }
          case 'user_moments':
            {
              // 某个用户的动态（用于好友主页）
              final me = asMap(db['users'])[uid];
              if (me == null) return err('请先登录');
              final of = (d['of'] ?? '').toString();
              final feed = (db['moments'] as List)
                  .where((m) => m['from'] == of)
                  .take(50)
                  .toList();
              reply({'ok': true, 'feed': feed});
            }
          case 'delete_moment':
            {
              final me = asMap(db['users'])[uid];
              if (me == null) return err('请先登录');
              final id = (d['id'] ?? '').toString();
              (db['moments'] as List)
                  .removeWhere((m) => m['id'] == id && m['from'] == uid);
              saveDb();
              reply({'ok': true});
            }
          case 'like_moment':
            {
              final me = asMap(db['users'])[uid];
              if (me == null) return err('请先登录');
              final id = (d['id'] ?? '').toString();
              Map<String, dynamic>? target;
              for (final m in (db['moments'] as List)) {
                if (m['id'] == id) target = m;
              }
              if (target == null) return err('动态不存在');
              final likes = target['likes'] as List;
              if (likes.contains(uid)) {
                likes.remove(uid);
              } else {
                likes.add(uid);
              }
              saveDb();
              reply({'ok': true, 'likes': likes});
            }
          case 'comment_moment':
            {
              // 月痕评论
              final me = asMap(db['users'])[uid];
              if (me == null) return err('请先登录');
              final id = (d['id'] ?? '').toString();
              final text = (d['text'] ?? '').toString().trim();
              if (text.isEmpty) return err('评论不能为空');
              if (text.length > 200) return err('评论太长了');
              Map<String, dynamic>? target;
              for (final m in (db['moments'] as List)) {
                if (m['id'] == id) target = m;
              }
              if (target == null) return err('动态不存在');
              final comments = target.putIfAbsent('comments', () => []);
              comments.add({
                'from': uid,
                'name': me['name'],
                'text': text,
                'ts': DateTime.now().millisecondsSinceEpoch,
              });
              saveDb();
              reply({'ok': true, 'moment': target});
            }
          case 'update_profile':
            {
              final me = asMap(db['users'])[uid];
              if (me == null) return err('请先登录');
              normalizeUser(me);
              final name = (d['name'] ?? '').toString().trim();
              if (name.isEmpty) return err('名称不能为空');
              if (name.length > 16) return err('名称最长 16 个字符');
              me['name'] = name;
              final profile = Map<String, dynamic>.from(me['profile']);
              ((d['profile'] as Map?) ?? {}).forEach((k, v) {
                profile[k] = v.toString();
              });
              // 头像 base64 限制 300KB，防止滥用
              if ((profile['avatar'] ?? '').length > 400 * 1024) {
                return err('头像图片太大');
              }
              me['profile'] = profile;
              saveDb();
              broadcastProfile(me);
              reply({'ok': true, 'me': userBrief(me)});
            }
          case 'change_password':
            {
              final me = asMap(db['users'])[uid];
              if (me == null) return err('请先登录');
              final oldPwd = (d['old'] ?? '').toString();
              final newPwd = (d['new'] ?? '').toString();
              if (me['password'] != oldPwd) return err('原密码错误');
              if (newPwd.length < 6) return err('新密码至少 6 位');
              me['password'] = newPwd;
              saveDb();
              reply({'ok': true});
            }
          case 'update_settings':
            {
              final me = asMap(db['users'])[uid];
              if (me == null) return err('请先登录');
              normalizeUser(me);
              ((d['settings'] as Map?) ?? {}).forEach((k, v) {
                me['settings'][k] = v;
              });
              saveDb();
              reply({'ok': true, 'settings': me['settings']});
            }
          case 'heartbeat':
            reply({'ok': true});
          default:
            err('未知操作: $action');
        }
      } catch (e, st) {
        stderr.writeln('处理消息出错: $e\n$st');
      }
    },
    onDone: () {
      if (uid != null && online[uid] == ws) online.remove(uid);
    },
    onError: (_) {
      if (uid != null && online[uid] == ws) online.remove(uid);
    },
    cancelOnError: false,
  );
}
