package snikket;

import datetime.DateTime;
import haxe.crypto.Base64;
import haxe.io.Bytes;
import haxe.io.BytesData;
import haxe.Exception;
using Lambda;
using StringTools;

#if cpp
import HaxeCBridge;
#end

import snikket.Hash;
import snikket.JID;
import snikket.Identicon;
import snikket.StringUtil;
import snikket.XEP0393;
import snikket.EmojiUtil;
import snikket.Message;
import snikket.Stanza;
import snikket.Util;

@:expose
@:nullSafety(Strict)
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class ChatAttachment {
	public final name: Null<String>;
	public final mime: String;
	public final size: Null<Int>;
	public final uris: Array<String>;
	public final hashes: Array<Hash>;

	#if cpp
	@:allow(snikket)
	private
	#else
	public
	#end
	function new(name: Null<String>, mime: String, size: Null<Int>, uris: Array<String>, hashes: Array<Hash>) {
		this.name = name;
		this.mime = mime;
		this.size = size;
		this.uris = uris;
		this.hashes = hashes;
	}
}

@:expose
@:nullSafety(Strict)
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class ChatMessage {
	/**
		The ID as set by the creator of this message
	**/
	public var localId (default, set) : Null<String> = null;
	/**
		The ID as set by the authoritative server
	**/
	public var serverId (default, set) : Null<String> = null;
	/**
		The ID of the server which set the serverId
	**/
	public var serverIdBy : Null<String> = null;
	/**
		The type of this message (Chat, Call, etc)
	**/
	public var type : MessageType = MessageChat;

	@:allow(snikket)
	private var syncPoint : Bool = false;

	@:allow(snikket)
	private var replyId : Null<String> = null;

	/**
		The timestamp of this message, in format YYYY-MM-DDThh:mm:ss[.sss]+00:00
	**/
	public var timestamp (default, set) : Null<String> = null;

	@:allow(snikket)
	private var to: Null<JID> = null;
	@:allow(snikket)
	private var from: Null<JID> = null;
	@:allow(snikket)
	private var sender: Null<JID> = null;
	@:allow(snikket)
	private var recipients: Array<JID> = [];
	@:allow(snikket)
	private var replyTo: Array<JID> = [];

	/**
		Message this one is in reply to, or NULL
	**/
	public var replyToMessage: Null<ChatMessage> = null;
	/**
		ID of the thread this message is in, or NULL
	**/
	public var threadId: Null<String> = null;

	/**
		Array of attachments to this message
	**/
	public var attachments (default, null): Array<ChatAttachment> = [];
	/**
		Map of reactions to this message
	**/
	@HaxeCBridge.noemit
	public var reactions: Map<String, Array<Reaction>> = [];

	/**
		Body text of this message or NULL
	**/
	public var text: Null<String> = null;
	/**
		Language code for the body text
	**/
	public var lang: Null<String> = null;

	/**
		Direction of this message
	**/
	public var direction: MessageDirection = MessageReceived;
	/**
		Status of this message
	**/
	public var status: MessageStatus = MessagePending;
	/**
		Array of past versions of this message, if it has been edited
	**/
	@:allow(snikket)
	public var versions (default, null): Array<ChatMessage> = [];
	@:allow(snikket, test)
	private var payloads: Array<Stanza> = [];

	/**
		@returns a new blank ChatMessage
	**/
	public function new() { }

	@:allow(snikket)
	private static function fromStanza(stanza:Stanza, localJid:JID):Null<ChatMessage> {
		switch Message.fromStanza(stanza, localJid).parsed {
			case ChatMessageStanza(message):
				return message;
			default:
				return null;
		}
	}

	@:allow(snikket)
	private function attachSims(sims: Stanza) {
		var mime = sims.findText("{urn:xmpp:jingle:apps:file-transfer:5}/media-type#");
		if (mime == null) mime = sims.findText("{urn:xmpp:jingle:apps:file-transfer:3}/media-type#");
		if (mime == null) mime = "application/octet-stream";
		var name = sims.findText("{urn:xmpp:jingle:apps:file-transfer:5}/name#");
		if (name == null) name = sims.findText("{urn:xmpp:jingle:apps:file-transfer:3}/name#");
		var size = sims.findText("{urn:xmpp:jingle:apps:file-transfer:5}/size#");
		if (size == null) size = sims.findText("{urn:xmpp:jingle:apps:file-transfer:3}/size#");
		final hashes = ((sims.getChild("file", "urn:xmpp:jingle:apps:file-transfer:5") ?? sims.getChild("file", "urn:xmpp:jingle:apps:file-transfer:3"))
			?.allTags("hash", "urn:xmpp:hashes:2") ?? []).map((hash) -> new Hash(hash.attr.get("algo") ?? "", Base64.decode(hash.getText()).getData()));
		final sources = sims.getChild("sources");
		final uris = (sources?.allTags("reference", "urn:xmpp:reference:0") ?? []).map((ref) -> ref.attr.get("uri") ?? "").filter((uri) -> uri != "");
		if (uris.length > 0) attachments.push(new ChatAttachment(name, mime, size == null ? null : Std.parseInt(size), uris, hashes));
	}

	public function addAttachment(attachment: ChatAttachment) {
		attachments.push(attachment);
	}

	/**
		Create a new ChatMessage in reply to this one
	**/
	public function reply() {
		final m = new ChatMessage();
		m.type = type;
		m.threadId = threadId ?? ID.long();
		m.replyToMessage = this;
		return m;
	}

	public function getReplyId() {
		if (replyId != null) return replyId;
		return type == MessageChannel || type == MessageChannelPrivate ? serverId : localId;
	}

	@:allow(snikket)
	private function makeModerated(timestamp: String, moderatorId: Null<String>, reason: Null<String>) {
		text = null;
		attachments = [];
		payloads = [];
		versions = [];
		final cleanedStub = clone();
		final payload = new Stanza("retracted", { xmlns: "urn:xmpp:message-retract:1", stamp: timestamp });
		if (reason != null) payload.textTag("reason", reason);
		payload.tag("moderated", { by: moderatorId, xmlns: "urn:xmpp:message-moderate:1" }).up();
		payloads.push(payload);
		final head = clone();
		head.timestamp = timestamp;
		versions = [head, cleanedStub];
	}

	private function set_localId(localId:Null<String>) {
		if(this.localId != null) {
			throw new Exception("Message already has a localId set");
		}
		return this.localId = localId;
	}

	private function set_serverId(serverId:Null<String>) {
		if(this.serverId != null && this.serverId != serverId) {
			throw new Exception("Message already has a serverId set");
		}
		return this.serverId = serverId;
	}

	private function set_timestamp(timestamp:Null<String>) {
		return this.timestamp = timestamp;
	}

	@:allow(snikket)
	private function resetLocalId() {
		Reflect.setField(this, "localId", null);
	}

	@:allow(snikket)
	private function inlineHashReferences(): Array<Hash> {
		final result = [];
		final htmlBody = payloads.find((p) -> p.attr.get("xmlns") == "http://jabber.org/protocol/xhtml-im" && p.name == "html")?.getChild("body", "http://www.w3.org/1999/xhtml");
		if (htmlBody != null) {
			htmlBody.traverse(child -> {
				if (child.name == "img") {
					final src = child.attr.get("src");
					if (src != null) {
						final hash = Hash.fromUri(src);
						if (hash != null) {
							final x:Hash = hash;
							result.push(x);
						}
					}
					return true;
				}
				return false;
			});
		}

		return result;
	}

	/**
		Get HTML version of the message body

		WARNING: this is possibly untrusted HTML. You must parse or sanitize appropriately!
	**/
	public function html():String {
		final htmlBody = payloads.find((p) -> p.attr.get("xmlns") == "http://jabber.org/protocol/xhtml-im" && p.name == "html")?.getChild("body", "http://www.w3.org/1999/xhtml");
		if (htmlBody != null) {
			return htmlBody.getChildren().map(el -> el.traverse(child -> {
				if (child.name == "img") {
					final src = child.attr.get("src");
					if (src != null) {
						final hash = Hash.fromUri(src);
						if (hash != null) {
							child.attr.set("src", hash.toUri());
						}
					}
					return true;
				}
				return false;
			}).serialize()).join("");
		}

		final codepoints = StringUtil.codepointArray(text ?? "");
		// TODO: not every app will implement every feature. How should the app tell us what fallbacks to handle?
		final fallbacks: Array<{start: Int, end: Int}> = cast payloads.filter(
			(p) -> p.attr.get("xmlns") == "urn:xmpp:fallback:0" && (p.attr.get("for") == "jabber:x:oob" || p.attr.get("for") == "urn:xmpp:sims:1" || (replyToMessage != null && p.attr.get("for") == "urn:xmpp:reply:0") || p.attr.get("for") == "http://jabber.org/protocol/address")
		).map((p) -> p.getChild("body")).map((b) -> b == null ? null : { start: Std.parseInt(b.attr.get("start") ?? "0") ?? 0, end: Std.parseInt(b.attr.get("end") ?? Std.string(codepoints.length)) ?? codepoints.length }).filter((b) -> b != null);
		fallbacks.sort((x, y) -> y.start - x.start);
		for (fallback in fallbacks) {
			codepoints.splice(fallback.start, (fallback.end - fallback.start));
		}
		final body = codepoints.join("");
		return payloads.find((p) -> p.attr.get("xmlns") == "urn:xmpp:styling:0" && p.name == "unstyled") == null ? XEP0393.parse(body).map((s) -> s.toString()).join("") : StringTools.htmlEscape(body);
	}

	/**
		Set rich text using an HTML string
		Also sets the plain text body appropriately
	**/
	public function setHtml(html: String) {
		final htmlEl = new Stanza("html", { xmlns: "http://jabber.org/protocol/xhtml-im" });
		final body = new Stanza("body", { xmlns: "http://www.w3.org/1999/xhtml" });
		htmlEl.addChild(body);
		final nodes = htmlparser.HtmlParser.run(html, true);
		for (node in nodes) {
			final el = Util.downcast(node, htmlparser.HtmlNodeElement);
			if (el != null && (el.name == "html" || el.name == "body")) {
				for (inner in el.nodes) {
					body.addDirectChild(htmlToNode(inner));
				}
			} else {
				body.addDirectChild(htmlToNode(node));
			}
		}
		final htmlIdx = payloads.findIndex((p) -> p.attr.get("xmlns") == "http://jabber.org/protocol/xhtml-im" && p.name == "html");
		if (htmlIdx >= 0) payloads.splice(htmlIdx, 1);
		payloads.push(htmlEl);
		text = XEP0393.render(body);
	}

	private function htmlToNode(node: htmlparser.HtmlNode) {
		final txt = Util.downcast(node, htmlparser.HtmlNodeText);
		if (txt != null) {
			return CData(new TextNode(txt.toText()));
		}
		final el = Util.downcast(node, htmlparser.HtmlNodeElement);
		if (el != null) {
			final s = new Stanza(el.name, {});
			for (attr in el.attributes) {
				s.attr.set(attr.name, attr.value);
			}
			for (child in el.nodes) {
				s.addDirectChild(htmlToNode(child));
			}
			return Element(s);
		}
		throw "node was neither text nor element?";
	}

	/**
		The ID of the Chat this message is associated with
	**/
	public function chatId():String {
		if (isIncoming()) {
			return replyTo.map((r) -> r.asBare().asString()).join("\n");
		} else {
			return recipients.map((r) -> r.asString()).join("\n");
		}
	}

	/**
		The ID of the sender of this message
	**/
	public function senderId():String {
		return sender?.asString() ?? throw "sender is null";
	}

	/**
		The ID of the account associated with this message
	**/
	public function account():String {
		return (!isIncoming() ? from?.asBare()?.asString() : to?.asBare()?.asString()) ?? throw "from or to is null";
	}

	/**
		Is this an incoming message?
	**/
	public function isIncoming():Bool {
		return direction == MessageReceived;
	}

	/**
		The URI of an icon for the thread associated with this message, or NULL
	**/
	public function threadIcon() {
		return threadId == null ? null : Identicon.svg(threadId);
	}

	/**
		The last status of the call if this message is related to a call
	**/
	public function callStatus() {
		return payloads.find((el) -> el.attr.get("xmlns") == "urn:xmpp:jingle-message:0")?.name;
	}

	/**
		The duration of the call if this message is related to a call
	**/
	public function callDuration(): Null<String> {
		if (versions.length < 2) return null;
		final startedStr = versions[versions.length - 1].timestamp;

		return switch (callStatus()) {
		case "finish":
			final endedStr = versions[0].timestamp;
			if (startedStr == null || endedStr == null) return null;
			final started = DateTime.fromString(startedStr);
			final ended = DateTime.fromString(endedStr);
			final duration = ended - started;
			duration.format("%I:%S");
		case "proceed":
			if (startedStr == null) return null;
			final started = DateTime.fromString(startedStr);
			final ended = DateTime.now(); // ongoing
			final duration = ended - started;
			duration.format("%I:%S");
		default:
			null;
		}
	}

	@:allow(snikket)
	private function asStanza():Stanza {
		var body = text;
		var attrs: haxe.DynamicAccess<String> = { type: type == MessageChannel ? "groupchat" : "chat" };
		if (from != null) attrs.set("from", from.asString());
		if (to != null) attrs.set("to", to.asString());
		if (localId != null) attrs.set("id", localId);
		var stanza = new Stanza("message", attrs);
		if (versions.length > 0) stanza.tag("replace", { xmlns: "urn:xmpp:message-correct:0", id: versions[versions.length-1].localId }).up();
		if (threadId != null) stanza.textTag("thread", threadId);
		if (recipients.length > 1) {
			final addresses = stanza.tag("addresses", { xmlns: "http://jabber.org/protocol/address" });
			for (recipient in recipients) {
				addresses.tag("address", { type: "to", jid: recipient.asString(), delivered: "true" }).up();
			}
			addresses.up();
		} else if (recipients.length == 1 && to == null) {
			attrs.set("to", recipients[0].asString());
		}

		final replyToM = replyToMessage;
		if (replyToM != null) {
			final replyId = replyToM.getReplyId();
			if (body != null) {
				final lines = replyToM.text?.split("\n") ?? [];
				var quoteText = "";
				for (line in lines) {
					if (!~/^(?:> ?){3,}/.match(line)) {
						if (line.charAt(0) == ">") {
							quoteText += ">" + line + "\n";
						} else {
							quoteText += "> " + line + "\n";
						}
					}
				}
				final reaction = EmojiUtil.isEmoji(StringTools.trim(body)) ? StringTools.trim(body) : null;
				body = quoteText + body;
				if (replyId != null) {
					final codepoints = StringUtil.codepointArray(quoteText);
					if (reaction != null) {
						final addedReactions: Map<String, Bool> = [];
						stanza.tag("reactions", { xmlns: "urn:xmpp:reactions:0", id: replyId });
						stanza.textTag("reaction", reaction);
						addedReactions[reaction] = true;

						for (areaction => reactions in replyToM.reactions) {
							if (!(addedReactions[areaction] ?? false) && reactions.find(r -> r.senderId == senderId()) != null) {
								addedReactions[areaction] = true;
								stanza.textTag("reaction", areaction);
							}
						}
						stanza.up();
						stanza.tag("fallback", { xmlns: "urn:xmpp:fallback:0", "for": "urn:xmpp:reactions:0" })
								.tag("body").up().up();
					}
					stanza.tag("fallback", { xmlns: "urn:xmpp:fallback:0", "for": "urn:xmpp:reply:0" })
							.tag("body", { start: "0", end: Std.string(codepoints.length) }).up().up();
				}
			}
			if (replyId != null) stanza.tag("reply", { xmlns: "urn:xmpp:reply:0", to: replyToM.from?.asString(), id: replyId }).up();
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
				stanza.textTag("hash", Base64.encode(Bytes.ofData(hash.hash)), { xmlns: "urn:xmpp:hashes:2", algo: hash.algorithm });
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
		for (payload in payloads) {
			stanza.addDirectChild(Element(payload));
		}
		return stanza;
	}

	/**
		Duplicate this ChatMessage
	**/
	public function clone() {
		final cls:Class<ChatMessage> = untyped Type.getClass(this);
		final inst = Type.createEmptyInstance(cls);
		final fields = Type.getInstanceFields(cls);
		for (field in fields) {
			final val:Dynamic = Reflect.field(this, field);
			if (!Reflect.isFunction(val)) {
				Reflect.setField(inst,field,val);
			}
		}
		return inst;
	}
}
