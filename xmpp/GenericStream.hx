package xmpp;

import xmpp.Stanza;
import xmpp.EventEmitter;

abstract class GenericStream extends EventEmitter {

	public function new() {
		super();
	}
	
	/* Connections and streams */

	abstract public function connect(jid:String):Void;
	abstract public function sendStanza(stanza:Stanza):Void;
	abstract public function newId():String;

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
					if (trigger('iq', { stanza: stanza }) == EventUnhandled) {
						var reply = new Stanza("iq", {
							type: "error",
							id: stanza.attr.get("id"),
							to: stanza.attr.get("from")
						})
							.tag("error", { type: "cancel" })
							.tag("service-unavailable", { xmlns: "urn:ietf:params:xml:ns:xmpp-stanzas" })
							.up().up();
						sendStanza(reply);
					}
				}
			} else if (name == "message" || name == "presence") {
				trigger(name, { stanza: stanza });
			}
		}
	}
}
