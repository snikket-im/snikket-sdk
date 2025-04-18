package snikket.persistence;

#if cpp
import HaxeCBridge;
#end
import haxe.io.BytesData;
import snikket.Caps;
import snikket.Chat;
import snikket.Message;
#if !NO_OMEMO
import snikket.OMEMO;
using snikket.SignalProtocol;
#end


// TODO: consider doing background threads for operations

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class Dummy implements Persistence {
	/**
		Create a basic persistence layer that persists nothing

		@returns new persistence layer
	**/
	public function new() { }

	@HaxeCBridge.noemit
	public function lastId(accountId: String, chatId: Null<String>, callback:(Null<String>)->Void):Void {
		callback(null);
	}

	@HaxeCBridge.noemit
	public function storeChats(accountId: String, chat: Array<Chat>) { }

	@HaxeCBridge.noemit
	public function getChats(accountId: String, callback: (Array<SerializedChat>)->Void) {
		callback([]);
	}

	@HaxeCBridge.noemit
	public function storeMessages(accountId: String, messages: Array<ChatMessage>, callback: (Array<ChatMessage>)->Void) {
		callback(messages);
	}

	@HaxeCBridge.noemit
	public function updateMessage(accountId: String, message: ChatMessage) {
	}

	@HaxeCBridge.noemit
	public function getMessage(accountId: String, chatId: String, serverId: Null<String>, localId: Null<String>, callback: (Null<ChatMessage>)->Void) {
		callback(null);
	}

	@HaxeCBridge.noemit
	public function getMessagesBefore(accountId: String, chatId: String, beforeId: Null<String>, beforeTime: Null<String>, callback: (Array<ChatMessage>)->Void) {
		callback([]);
	}

	@HaxeCBridge.noemit
	public function getMessagesAfter(accountId: String, chatId: String, afterId: Null<String>, afterTime: Null<String>, callback: (Array<ChatMessage>)->Void) {
		callback([]);
	}

	@HaxeCBridge.noemit
	public function getMessagesAround(accountId: String, chatId: String, aroundId: Null<String>, aroundTime: Null<String>, callback: (Array<ChatMessage>)->Void) {
		callback([]);
	}

	@HaxeCBridge.noemit
	public function getChatsUnreadDetails(accountId: String, chats: Array<Chat>, callback: (Array<{ chatId: String, message: ChatMessage, unreadCount: Int }>)->Void) {
		callback([]);
	}

	@HaxeCBridge.noemit
	public function storeReaction(accountId: String, update: ReactionUpdate, callback: (Null<ChatMessage>)->Void) {
		callback(null);
	}

	@HaxeCBridge.noemit
	public function updateMessageStatus(accountId: String, localId: String, status:MessageStatus, callback: (ChatMessage)->Void) {
		callback(null);
	}

	@HaxeCBridge.noemit
	public function getMediaUri(hashAlgorithm:String, hash:BytesData, callback: (Null<String>)->Void) {
		callback(null);
	}

	@HaxeCBridge.noemit
	public function hasMedia(hashAlgorithm:String, hash:BytesData, callback: (Bool)->Void) {
		callback(false);
	}

	@HaxeCBridge.noemit
	public function storeMedia(mime:String, bd:BytesData, callback: ()->Void) {
		callback();
	}

	@HaxeCBridge.noemit
	public function removeMedia(hashAlgorithm:String, hash:BytesData) {
	}

	@HaxeCBridge.noemit
	public function storeCaps(caps:Caps) { }

	@HaxeCBridge.noemit
	public function getCaps(ver:String, callback: (Caps)->Void) {
		callback(null);
	}

	@HaxeCBridge.noemit
	public function storeLogin(login:String, clientId:String, displayName:String, token:Null<String>) { }

	@HaxeCBridge.noemit
	public function getLogin(login:String, callback:(Null<String>, Null<String>, Int, Null<String>)->Void) {
		callback(null, null, 0, null);
	}

	@HaxeCBridge.noemit
	public function removeAccount(accountId:String, completely:Bool) { }

	@HaxeCBridge.noemit
	public function listAccounts(callback:(Array<String>)->Void) {
		callback([]);
	}

	@HaxeCBridge.noemit
	public function storeStreamManagement(accountId:String, sm:Null<BytesData>) { }

	@HaxeCBridge.noemit
	public function getStreamManagement(accountId:String, callback: (Null<BytesData>)->Void) {
		callback(null);
	}

	@HaxeCBridge.noemit
	public function storeService(accountId:String, serviceId:String, name:Null<String>, node:Null<String>, caps:Caps) { }

	@HaxeCBridge.noemit
	public function findServicesWithFeature(accountId:String, feature:String, callback:(Array<{serviceId:String, name:Null<String>, node:Null<String>, caps: Caps}>)->Void) {
		callback([]);
	}

#if !NO_OMEMO
	@HaxeCBridge.noemit
	public function getOmemoId(login:String, callback:(omemoId:Null<Int>)->Void):Void { }

	@HaxeCBridge.noemit
	public function storeOmemoId(login:String, omemoId:Int):Void { }

	@HaxeCBridge.noemit
	public function getOmemoDeviceList(identifier:String, callback: (Array<Int>)->Void) { }
	@HaxeCBridge.noemit
	public function storeOmemoDeviceList(identifier:String, deviceIds:Array<Int>):Void { }

	@HaxeCBridge.noemit
	public function storeOmemoPreKey(identifier:String, keyId:Int, keyPair:PreKeyPair):Void { }
	@HaxeCBridge.noemit
	public function getOmemoPreKey(identifier:String, keyId:Int, callback: (PreKeyPair)->Void):Void { }
	@HaxeCBridge.noemit
	public function removeOmemoPreKey(identifier:String, keyId:Int):Void { }

	@HaxeCBridge.noemit
	public function storeOmemoIdentityKey(login:String, keypair:IdentityKeyPair):Void { }
	@HaxeCBridge.noemit
	public function getOmemoIdentityKey(login:String, callback: (IdentityKeyPair)->Void):Void { }

	@HaxeCBridge.noemit
	public function storeOmemoSignedPreKey(login:String, signedPreKey:SignedPreKey):Void { }
	@HaxeCBridge.noemit
	public function getOmemoSignedPreKey(login:String, keyId:Int, callback: (SignedPreKey)->Void):Void { }

	@HaxeCBridge.noemit
	public function getOmemoPreKeys(login:String, callback: (Array<PreKeyPair>)->Void):Void { }

	@HaxeCBridge.noemit
	public function storeOmemoContactIdentityKey(account:String, address:String, identityKey:IdentityPublicKey):Void { }
	@HaxeCBridge.noemit
	public function getOmemoContactIdentityKey(account:String, address:String, callback:(IdentityPublicKey)->Void):Void { }

	@HaxeCBridge.noemit
	public function getOmemoSession(account:String, address:String, callback:(SignalSession)->Void):Void { }
	@HaxeCBridge.noemit
	public function storeOmemoSession(account:String, address:String, session:SignalSession):Void { }
#end
}
