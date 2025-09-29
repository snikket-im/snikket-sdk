package borogove.persistence;

#if cpp
import HaxeCBridge;
#end
import haxe.io.BytesData;
import borogove.Caps;
import borogove.Chat;
import borogove.Message;
import thenshim.Promise;
#if !NO_OMEMO
import borogove.OMEMO;
using borogove.SignalProtocol;
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
	public function lastId(accountId: String, chatId: Null<String>): Promise<Null<String>> {
		return Promise.resolve(null);
	}

	@HaxeCBridge.noemit
	public function storeChats(accountId: String, chat: Array<Chat>) { }

	@HaxeCBridge.noemit
	public function getChats(accountId: String): Promise<Array<SerializedChat>> {
		return Promise.resolve([]);
	}

	@HaxeCBridge.noemit
	public function storeMessages(accountId: String, messages: Array<ChatMessage>): Promise<Array<ChatMessage>> {
		return Promise.resolve(messages);
	}

	@HaxeCBridge.noemit
	public function updateMessage(accountId: String, message: ChatMessage) {
	}

	@HaxeCBridge.noemit
	public function getMessage(accountId: String, chatId: String, serverId: Null<String>, localId: Null<String>): Promise<Null<ChatMessage>> {
		return Promise.resolve(null);
	}

	@HaxeCBridge.noemit
	public function getMessagesBefore(accountId: String, chatId: String, beforeId: Null<String>, beforeTime: Null<String>): Promise<Array<ChatMessage>> {
		return Promise.resolve([]);
	}

	@HaxeCBridge.noemit
	public function getMessagesAfter(accountId: String, chatId: String, afterId: Null<String>, afterTime: Null<String>): Promise<Array<ChatMessage>> {
		return Promise.resolve([]);
	}

	@HaxeCBridge.noemit
	public function getMessagesAround(accountId: String, chatId: String, aroundId: Null<String>, aroundTime: Null<String>): Promise<Array<ChatMessage>> {
		return Promise.resolve([]);
	}

	@HaxeCBridge.noemit
	public function getChatsUnreadDetails(accountId: String, chats: Array<Chat>): Promise<Array<{ chatId: String, message: ChatMessage, unreadCount: Int }>> {
		return Promise.resolve([]);
	}

	@HaxeCBridge.noemit
	public function storeReaction(accountId: String, update: ReactionUpdate): Promise<Null<ChatMessage>> {
		return Promise.resolve(null);
	}

	@HaxeCBridge.noemit
	public function updateMessageStatus(accountId: String, localId: String, status:MessageStatus): Promise<ChatMessage> {
		return Promise.reject("Dummy cannot updateMessageStatus");
	}

	@HaxeCBridge.noemit
	public function hasMedia(hashAlgorithm:String, hash:BytesData): Promise<Bool> {
		return Promise.resolve(false);
	}

	@HaxeCBridge.noemit
	public function storeMedia(mime:String, bd:BytesData): Promise<Bool> {
		return Promise.resolve(false);
	}

	@HaxeCBridge.noemit
	public function removeMedia(hashAlgorithm:String, hash:BytesData) {
	}

	@HaxeCBridge.noemit
	public function storeCaps(caps:Caps) { }

	@HaxeCBridge.noemit
	public function getCaps(ver:String): Promise<Caps> {
		return Promise.resolve(null);
	}

	@HaxeCBridge.noemit
	public function storeLogin(login:String, clientId:String, displayName:String, token:Null<String>) { }

	@HaxeCBridge.noemit
	public function getLogin(login:String): Promise<{ clientId:Null<String>, token:Null<String>, fastCount: Int, displayName:Null<String> }> {
		return Promise.resolve({ clientId: null, token: null, fastCount: 0, displayName: null });
	}

	@HaxeCBridge.noemit
	public function removeAccount(accountId:String, completely:Bool) { }

	@HaxeCBridge.noemit
	public function listAccounts(): Promise<Array<String>> {
		return Promise.resolve([]);
	}

	@HaxeCBridge.noemit
	public function storeStreamManagement(accountId:String, sm:Null<BytesData>) { }

	@HaxeCBridge.noemit
	public function getStreamManagement(accountId:String): Promise<Null<BytesData>> {
		return Promise.resolve(null);
	}

	@HaxeCBridge.noemit
	public function storeService(accountId:String, serviceId:String, name:Null<String>, node:Null<String>, caps:Caps) { }

	@HaxeCBridge.noemit
	public function findServicesWithFeature(accountId:String, feature:String): Promise<Array<{serviceId:String, name:Null<String>, node:Null<String>, caps: Caps}>> {
		return Promise.resolve([]);
	}

	#if !NO_OMEMO
	@HaxeCBridge.noemit
	public function getOmemoId(login:String): Promise<Null<Int>> {
		return Promise.resolve(null);
	}

	@HaxeCBridge.noemit
	public function storeOmemoId(login:String, omemoId:Int):Void { }

	@HaxeCBridge.noemit
	public function storeOmemoIdentityKey(login:String, keypair:IdentityKeyPair):Void { }

	@HaxeCBridge.noemit
	public function getOmemoIdentityKey(login:String): Promise<IdentityKeyPair> {
		return Promise.reject("Not found");
	}

	@HaxeCBridge.noemit
	public function getOmemoDeviceList(identifier:String): Promise<Array<Int>> {
		return Promise.resolve([]);
	}

	@HaxeCBridge.noemit
	public function storeOmemoDeviceList(identifier:String, deviceIds:Array<Int>):Void { }

	@HaxeCBridge.noemit
	public function storeOmemoPreKey(identifier:String, keyId:Int, keyPair:PreKeyPair):Void { }

	@HaxeCBridge.noemit
	public function getOmemoPreKey(identifier:String, keyId:Int): Promise<PreKeyPair> {
		return Promise.reject("Not found");
	}

	@HaxeCBridge.noemit
	public function removeOmemoPreKey(identifier:String, keyId:Int):Void { }

	@HaxeCBridge.noemit
	public function storeOmemoSignedPreKey(login:String, signedPreKey:SignedPreKey):Void { }

	@HaxeCBridge.noemit
	public function getOmemoSignedPreKey(login:String, keyId:Int): Promise<SignedPreKey> {
		return Promise.reject("Not found");
	}

	@HaxeCBridge.noemit
	public function getOmemoPreKeys(login:String): Promise<Array<PreKey>> {
		return Promise.resolve([]);
	}

	@HaxeCBridge.noemit
	public function storeOmemoContactIdentityKey(account:String, address:String, identityKey:IdentityPublicKey):Void { }

	@HaxeCBridge.noemit
	public function getOmemoContactIdentityKey(account:String, address:String): Promise<IdentityPublicKey> {
		return Promise.reject("Not found");
	}

	@HaxeCBridge.noemit
	public function getOmemoSession(account:String, address:String): Promise<SignalSession> {
		return Promise.reject("Not found");
	}

	@HaxeCBridge.noemit
	public function storeOmemoSession(account:String, address:String, session:SignalSession):Void { }

	@HaxeCBridge.noemit
	public function removeOmemoSession(account:String, address:String):Void { }

	@HaxeCBridge.noemit
	public function storeOmemoMetadata(account:String, address:String, metadata:OMEMOSessionMetadata):Void { }

	@HaxeCBridge.noemit
	public function getOmemoMetadata(account:String, address:String): Promise<OMEMOSessionMetadata> {
		return Promise.reject("Not found");
	}
#end
}
