// 临时端到端联调脚本（验证后删除）
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

class Client {
  final WebSocket ws;
  final pending = <int, Completer<Map>>{};
  final events = <Map>[];
  final _waiters = <String, Completer<Map>>{};
  int reqId = 0;

  Client(this.ws) {
    ws.listen((d) {
      final m = jsonDecode(d.toString()) as Map;
      if (m['event'] == 'resp') {
        pending[m['reqId']]?.complete(m);
      } else {
        events.add(m);
        _waiters.remove(m['event'])?.complete(m);
      }
    });
  }

  Future<Map> req(String action, Map data) {
    final id = ++reqId;
    final c = Completer<Map>();
    pending[id] = c;
    ws.add(jsonEncode({'action': action, 'data': data, 'reqId': id}));
    return c.future.timeout(Duration(seconds: 5));
  }

  /// 每次调用返回新的 future；须在触发动作前调用
  Future<Map> waitEvent(String name) {
    final c = Completer<Map>();
    _waiters[name] = c;
    return c.future.timeout(Duration(seconds: 5));
  }
}

Future<String> mkUser(Client c, String name) async {
  final account = '$name${Random().nextInt(100000).toString().padLeft(5, '0')}';
  final reg = await c.req('register', {
    'account': account,
    'password': '123456',
    'invite': '84562',
  });
  if (reg['ok'] != true) throw StateError('注册失败: $reg');
  final login =
      await c.req('login', {'account': account, 'password': '123456'});
  if (login['me'] == null) throw StateError('登录失败: $login');
  return login['me']['id'] as String;
}

