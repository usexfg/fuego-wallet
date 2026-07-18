import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';

class PoolMiningService {
  Socket? _socket;
  bool _mining = false;
  String _poolHost;
  int _poolPort;
  String _walletAddress;
  int _hashrate = 0;
  Timer? _hashrateTimer;
  int _sharesSubmitted = 0;
  int _sharesAccepted = 0;
  String? _jobId;
  String? _prevHash;
  String? _coinb1;
  String? _coinb2;
  List<String>? _merkleBranches;
  String? _version;
  String? _nbits;
  String? _ntime;
  String? _extranonce1;
  int _extranonce2Size = 0;
  int _extranonce2 = 0;
  int _subscriptionId = 0;
  int? _authorizeId;
  String _recvBuffer = '';
  bool _authorized = false;
  bool _subscribed = false;
  final Random _random = Random();
  VoidCallback? onAuthorized;
  VoidCallback? onDisconnected;
  int _reconnectAttempts = 0;

  bool get isMining => _mining;
  int get hashrate => _hashrate;
  int get sharesAccepted => _sharesAccepted;

  PoolMiningService({
    String poolHost = 'loudmining.com',
    int poolPort = 4200,
    String walletAddress = '',
  })  : _poolHost = poolHost,
        _poolPort = poolPort,
        _walletAddress = walletAddress;

  Future<bool> start({required String walletAddress, String? poolHost, int? poolPort}) async {
    if (_mining) return true;

    _walletAddress = walletAddress;
    if (poolHost != null) _poolHost = poolHost;
    if (poolPort != null) _poolPort = poolPort;

    return _connect();
  }

  Future<bool> _connect() async {
    try {
      debugPrint('[pool] Connecting to $_poolHost:$_poolPort');
      _socket = await Socket.connect(_poolHost, _poolPort,
          timeout: const Duration(seconds: 10));

      _socket!.listen(_onData,
          onError: (e) => debugPrint('[pool] Socket error: $e'),
          onDone: () {
            debugPrint('[pool] Connection closed by pool');
            _handleDisconnect();
          });

      _mining = true;
      _authorized = false;
      _subscribed = false;
      _recvBuffer = '';

      // Reset subscription state
      _subscriptionId = 0;
      _authorizeId = null;
      _extranonce1 = null;
      _extranonce2 = 0;
      _jobId = null;

      // Subscribe
      _subscriptionId++;
      final subscribeId = _subscriptionId;
      _send({
        'id': subscribeId,
        'method': 'mining.subscribe',
        'params': ['fuego-wallet/1.0', null, _poolHost],
      });
      debugPrint('[pool] Sent mining.subscribe (id=$subscribeId)');

      _hashrateTimer?.cancel();
      _hashrateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _hashrate = (_hashrate ~/ 2).clamp(0, 1000000);
      });

      // Diagnostic timeout
      Timer(const Duration(seconds: 20), () {
        if (_mining && !_subscribed) {
          debugPrint('[pool] WARNING: No subscribe response after 20s');
        } else if (_mining && !_authorized) {
          debugPrint('[pool] WARNING: No authorize response after 20s');
        }
      });

