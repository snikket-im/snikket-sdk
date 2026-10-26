package borogove.streams;

import thenshim.Promise;
import haxe.io.BytesData;

import borogove.ID;
import borogove.GenericStream;
import borogove.Stanza;

class TestStream extends GenericStream {
	private final iqHandlers: Map<IqRequestType, Map<String, Stanza->IqResult>> = [IqRequestType.Get => [], IqRequestType.Set => []];

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

	public function onIq(type:IqRequestType, tag:String, xmlns:String, handler:(Stanza)->IqResult):Void {
		iqHandlers[type]['{' + xmlns + '}' + tag] = handler;
	}

	/**
		Dispatch an incoming IQ request to the handler registered for it.
	**/
	public function dispatchIq(stanza:Stanza):IqResult {
		final child = stanza.getFirstChild();
		if (child == null) return IqNoResult;

		final type = stanza.attr.get("type") == "get" ? IqRequestType.Get : IqRequestType.Set;
		final handler = iqHandlers[type]['{' + child.attr.get("xmlns") + '}' + child.name];
		if (handler == null) return IqNoResult;

		return handler(stanza);
	}
}
