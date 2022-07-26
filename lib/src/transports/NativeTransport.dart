import 'dart:convert';
import 'dart:io';

import '../logger.dart';
import '../message.dart';
import 'TransportInterface.dart';

final _logger = Logger('Logger::NativeTransport');

class Transport extends TransportInterface {
  late bool _closed;
  late String _url;
  late dynamic _options;
  WebSocket? _ws;

  Transport(String url, {dynamic options}) : super(url, options: options) {
    _logger.debug('constructor() [url:$url, options:$options]');
    this._closed = false;
    this._url = url;
    this._options = options ?? {};
    this._ws = null;

    this._runWebSocket();
  }

  get closed => _closed;

  @override
  close() {
    _logger.debug('close()');

    this._closed = true;
    this.safeEmit('close');

    try {
      this._ws?.close();
    } catch (error) {
      _logger.error('close() | error closing the WebSocket: $error');
    }
  }

  @override
  Future send(message) async {
    try {
      this._ws?.add(jsonEncode(message));
    } catch (error) {
      _logger.warn('send() failed:$error');
    }
  }

  _runWebSocket() async {
    WebSocket.connect(this._url, protocols: ['protoo']).then((ws) {
      if (ws.readyState == WebSocket.open) {
        final interval = _options['pingInterval'] as int? ?? 3;
        ws.pingInterval = Duration(seconds: interval);
        this._ws = ws;
        _onOpen();
        ws.listen(_onMessage, onDone: _onClose, onError: _onError);
      } else {
        _logger.warn(
            'WebSocket "close" event code:${ws.closeCode}, reason:"${ws.closeReason}"]');
        _onClose();
      }
    });
  }

  _onOpen() {
    _logger.debug('onOpen');
    this.safeEmit('open');
  }

  _onClose() async {
    this._closed = true;
    final closeCode = _ws?.closeCode;
    final closeReason = _ws?.closeReason;
    safeEmit('close', {
      'closeCode': closeCode,
      'closeReason': closeReason,
    });
  }

  _onMessage(event) {
    final message = Message.parse(event);
    if (message == null) return;
    safeEmit('message', message);
  }

  _onError(err) {
    _logger.error('WebSocket "error" event');
    emit('failed', err);
  }
}
