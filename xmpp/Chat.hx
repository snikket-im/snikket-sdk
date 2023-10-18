package xmpp;

import haxe.io.BytesData;
import xmpp.Chat;
import xmpp.ChatMessage;
import xmpp.Color;
import xmpp.GenericStream;
import xmpp.ID;
import xmpp.MessageSync;
import xmpp.jingle.PeerConnection;
import xmpp.jingle.Session;
import xmpp.queries.MAMQuery;
using Lambda;

abstract class Chat {
	private var client:Client;
	private var stream:GenericStream;
	private var persistence:Persistence;
	private var avatarSha1:Null<BytesData> = null;
	private var caps:haxe.DynamicAccess<Null<Caps>> = {};
	private var trusted:Bool = false;
	public var chatId(default, null):String;
	public var jingleSessions: Map<String, xmpp.jingle.Session> = [];

	private function new(client:Client, stream:GenericStream, persistence:Persistence, chatId:String) {
		this.client = client;
		this.stream = stream;
		this.persistence = persistence;
		this.chatId = chatId;
	}

	abstract public function sendMessage(message:ChatMessage):Void;

	abstract public function getMessages(beforeId:Null<String>, beforeTime:Null<String>, handler:(Array<ChatMessage>)->Void):Void;

	abstract public function getDisplayName():String;

	abstract public function getParticipants():Array<String>;

	public function setCaps(resource:String, caps:Caps) {
		this.caps.set(resource, caps);
	}

	public function getCaps():KeyValueIterator<String, Caps> {
		return caps.keyValueIterator();
	}

	public function getResourceCaps(resource:String):Caps {
		return caps[resource];
	}

	public function setTrusted(trusted:Bool) {
		this.trusted = trusted;
	}

	public function isTrusted():Bool {
		return this.trusted;
	}

	public function canAudioCall():Bool {
		for (resource => cap in caps) {
			if (cap?.features?.contains("urn:xmpp:jingle:apps:rtp:audio") ?? false) return true;
		}

		return false;
	}

	public function canVideoCall():Bool {
		for (resource => cap in caps) {
			if (cap?.features?.contains("urn:xmpp:jingle:apps:rtp:video") ?? false) return true;
		}

		return false;
	}

	public function startCall(audio: Bool, video: Bool) {
		final session = new OutgoingProposedSession(client, JID.parse(chatId));
		jingleSessions.set(session.sid, session);
		session.propose(audio, video);
	}

	public function addMedia(streams: Array<MediaStream>) {
		if (callStatus() != "ongoing") throw "cannot add media when no call ongoing";
		jingleSessions.iterator().next().addMedia(streams);
	}

	public function acceptCall() {
		for (session in jingleSessions) {
			session.accept();
		}
	}

	public function hangup() {
		for (session in jingleSessions) {
			session.hangup();
			jingleSessions.remove(session.sid);
		}
	}

	public function callStatus() {
		for (session in jingleSessions) {
			return session.callStatus();
		}

		return "none";
	}

	public function dtmf() {
		for (session in jingleSessions) {
			final dtmf = session.dtmf();
			if (dtmf != null) return dtmf;
		}

		return null;
	}

	public function videoTracks() {
		return jingleSessions.flatMap((session) -> session.videoTracks());
	}

	public function onMessage(handler:ChatMessage->Void):Void {
		this.stream.on("message", function(event) {
			final stanza:Stanza = event.stanza;
			final from = JID.parse(stanza.attr.get("from"));
			if (from.asBare() != JID.parse(this.chatId)) return EventUnhandled;

			final chatMessage = ChatMessage.fromStanza(stanza, this.client.jid);
			if (chatMessage != null) handler(chatMessage);

			return EventUnhandled; // Allow others to get this event as well
		});
	}
}

@:expose
class DirectChat extends Chat {
	private var displayName:String;
	public function new(client:Client, stream:GenericStream, persistence:Persistence, chatId:String) {
		super(client, stream, persistence, chatId);
		this.displayName = chatId;
	}

	public function setDisplayName(fn:String) {
		this.displayName = fn;
	}

	public function getDisplayName() {
		return this.displayName;
	}

	public function getParticipants() {
		return chatId.split("\n");
	}

	public function getMessages(beforeId:Null<String>, beforeTime:Null<String>, handler:(Array<ChatMessage>)->Void):Void {
		persistence.getMessages(client.jid, chatId, beforeId, beforeTime, (messages) -> {
			if (messages.length > 0) {
				handler(messages);
			} else {
				var filter:MAMQueryParams = { with: this.chatId };
				if (beforeId != null) filter.page = { before: beforeId };
				var sync = new MessageSync(this.client, this.stream, filter);
				sync.onMessages((messages) -> {
					for (message in messages.messages) {
						persistence.storeMessage(client.jid, message);
					}
					handler(messages.messages.filter((m) -> m.chatId() == chatId));
				});
				sync.fetchNext();
			}
		});
	}

	public function sendMessage(message:ChatMessage):Void {
		client.chatActivity(this);
		message.recipients = getParticipants().map((p) -> JID.parse(p));
		for (recipient in message.recipients) {
			message.to = recipient;
			client.sendStanza(message.asStanza());
		}
	}

	public function bookmark() {
		stream.sendIq(
			new Stanza("iq", { type: "set", id: ID.short() })
				.tag("query", { xmlns: "jabber:iq:roster" })
				.tag("item", { jid: chatId })
				.up().up(),
			(response) -> {
				if (response.attr.get("type") == "error") return;
				stream.sendStanza(new Stanza("presence", { to: chatId, type: "subscribe", id: ID.short() }));
				stream.sendStanza(new Stanza("presence", { to: chatId, type: "subscribed", id: ID.short() }));
			}
		);
	}

	public function setAvatarSha1(sha1: BytesData) {
		this.avatarSha1 = sha1;
	}

	public function getPhoto(callback:(String)->Void) {
		if (avatarSha1 != null) {
			persistence.getMediaUri("sha-1", avatarSha1, (uri) -> {
				if (uri != null) {
					callback(uri);
				} else {
					callback(Color.defaultPhoto(chatId, chatId.charAt(0)));
				}
			});
		} else {
			callback(Color.defaultPhoto(chatId, chatId.charAt(0)));
		}
	}
}

@:expose
class SerializedChat {
	public final chatId:String;
	public final trusted:Bool;
	public final avatarSha1:Null<BytesData>;
	public final caps:haxe.DynamicAccess<Caps>;
	public final displayName:Null<String>;
	public final klass:String;

	public function new(chatId: String, trusted: Bool, avatarSha1: Null<BytesData>, caps: haxe.DynamicAccess<Caps>, displayName: Null<String>, klass: String) {
		this.chatId = chatId;
		this.trusted = trusted;
		this.avatarSha1 = avatarSha1;
		this.caps = caps;
		this.displayName = displayName;
		this.klass = klass;
	}

	public function toDirectChat(client: Client, stream: GenericStream, persistence: Persistence) {
		if (klass != "DirectChat") throw "Not a direct chat: " + klass;
		final chat = new DirectChat(client, stream, persistence, chatId);
		if (displayName != null) chat.setDisplayName(displayName);
		if (avatarSha1 != null) chat.setAvatarSha1(avatarSha1);
		chat.setTrusted(trusted);
		for (resource => c in caps) {
			chat.setCaps(resource, c);
		}
		return chat;
	}
}
