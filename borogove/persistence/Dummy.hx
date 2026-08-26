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
	public function syncPoint(accountId: String, chatId: Null<String>): Promise<Null<ChatMessage>> {
		return Promise.resolve(null);
	}

	@HaxeCBridge.noemit
	public function storeChats(accountId: String, chat: Array<Chat>) { }

	@HaxeCBridge.noemit
	public function getChats(accountId: String): Promise<Array<SerializedChat>> {
		return Promise.resolve([]);
	}

	@HaxeCBridge.noemit
	public function storeMembers(accountId: String, chatId: String, chat: Array<Member>) {
		return Promise.resolve(false);
	}

	@HaxeCBridge.noemit
	public function storeMemberUpdates(accountId: String, chat: Chat, updates: Array<MemberUpdate>, isFullList: Bool) {
		return Promise.resolve([]);
	}

	@HaxeCBridge.noemit
	public function clearMemberPresence(accountId: String, chatId: Null<String>) {
		return Promise.resolve(false);
	}

	@HaxeCBridge.noemit
	public function getMembers(accountId: String, chat: Chat, forModerator: Bool) {
		return Promise.resolve([]);
	}

	@HaxeCBridge.noemit
	public function getMemberDetails(accountId: String, chat: Null<Chat>, ids: Array<String>) {
		return Promise.resolve([]);
	}

	@HaxeCBridge.noemit
	public function storeVoiceRequest(accountId: String, chat: Chat, jid: String, requesting: Bool) {
		return Promise.resolve(false);
	}

	@HaxeCBridge.noemit
	public function listVoiceRequests(accountId: String, chat: Chat) {
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
	public function getMessagesBefore(accountId: String, chatId: String, before: Null<ChatMessage>): Promise<Array<ChatMessage>> {
		return Promise.resolve([]);
	}

	@HaxeCBridge.noemit
	public function getMessagesAfter(accountId: String, chatId: String, after: Null<ChatMessage>): Promise<Array<ChatMessage>> {
		return Promise.resolve([]);
	}

	@HaxeCBridge.noemit
	public function getMessagesAround(accountId: String, around: Null<ChatMessage>): Promise<Array<ChatMessage>> {
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
	public function updateMessageStatus(accountId: String, localId: String, status:MessageStatus, statusText: Null<String>): Promise<ChatMessage> {
		return Promise.reject("Dummy cannot updateMessageStatus");
	}

	@HaxeCBridge.noemit
	public function hasMedia(hash: Hash): Promise<Null<String>> {
		return Promise.resolve(null);
	}

	@HaxeCBridge.noemit
	public function storeMedia(mime:String, source:Source): Promise<String> {
		return Promise.reject("Dummy cannot storeMedia");
	}

	@HaxeCBridge.noemit
	public function removeMedia(hashAlgorithm:String, hash:BytesData): Promise<Bool> {
		return Promise.resolve(false);
	}

	@HaxeCBridge.noemit
	public function storeCaps(caps:Caps) { }

	@HaxeCBridge.noemit
	public function getCaps(ver:String): Promise<Caps> {
		return Promise.resolve(null);
	}

	@HaxeCBridge.noemit
	public function storeLogin(login:String, clientId:String, displayName:String, rosterVer: Null<String>, token:Null<String>): Promise<Bool> {
		return Promise.resolve(false);
	}

	@HaxeCBridge.noemit
	public function getLogin(login:String): Promise<{ clientId:Null<String>, token:Null<String>, fastCount: Int, displayName:Null<String>, rosterVer: Null<String> }> {
		return Promise.resolve({ clientId: null, token: null, fastCount: 0, displayName: null, rosterVer: null });
	}

	@HaxeCBridge.noemit
	public function removeAccount(accountId:String, completely:Bool) {
		return Promise.resolve(false);
	}

	@HaxeCBridge.noemit
	public function listAccounts(): Promise<Array<String>> {
		return Promise.resolve([]);
	}

	@HaxeCBridge.noemit
	public function storeStreamManagement(accountId:String, sm:Null<BytesData>, sortId: String): Promise<Bool> {
		return Promise.resolve(false);
	}

	@HaxeCBridge.noemit
	public function getStreamManagement(accountId:String): Promise<{ sm: Null<BytesData>, sortId: String }> {
		return Promise.resolve({ sm: null, sortId: "a " });
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
	public function storeOmemoId(login:String, omemoId:Int):Promise<Int> {
		return Promise.resolve(omemoId);
	}

	@HaxeCBridge.noemit
	public function storeOmemoIdentityKey(login:String, keypair:IdentityKeyPair):Promise<IdentityKeyPair> {
		return Promise.resolve(keypair);
	}

	@HaxeCBridge.noemit
	public function getOmemoIdentityKey(login:String): Promise<Null<IdentityKeyPair>> {
		return Promise.resolve(null);
	}

	@HaxeCBridge.noemit
	public function getOmemoDeviceList(identifier:String): Promise<Array<Int>> {
		return Promise.resolve([]);
	}

	@HaxeCBridge.noemit
	public function storeOmemoDeviceList(identifier:String, deviceIds:Array<Int>):Promise<Array<Int>> {
		return Promise.resolve(deviceIds);
	}

	@HaxeCBridge.noemit
	public function storeOmemoPreKey(accountId:String, keyId:Int, keyPair:PreKeyPair):Promise<PreKeyPair> {
		return Promise.resolve(keyPair);
	}

	@HaxeCBridge.noemit
	public function getOmemoPreKey(accountId:String, keyId:Int): Promise<Null<PreKeyPair>> {
		return Promise.resolve(null);
	}

	@HaxeCBridge.noemit
	public function removeOmemoPreKey(accountId:String, keyId:Int):Promise<Bool> {
		return Promise.resolve(true);
	}

	@HaxeCBridge.noemit
	public function storeOmemoSignedPreKey(login:String, signedPreKey:SignedPreKey):Promise<SignedPreKey> {
		return Promise.resolve(signedPreKey);
	}

	@HaxeCBridge.noemit
	public function getOmemoSignedPreKey(login:String, keyId:Int): Promise<Null<SignedPreKey>> {
		return Promise.resolve(null);
	}

	@HaxeCBridge.noemit
	public function getOmemoPreKeys(login:String): Promise<Array<PreKey>> {
		return Promise.resolve([]);
	}

	@HaxeCBridge.noemit
	public function storeOmemoContactIdentityKey(account:String, address:String, identityKey:IdentityPublicKey):Promise<IdentityPublicKey> {
		return Promise.resolve(identityKey);
	}

	@HaxeCBridge.noemit
	public function getOmemoContactIdentityKey(account:String, address:String): Promise<Null<IdentityPublicKey>> {
		return Promise.resolve(null);
	}

	@HaxeCBridge.noemit
	public function getOmemoSession(account:String, address:String): Promise<Null<SignalSession>> {
		return Promise.resolve(null);
	}

	@HaxeCBridge.noemit
	public function storeOmemoSession(account:String, address:String, session:SignalSession):Promise<SignalSession> {
		return Promise.resolve(session);
	}

	@HaxeCBridge.noemit
	public function removeOmemoSession(account:String, address:String):Promise<Bool> {
		return Promise.resolve(true);
	}

	@HaxeCBridge.noemit
	public function storeOmemoMetadata(account:String, address:String, metadata:OMEMOSessionMetadata):Promise<OMEMOSessionMetadata> {
		return Promise.resolve(metadata);
	}

	@HaxeCBridge.noemit
	public function getOmemoMetadata(account:String, address:String): Promise<Null<OMEMOSessionMetadata>> {
		return Promise.resolve(null);
	}
#end
}
