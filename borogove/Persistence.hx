package borogove;

import haxe.io.BytesData;
import borogove.Chat;
import borogove.ChatMessage;
import borogove.Message;
import thenshim.Promise;

#if cpp
import HaxeCBridge;
#end

#if !NO_OMEMO
import borogove.OMEMO;
using borogove.SignalProtocol;
#end

#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
interface Persistence {
	public function lastId(accountId: String, chatId: Null<String>): Promise<Null<String>>;
	public function storeChats(accountId: String, chats: Array<Chat>):Void;
	@HaxeCBridge.noemit
	public function getChats(accountId: String): Promise<Array<SerializedChat>>;
	@HaxeCBridge.noemit
	public function getChatsUnreadDetails(accountId: String, chats: Array<Chat>): Promise<Array<{ chatId: String, message: ChatMessage, unreadCount: Int }>>;
	@HaxeCBridge.noemit
	public function storeReaction(accountId: String, update: ReactionUpdate): Promise<Null<ChatMessage>>;
	public function storeMessages(accountId: String, message: Array<ChatMessage>): Promise<Array<ChatMessage>>;
	public function updateMessage(accountId: String, message: ChatMessage):Void;
	public function updateMessageStatus(accountId: String, localId: String, status:borogove.Message.MessageStatus, statusText: Null<String>): Promise<ChatMessage>;
	public function getMessage(accountId: String, chatId: String, serverId: Null<String>, localId: Null<String>): Promise<Null<ChatMessage>>;
	public function getMessagesBefore(accountId: String, chatId: String, beforeId: Null<String>, beforeTime: Null<String>): Promise<Array<ChatMessage>>;
	public function getMessagesAfter(accountId: String, chatId: String, afterId: Null<String>, afterTime: Null<String>): Promise<Array<ChatMessage>>;
	public function getMessagesAround(accountId: String, chatId: String, aroundId: Null<String>, aroundTime: Null<String>): Promise<Array<ChatMessage>>;
	public function hasMedia(hashAlgorithm:String, hash:BytesData): Promise<Bool>;
	public function storeMedia(mime:String, bytes:BytesData): Promise<Bool>;
	public function removeMedia(hashAlgorithm:String, hash:BytesData):Void;
	@HaxeCBridge.noemit
	public function storeCaps(caps:Caps):Void;
	@HaxeCBridge.noemit
	public function getCaps(ver:String): Promise<Null<Caps>>;
	public function storeLogin(login:String, clientId:String, displayName:String, token:Null<String>):Void;
	@HaxeCBridge.noemit
	public function getLogin(login:String): Promise<{ clientId:Null<String>, token:Null<String>, fastCount: Int, displayName:Null<String> }>;
	public function removeAccount(accountId: String, completely:Bool):Void;
	public function listAccounts(): Promise<Array<String>>;
	@HaxeCBridge.noemit
	public function storeStreamManagement(accountId:String, data:Null<BytesData>):Void;
	@HaxeCBridge.noemit
	public function getStreamManagement(accountId:String): Promise<Null<BytesData>>;
	@HaxeCBridge.noemit
	public function storeService(accountId:String, serviceId:String, name:Null<String>, node:Null<String>, caps:Caps):Void;
	@HaxeCBridge.noemit
	public function findServicesWithFeature(accountId:String, feature:String): Promise<Array<{serviceId:String, name:Null<String>, node:Null<String>, caps: Caps}>>;
#if !NO_OMEMO
	public function getOmemoId(login:String): Promise<Null<Int>>;
	public function storeOmemoId(login:String, omemoId:Int):Void;
	public function storeOmemoIdentityKey(login:String, keypair:IdentityKeyPair):Void;
	public function getOmemoIdentityKey(login:String): Promise<IdentityKeyPair>;
	public function getOmemoDeviceList(identifier:String): Promise<Array<Int>>;
	public function storeOmemoDeviceList(identifier:String, deviceIds:Array<Int>):Void;
	public function storeOmemoPreKey(identifier:String, keyId:Int, keyPair:PreKeyPair):Void;
	public function getOmemoPreKey(identifier:String, keyId:Int): Promise<PreKeyPair>;
	public function removeOmemoPreKey(identifier:String, keyId:Int):Void;
	public function storeOmemoSignedPreKey(login:String, signedPreKey:SignedPreKey):Void;
	public function getOmemoSignedPreKey(login:String, keyId:Int): Promise<SignedPreKey>;
	public function getOmemoPreKeys(login:String): Promise<Array<PreKey>>;
	public function storeOmemoContactIdentityKey(account:String, address:String, identityKey:IdentityPublicKey):Void;
	public function getOmemoContactIdentityKey(account:String, address:String): Promise<IdentityPublicKey>;
	public function getOmemoSession(account:String, address:String): Promise<SignalSession>;
	public function storeOmemoSession(account:String, address:String, session:SignalSession):Void;
	public function removeOmemoSession(account:String, address:String):Void;
	public function storeOmemoMetadata(account:String, address:String, metadata:OMEMOSessionMetadata):Void;
	public function getOmemoMetadata(account:String, address:String): Promise<OMEMOSessionMetadata>;
#end
}
