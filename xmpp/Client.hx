package xmpp;

import xmpp.Chat;
import xmpp.EventEmitter;
import xmpp.Stream;
import xmpp.queries.GenericQuery;

typedef ChatList = Array<Chat>;

class Client extends xmpp.EventEmitter {
	private var stream:GenericStream;
	public var jid(default,null):String;

	public function new(jid: String) {
		super();
		this.jid = jid;
		stream = new Stream();
		stream.on("status/online", this.onConnected);
		stream.on("auth/password-needed", (data)->this.trigger("auth/password-needed", { jid: this.jid }));
	}

	public function start() {
		stream.connect(jid);
	}

	private function onConnected(data) {
		return this.trigger("status/online", {});
	}

	public function usePassword(password: String):Void {
		this.stream.trigger("auth/password", { password: password });
	}

	/* Return array of chats, sorted by last activity */
	public function getChats():ChatList {
		return [];
	}

	public function getDirectChat(chatId:String):DirectChat {
		return new DirectChat(this, this.stream, chatId);
	}

	/* Internal-ish methods */
	public function sendQuery(query:GenericQuery) {
		this.stream.sendIq(query.getQueryStanza(), query.handleResponse);
	}
}
