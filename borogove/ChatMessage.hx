package borogove;

import datetime.DateTime;
import haxe.Exception;
import haxe.crypto.Base64;
import haxe.ds.ReadOnlyArray;
import haxe.io.Bytes;
import haxe.io.BytesData;
using Lambda;
using StringTools;

#if cpp
import HaxeCBridge;
#end

import borogove.Hash;
import borogove.JID;
import borogove.Identicon;
import borogove.StringUtil;
import borogove.XEP0393;
import borogove.EmojiUtil;
import borogove.Message;
import borogove.Stanza;
import borogove.Util;

@:expose
@:nullSafety(StrictThreaded)
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class ChatAttachment {
	/**
		Filename
	**/
	public final name: Null<String>;
	/**
		MIME Type
	**/
	public final mime: String;
	/**
		Size in bytes
	**/
	public final size: Null<Int>;
	/**
		URIs to data
	**/
	public final uris: ReadOnlyArray<String>;
	/**
		Hashes of data
	**/
	public final hashes: ReadOnlyArray<Hash>;

	#if cpp
	@:allow(borogove)
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

	#if cpp
	/**
		Create a new attachment for adding to a ChatMessage

		@param name Optional filename
		@param mime MIME type
		@param size Size in bytes
		@param uri URI to attachment
	**/
	public static function create(name: Null<String>, mime: String, size: Int, uri: String) {
		return new ChatAttachment(name, mime, size > 0 ? size : null, [uri], []);
	}
	#end
}

