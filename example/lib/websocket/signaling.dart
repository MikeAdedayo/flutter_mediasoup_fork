import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter_mediasoup_example/websocket/websocket.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'random_string.dart';
import 'package:flutter_mediasoup/flutter_mediasoup.dart';

enum SignalingState {
  CallStateNew,
  CallStateRinging,
  CallStateInvite,
  CallStateConnected,
  CallStateBye,
  ConnectionOpen,
  ConnectionClosed,
  ConnectionError,
}

/*
 * callbacks for Signaling API.
 */
typedef void SignalingStateCallback(SignalingState state);
typedef void StreamStateCallback(MediaStream stream);
typedef void OtherEventCallback(dynamic event);
typedef void DataChannelMessageCallback(
    RTCDataChannel dc, RTCDataChannelMessage data);
typedef void DataChannelCallback(RTCDataChannel dc);

class Signaling {
  String _selfId = randomNumeric(6);
  SimpleWebSocket _socket;
  var _sessionId;
  var _host;
  var _port = 4443;
  RTCPeerConnection _peerConnection;
  var _dataChannels = new Map<String, RTCDataChannel>();
  var _remoteCandidates = [];
  Map<String, RTCPeerConnection> _peerConnections = {};
  Random randomGen = Random();

  MediaStream _localVideoStream, _localAudioStream;
  List<MediaStream> _remoteStreams;
  SignalingStateCallback onStateChange;
  StreamStateCallback onLocalStream;
  StreamStateCallback onAddRemoteStream;
  StreamStateCallback onRemoveRemoteStream;
  OtherEventCallback onPeersUpdate;
  DataChannelMessageCallback onDataChannelMessage;
  DataChannelCallback onDataChannel;

  Map<int, Request> requestQueue = {};
  List<Transport> transportList = [];
  List<Peer> _peers = [];

  Transport _sendTransport;
  Transport _recvTransport;

  Device device = Device();

  Completer connected = Completer();

  Signaling(this._host);

  close() {
    if (_localVideoStream != null) {
      _localVideoStream.dispose();
      _localVideoStream = null;
    }

    // _peerConnections.forEach((key, pc) {
    //   pc.close();
    // });
    if (_socket != null) _socket.close();
  }

  void switchCamera() {
    if (_localVideoStream != null) {
      _localVideoStream.getVideoTracks()[0].switchCamera();
    }
  }

  void invite(String peerId, String media, useScreen) async {
    this._sessionId = this._selfId + '-' + peerId;

    if (this.onStateChange != null) {
      this.onStateChange(SignalingState.CallStateNew);
    }

    // Wait for the socket connection
    await connected.future;

    // Map rtpCapabilities = await getNativeRtpCapabilities();
    Map routerRtpCapabilities = await _send('getRouterRtpCapabilities', null);

    await device.load(routerRtpCapabilities);

    // Create producer
    _sendTransport = await _createTransport(peerId, media, producing: true, consuming: false);

    _sendTransport.onProduce = (Map producer) async {
      dynamic res = await _send('produce', {
        'transportId': _sendTransport.id,
        'kind': producer["kind"],
        'rtpParameters': producer['rtpParameters']
      });
      print(res);
    };

    _recvTransport = await _createTransport(peerId, media, producing: false, consuming: true);
    _recvTransport.onAddRemoteStream = onAddRemoteStream;

    dynamic res = await _send('join', {
        "displayName" : "Sigilyph",
        "device": {
          "flag": "mobile",
          "name": "mobile",
          "version": "1.0"
        },
        "rtpCapabilities": device.rtpCapabilities
    });

    if (res != null) {
      _peers = List<Peer>.from(res['peers'].map((peer) => Peer.fromJson(peer)));
      _updatePeers();

      _localVideoStream = await createStream("video");
      _localAudioStream = await createStream("audio");
      onLocalStream(_localVideoStream);
      // sendLocalStream(_localAudioStream, "audio");
      // sendLocalStream(_localVideoStream, "video");
    }
  }

  sendLocalStream(MediaStream stream, String kind) async {
    Map producer = await _sendTransport.produce(
      kind: kind,
      stream: stream, sendingRemoteRtpParameters: device.sendingRemoteRtpParameters('audio'));
  }

