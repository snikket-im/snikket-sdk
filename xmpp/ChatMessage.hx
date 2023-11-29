package xmpp;

import haxe.crypto.Base64;
import haxe.io.Bytes;
import haxe.io.BytesData;
import haxe.Exception;
using Lambda;

import xmpp.JID;
import xmpp.Identicon;
import xmpp.StringUtil;
import xmpp.XEP0393;

enum MessageDirection {
	MessageReceived;
	MessageSent;
}

enum MessageStatus {
	MessagePending; // Message is waiting in client for sending
	MessageDeliveredToServer; // Server acknowledged receipt of the message
	MessageDeliveredToDevice; //The message has been delivered to at least one client device
	MessageFailedToSend; // There was an error sending this message
}

class ChatAttachment {
	public final name: Null<String>;
	public final mime: String;
	public final size: Null<Int>;
	public final uris: Array<String>;
	public final hashes: Array<{algo:String, hash:BytesData}>;

	public function new(name: Null<String>, mime: String, size: Null<Int>, uris: Array<String>, hashes: Array<{algo:String, hash:BytesData}>) {
		this.name = name;
		this.mime = mime;
		this.size = size;
		this.uris = uris;
		this.hashes = hashes;
	}
}

@:expose
@:nullSafety(Strict)
class ChatMessage {
	public var localId (default, set) : Null<String> = null;
	public var serverId (default, set) : Null<String> = null;
	public var serverIdBy : Null<String> = null;
	public var syncPoint : Bool = false;

	public var timestamp (default, set) : Null<String> = null;

	public var to: Null<JID> = null;
	public var from: Null<JID> = null;
	public var sender: Null<JID> = null;
	public var recipients: Array<JID> = [];
	public var replyTo: Array<JID> = [];

	public var threadId (default, null): Null<String> = null;

	public var attachments : Array<ChatAttachment> = [];

	public var text (default, null): Null<String> = null;
	public var lang (default, null): Null<String> = null;

	public var direction: MessageDirection = MessageReceived;
	public var status: MessageStatus = MessagePending;
	public var versions: Array<ChatMessage> = [];
	public var payloads: Array<Stanza> = [];

	public function new() { }

