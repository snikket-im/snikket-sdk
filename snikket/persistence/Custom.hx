package snikket.persistence;

#if cpp
import HaxeCBridge;
#end
import haxe.io.BytesData;
import snikket.Caps;
import snikket.Chat;
import snikket.Message;

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class Custom implements Persistence {
	private final backing: Persistence;
	private var _storeMessages: Null<(String, Array<ChatMessage>, Callback<Array<ChatMessage>>)->Bool> = null;

	/**
		Create a persistence layer that wraps another with optional overrides

		@returns new persistence layer
	**/
	public function new(backing: Persistence) {
		this.backing = backing;
	}

	@HaxeCBridge.noemit
	public function lastId(accountId: String, chatId: Null<String>, callback:(Null<String>)->Void):Void {
		backing.lastId(accountId, chatId, callback);
	}

	@HaxeCBridge.noemit
	public function storeChats(accountId: String, chats: Array<Chat>) {
		backing.storeChats(accountId, chats);
	}

	@HaxeCBridge.noemit
	public function getChats(accountId: String, callback: (Array<SerializedChat>)->Void) {
		backing.getChats(accountId, callback);
	}

	/**
		Override the storeMessages method of the underlying persistence layer

		@param f takes three arguments, the account ID, the ChatMessage array to store, and the Callback to call when done
		       return false to pass control to the wrapped layer (do not call the Callback in this case)
	**/
	public function overrideStoreMessages(f: (String, Array<ChatMessage>, Callback<Array<ChatMessage>>)->Bool) {
		_storeMessages = f;
	}

	@HaxeCBridge.noemit
	public function storeMessages(accountId: String, messages: Array<ChatMessage>, callback: (Array<ChatMessage>)->Void) {
		if (_storeMessages == null || !_storeMessages(accountId, messages, new Callback(callback))) {
			backing.storeMessages(accountId, messages, callback);
		}
	}

	@HaxeCBridge.noemit
	public function updateMessage(accountId: String, message: ChatMessage) {
		backing.updateMessage(accountId, message);
	}

	@HaxeCBridge.noemit
	public function getMessage(accountId: String, chatId: String, serverId: Null<String>, localId: Null<String>, callback: (Null<ChatMessage>)->Void) {
		backing.getMessage(accountId, chatId, serverId, localId, callback);
	}

	@HaxeCBridge.noemit
	public function getMessagesBefore(accountId: String, chatId: String, beforeId: Null<String>, beforeTime: Null<String>, callback: (Array<ChatMessage>)->Void) {
		backing.getMessagesBefore(accountId, chatId, beforeId, beforeTime, callback);
	}

	@HaxeCBridge.noemit
	public function getMessagesAfter(accountId: String, chatId: String, afterId: Null<String>, afterTime: Null<String>, callback: (Array<ChatMessage>)->Void) {
		backing.getMessagesAfter(accountId, chatId, afterId, afterTime, callback);
	}

	@HaxeCBridge.noemit
	public function getMessagesAround(accountId: String, chatId: String, aroundId: Null<String>, aroundTime: Null<String>, callback: (Array<ChatMessage>)->Void) {
		backing.getMessagesAround(accountId, chatId, aroundId, aroundTime, callback);
	}

	@HaxeCBridge.noemit
	public function getChatsUnreadDetails(accountId: String, chats: Array<Chat>, callback: (Array<{ chatId: String, message: ChatMessage, unreadCount: Int }>)->Void) {
		backing.getChatsUnreadDetails(accountId, chats, callback);
	}

	@HaxeCBridge.noemit
	public function storeReaction(accountId: String, update: ReactionUpdate, callback: (Null<ChatMessage>)->Void) {
		backing.storeReaction(accountId, update, callback);
	}

	@HaxeCBridge.noemit
	public function updateMessageStatus(accountId: String, localId: String, status:MessageStatus, callback: (ChatMessage)->Void) {
		backing.updateMessageStatus(accountId, localId, status, callback);
	}

	@HaxeCBridge.noemit
	public function hasMedia(hashAlgorithm:String, hash:BytesData, callback: (Bool)->Void) {
		backing.hasMedia(hashAlgorithm, hash, callback);
	}

	@HaxeCBridge.noemit
	public function storeMedia(mime:String, bd:BytesData, callback: ()->Void) {
		backing.storeMedia(mime, bd, callback);
	}

	@HaxeCBridge.noemit
	public function removeMedia(hashAlgorithm:String, hash:BytesData) {
		backing.removeMedia(hashAlgorithm, hash);
	}

	@HaxeCBridge.noemit
	public function storeCaps(caps:Caps) {
		backing.storeCaps(caps);
	}

	@HaxeCBridge.noemit
	public function getCaps(ver:String, callback: (Caps)->Void) {
		backing.getCaps(ver, callback);
	}

	@HaxeCBridge.noemit
	public function storeLogin(login:String, clientId:String, displayName:String, token:Null<String>) {
		backing.storeLogin(login, clientId, displayName, token);
	}

	@HaxeCBridge.noemit
	public function getLogin(login:String, callback:(Null<String>, Null<String>, Int, Null<String>)->Void) {
		backing.getLogin(login, callback);
	}

	@HaxeCBridge.noemit
	public function storeStreamManagement(accountId:String, sm:BytesData) {
		backing.storeStreamManagement(accountId, sm);
	}

	@HaxeCBridge.noemit
	public function removeAccount(accountId:String, completely:Bool) {
		backing.removeAccount(accountId, completely);
	}

	@HaxeCBridge.noemit
	public function getStreamManagement(accountId:String, callback: (BytesData)->Void) {
		backing.getStreamManagement(accountId, callback);
	}

	@HaxeCBridge.noemit
	public function storeService(accountId:String, serviceId:String, name:Null<String>, node:Null<String>, caps:Caps) {
		backing.storeService(accountId, serviceId, name, node, caps);
	}

	@HaxeCBridge.noemit
	public function findServicesWithFeature(accountId:String, feature:String, callback:(Array<{serviceId:String, name:Null<String>, node:Null<String>, caps: Caps}>)->Void) {
		backing.findServicesWithFeature(accountId, feature, callback);
	}


	// OMEMO
	// TODO
	@HaxeCBridge.noemit
	public function getOmemoId(login:String, callback:(omemoId:Null<Int>)->Void):Void {
		backing.getOmemoId(login, callback);
	}

	@HaxeCBridge.noemit
	public function storeOmemoId(login:String, omemoId:Int):Void {
		backing.storeOmemoId(login, omemoId);
	}

	@HaxeCBridge.noemit
	public function getOMEMODeviceList(identifier:String, callback: (Array<Int>)->Void) {
		return backing.getOMEMODeviceList(identifier, callback);
	}

	@HaxeCBridge.noemit
	public function storeOMEMODeviceList(identifier:String, deviceIds:Array<Int>) {
		backing.storeOMEMODeviceList(identifier, deviceIds);
	}
}

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class Callback<T> {
	private final f: T->Void;

	@:allow(snikket)
	private function new(f: T->Void) {
		this.f = f;
	}

	public function call(v: Any) {
		f(v);
	}
}
