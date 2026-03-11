package borogove.calls;

import thenshim.Promise;

typedef MediaStreamTrack = Dynamic;
typedef DTMFSender = Dynamic;

typedef Transceiver = {
	receiver: Null<{ track: MediaStreamTrack }>,
	sender: Null<{ track: MediaStreamTrack, dtmf: DTMFSender }>
}

enum abstract SdpType(Int) {
	var UNSPEC;
	var OFFER;
	var ANSWER;
	var PRANSWER;
	var ROLLBACK;
}

class MediaStream {
	public function getTracks() {
		return [];
	}
}

class PeerConnection {
	public var localDescription: { sdp: Null<String> };
	public var connectionState: String;

	public function new(?configuration : Dynamic, ?constraints : Dynamic) { }


	public function setLocalDescription(sdpType: Null<SdpType>): Promise<Any> {
		return Promise.resolve(null);
	}

	public function setRemoteDescription(description: Dynamic): Promise<Any> {
		return Promise.resolve(null);
	}

	public function addIceCandidate(candidate: { candidate: String, sdpMid: String, sppMLineIndex: Int, usernameFragment: String }): Promise<Any> {
		return Promise.resolve(null);
	}

	public function addTrack(track: MediaStreamTrack, stream: MediaStream) { }

	public function getTransceivers(): Array<Transceiver> {
		return [];
	}

	public function close() { }

	public function addEventListener(event: String, callback: Dynamic->Void) { }
}