Future<void> main() async {
  final a = Client(await WebSocket.connect('ws://127.0.0.1:8080'));
  final b = Client(await WebSocket.connect('ws://127.0.0.1:8080'));
  final c = Client(await WebSocket.connect('ws://127.0.0.1:8080'));

  final idA = await mkUser(a, 'usera');
  final idB = await mkUser(b, 'userb');
  final idC = await mkUser(c, 'userc');
  print('注册+登录 OK: A=$idA B=$idB C=$idC');

  // 加好友（先挂监听再触发，事件可能先于回执到达）
  final frFuture = b.waitEvent('friend_request');
  await a.req('add_friend', {'to': idB});
  final fr = await frFuture;
  final okFuture = a.waitEvent('friend_accepted');
  await b.req('respond_friend', {'from': fr['data']['from'], 'accept': true});
  final ok = await okFuture;
  print('加好友 OK: ${ok['data']['name']} 已成为好友');

  // 私聊
  final bMsgFuture = b.waitEvent('msg');
  final aMsgFuture = a.waitEvent('msg');
  await a.req('send_msg', {'toUser': idB, 'type': 'text', 'content': '你好，暗语'});
  final msgB = await bMsgFuture;
  final msgA = await aMsgFuture;
  print(
      '私聊 OK: B收到「${msgB['data']['content']}」 A回显「${msgA['data']['content']}」');

  // 图片（用小 base64 模拟）
  final imgFuture = b.waitEvent('msg');
  await a
      .req('send_msg', {'toUser': idB, 'type': 'image', 'content': 'aGVsbG8='});
  final img = await imgFuture;
  print('图片 OK: B收到类型=${img['data']['type']}');

  // 建群 + 群聊
  final gcFuture = b.waitEvent('group_created');
  await a.req('create_group', {
    'name': '夜行者',
    'members': [idB]
  });
  final gc = await gcFuture;
  final gid = gc['data']['id'];
  final gMsgFuture = b.waitEvent('msg');
  await a
      .req('send_msg', {'toGroup': gid, 'type': 'text', 'content': '群里第一句话'});
  final gmsg = await gMsgFuture;
  print('群聊 OK: 群「${gc['data']['name']}」 B收到「${gmsg['data']['content']}」');

  // 登出后再登录 → 收离线消息
  await a.ws.close();
  await b.req('send_msg', {'toUser': idA, 'type': 'text', 'content': '你上线了吗'});
  await Future.delayed(Duration(milliseconds: 300));
  final a2 = Client(await WebSocket.connect('ws://127.0.0.1:8080'));
  final offlineFuture = a2.waitEvent('msg');
  final login2 = await a2.req('login', {'account': idA, 'password': '123456'});
  final offline = await offlineFuture;
  print(
      '离线消息 OK: 重连后收到「${offline['data']['content']}」(${login2['ok'] ? '登录成功' : '登录失败'})');

  // 资料修改 + 好友同步 + 拍一拍（用 a2 的连接，a 已在离线测试中关闭）
  final updFuture = b.waitEvent('friend_updated');
  final upd = await a2.req('update_profile', {
    'name': '小明',
    'profile': {'gender': '男', 'age': '21', 'mbti': 'INTJ', 'poke': '的脑袋'}
  });
  if (upd['ok'] != true) throw StateError('改资料失败: $upd');
  final updEvt = await updFuture;
  print('资料修改 OK: 好友侧同步到「${updEvt['data']['name']}」');
  final pokeFuture = b.waitEvent('msg');
  await a2.req('send_msg', {'toUser': idB, 'type': 'poke', 'content': '的脑袋'});
  final poke = await pokeFuture;
  print(
      '拍一拍 OK: type=${poke['data']['type']} content=${poke['data']['content']}');
  final chg =
      await a2.req('change_password', {'old': '123456', 'new': 'abc123'});
  if (chg['ok'] != true) throw StateError('改密失败: $chg');
  final relogin = await a2.req('login', {'account': idA, 'password': 'abc123'});
  print('改密+重登 OK: ${relogin['ok'] == true && relogin['me']['name'] == '小明'}');

  // 月痕：A 发布，好友 B 可见、陌生人 C 不可见
  final post = await a2.req('post_moment', {'text': '今晚的月色真暗'});
  if (post['ok'] != true) throw StateError('发月痕失败: $post');
  final feedB = await b.req('moments_feed', {});
  final bHas = (feedB['feed'] as List).any((m) => m['text'] == '今晚的月色真暗');
  final feedC = await c.req('moments_feed', {});
  final cHas = (feedC['feed'] as List).any((m) => m['text'] == '今晚的月色真暗');
  if (!bHas || cHas) throw StateError('月痕可见性错误: bHas=$bHas cHas=$cHas');
  print('月痕 OK: 好友可见=$bHas 陌生人不可见=${!cHas}');

  // 点月 + 评论（回显点赞人姓名与评论内容）
  final mid = ((await a2.req('moments_feed', {}))['feed'] as List)
      .firstWhere((m) => m['text'] == '今晚的月色真暗')['id'];
  await b.req('like_moment', {'id': mid});
  final cm = await b.req('comment_moment', {'id': mid, 'text': '确实美'});
  if (cm['ok'] != true) throw StateError('评论失败: $cm');
  final feedA = await a2.req('moments_feed', {});
  final mA = (feedA['feed'] as List).firstWhere((m) => m['id'] == mid);
  if ((mA['likes'] as List).length != 1 ||
      (mA['comments'] as List).length != 1) {
    throw StateError('点月/评论错误: $mA');
  }
  print(
      '点月+评论 OK: 点月人=${mA['likes'][0]} 评论=${mA['comments'][0]['name']}:${mA['comments'][0]['text']}');

  // 本地图片头像：A 设置 → B 好友列表可见；超大头像被拒
  final fakeAvatar = base64Encode(List.filled(100, 7));
  final upAv = await a2.req('update_profile', {
    'name': '小明',
    'profile': {'avatar': fakeAvatar}
  });
  final flB = await b.req('login', {'account': idB, 'password': '123456'});
  final fa = (flB['friends'] as List).firstWhere((f) => f['id'] == idA);
  final big = await a2.req('update_profile', {
    'name': '小明',
    'profile': {'avatar': base64Encode(List.filled(500 * 1024, 1))}
  });
  if (upAv['ok'] != true ||
      (fa['profile']['avatar'] as String).isEmpty ||
      big['ok'] != false) {
    throw StateError('头像逻辑错误: up=${upAv['ok']} big=${big['ok']}');
  }
  print('头像 OK: B看到A头像(${(fa['profile']['avatar'] as String).length}B) 超大被拒');

  // 星标 + 备注
  final meta = await a2
      .req('set_friend_meta', {'to': idB, 'star': true, 'remark': '老王'});
  if (meta['ok'] != true || meta['meta'][idB]['star'] != true) {
    throw StateError('星标备注失败: $meta');
  }
  print('星标+备注 OK: ${meta['meta'][idB]}');

  // 拉黑后 B 发消息被拒
  final blk = await a2.req('block_user', {'to': idB, 'block': true});
  final rejected =
      await b.req('send_msg', {'toUser': idA, 'type': 'text', 'content': '在吗'});
  final unblk = await a2.req('block_user', {'to': idB, 'block': false});
  if (blk['ok'] != true || rejected['ok'] != false || unblk['ok'] != true) {
    throw StateError('拉黑逻辑错误: $blk / $rejected / $unblk');
  }
  print('拉黑拦截 OK: 「${rejected['msg']}」 解除 OK');

  // 删除好友（双向）
  final rm = await a2.req('remove_friend', {'to': idB});
  final reA2 = await a2.req('login', {'account': idA, 'password': 'abc123'});
  final reB2 = await b.req('login', {'account': idB, 'password': '123456'});
  if (rm['ok'] != true ||
      (reA2['friends'] as List).isNotEmpty ||
      (reB2['friends'] as List).isNotEmpty) {
    throw StateError('删除好友失败: rm=$rm');
  }
  print('删除好友 OK: 双方好友列表已清空');

  print('ALL PASS');
  exit(0);
}