  Future<MediaStream> createStream(String kind) async {
    Map<String, dynamic> mediaConstraints;
    if (kind == "audio") {
      mediaConstraints = {
        'audio': true
      };
    } else {
      mediaConstraints = {
        'video': {
          'mandatory': {
            'minWidth': '640', // Provide your own width, height and frame rate here
            'minHeight': '480',
            'minFrameRate': '30',
          },
          'facingMode': 'environment',
          'optional': [],
        }
      };
    }

    MediaStream stream = await navigator.getUserMedia(mediaConstraints);
    return stream;
  }

  void bye() {
    _send('bye', {
      'session_id': this._sessionId,
      'from': this._selfId,
    });
  }

  void onMessage(message) async {
    Map<String, dynamic> mapData = message;
    var data = mapData['data'];
    int requestId = mapData['id'];
    String method = mapData['method'];

    if (requestQueue.containsKey(requestId)) {
      requestQueue[requestId].completer.complete(data);
    }

    if (mapData['notification'] == true) {
      print("Notification: $method");
      switch (method) {
        case 'peerClosed':
          print('peerClosed');
          _peers.removeWhere((peer) => peer.id == data['peerId']);
          _updatePeers();
          break;
        case 'newPeer':
          _peers.add(Peer.fromJson(data));
          _updatePeers();
          break;
      }
    }

    if (mapData['request'] == true) {
      print("Request: $method");
      switch (method) {
        case 'newConsumer':
          print(message);

          _recvTransport.consume(id: message["data"]["id"], kind:  message["data"]["kind"], rtpParameters: message["data"]["rtpParameters"]);

          _accept(message);
          break;
      }
    }

    requestQueue.remove(requestId);
    return;

    switch (mapData['type']) {
      case 'peers':
        {
          List<dynamic> peers = data;
          if (this.onPeersUpdate != null) {
            Map<String, dynamic> event = new Map<String, dynamic>();
            event['self'] = _selfId;
            event['peers'] = peers;
            this.onPeersUpdate(event);
          }
        }
        break;
      case 'offer':
        {
          var id = data['from'];
          var description = data['description'];
          var media = data['media'];
          var sessionId = data['session_id'];
          this._sessionId = sessionId;

          if (this.onStateChange != null) {
            this.onStateChange(SignalingState.CallStateNew);
          }

          // RTCPeerConnection pc = await _createPeerConnection(id, media, false);
          // _peerConnections[id] = pc;
          // await pc.setRemoteDescription(new RTCSessionDescription(
          //     description['sdp'], description['type']));
          // await _createAnswer(id, pc, media);
          // if (this._remoteCandidates.length > 0) {
          //   _remoteCandidates.forEach((candidate) async {
          //     await pc.addCandidate(candidate);
          //   });
          //   _remoteCandidates.clear();
          // }
        }
        break;
      case 'answer':
        {
          var id = data['from'];
          var description = data['description'];

          // var pc = _peerConnections[id];
          // if (pc != null) {
          //   await pc.setRemoteDescription(new RTCSessionDescription(
          //       description['sdp'], description['type']));
          // }
        }
        break;
      case 'candidate':
        {
          // var id = data['from'];
          // var candidateMap = data['candidate'];
          // var pc = _peerConnections[id];
          // RTCIceCandidate candidate = new RTCIceCandidate(
          //     candidateMap['candidate'],
          //     candidateMap['sdpMid'],
          //     candidateMap['sdpMLineIndex']);
          // if (pc != null) {
          //   await pc.addCandidate(candidate);
          // } else {
          //   _remoteCandidates.add(candidate);
          // }
        }
        break;
      case 'leave':
        {
          var id = data;
          // var pc = _peerConnections.remove(id);
          // _dataChannels.remove(id);

          // if (_localStream != null) {
          //   _localStream.dispose();
          //   _localStream = null;
          // }

          // if (pc != null) {
          //   pc.close();
          // }
          // this._sessionId = null;
          // if (this.onStateChange != null) {
          //   this.onStateChange(SignalingState.CallStateBye);
          // }
        }
        break;
      case 'bye':
        {
          var from = data['from'];
          var to = data['to'];
          var sessionId = data['session_id'];
          print('bye: ' + sessionId);

          if (_localVideoStream != null) {
            _localVideoStream.dispose();
            _localVideoStream = null;
          }

          // var pc = _peerConnections[to];
          // if (pc != null) {
          //   pc.close();
          //   _peerConnections.remove(to);
          // }

          var dc = _dataChannels[to];
          if (dc != null) {
            dc.close();
            _dataChannels.remove(to);
          }

          this._sessionId = null;
          if (this.onStateChange != null) {
            this.onStateChange(SignalingState.CallStateBye);
          }
        }
        break;
      case 'keepalive':
        {
          print('keepalive response!');
        }
        break;
      default:
        break;
    }
  }

