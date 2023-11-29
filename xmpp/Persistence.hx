package xmpp;

import haxe.io.BytesData;
import xmpp.ChatMessage;
import xmpp.Chat;

abstract class Persistence {
	abstract public function lastId(accountId: String, chatId: Null<String>, callback:(serverId:Null<String>)->Void):Void;
	abstract public function storeChat(accountId: String, chat: Chat):Void;
	abstract public function getChats(accountId: String, callback: (chats:Array<SerializedChat>)->Void):Void;
	abstract public function getChatsUnreadDetails(accountId: String, chats: Array<Chat>, callback: (details:Array<{ chatId: String, message: ChatMessage, unreadCount: Int }>)->Void):Void;
	abstract public function storeMessage(accountId: String, message: ChatMessage):Void;
	abstract public function updateMessageStatus(accountId: String, localId: String, status:MessageStatus, callback: (ChatMessage)->Void):Void;
	abstract public function correctMessage(accountId: String, localId: String, message: ChatMessage, callback: (ChatMessage)->Void):Void;
	abstract public function getMessages(accountId: String, chatId: String, beforeId: Null<String>, beforeTime: Null<String>, callback: (messages:Array<ChatMessage>)->Void):Void;
	abstract public function getMediaUri(hashAlgorithm:String, hash:BytesData, callback: (uri:Null<String>)->Void):Void;
	abstract public function storeMedia(mime:String, bytes:BytesData, callback: ()->Void):Void;
	abstract public function storeCaps(caps:Caps):Void;
	abstract public function getCaps(ver:String, callback: (Caps)->Void):Void;
	abstract public function storeLogin(login:String, clientId:String, displayName:String, token:Null<String>):Void;
	abstract public function getLogin(login:String, callback:(clientId:String, token:Null<String>, fastCount: Int, displayName:String)->Void):Void;
	abstract public function storeStreamManagement(accountId:String, smId:String, outboundCount:Int, inboundCount:Int, outboundQueue:Array<String>):Void;
	abstract public function getStreamManagement(accountId:String, callback: (smId:String, outboundCount:Int, inboundCount:Int, outboundQueue:Array<String>)->Void):Void;
	abstract public function storeService(accountId:String, serviceId:String, name:Null<String>, node:Null<String>, caps:Caps):Void;
	abstract public function findServicesWithFeature(accountId:String, feature:String, callback:(Array<{serviceId:String, name:Null<String>, node:Null<String>, caps: Caps}>)->Void):Void;
}
