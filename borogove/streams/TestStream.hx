package borogove.streams;

import thenshim.Promise;
import haxe.io.BytesData;

import borogove.ID;
import borogove.GenericStream;
import borogove.Stanza;

class TestStream extends GenericStream {
	public function register(domain: String, preAuth: Null<String>) {
		return Promise.resolve(null);
	}

	public function connect(jid:String, sm:Null<BytesData>) {
		this.trigger("connect", { jid: jid, sm: sm });
	}

	public function disconnect() { }

	public function sendStanza(stanza:Stanza) {
		this.trigger("sendStanza", stanza);
	}

	public function onIq(type:IqRequestType, tag:String, xmlns:String, handler:(Stanza)->IqResult):Void { }
}