  void connect() async {
    var url = 'wss://$_host:$_port';
    _socket = SimpleWebSocket(_host, _port, roomId: 'bazz', peerId: _selfId);

    print('connect to $url');

    _socket.onOpen = () async {
      print('onOpen');
      this?.onStateChange(SignalingState.ConnectionOpen);

      connected.complete();
    };

    _socket.onMessage = (message) {
      print('Recivied data: ' + message);
      JsonDecoder decoder = new JsonDecoder();
      this.onMessage(decoder.convert(message));
    };

    _socket.onClose = (int code, String reason) {
      print('Closed by server [$code => $reason]!');
      if (this.onStateChange != null) {
        this.onStateChange(SignalingState.ConnectionClosed);
      }
    };

    await _socket.connect();
  }

  _updatePeers() {
    if (this.onPeersUpdate != null) {
      Map<String, dynamic> event = new Map<String, dynamic>();
      event['self'] = _selfId;
      event['peers'] = _peers;
      this.onPeersUpdate(event);
    }
  }

  _createTransport(String peerId, String media, { bool producing: false, bool consuming = false}) async {
      Map res = await _send('createWebRtcTransport', {
        "producing": producing,
        "consuming": consuming,
        "forceTcp": false,
        "sctpCapabilities": {
          "numStreams":
            {
              "OS":1024,
              "MIS":1024
            }
        }
      });

      Transport transport;
      if (consuming) {
        transport = await device.createSendTransport(peerId, media,
          id: res["id"],
          iceParameters: res["iceParameters"],
          iceCandidates: res["iceCandidates"],
          dtlsParameters: res["dtlsParameters"],
          sctpParameters: res["sctpParameters"],
        );
      } else if (producing) {
        transport = await device.createRecvTransport(peerId, media,
          id: res["id"],
          iceParameters: res["iceParameters"],
          iceCandidates: res["iceCandidates"],
          dtlsParameters: res["dtlsParameters"],
          sctpParameters: res["sctpParameters"],
        );
      }
      _connectTransport(transport);

      return transport;
  }

  _connectTransport(Transport transport) async {
    Map res = await _send('connectWebRtcTransport', {
      'transportId': transport.id,
      'dtlsParameters': transport.dtlsParameters.toMap()
    });
    print(res);
  }

  _addDataChannel(id, RTCDataChannel channel) {
    channel.onDataChannelState = (e) {};
    channel.onMessage = (RTCDataChannelMessage data) {
      if (this.onDataChannelMessage != null)
        this.onDataChannelMessage(channel, data);
    };
    _dataChannels[id] = channel;

    if (this.onDataChannel != null) this.onDataChannel(channel);
  }

  _createDataChannel(id, RTCPeerConnection pc, {label: 'fileTransfer'}) async {
    RTCDataChannelInit dataChannelDict = new RTCDataChannelInit();
    RTCDataChannel channel = await pc.createDataChannel(label, dataChannelDict);
    _addDataChannel(id, channel);
  }

  _accept(message, {data}) {
    JsonEncoder encoder = new JsonEncoder();
    _socket.send(encoder.convert({
			"response" : true,
			"id"       : message["id"],
			"ok"       : true,
			"data"     : data ?? {}
		}));
  }

  _send(method, data) {
    Map message = Map();
    int requestId = randomGen.nextInt(100000000);
    message['method'] = method;
    message['request'] = true;
    message['id'] = requestId;
    message['data'] = data;
    print("Sending request $method id: $requestId");
    requestQueue[requestId] = Request(message);
    JsonEncoder encoder = new JsonEncoder();
    _socket.send(encoder.convert(message));

    return requestQueue[requestId].completer.future;
  }
}
