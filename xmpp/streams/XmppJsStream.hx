package xmpp.streams;

import js.lib.Promise;
import haxe.Http;
import haxe.Json;

import xmpp.FSM;
import xmpp.GenericStream;
import xmpp.Stanza;

@:jsRequire("@xmpp/client", "client")
extern class XmppJsClient {
	function new(options:Dynamic);
	function start():Promise<Dynamic>;
	function on(eventName:String, callback:(Dynamic)->Void):Void;
	function send(stanza:XmppJsXml):Void;
}

@:jsRequire("@xmpp/jid", "jid")
extern class XmppJsJID {
	function new(jid:String);

	var local(default, set):String;
	var domain(default, set):String;
	var resource(default, set):String;
}

@:jsRequire("@xmpp/debug")
extern class XmppJsDebug {
	@:selfCall
	function new(client:XmppJsClient, force:Bool):Void;
}

@:jsRequire("@xmpp/xml")
extern class XmppJsXml {
	@:selfCall
	@:overload(function(tagName:String, ?attr:Dynamic):XmppJsXml { })
	function new();
	@:overload(function(textContent:String):Void { })
	function append(el:XmppJsXml):Void;

	var name:String;
	var attrs:Dynamic;
	var children:Array<Dynamic>;
}

@:jsRequire("ltx") // The default XML library used by xmpp.js
extern class XmppJsLtx {
	static function isNode(el:Dynamic):Bool;
	static function isElement(el:Dynamic):Bool;
	static function isText(el:Dynamic):Bool;
}

@:jsRequire("@xmpp/id")
extern class XmppJsId {
	@:selfCall
	static function id():String;
}

typedef HostMetaRecord = {
	rel : String,
	href : String,
};
typedef HostMetaJson = {
	links : Array<HostMetaRecord>,
};

class XmppJsStream extends GenericStream {
	private var client:XmppJsClient;
	private var jid:XmppJsJID;
	private var connectionURI:String;
	private var debug = true;
	private var state:FSM;

	override public function new() {
		super();
		state = new FSM({
			transitions: [
				{ name: "connect-requested", from: ["offline"], to: "connecting" },
				{ name: "connection-success", from: ["connecting"], to: "online" },
				{ name: "connection-error", from: ["connecting"], to: "offline" },
				{ name: "connection-closed", from: ["connecting", "online"], to: "offline" },
			],
			state_handlers: [
				"online" => this.onOnline,
				"offline" => this.onOffline,
				
			],
		}, "offline");
	}

	static private function resolveConnectionURI(domain:String, callback:(String)->Void):Void {
		var request = new Http('https://$domain/.well-known/host-meta.json');
		request.onData = function (data:String) {
			try {
				var parsed:HostMetaJson = Json.parse(data);
				for(entry in parsed.links) {
					trace("ENTRY");
					if(entry.href.substr(0, 6) == "wss://") {
						callback(entry.href);
						return;
					}
				}
			} catch (e) {
			}
			callback(null);
		};
		request.onError = function (msg:String) {
			callback(null);
		}
		request.request(false);
	}

	private function connectWithURI(uri:String) {
		trace("Got connection URI: "+uri);
		if(uri == null) {
			this.state.event("connection-error");
			return;
		}
		connectionURI = uri;

		this.on("auth/password", function (event) {
			var xmpp = new XmppJsClient({
				service: connectionURI,
				domain: jid.domain,
				username: jid.local,
				password: event.password,
			});

			if(this.debug) {
				new XmppJsDebug(xmpp, true);
			}

			this.client = xmpp;

			xmpp.on("online", function (data) {
				this.state.event("connection-success");
			});

			xmpp.on("offline", function (data) {
				this.state.event("connection-closed");
			});

			xmpp.on("stanza", function (stanza) {
				this.onStanza(convertToStanza(stanza));
			});

			xmpp.start().catchError(function (err) {
				trace(err);
			});
			return EventHandled;
		});
		this.trigger("auth/password-needed", {});
	}

	public function connect(jid:String) {
		this.state.event("connect-requested");
		this.jid = new XmppJsJID(jid);

		resolveConnectionURI(this.jid.domain, this.connectWithURI);
	}

	private function convertFromStanza(el:Stanza):XmppJsXml {
		var xml = new XmppJsXml(el.name, el.attr);
		if(el.children.length > 0) {
			for(child in el.children) {
				switch(child) {
					case Element(stanza): xml.append(convertFromStanza(stanza));
					case CData(text): xml.append(text.serialize());
				};
			}
		}
		return xml;
	}

	private function convertToStanza(el:XmppJsXml):Stanza {
		var stanza = new Stanza(el.name, el.attrs);
		for (child in el.children) {
			if(XmppJsLtx.isElement(child)) {
				stanza.addChild(convertToStanza(child));
			} else if(XmppJsLtx.isText(child)) {
				stanza.text(cast(child, String));
			}
		}
		return stanza;
	}

	public function sendStanza(stanza:Stanza) {
		client.send(convertFromStanza(stanza));
	}

	public function newId():String {
		return XmppJsId.id();
	}

	/* State handlers */

	private function onOnline(event) {
		trigger("status/online", {});
	}

	private function onOffline(event) {
		trigger("status/offline", {});
	}
}
