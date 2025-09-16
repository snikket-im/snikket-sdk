package snikket;

import haxe.io.BytesData;
import snikket.Chat;
import snikket.ChatMessage;
import snikket.Message;
import thenshim.Promise;

#if cpp
@:build(HaxeSwiftBridge.expose())
#end
interface Persistence {
	public function lastId(accountId: String, chatId: Null<String>): Promise<Null<String>>;
	public function storeChats(accountId: String, chats: Array<Chat>):Void;
	public function getChats(accountId: String): Promise<Array<SerializedChat>>;
	@HaxeCBridge.noemit
	public function getChatsUnreadDetails(accountId: String, chats: Array<Chat>): Promise<Array<{ chatId: String, message: ChatMessage, unreadCount: Int }>>;
	public function storeReaction(accountId: String, update: ReactionUpdate): Promise<Null<ChatMessage>>;
	public function storeMessages(accountId: String, message: Array<ChatMessage>): Promise<Array<ChatMessage>>;
	public function updateMessage(accountId: String, message: ChatMessage):Void;
	public function updateMessageStatus(accountId: String, localId: String, status:MessageStatus): Promise<ChatMessage>;
	public function getMessage(accountId: String, chatId: String, serverId: Null<String>, localId: Null<String>): Promise<Null<ChatMessage>>;
	public function getMessagesBefore(accountId: String, chatId: String, beforeId: Null<String>, beforeTime: Null<String>): Promise<Array<ChatMessage>>;
	public function getMessagesAfter(accountId: String, chatId: String, afterId: Null<String>, afterTime: Null<String>): Promise<Array<ChatMessage>>;
	public function getMessagesAround(accountId: String, chatId: String, aroundId: Null<String>, aroundTime: Null<String>): Promise<Array<ChatMessage>>;
	public function hasMedia(hashAlgorithm:String, hash:BytesData): Promise<Bool>;
	public function storeMedia(mime:String, bytes:BytesData): Promise<Bool>;
	public function removeMedia(hashAlgorithm:String, hash:BytesData):Void;
	public function storeCaps(caps:Caps):Void;
	public function getCaps(ver:String): Promise<Null<Caps>>;
	public function storeLogin(login:String, clientId:String, displayName:String, token:Null<String>):Void;
	public function getLogin(login:String): Promise<{ clientId:Null<String>, token:Null<String>, fastCount: Int, displayName:Null<String> }>;
	public function removeAccount(accountId: String, completely:Bool):Void;
	public function listAccounts(): Promise<Array<String>>;
	public function storeStreamManagement(accountId:String, data:Null<BytesData>):Void;
	public function getStreamManagement(accountId:String): Promise<Null<BytesData>>;
	public function storeService(accountId:String, serviceId:String, name:Null<String>, node:Null<String>, caps:Caps):Void;
	@HaxeCBridge.noemit
	public function findServicesWithFeature(accountId:String, feature:String): Promise<Array<{serviceId:String, name:Null<String>, node:Null<String>, caps: Caps}>>;
}
