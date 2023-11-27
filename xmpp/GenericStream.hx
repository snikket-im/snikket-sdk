package xmpp;

import xmpp.Stanza;
import xmpp.EventEmitter;

enum IqResult {
	IqResultElement(element:Stanza);
	IqResult;
	IqNoResult;
}

abstract class GenericStream extends EventEmitter {
	public var clientId: Null<String> = null;

	public function new() {
		super();
	}
	
	/* Connections and streams */

	abstract public function connect(jid:String, sm:Null<{id:String,outbound:Int,inbound:Int,outbound_q:Array<String>}>):Void;
	abstract public function sendStanza(stanza:Stanza):Void;
	abstract public function newId():String;
	abstract public function onIq(type:IqRequestType, tag:String, xmlns:String, handler:(Stanza)->IqResult):Void;

	public function sendIq(stanza:Stanza, callback:(stanza:Stanza)->Void):Void {
		var id = newId();
		stanza.attr.set("id", id);
		this.once('iq-response/$id', function (event) {
			callback(event.stanza);
			return EventHandled;
		});
		sendStanza(stanza);
	}

	private function onStanza(stanza:Stanza):Void {
		trace("stanza received!");
		final xmlns = stanza.attr.get("xmlns");
		if(xmlns == "jabber:client") {
			final name = stanza.name;
			if(name == "iq") {
				var type = stanza.attr.get("type");
				trace('type: $type');
				if(type == "result" || type == "error") {
					var id = stanza.attr.get("id");
					trigger('iq-response/$id', { stanza: stanza });
				} else {
					// These are handled by onIq instead
				}
			} else if (name == "message" || name == "presence") {
				trigger(name, { stanza: stanza });
			}
		}
	}
}