@:expose
@:nullSafety(StrictThreaded)
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class ChatMessage {
	/**
		The ID as set by the creator of this message
	**/
	public final localId: Null<String>;

	/**
		The ID as set by the authoritative server
	**/
	public final serverId: Null<String>;

	/**
		The ID of the server which set the serverId
	**/
	public final serverIdBy: Null<String>;

	/**
		The type of this message (Chat, Call, etc)
	**/
	public final type: MessageType;

	@:allow(borogove)
	private final syncPoint : Bool;

	@:allow(borogove)
	private final replyId : Null<String>;

	/**
		The timestamp of this message, in format YYYY-MM-DDThh:mm:ss[.sss]Z
	**/
	public final timestamp: String;

	@:allow(borogove)
	private final to: JID;
	@:allow(borogove)
	private final from: JID;
	@:allow(borogove)
	private final recipients: ReadOnlyArray<JID>;
	@:allow(borogove)
	private final replyTo: ReadOnlyArray<JID>;

	/**
		The ID of the sender of this message
	**/
	public final senderId: String;

	/**
		Message this one is in reply to, or NULL
	**/
	public var replyToMessage(default, null): Null<ChatMessage>;

	/**
		ID of the thread this message is in, or NULL
	**/
	public final threadId: Null<String>;

	/**
		Array of attachments to this message
	**/
	public final attachments: ReadOnlyArray<ChatAttachment>;

	/**
		Map of reactions to this message
	**/
	@HaxeCBridge.noemit
	public var reactions(default, null): Map<String, Array<Reaction>>;

	#if cpp
	/**
		List of reactions to this message
	**/
	public var reactionKeys(get, never): Array<String>;

	@HaxeCBridge.noemit
	public function get_reactionKeys() {
		return { iterator: reactions.keys }.array();
	}

	/**
		Details of a set of reaction to this message
	**/
	public function reactionDetails(reactionKey: String): Array<Reaction> {
		return reactions[reactionKey] ?? [];
	}
	#end

	/**
		Body text of this message or NULL
	**/
	public final text: Null<String>;

	/**
		Language code for the body text
	**/
	public final lang: Null<String>;

	/**
		Direction of this message
	**/
	public final direction: MessageDirection;

	/**
		Status of this message
	**/
	public var status: MessageStatus;

	/**
		Array of past versions of this message, if it has been edited
	**/
	@:allow(borogove)
	public final versions: ReadOnlyArray<ChatMessage>;

	@:allow(borogove, test)
	private final payloads: ReadOnlyArray<Stanza>;

	/**
		Information about the encryption used by the sender of
		this message.
	**/
	public var encryption: Null<EncryptionInfo>;

	@:allow(borogove)
	private final stanza: Null<Stanza>;

	@:allow(borogove)
	private function new(params: {
		?localId: Null<String>,
		?serverId: Null<String>,
		?serverIdBy: Null<String>,
		?type: MessageType,
		?syncPoint: Bool,
		?replyId: Null<String>,
		timestamp: String,
		to: JID,
		from: JID,
		senderId: String,
		?recipients: Array<JID>,
		?replyTo: Array<JID>,
		?replyToMessage: Null<ChatMessage>,
		?threadId: Null<String>,
		?attachments: Array<ChatAttachment>,
		?reactions: Map<String, Array<Reaction>>,
		?text: Null<String>,
		?lang: Null<String>,
		?direction: MessageDirection,
		?status: MessageStatus,
		?versions: Array<ChatMessage>,
		?payloads: Array<Stanza>,
		?encryption: Null<EncryptionInfo>,
		?stanza: Null<Stanza>,
	}) {
		this.localId = params.localId;
		this.serverId = params.serverId;
		this.serverIdBy = params.serverIdBy;
		this.type = params.type ?? MessageChat;
		this.syncPoint = params.syncPoint ?? false;
		this.replyId = params.replyId;
		this.timestamp = params.timestamp;
		this.to = params.to;
		this.from = params.from;
		this.senderId = params.senderId;
		this.recipients = params.recipients ?? [];
		this.replyTo = params.replyTo ?? [];
		this.replyToMessage = params.replyToMessage;
		this.threadId = params.threadId;
		this.attachments = params.attachments ?? [];
		this.reactions = params.reactions ?? ([] : Map<String, Array<Reaction>>);
		this.text = params.text;
		this.lang = params.lang;
		this.direction = params.direction ?? MessageSent;
		this.status = params.status ?? MessagePending;
		this.versions = params.versions ?? [];
		this.payloads = params.payloads ?? [];
		this.encryption = params.encryption;
		this.stanza = params.stanza;
	}

	@:allow(borogove)
	private static function fromStanza(stanza:Stanza, localJid:JID, ?addContext: (ChatMessageBuilder, Stanza)->ChatMessageBuilder):Null<ChatMessage> {
		switch Message.fromStanza(stanza, localJid, addContext).parsed {
			case ChatMessageStanza(message):
				return message;
			default:
				return null;
		}
	}

	/**
		Create a new ChatMessage in reply to this one
	**/
	public function reply() {
		final m = new ChatMessageBuilder();
		m.type = type;
		m.threadId = threadId ?? ID.long();
		m.replyToMessage = this;
		return m;
	}

	@:allow(borogove)
	private function getReplyId() {
		if (replyId != null) return replyId;
		return type == MessageChannel || type == MessageChannelPrivate ? serverId : localId;
	}

	@:allow(borogove)
	private function set_replyToMessage(m: ChatMessage) {
		final rtm = replyToMessage;
		if (rtm == null) throw "Cannot hydrate null replyToMessage";
		if (rtm.serverId != null && rtm.serverId != m.serverId) throw "Hydrate serverId mismatch";
		if (rtm.localId != null && rtm.localId != m.localId) throw "Hydrate localId mismatch";
		return replyToMessage = m;
	}

	@:allow(borogove)
	private function set_reactions(r: Map<String, Array<Reaction>>) {
		if (reactions != null && !{ iterator: () -> reactions.keys() }.empty()) throw "Reactions already hydrated";
		return reactions = r;
	}

	@:allow(borogove)
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

		@param sender optionally specify the full details of the sender
	**/
	public function html(sender: Null<Participant> = null):String {
		final htmlBody = payloads.find((p) -> p.attr.get("xmlns") == "http://jabber.org/protocol/xhtml-im" && p.name == "html")?.getChild("body", "http://www.w3.org/1999/xhtml");
		var htmlSource = "";
		var isAction = false;
		if (htmlBody != null) {
			htmlSource = htmlBody.getChildren().map(el -> el.traverse(child -> {
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
				final senderP = sender;
				if (senderP != null && child.getFirstChild() == null) {
					final txt = child.getText();
					if (txt.startsWith("/me")) {
						isAction = true;
						child.removeChildren();
						child.text(senderP.displayName + txt.substr(3));
					}
				}
				return false;
			}).serialize()).join("");
		} else {
			var bodyText = text ?? "";
			if (sender != null && bodyText.startsWith("/me")) {
				isAction = true;
				bodyText = sender.displayName + bodyText.substr(3);
			}
			final codepoints = StringUtil.codepointArray(bodyText);
			// TODO: not every app will implement every feature. How should the app tell us what fallbacks to handle?
			final fallbacks: Array<{start: Int, end: Int}> = cast payloads.filter(
				(p) -> p.attr.get("xmlns") == "urn:xmpp:fallback:0" &&
					(((p.attr.get("for") == "jabber:x:oob" || p.attr.get("for") == "urn:xmpp:sims:1") && attachments.length > 0) ||
					 (replyToMessage != null && p.attr.get("for") == "urn:xmpp:reply:0") ||
					 p.attr.get("for") == "http://jabber.org/protocol/address")
			).map((p) -> p.getChild("body")).map((b) -> b == null ? null : { start: Std.parseInt(b.attr.get("start") ?? "0") ?? 0, end: Std.parseInt(b.attr.get("end") ?? Std.string(codepoints.length)) ?? codepoints.length }).filter((b) -> b != null);
			fallbacks.sort((x, y) -> y.start - x.start);
			for (fallback in fallbacks) {
				codepoints.splice(fallback.start, (fallback.end - fallback.start));
			}
			final body = codepoints.join("");
			htmlSource = payloads.find((p) -> p.attr.get("xmlns") == "urn:xmpp:styling:0" && p.name == "unstyled") == null ? XEP0393.parse(body).map((s) -> s.toString()).join("") : StringTools.htmlEscape(body);
		}
		return isAction ? '<div class="action">${htmlSource}</div>' : htmlSource;
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
		The session id of the call if this message is related to a call
	**/
	public function callSid() {
		return payloads.find((el) -> el.attr.get("xmlns") == "urn:xmpp:jingle-message:0")?.attr?.get("id");
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

	@:allow(borogove)
	private function asStanza():Stanza {
		if (stanza != null) return stanza;

		var body = text;
		var attrs: haxe.DynamicAccess<String> = { type: type == MessageChannel ? "groupchat" : "chat" };
		if (from != null) attrs.set("from", from.asString());
		if (to != null) attrs.set("to", to.asString());
		if (localId != null) attrs.set("id", localId);
		var stanza = new Stanza("message", attrs);
		if (versions.length > 0 && versions[versions.length-1].localId != null) stanza.tag("replace", { xmlns: "urn:xmpp:message-correct:0", id: versions[versions.length-1].localId }).up();
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
							if (!(addedReactions[areaction] ?? false) && reactions.find(r -> r.senderId == senderId) != null) {
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
}