	public static function fromStanza(stanza:Stanza, localJid:JID):Null<ChatMessage> {
		if (stanza.attr.get("type") == "error") return null;

		var msg = new ChatMessage();
		msg.timestamp = stanza.findText("{urn:xmpp:delay}delay@stamp") ?? Date.format(std.Date.now());
		msg.threadId = stanza.getChildText("thread");
		msg.lang = stanza.attr.get("xml:lang");
		msg.text = stanza.getChildText("body");
		if (msg.text != null && (msg.lang == null || msg.lang == "")) {
			msg.lang = stanza.getChild("body")?.attr.get("xml:lang");
		}
		final from = stanza.attr.get("from");
		msg.from = from == null ? null : JID.parse(from);
		msg.sender = stanza.attr.get("type") == "groupchat" ? msg.from : msg.from?.asBare();
		final localJidBare = localJid.asBare();
		final domain = localJid.domain;
		final to = stanza.attr.get("to");
		msg.to = to == null ? localJid : JID.parse(to);

		if (msg.from != null && msg.from.equals(localJidBare)) {
			var carbon = stanza.getChild("received", "urn:xmpp:carbons:2");
			if (carbon == null) carbon = stanza.getChild("sent", "urn:xmpp:carbons:2");
			if (carbon != null) {
				var fwd = carbon.getChild("forwarded", "urn:xmpp:forward:0");
				if(fwd != null) return fromStanza(fwd.getFirstChild(), localJid);
			}
		}

		final localId = stanza.attr.get("id");
		if (localId != null) msg.localId = localId;
		var altServerId = null;
		for (stanzaId in stanza.allTags("stanza-id", "urn:xmpp:sid:0")) {
			final id = stanzaId.attr.get("id");
			if ((stanzaId.attr.get("by") == domain || stanzaId.attr.get("by") == localJidBare.asString()) && id != null) {
				msg.serverIdBy = localJidBare.asString();
				msg.serverId = id;
				break;
			}
			altServerId = stanzaId;
		}
		if (msg.serverId == null && altServerId != null && stanza.attr.get("type") != "error") {
			final id = altServerId.attr.get("id");
			if (id != null) {
				msg.serverId = id;
				msg.serverIdBy = altServerId.attr.get("by");
			}
		}
		msg.direction = (msg.to == null || msg.to.asBare().equals(localJidBare)) ? MessageReceived : MessageSent;
		if (msg.from != null && msg.from.asBare().equals(localJidBare)) msg.direction = MessageSent;
		msg.status = msg.direction == MessageReceived ? MessageDeliveredToDevice : MessageDeliveredToServer; // Delivered to us, a device

		final recipients: Map<String, Bool> = [];
		final replyTo: Map<String, Bool> = [];
		if (msg.to != null) {
			recipients[msg.to.asBare().asString()] = true;
		}
		if (msg.direction == MessageReceived && msg.from != null) {
			replyTo[stanza.attr.get("type") == "groupchat" ? msg.from.asBare().asString() : msg.from.asString()] = true;
		} else if(msg.to != null) {
			replyTo[msg.to.asString()] = true;
		}

		final addresses = stanza.getChild("addresses", "http://jabber.org/protocol/address");
		var anyExtendedReplyTo = false;
		if (addresses != null) {
			for (address in addresses.allTags("address")) {
				final jid = address.attr.get("jid");
				if (address.attr.get("type") == "noreply") {
					replyTo.clear();
				} else if (jid == null) {
					trace("No support for addressing to non-jid", address);
					return null;
				} else if (address.attr.get("type") == "to" || address.attr.get("type") == "cc") {
					recipients[JID.parse(jid).asBare().asString()] = true;
					if (!anyExtendedReplyTo) replyTo[JID.parse(jid).asString()] = true; // reply all
				} else if (address.attr.get("type") == "replyto" || address.attr.get("type") == "replyroom") {
					if (!anyExtendedReplyTo) {
						replyTo.clear();
						anyExtendedReplyTo = true;
					}
					replyTo[JID.parse(jid).asString()] = true;
				} else if (address.attr.get("type") == "ofrom") {
					if (JID.parse(jid).domain == msg.sender?.domain) {
						// TODO: check that domain supports extended addressing
						msg.sender = JID.parse(jid).asBare();
					}
				}
			}
		}

		msg.recipients = ({ iterator: () -> recipients.keys() }).map((s) -> JID.parse(s));
		msg.recipients.sort((x, y) -> Reflect.compare(x.asString(), y.asString()));
		msg.replyTo = ({ iterator: () -> replyTo.keys() }).map((s) -> JID.parse(s));
		msg.replyTo.sort((x, y) -> Reflect.compare(x.asString(), y.asString()));

		final msgFrom = msg.from;
		if (msg.direction == MessageReceived && msgFrom != null && msg.replyTo.find((r) -> r.asBare().equals(msgFrom.asBare())) == null) {
			trace("Don't know what chat message without from in replyTo belongs in", stanza);
			return null;
		}

		for (ref in stanza.allTags("reference", "urn:xmpp:reference:0")) {
			if (ref.attr.get("begin") == null && ref.attr.get("end") == null) {
				final sims = ref.getChild("media-sharing", "urn:xmpp:sims:1");
				if (sims != null) msg.attachSims(sims);
			}
		}

		for (sims in stanza.allTags("media-sharing", "urn:xmpp:sims:1")) {
			msg.attachSims(sims);
		}

		if (msg.text == null && msg.attachments.length < 1) return null;

		for (fallback in stanza.allTags("fallback", "urn:xmpp:fallback:0")) {
			msg.payloads.push(fallback);
		}

		final unstyled = stanza.getChild("unstyled", "urn:xmpp:styling:0");
		if (unstyled != null) {
			msg.payloads.push(unstyled);
		}

		return msg;
	}

	public function attachSims(sims: Stanza) {
		var mime = sims.findText("{urn:xmpp:jingle:apps:file-transfer:5}/media-type#");
		if (mime == null) mime = sims.findText("{urn:xmpp:jingle:apps:file-transfer:3}/media-type#");
		if (mime == null) mime = "application/octet-stream";
		var name = sims.findText("{urn:xmpp:jingle:apps:file-transfer:5}/name#");
		if (name == null) name = sims.findText("{urn:xmpp:jingle:apps:file-transfer:3}/name#");
		var size = sims.findText("{urn:xmpp:jingle:apps:file-transfer:5}/size#");
		if (size == null) size = sims.findText("{urn:xmpp:jingle:apps:file-transfer:3}/size#");
		final hashes = ((sims.getChild("file", "urn:xmpp:jingle:apps:file-transfer:5") ?? sims.getChild("file", "urn:xmpp:jingle:apps:file-transfer:3"))
			?.allTags("hash", "urn:xmpp:hashes:2") ?? []).map((hash) -> { algo: hash.attr.get("algo") ?? "", hash: Base64.decode(hash.getText()).getData() });
		final sources = sims.getChild("sources");
		final uris = (sources?.allTags("reference", "urn:xmpp:reference:0") ?? []).map((ref) -> ref.attr.get("uri") ?? "").filter((uri) -> uri != "");
		if (uris.length > 0) attachments.push(new ChatAttachment(name, mime, size == null ? null : Std.parseInt(size), uris, hashes));
	}

