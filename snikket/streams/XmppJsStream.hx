package snikket.streams;

import haxe.Http;
import haxe.Json;
import haxe.io.Bytes;
import haxe.io.BytesData;
import js.lib.Promise;
using Lambda;

import snikket.FSM;
import snikket.GenericStream;
import snikket.Stanza;

@:js.import(@default "@xmpp/sasl-scram-sha-1")
extern class XmppJsScramSha1 {
	@:selfCall
	function new(sasl: Dynamic);
}

@:js.import("@xmpp/client", "client")
extern class XmppJsClient {
	function new(options:Dynamic);
	function start():Promise<Dynamic>;
	function stop():Promise<Dynamic>;
	function on(eventName:String, callback:(Dynamic)->Void):Void;
	function send(stanza:XmppJsXml):Void;
	var jid:XmppJsJID;
	var streamFrom:Null<XmppJsJID>;
	var status: String;
	var iqCallee:{
		get: (String, String, ({stanza: XmppJsXml})->Any)->Void,
		set: (String, String, ({stanza: XmppJsXml})->Any)->Void,
	};
	var middleware: { use:(({stanza: XmppJsXml})->Void)->Void };
	var streamFeatures: { use:(String,String,({}, ()->Void, XmppJsXml)->Void)->Void };
	var streamManagement: { id:String, outbound: Int, inbound: Int, outbound_q: Array<XmppJsXml>, enabled: Bool, allowResume: Bool };
	var sasl2: Dynamic;
}

@:js.import("@xmpp/jid", "jid")
extern class XmppJsJID {
	function new(jid:String);
	function toString():String;

	var local(default, set):String;
	var domain(default, set):String;
	var resource(default, set):String;
}

@:js.import(@default "@xmpp/debug")
extern class XmppJsDebug {
	@:selfCall
	function new(client:XmppJsClient, force:Bool):Void;
}

@:js.import(@default "@xmpp/xml")
extern class XmppJsXml {
	@:selfCall
	@:overload(function(tagName:String, ?attr:Dynamic):XmppJsXml { })
	function new();
	@:overload(function(textContent:String):Void { })
	function append(el:XmppJsXml):Void;
	function toString():String;

	var name:String;
	var attrs:Dynamic;
	var children:Array<Dynamic>;
}

@:js.import(@star "ltx") // The default XML library used by xmpp.js
extern class XmppJsLtx {
	static function isNode(el:Dynamic):Bool;
	static function isElement(el:Dynamic):Bool;
	static function isText(el:Dynamic):Bool;
	static function parse(input:String):XmppJsXml;
}

@:js.import(@default "@xmpp/id")
extern class XmppJsId {
	@:selfCall
	static function id():String;
}

