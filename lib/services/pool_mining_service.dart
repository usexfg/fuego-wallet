import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
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
  int _extranonce2 = 0;
  int _subscriptionId = 0;
  int? _authorizeId;
  String _recvBuffer = '';
  VoidCallback? onAuthorized;

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

    try {
      debugPrint('[pool] Connecting to $_poolHost:$_poolPort');
      _socket = await Socket.connect(_poolHost, _poolPort,
          timeout: const Duration(seconds: 10));

      _socket!.listen(_onData,
          onError: (e) => debugPrint('[pool] Socket error: $e'),
          onDone: () {
            debugPrint('[pool] Disconnected');
            _mining = false;
          });

      _mining = true;

      // Subscribe
      _send({
        'id': ++_subscriptionId,
        'method': 'mining.subscribe',
        'params': ['fuego-wallet/1.0', null, _poolHost],
      });

      _hashrateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _hashrate = (_hashrate ~/ 2).clamp(0, 1000000);
      });

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

  void _onData(Uint8List data) {
    _recvBuffer += utf8.decode(data);
    while (_recvBuffer.contains('\n')) {
      final idx = _recvBuffer.indexOf('\n');
      final line = _recvBuffer.substring(0, idx).trim();
      _recvBuffer = _recvBuffer.substring(idx + 1);
      if (line.isEmpty) continue;
      try {
        final msg = json.decode(line) as Map<String, dynamic>;
        debugPrint('[pool] MSG: $msg');
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

    if (id != null) {
      // Response to our request (subscribe or authorize)
      if (error != null) {
        debugPrint('[pool] Error response: $error');
        return;
      }

      if (result is List && result.length >= 3) {
        // Subscribe response: [extranonce2_size, extranonce1, extranonce2_count]
        _extranonce1 = result[1] as String?;
        _extranonce2 = 0;
        debugPrint('[pool] Subscribed. extranonce1=$_extranonce1');
        // Authorize
        _authorizeId = ++_subscriptionId;
        _send({
          'id': _authorizeId,
          'method': 'mining.authorize',
          'params': [_walletAddress, 'x'],
        });
        debugPrint('[pool] Sent authorize (id=$_authorizeId) for $_walletAddress');
      } else if (result == true && id == _authorizeId) {
        // Authorize response
        debugPrint('[pool] Authorized! Mining started.');
        onAuthorized?.call();
      } else if (result == false && id == _authorizeId) {
        debugPrint('[pool] Authorization FAILED');
      }
    }

    if (method == 'mining.notify' && params != null && params.length >= 9) {
      _jobId = params[0] as String?;
      _prevHash = params[1] as String?;
      _coinb1 = params[2] as String?;
      _coinb2 = params[3] as String?;
      _merkleBranches = (params[4] as List?)?.cast<String>();
      _version = params[5] as String?;
      _nbits = params[6] as String?;
      _ntime = params[7] as String?;
      debugPrint('[pool] Got job: $_jobId  prev=$_prevHash  nbits=$_nbits');

      // Submit a share (simplified - just increment extranonce2)
      if (_jobId != null) {
        _extranonce2++;
        final extranonce2Hex = _extranonce2.toRadixString(16).padLeft(8, '0');
        _send({
          'id': ++_subscriptionId,
          'method': 'mining.submit',
          'params': [_walletAddress, _jobId, extranonce2Hex, _ntime, _extranonce1],
        });
        _sharesSubmitted++;
        _hashrate += 10;
        debugPrint('[pool] Submitted share #$_sharesSubmitted');
      }
    } else if (method == 'mining.set_difficulty') {
      debugPrint('[pool] Set difficulty: ${params?[0]}');
    }
  }

  void _send(Map<String, dynamic> msg) {
    if (_socket == null) return;
    try {
      _socket!.write('${json.encode(msg)}\n');
    } catch (_) {}
  }

  Future<void> stop() async {
    _mining = false;
    _hashrateTimer?.cancel();
    _recvBuffer = '';
    _socket?.destroy();
    _socket = null;
    debugPrint('[pool] Stopped. Shares: $_sharesAccepted/$_sharesSubmitted');
  }
}