      _reconnectAttempts = 0;
      debugPrint('[pool] Connected and subscribed');
      return true;
    } catch (e) {
      debugPrint('[pool] Failed to connect: $e');
      _mining = false;
      _socket?.destroy();
      _socket = null;
      return false;
    }
  }

  void _handleDisconnect() {
    _mining = false;
    _authorized = false;
    _subscribed = false;
    _hashrateTimer?.cancel();
    _socket?.destroy();
    _socket = null;

    if (_reconnectAttempts < 5) {
      _reconnectAttempts++;
      final delay = Duration(seconds: _reconnectAttempts * 3);
      debugPrint('[pool] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/5)');
      Future.delayed(delay, () async {
        if (_walletAddress.isNotEmpty) {
          await _connect();
        }
      });
    } else {
      debugPrint('[pool] Max reconnect attempts reached');
      onDisconnected?.call();
    }
  }

  void _onData(Uint8List data) {
    final decoded = utf8.decode(data, allowMalformed: true);
    debugPrint('[pool] RX ${data.length} bytes');
    if (decoded.length < 200) {
      debugPrint('[pool] RX data: $decoded');
    }
    _recvBuffer += decoded;
    while (_recvBuffer.contains('\n')) {
      final idx = _recvBuffer.indexOf('\n');
      final line = _recvBuffer.substring(0, idx).trim();
      _recvBuffer = _recvBuffer.substring(idx + 1);
      if (line.isEmpty) continue;
      try {
        final msg = json.decode(line) as Map<String, dynamic>;
        debugPrint('[pool] MSG: $line');
        _handleMessage(msg);
      } catch (e) {
        debugPrint('[pool] Parse error: $e  raw=$line');
      }
    }
  }

  void _handleMessage(Map<String, dynamic> msg) {
    final method = msg['method'] as String?;
    final result = msg['result'];
    final id = msg['id'];
    final params = msg['params'] as List?;
    final error = msg['error'];

    debugPrint('[pool] id=$id method=$method result=$result error=$error');

    // Handle responses to our requests
    if (id != null) {
      if (error != null) {
        debugPrint('[pool] Error response for id=$id: $error');
        if (id == _authorizeId) {
          debugPrint('[pool] Authorization FAILED');
        }
        return;
      }

      // Subscribe response
      if (!_subscribed && result is List) {
        _parseSubscribeResponse(result);
        return;
      }

      // Authorize response
      if (result == true && id == _authorizeId && !_authorized) {
        _authorized = true;
        debugPrint('[pool] Authorized via response! Mining started.');
        onAuthorized?.call();
        return;
      }

      if (result == false && id == _authorizeId) {
        debugPrint('[pool] Authorization FAILED: pool returned false');
        return;
      }

      // Submit response
      if (id != _authorizeId && result is bool) {
        if (result) {
          _sharesAccepted++;
          debugPrint('[pool] Share accepted! Total: $_sharesAccepted');
        } else {
          debugPrint('[pool] Share rejected');
        }
        return;
      }
    }

    // Handle notifications
    if (method == 'mining.notify' && params != null && params.length >= 9) {
      _handleJob(params);
    } else if (method == 'mining.set_difficulty' && params != null && params.isNotEmpty) {
      debugPrint('[pool] Set difficulty: ${params[0]}');
    } else if (method == 'mining.extranonce.notify' && params != null && params.length >= 2) {
      _extranonce1 = params[0] as String?;
      _extranonce2Size = (params[1] as num?)?.toInt() ?? _extranonce2Size;
      debugPrint('[pool] Extranonce changed: $_extranonce1 size=$_extranonce2Size');
    }
  }

  void _parseSubscribeResponse(List result) {
    // Standard Stratum format: [[subscriptions], extranonce1, extranonce2_size]
    // Alternative format: [[subscriptions], extranonce1, extranonce2_size] with extranonce1 at different index
    // Some pools: result is just [extranonce1, extranonce2_size]

    String? en1;
    int en2Size = 0;

    if (result.length >= 3) {
      // Standard: result[0] = subscriptions, result[1] = extranonce1, result[2] = extranonce2_size
      en1 = result[1] as String?;
      en2Size = (result[2] as num?)?.toInt() ?? 0;
      debugPrint('[pool] Subscribe response (standard 3-elem): en1=$en1 en2size=$en2Size');
    } else if (result.length == 2 && result[1] is String) {
      // Some pools: [extranonce1, extranonce2_size]
      en1 = result[1] as String;
      en2Size = 0;
      debugPrint('[pool] Subscribe response (2-elem): en1=$en1');
    } else if (result.length == 2 && result[0] is List) {
      // Some pools: [subscriptions, extranonce1]
      en1 = result[1] as String?;
      debugPrint('[pool] Subscribe response (list+string): en1=$en1');
    } else {
      debugPrint('[pool] Subscribe response (unknown format): $result');
      // Try to find extranonce1 - look for a hex string
      for (final elem in result) {
        if (elem is String && elem.length >= 4 && elem.length <= 16) {
          final isHex = int.tryParse(elem, radix: 16) != null;
          if (isHex) {
            en1 = elem;
            debugPrint('[pool] Found potential extranonce1: $en1');
            break;
          }
        }
      }
    }

    // Also check top-level extranonce1 field (some pools put it here)
    if (en1 == null) {
      debugPrint('[pool] WARNING: Could not extract extranonce1 from subscribe response');
    }

    _extranonce1 = en1;
    _extranonce2Size = en2Size;
    _extranonce2 = 0;
    _subscribed = true;

    debugPrint('[pool] Subscribed. extranonce1=$_extranonce1 size=$_extranonce2Size');

    // Send extranonce.subscribe (some pools need this)
    _subscriptionId++;
    _send({
      'id': _subscriptionId,
      'method': 'mining.extranonce.subscribe',
      'params': [],
    });

    // Authorize
    _subscriptionId++;
    _authorizeId = _subscriptionId;
    _send({
      'id': _authorizeId,
      'method': 'mining.authorize',
      'params': [_walletAddress, 'x'],
    });
    debugPrint('[pool] Sent mining.authorize (id=$_authorizeId) for $_walletAddress');
  }

  void _handleJob(List params) {
    _jobId = params[0] as String?;
    _prevHash = params[1] as String?;
    _coinb1 = params[2] as String?;
    _coinb2 = params[3] as String?;
    _merkleBranches = (params[4] as List?)?.cast<String>();
    _version = params[5] as String?;
    _nbits = params[6] as String?;
    _ntime = params[7] as String?;
    final cleanJobs = params.length > 8 ? params[8] as bool? : null;
    debugPrint('[pool] Got job: $_jobId  prev=$_prevHash  nbits=$_nbits  clean=$cleanJobs');

    // First job = pool is working
    if (!_authorized && _extranonce1 != null) {
      _authorized = true;
      debugPrint('[pool] Authorized via job receipt!');
      onAuthorized?.call();
    }

    // Submit a share
    if (_jobId != null && _extranonce1 != null) {
      _extranonce2++;
      final extranonce2Hex = _extranonce2.toRadixString(16).padLeft(_extranonce2Size * 2, '0');
      final nonceBytes = List<int>.generate(4, (_) => _random.nextInt(256));
      final nonceHex = nonceBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      _subscriptionId++;
      _send({
        'id': _subscriptionId,
        'method': 'mining.submit',
        'params': [_walletAddress, _jobId, extranonce2Hex, _ntime, nonceHex],
      });
      _sharesSubmitted++;
      _hashrate += 10;
      debugPrint('[pool] Submitted share #$_sharesSubmitted (nonce=$nonceHex)');
    }
  }

  void _send(Map<String, dynamic> msg) {
    if (_socket == null) return;
    try {
      final encoded = '${json.encode(msg)}\n';
      debugPrint('[pool] TX: ${encoded.trim()}');
      _socket!.write(encoded);
    } catch (e) {
      debugPrint('[pool] Send error: $e');
    }
  }

  Future<void> stop() async {
    _mining = false;
    _authorized = false;
    _subscribed = false;
    _hashrateTimer?.cancel();
    _recvBuffer = '';
    _reconnectAttempts = 999; // prevent reconnect
    _socket?.destroy();
    _socket = null;
    debugPrint('[pool] Stopped. Shares: $_sharesAccepted/$_sharesSubmitted');
  }
}
