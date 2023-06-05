package xmpp;

import xmpp.MessageSync;
import xmpp.ChatMessage;
import xmpp.Chat;
import xmpp.GenericStream;

enum ChatType {
	ChatTypeDirect;
	ChatTypeGroup;
	ChatTypePublic;
}

abstract class Chat {
	private var client:Client;
	private var stream:GenericStream;
	public var chatId(default, null):String;
	public var type(default, null):ChatType;

	private function new(client:Client, stream:GenericStream, chatId:String, type:ChatType) {
		this.client = client;
		this.stream = stream;
		this.chatId = chatId;
	}

	abstract public function sendMessage(message:ChatMessage):Void;

	abstract public function getMessages(handler:MessageListHandler):MessageSync;

	public function isDirectChat():Bool { return type.match(ChatTypeDirect); };
	public function isGroupChat():Bool  { return type.match(ChatTypeGroup);  };
	public function isPublicChat():Bool { return type.match(ChatTypePublic); };
}

class DirectChat extends Chat {
	public function new(client:Client, stream:GenericStream, chatId:String) {
		super(client, stream, chatId, ChatTypeDirect);
	}

	public function getMessages(handler:MessageListHandler):MessageSync {
		var sync = new MessageSync(this.client, this.stream, this.chatId, {});
		sync.onMessages(handler);
		sync.fetchNext();
		return sync;
	}

	public function sendMessage(message:ChatMessage):Void {}
}
