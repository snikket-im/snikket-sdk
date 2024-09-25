package snikket;

import haxe.io.BytesData;
import snikket.Chat;
import snikket.ChatMessage;
import snikket.Message;

#if cpp
@:build(HaxeSwiftBridge.expose())
#end
interface Persistence {
	public function lastId(accountId: String, chatId: Null<String>, callback:(serverId:Null<String>)->Void):Void;
	public function storeChat(accountId: String, chat: Chat):Void;
	public function getChats(accountId: String, callback: (chats:Array<SerializedChat>)->Void):Void;
	@HaxeCBridge.noemit
	public function getChatsUnreadDetails(accountId: String, chats: Array<Chat>, callback: (details:Array<{ chatId: String, message: ChatMessage, unreadCount: Int }>)->Void):Void;
	public function storeReaction(accountId: String, update: ReactionUpdate, callback: (Null<ChatMessage>)->Void):Void;
	public function storeMessage(accountId: String, message: ChatMessage, callback: (ChatMessage)->Void):Void;
	public function updateMessageStatus(accountId: String, localId: String, status:MessageStatus, callback: (ChatMessage)->Void):Void;
	public function getMessagesBefore(accountId: String, chatId: String, beforeId: Null<String>, beforeTime: Null<String>, callback: (messages:Array<ChatMessage>)->Void):Void;
	public function getMessagesAfter(accountId: String, chatId: String, afterId: Null<String>, afterTime: Null<String>, callback: (messages:Array<ChatMessage>)->Void):Void;
	public function getMessagesAround(accountId: String, chatId: String, aroundId: Null<String>, aroundTime: Null<String>, callback: (messages:Array<ChatMessage>)->Void):Void;
	public function getMediaUri(hashAlgorithm:String, hash:BytesData, callback: (uri:Null<String>)->Void):Void;
	public function storeMedia(mime:String, bytes:BytesData, callback: ()->Void):Void;
	public function storeCaps(caps:Caps):Void;
	public function getCaps(ver:String, callback: (Null<Caps>)->Void):Void;
	public function storeLogin(login:String, clientId:String, displayName:String, token:Null<String>):Void;
	public function getLogin(login:String, callback:(clientId:Null<String>, token:Null<String>, fastCount: Int, displayName:Null<String>)->Void):Void;
	public function storeStreamManagement(accountId:String, data:BytesData):Void;
	public function getStreamManagement(accountId:String, callback: (Null<BytesData>)->Void):Void;
	public function storeService(accountId:String, serviceId:String, name:Null<String>, node:Null<String>, caps:Caps):Void;
	@HaxeCBridge.noemit
	public function findServicesWithFeature(accountId:String, feature:String, callback:(Array<{serviceId:String, name:Null<String>, node:Null<String>, caps: Caps}>)->Void):Void;
}
