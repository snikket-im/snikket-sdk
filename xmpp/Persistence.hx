package xmpp;

import xmpp.ChatMessage;

abstract class Persistence {
	abstract public function lastId(accountId: String, chatId: Null<String>, callback:(serverId:Null<String>)->Void):Void;
	abstract public function storeMessage(accountId: String, message: ChatMessage):Void;
	abstract public function getMessages(accountId: String, chatId: String, beforeId: Null<String>, beforeTime: Null<String>, callback: (messages:Array<ChatMessage>)->Void):Void;
}
