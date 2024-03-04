package snikket.jingle;

typedef TODO = Dynamic;
typedef DTMFSender = TODO;
typedef Transceiver = {
	 receiver: Null<{ track: MediaStreamTrack }>,
	 sender: Null<{ track: MediaStreamTrack, dtmf: DTMFSender }>
}

class MediaStreamTrack {
	 public var muted: Bool;
	 public var kind: String;

	 public function stop() { }
}

class MediaStream {
	 public function getTracks() {
		  return [];
	 }
}

typedef SessionDescriptionInit = {
	var ?sdp : String;
	var type : SdpType;
}

typedef Configuration = {
	//var ?bundlePolicy : BundlePolicy;
	//var ?certificates : Array<Certificate>;
	var ?iceServers : Array<IceServer>;
	//var ?iceTransportPolicy : IceTransportPolicy;
	var ?peerIdentity : String;
}

class PeerConnection {
	 public var localDescription: Dynamic;

	public function new(?configuration : Configuration, ?constraints : Dynamic){

	}

	 public function setLocalDescription(description : SessionDescriptionInit): Promise<Any> {
		return new Promise(null);
	}

	 public function setRemoteDescription(description : SessionDescriptionInit): Promise<Any> {
		  return new Promise(null);
	 }

	 public function addIceCandidate(candidate : TODO): Promise<Any> {
		  return new Promise(null);
	 }

	 public function addTrack(track : MediaStreamTrack, stream : MediaStream) {
		  return null;
	 }

	 public function getTransceivers(): Array<Transceiver> {
		  return [];
	 }

	 public function close() { }

	 public function addEventListener(event: String, callback: Dynamic->Void) {

	 }
}

enum abstract SdpType(String) {
	var OFFER = "offer";
	var PRANSWER = "pranswer";
	var ANSWER = "answer";
	var ROLLBACK = "rollback";
}

class Promise<T> {
	 public static function resolve<T>(value: T):Dynamic { // TODO: should be Promise<T>
		  return new Promise(value);
	 }

	 public static function all<T>(iterable:Array<Promise<T>>): Promise<Array<T>> {
		  return new Promise([]);
	 }

	 public function new(?value: T) {

	 }

	 public function then<TOut>(onFulfilled:Null<PromiseHandler<T, TOut>>, ?onRejected:PromiseHandler<Dynamic, TOut>):Promise<TOut> {
		  return onFulfilled.call(null);
	 }

	 public function catchError(onRejected:PromiseHandler<Dynamic, T>) {
		  return new Promise(1);
	 }
}

abstract PromiseHandler<T, TOut>(T->Promise<TOut>) from T->Promise<TOut> {
	 @:from
	 public static function fromVoid<T>(f: T->Void): PromiseHandler<T, Any> {
		  return (x) -> { f(x); return new Promise(null); };
	 }

	 @:from
	 public static function fromNoPromise<T, TOut>(f: T->TOut): PromiseHandler<T, TOut> {
		  return (x) -> new Promise(f(x));
	 }

	 public function call(x: T): Promise<TOut> {
		  return this(x);
	 }
}
