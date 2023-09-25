package xmpp;

import haxe.io.BytesData;
import xmpp.ChatMessage;

abstract class Persistence {
	abstract public function lastId(accountId: String, chatId: Null<String>, callback:(serverId:Null<String>)->Void):Void;
	abstract public function storeMessage(accountId: String, message: ChatMessage):Void;
	abstract public function getMessages(accountId: String, chatId: String, beforeId: Null<String>, beforeTime: Null<String>, callback: (messages:Array<ChatMessage>)->Void):Void;
	abstract public function getMediaUri(hashAlgorithm:String, hash:BytesData, callback: (uri:Null<String>)->Void):Void;
	abstract public function storeMedia(mime:String, bytes:BytesData, callback: ()->Void):Void;
	abstract public function storeCaps(caps:Caps):Void;
	abstract public function getCaps(ver:String, callback: (Caps)->Void):Void;
	abstract public function storeLogin(login:String, clientId:String, token:Null<String>):Void;
	abstract public function getLogin(login:String, callback:({ ?clientId: String, ?token: String })->Void):Void;
}