@:js.import(@default "@xmpp/error")
extern class XmppJsError {
	public final name: String;
	public final condition: String;
	public final text: String;
	public final application: String;
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
	private var connectionURI: Null<String>;
	private var debug = true;
	private var state:FSM;
	private var pending:Array<XmppJsXml> = [];
	private var pendingOnIq:Array<{type:IqRequestType,tag:String,xmlns:String,handler:(Stanza)->IqResult}> = [];
	private var initialSM: Null<BytesData> = null;
	private var resumed = false;
	private var everConnected = false;

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
			transition_handlers: [
				"connection-error" => this.onError,
			],
		}, "offline");
	}

	static private function resolveConnectionURI(domain:String, callback:(String)->Void):Void {
		#if nodejs
		callback("xmpp://" + domain);
		return;
		#else
		var request = new Http('https://$domain/.well-known/host-meta.json');
		request.onData = function (data:String) {
			try {
				var parsed:HostMetaJson = Json.parse(data);
				final links = parsed.links.filter((entry) -> entry.href.substr(0, 6) == "wss://");
				if (links.length > 0) {
					callback(links[0].href);
					return;
				}
			} catch (e) {
			}
			callback(null);
		};
		request.onError = function (msg:String) {
			callback(null);
		}
		request.request(false);
		#end
	}

	private function connectWithURI(uri:String) {
		trace("Got connection URI: "+uri);
		if(uri == null) {
			this.state.event("connection-error");
			return;
		}
		connectionURI = uri;

		final waitForCreds = new js.lib.Promise((resolve, reject) -> {
			this.on("auth/password", (event: Dynamic) -> {
				if (event.username == null) event.username = jid.local;
				resolve(event);
				return EventHandled;
			});
		});

		final clientId = jid.resource;
		final xmpp = new XmppJsClient({
			service: connectionURI,
			domain: jid.domain,
			resource: jid.resource,
			clientId: clientId,
			credentials: (callback, mechanisms: Dynamic) -> {
				this.clientId = Std.is(mechanisms, Array) ? clientId : null;
				final mechs: Array<{name: String, canFast: Bool, canOther: Bool}> = Std.is(mechanisms, Array) ? mechanisms : [{ name: mechanisms, canFast: false, canOther: true }];
				final mech = mechs.find((m) -> m.canOther)?.name;
				this.trigger("auth/password-needed", { mechanisms: mechs });
				return waitForCreds.then((creds) -> {
					return callback(creds, creds.mechanism ?? mech);
				});
			}
		});
		new XmppJsScramSha1(xmpp.sasl2);
		xmpp.streamFrom = this.jid;

		xmpp.streamFeatures.use("csi", "urn:xmpp:csi:0", (ctx, next, feature) -> {
			csi = true;
			return next();
		});

		if(this.debug) {
			new XmppJsDebug(xmpp, true);
		}

		if (initialSM != null) {
			final parsedSM = haxe.Json.parse(Bytes.ofData(initialSM).toString());
			final parsedPending: Null<Array<String>> = parsedSM.pending;
			if (parsedPending != null) {
				for (item in parsedPending) {
					pending.push(XmppJsLtx.parse(item));
				}
			}
			xmpp.streamManagement.id = parsedSM.id;
			xmpp.streamManagement.outbound = parsedSM.outbound;
			xmpp.streamManagement.inbound = parsedSM.inbound;
			xmpp.streamManagement.outbound_q = (parsedSM.outbound_q ?? []).map(XmppJsLtx.parse);
			initialSM = null;
		}

		this.client = xmpp;
		processPendingOnIq();

		xmpp.on("online", function (jid) {
			resumed = false;
			this.jid = jid;
			this.state.event("connection-success");
		});

		xmpp.on("offline", function (data) {
			this.state.event("connection-closed");
		});

		xmpp.middleware.use(function (data) {
			everConnected = true;
			if (data.stanza.attrs.xmlns == "urn:xmpp:sm:3") return;
			if (xmpp.status == "online" && this.state.can("connection-success")) {
				resumed = xmpp.streamManagement.enabled && xmpp.streamManagement.id != null && xmpp.streamManagement.id != "";
				if (xmpp.jid == null) {
					xmpp.jid = this.jid;
				} else {
					this.jid = xmpp.jid;
				}
				this.state.event("connection-success");
			}
		});

		xmpp.on("stanza", function (stanza) {
			this.onStanza(convertToStanza(stanza));
			triggerSMupdate();
		});

		xmpp.on("stream-management/ack", (stanza) -> {
			if (stanza.name == "message" && stanza.attrs.id != null) this.trigger("sm/ack", { id: stanza.attrs.id });
			triggerSMupdate();
		});

		xmpp.on("stream-management/fail", (stanza) -> {
			if (stanza.name == "message" && stanza.attrs.id != null) this.trigger("sm/fail", { id: stanza.attrs.id });
			triggerSMupdate();
		});

		xmpp.on("fast-token", (tokenEl) -> {
			this.trigger("fast-token", tokenEl.attrs);
		});

		xmpp.on("status", (status) -> {
			if (status == "disconnect") {
				if (this.state.can("connection-closed")) this.state.event("connection-closed");
			} else if(status == "connecting") {
				if (this.state.can("connect-requested")) this.state.event("connect-requested");
			}
		});

		resumed = false;
		xmpp.start().catchError(function (err) {
			if (this.state.can("connection-error")) this.state.event("connection-error");
			final xmppError = Std.downcast(err, XmppJsError);
			if (xmppError?.name == "SASLError") {
				this.trigger("auth/fail", xmppError);
			} else {
				trace(err);
			}
		});
	}

	public function connect(jid:String, sm:Null<BytesData>) {
		this.state.event("connect-requested");
		this.jid = new XmppJsJID(jid);
		this.initialSM = sm;

		resolveConnectionURI(this.jid.domain, this.connectWithURI);
	}

	public function disconnect() {
		if (client == null) return;
		client.stop();
	}

	private function convertFromStanza(el:Stanza):XmppJsXml {
		var xml = new XmppJsXml(el.name, el.attr);
		if(el.children.length > 0) {
			for(child in el.children) {
				switch(child) {
					case Element(stanza): xml.append(convertFromStanza(stanza));
					case CData(text): xml.append(text.content);
				};
			}
		}
		return xml;
	}

	private static function convertToStanza(el:XmppJsXml):Stanza {
		var stanza = new Stanza(el.name, el.attrs);
		for (child in el.children) {
			if(XmppJsLtx.isText(child)) {
				stanza.text(cast(child, String));
			} else {
				stanza.addChild(convertToStanza(child));
			}
		}
		return stanza;
	}

	public static function parse(input:String):Stanza {
		return convertToStanza(XmppJsLtx.parse(input));
	}

	public function sendStanza(stanza:Stanza) {
		if (client == null || client.status != "online") {
			pending.push(convertFromStanza(stanza));
		} else {
			client.send(convertFromStanza(stanza));
		}
		triggerSMupdate();
	}

	public function newId():String {
		return XmppJsId.id();
	}

	private function triggerSMupdate() {
		if (!client.streamManagement.enabled || !client.streamManagement.allowResume) return;
		this.trigger(
			"sm/update",
			{
				sm: Bytes.ofString(haxe.Json.stringify({
					id: client.streamManagement.id,
					outbound: client.streamManagement.outbound,
					inbound: client.streamManagement.inbound,
					outbound_q: (client.streamManagement.outbound_q ?? []).map((stanza) -> stanza.toString()),
					pending: pending.map((stanza) -> stanza.toString())
				})).getData()
			}
		);
	}

	private function fromIqResult(result: IqResult): Any {
		switch (result) {
		case IqResultElement(el): return convertFromStanza(el);
		case IqResult: return true;
		case IqNoResult: return false;
		}
	}

	public function onIq(type:IqRequestType, tag:String, xmlns:String, handler:(Stanza)->IqResult) {
		if (client == null) {
			pendingOnIq.push({ type: type, tag: tag, xmlns: xmlns, handler: handler });
		} else {
			switch (type) {
			case Get:
				client.iqCallee.get(xmlns, tag, (el) -> fromIqResult(handler(convertToStanza(el.stanza))));
			case Set:
				client.iqCallee.set(xmlns, tag, (el) -> fromIqResult(handler(convertToStanza(el.stanza))));
			}
		}
	}

	private function processPendingOnIq() {
		var item;
		while ((item = pendingOnIq.shift()) != null) {
			onIq(item.type, item.tag, item.xmlns, item.handler);
		}
	}

	/* State handlers */

	private function onOnline(event) {
		var item;
		while ((item = pending.shift()) != null) {
			client.send(item);
		}
		triggerSMupdate();
		trigger("status/online", { jid: jid.toString(), resumed: resumed });
	}

	private function onOffline(event) {
		trigger("status/offline", {});
	}

	private function onError(event) {
		if (!everConnected) trigger("status/error", {});
		// If everConnected then we are retrying so not fatal
		return true;
	}
}
