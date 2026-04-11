package borogove;

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

import borogove.Hash;
import borogove.JID;
import borogove.Identicon;
import borogove.StringUtil;
import borogove.EmojiUtil;
import borogove.Message;
import borogove.Stanza;
import borogove.Util;
import borogove.ChatMessage;

@:expose
@:nullSafety(StrictThreaded)
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class ChatMessageBuilder {
	/**
		The ID as set by the creator of this message
	**/
	public var localId: Null<String> = null;

	/**
		The ID as set by the authoritative server
	**/
	public var serverId: Null<String> = null;

	/**
		The ID of the server which set the serverId
	**/
	public var serverIdBy: Null<String> = null;

	@:allow(borogove)
	private var sortId: Null<String> = null;

	/**
		The type of this message (Chat, Call, etc)
	**/
	public var type: MessageType = MessageChat;

	@:allow(borogove)
	private var syncPoint: Bool = false;

	@:allow(borogove)
	private var replyId: Null<String> = null;

	/**
		The timestamp of this message, in format YYYY-MM-DDThh:mm:ss[.sss]+00:00
	**/
	public var timestamp: Null<String> = null;

	@:allow(borogove)
	private var to: Null<JID> = null;
	@:allow(borogove)
	private var from: Null<JID> = null;
	@:allow(borogove)
	private var sender: Null<JID> = null; // DEPRECATED
	@:allow(borogove)
	private var recipients: Array<JID> = [];
	@:allow(borogove)
	private var replyTo: Array<JID> = [];

	/**
		The ID of the message sender
	**/
	public var senderId (get, default): Null<String> = null;

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
	@:allow(borogove.Message)
	private var text: Null<String> = null;

	/**
		Language code for the body
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
		Human readable text to go with the status
	**/
	public var statusText: Null<String> = null;

	/**
		Array of past versions of this message, if it has been edited
	**/
	public var versions: Array<ChatMessage> = [];

	@:allow(borogove)
	private var payloads: Array<Stanza> = [];

	/**
		Information about the encryption used by the sender of
		this message.
	**/
	public var encryption: Null<EncryptionInfo>;

	/**
		Metadata about links associated with this message
	**/
	public var linkMetadata: Array<LinkMetadata> = [];

	/**
		WARNING: if you set this, you promise all the attributes of this builder match it
	**/
	@:allow(borogove)
	private var stanza: Null<Stanza> = null;

	#if cpp
	/**
		Create a new message builder

		@returns a new blank ChatMessageBuilder
	**/
	public function new() { }
	#else
	/**
		Create a new message builder from a parameter object

		@param params initial values for the message builder
		@returns a new ChatMessageBuilder
	**/
	public function new(?params: {
		?localId: Null<String>,
		?serverId: Null<String>,
		?serverIdBy: Null<String>,
		?type: MessageType,
		?syncPoint: Bool,
		?replyId: Null<String>,
		?timestamp: String,
		?senderId: String,
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
		?html: Null<Html>,
	}) {
		this.localId = params?.localId;
		this.serverId = params?.serverId;
		this.serverIdBy = params?.serverIdBy;
		this.type = params?.type ?? MessageChat;
		this.syncPoint = params?.syncPoint ?? false;
		this.replyId = params?.replyId;
		this.timestamp = params?.timestamp;
		this.senderId = params?.senderId;
		this.replyToMessage = params?.replyToMessage;
		this.threadId = params?.threadId;
		this.attachments = params?.attachments ?? [];
		this.reactions = params?.reactions ?? ([] : Map<String, Array<Reaction>>);
		this.lang = params?.lang;
		this.direction = params?.direction ?? MessageSent;
		this.status = params?.status ?? MessagePending;
		this.versions = params?.versions ?? [];
		this.payloads = params?.payloads ?? [];
		this.encryption = params?.encryption;
		final text = params?.text;
		if (text != null) setBody(Html.text(text));
		final html = params?.html;
		if (html != null) setBody(html);
	}
	#end

	@:allow(borogove)
	private static function makeModerated(m: ChatMessage, timestamp: String, moderatorId: Null<String>, reason: Null<String>) {
		final builder = new ChatMessageBuilder();
		builder.localId = m.localId;
		builder.serverId = m.serverId;
		builder.serverIdBy = m.serverIdBy;
		builder.sortId = m.sortId;
		builder.type = m.type;
		builder.syncPoint = m.syncPoint;
		builder.replyId = m.replyId;
		builder.timestamp = m.timestamp;
		builder.to = m.to;
		builder.from = m.from;
		builder.senderId = m.senderId;
		builder.recipients = m.recipients.array();
		builder.replyTo = m.replyTo.array();
		builder.replyToMessage = m.replyToMessage;
		builder.threadId = m.threadId;
		builder.reactions = m.reactions;
		builder.direction = m.direction;
		builder.status = m.status;
		final cleanedStub = builder.build();
		final payload = new Stanza("retracted", { xmlns: "urn:xmpp:message-retract:1", stamp: timestamp });
		if (reason != null) payload.textTag("reason", reason);
		payload.tag("moderated", { by: moderatorId, xmlns: "urn:xmpp:message-moderate:1" }).up();
		builder.payloads.push(payload);
		builder.timestamp = timestamp;
		builder.versions = [builder.build(), cleanedStub];
		builder.timestamp = m.timestamp;
		return builder.build();
	}

	@:allow(borogove)
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

	/**
		Add an attachment to this message

		@param attachment The ChatAttachment to add
	**/
	public function addAttachment(attachment: ChatAttachment) {
		attachments.push(attachment);
	}

	/**
		Set body from Html

		@param html rich text body to attach to the message
	**/
	public function setBody(html: Null<Html>) {
		final htmlIdx = payloads.findIndex((p) -> p.attr.get("xmlns") == "http://jabber.org/protocol/xhtml-im" && p.name == "html");
		if (htmlIdx >= 0) payloads.splice(htmlIdx, 1);

		final unstyledIdx = payloads.findIndex((p) -> p.attr.get("xmlns") == "urn:xmpp:styling:0" && p.name == "unstyled");
		if (unstyledIdx >= 0) payloads.splice(unstyledIdx, 1);

		if (html == null) {
			text = null;
		} else {
			if (html.isPlainText()) {
				payloads.push(new Stanza("unstyled", { xmlns: "urn:xmpp:styling:0" }));
			} else {
				final htmlEl = new Stanza("html", { xmlns: "http://jabber.org/protocol/xhtml-im" });
				final body = new Stanza("body", { xmlns: "http://www.w3.org/1999/xhtml" });
				htmlEl.addChild(body);
				body.addChildNodes(html.xml);
				payloads.push(htmlEl);
			}
			text = html.toPlainText();
		}
	}

	/**
		The ID of the Chat this message is associated with

		@returns Chat ID for this message
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

		@returns sender ID for this message
	**/
	public function get_senderId():String {
		return senderId ?? sender?.asString() ?? throw "sender is null";
	}

	@:allow(borogove)
	private function isIncoming():Bool {
		return direction == MessageReceived;
	}

	/**
		Build this builder into an immutable ChatMessage

		@returns the ChatMessage
	**/
	public function build() {
		if (serverId == null && localId == null) throw "Cannot build a ChatMessage with no id";
		final to = this.to;
		if (to == null) throw "Cannot build a ChatMessage with no to";
		final from = this.from;
		if (from == null) throw "Cannot build a ChatMessage with no from";
		final sender = this.sender ?? from.asBare();
		return new ChatMessage({
			localId: localId,
			serverId: serverId,
			serverIdBy: serverIdBy,
			sortId: sortId,
			type: type,
			syncPoint: syncPoint,
			replyId: replyId,
			timestamp: timestamp ?? Date.format(std.Date.now()),
			to: to,
			from: from,
			senderId: senderId,
			recipients: recipients,
			replyTo: replyTo,
			replyToMessage: replyToMessage,
			threadId: threadId,
			attachments: attachments,
			reactions: reactions,
			text: text,
			lang: lang,
			direction: direction,
			status: status,
			statusText: statusText,
			versions: versions,
			payloads: payloads,
			encryption: encryption,
			linkMetadata: linkMetadata,
			stanza: stanza,
		});
	}
}
