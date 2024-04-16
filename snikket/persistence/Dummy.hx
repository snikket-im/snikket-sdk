package snikket.persistence;

#if cpp
import HaxeCBridge;
#end
import haxe.io.BytesData;
import snikket.Caps;
import snikket.Chat;
import snikket.Message;

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
	public function storeChat(accountId: String, chat: Chat) { }

	@HaxeCBridge.noemit
	public function getChats(accountId: String, callback: (Array<SerializedChat>)->Void) {
		callback([]);
	}

	@HaxeCBridge.noemit
	public function storeMessage(accountId: String, message: ChatMessage, callback: (ChatMessage)->Void) {
		callback(message);
	}

	@HaxeCBridge.noemit
	public function getMessages(accountId: String, chatId: String, beforeId: Null<String>, beforeTime: Null<String>, callback: (Array<ChatMessage>)->Void) {
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
	public function storeMedia(mime:String, bd:BytesData, callback: ()->Void) {
		callback();
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
	public function storeStreamManagement(accountId:String, smId:String, outboundCount:Int, inboundCount:Int, outboundQueue:Array<String>) { }

	@HaxeCBridge.noemit
	public function getStreamManagement(accountId:String, callback: (Null<String>, Int, Int, Array<String>)->Void) {
		callback(null, -1, -1, []);
	}

	@HaxeCBridge.noemit
	public function storeService(accountId:String, serviceId:String, name:Null<String>, node:Null<String>, caps:Caps) { }

	@HaxeCBridge.noemit
	public function findServicesWithFeature(accountId:String, feature:String, callback:(Array<{serviceId:String, name:Null<String>, node:Null<String>, caps: Caps}>)->Void) {
		callback([]);
	}
}
