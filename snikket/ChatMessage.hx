package snikket;

import haxe.crypto.Base64;
import haxe.io.Bytes;
import haxe.io.BytesData;
import haxe.Exception;
using Lambda;

#if cpp
import HaxeCBridge;
#end

import snikket.JID;
import snikket.Identicon;
import snikket.StringUtil;
import snikket.XEP0393;
import snikket.EmojiUtil;
import snikket.Message;

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
	@HaxeCBridge.noemit
	public final hashes: Array<{algo:String, hash:BytesData}>;

	#if cpp
	@:allow(snikket)
	private
	#else
	public
	#end
	function new(name: Null<String>, mime: String, size: Null<Int>, uris: Array<String>, hashes: Array<{algo:String, hash:BytesData}>) {
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
	@:allow(snikket)
	private var syncPoint : Bool = false;

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
	public var reactions: Map<String, Array<String>> = [];

	/**
		Body text of this message or NULL
	**/
	public var text: Null<String> = null;
	/**
		Language code for the body text
	**/
	public var lang: Null<String> = null;

	/**
		Is this a Group Chat message?

		If the message is in the context of a Channel but this is false,
		then it is a private message
	**/
	public var isGroupchat: Bool = false; // Only really useful for distinguishing whispers
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
	@:allow(snikket)
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
			?.allTags("hash", "urn:xmpp:hashes:2") ?? []).map((hash) -> { algo: hash.attr.get("algo") ?? "", hash: Base64.decode(hash.getText()).getData() });
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
		m.isGroupchat = isGroupchat;
		m.threadId = threadId ?? ID.long();
		m.replyToMessage = this;
		return m;
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

	/**
		Get HTML version of the message body
	**/
	public function html():String {
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

	@:allow(snikket)
	private function asStanza():Stanza {
		var body = text;
		var attrs: haxe.DynamicAccess<String> = { type: isGroupchat ? "groupchat" : "chat" };
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
			if (body == null) body = "";
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
			final replyId = replyToM.isGroupchat ? replyToM.serverId : replyToM.localId;
			if (replyId != null) {
				final codepoints = StringUtil.codepointArray(quoteText);
				if (reaction != null) {
					final addedReactions: Map<String, Bool> = [];
					stanza.tag("reactions", { xmlns: "urn:xmpp:reactions:0", id: replyId });
					stanza.textTag("reaction", reaction);
					addedReactions[reaction] = true;

					for (areaction => senders in replyToM.reactions) {
						if (!(addedReactions[areaction] ?? false) && senders.contains(senderId())) {
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
				stanza.tag("reply", { xmlns: "urn:xmpp:reply:0", to: replyToM.from?.asString(), id: replyId }).up();
			}
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