	public function set_localId(localId:String):String {
		if(this.localId != null) {
			throw new Exception("Message already has a localId set");
		}
		return this.localId = localId;
	}

	public function set_serverId(serverId:String):String {
		if(this.serverId != null && this.serverId != serverId) {
			throw new Exception("Message already has a serverId set");
		}
		return this.serverId = serverId;
	}

	public function set_timestamp(timestamp:String):String {
		return this.timestamp = timestamp;
	}

	public function html():String {
		var body = text ?? "";
		// TODO: not every app will implement every feature. How should the app tell us what fallbacks to handle?
		final fallback = payloads.find((p) -> p.attr.get("xmlns") == "urn:xmpp:fallback:0" && (p.attr.get("for") == "jabber:x:oob" || p.attr.get("for") == "urn:xmpp:sims:1"));
		if (fallback != null) {
			final bodyFallback = fallback.getChild("body");
			if (bodyFallback != null) {
				final codepoints = StringUtil.codepointArray(body);
				final start = Std.parseInt(bodyFallback.attr.get("start") ?? "0") ?? 0;
				final end = Std.parseInt(bodyFallback.attr.get("end") ?? Std.string(codepoints.length)) ?? codepoints.length;
				codepoints.splice(start, (end - start));
				body = codepoints.join("");
			}
		}
		return payloads.find((p) -> p.attr.get("xmlns") == "urn:xmpp:styling:0" && p.name == "unstyled") == null ? XEP0393.parse(body).map((s) -> s.toString()).join("") : StringTools.htmlEscape(body);
	}

	public function chatId():String {
		if (isIncoming()) {
			return replyTo.map((r) -> r.asBare().asString()).join("\n");
		} else {
			return recipients.map((r) -> r.asString()).join("\n");
		}
	}

	public function senderId():String {
		return sender?.asString() ?? throw "sender is null";
	}

	public function account():String {
		return (!isIncoming() ? from?.asBare()?.asString() : to?.asBare()?.asString()) ?? throw "from or to is null";
	}

	public function isIncoming():Bool {
		return direction == MessageReceived;
	}

	public function threadIcon() {
		return threadId == null ? null : Identicon.svg(threadId);
	}

	public function asStanza(?type: String):Stanza {
		var body = text;
		var attrs: haxe.DynamicAccess<String> = { type: type ?? "chat" };
		if (from != null) attrs.set("from", from.asString());
		if (to != null) attrs.set("to", to.asString());
		if (localId != null) attrs.set("id", localId);
		var stanza = new Stanza("message", attrs);
		if (threadId != null) stanza.textTag("thread", threadId);
		if (recipients.length > 1) {
			final addresses = stanza.tag("addresses", { xmlns: "http://jabber.org/protocol/address" });
			for (recipient in recipients) {
				addresses.tag("address", { type: "to", jid: recipient.asString(), delivered: "true" }).up();
			}
			addresses.up();
		}
		for (attachment in attachments) {
			stanza
				.tag("reference", { xmlns: "urn:xmpp:reference:0", type: "data" })
				.tag("media-sharing", { xmlns: "urn:xmpp:sims:1" });

			stanza.tag("file", { xmlns: "urn:xmpp:jingle:apps:file-transfer:5" });
			if (attachment.name != null) stanza.textTag("name", attachment.name);
			stanza.textTag("media-type", attachment.mime);
			if (attachment.size != null) stanza.textTag("size", Std.string(attachment.size));
			for (hash in attachment.hashes) {
				stanza.textTag("hash", Base64.encode(Bytes.ofData(hash.hash)), { xmlns: "urn:xmpp:hashes:2", algo: hash.algo });
			}
			stanza.up();

			stanza.tag("sources");
			for (uri in attachment.uris) {
				stanza.tag("reference", { xmlns: "urn:xmpp:reference:0", type: "data", uri: uri }).up();
			}

			stanza.up().up().up();

			if (attachment.uris.length > 0) {
				stanza.tag("x", { xmlns: "jabber:x:oob" }).textTag("url", attachment.uris[0]).up();
				if (body == null) body = "";
				final codepoints = StringUtil.codepointArray(body);
				final start = codepoints.length;
				var end = start + attachment.uris[0].length; // Raw length is safe because uri should be ascii
				if (body != "") {
					body += "\n";
					end++;
				}
				body += attachment.uris[0];
				stanza
					.tag("fallback", { xmlns: "urn:xmpp:fallback:0", "for": "jabber:x:oob" })
					.tag("body", { start: Std.string(start), end: Std.string(end) }).up().up();
			}
		}
		if (body != null) stanza.textTag("body", body);
		return stanza;
	}
}
