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
@:expose
interface Persistence {
	/**
		Get the last message in an account or chat that is is safe to sync forward from

		@param accountId the account whose state should be queried
		@param chatId chat to inspect, or null for the account-wide sync point
		@returns Promise resolving to the sync point or null
	**/
	public function syncPoint(accountId: String, chatId: Null<String>): Promise<Null<ChatMessage>>;

	/**
		Persist the current metadata for a set of Chats

		@param accountId the account that owns the Chats
		@param chats chats to write to storage
	**/
	public function storeChats(accountId: String, chats: Array<Chat>):Void;

	/**
		Load the stored Chats for an account

		@param accountId the account to load Chats for
		@returns Promise resolving to serialized chat records
	**/
	@HaxeCBridge.noemit
	public function getChats(accountId: String): Promise<Array<SerializedChat>>;

	/**
		Load unread counters and most recent unread message per Chat

		@param accountId the account to load unread details for
		@param chats chats to inspect
		@returns Promise resolving to unread details for the requested chats
	**/
	@HaxeCBridge.noemit
	public function getChatsUnreadDetails(accountId: String, chats: Array<Chat>): Promise<Array<{ chatId: String, message: ChatMessage, unreadCount: Int }>>;

	/**
		Apply a reaction update to the stored message state

		@param accountId the account that owns the message
		@param update reaction update to apply
		@returns Promise resolving to the updated message or null if no message matched
	**/
	@HaxeCBridge.noemit
	public function storeReaction(accountId: String, update: ReactionUpdate): Promise<Null<ChatMessage>>;

	/**
		Persist one or more messages

		@param accountId the account that owns the messages
		@param message messages to store
		@returns Promise resolving to the stored message values
	**/
	public function storeMessages(accountId: String, message: Array<ChatMessage>): Promise<Array<ChatMessage>>;

	/**
		Replace the stored record for a message

		@param accountId the account that owns the message
		@param message message to write
	**/
	public function updateMessage(accountId: String, message: ChatMessage):Void;

	/**
		Update delivery state for a locally-created message

		@param accountId the account that owns the message
		@param localId local message ID to update
		@param status new delivery state
		@param statusText optional human-readable status detail
		@returns Promise resolving to the updated message
	**/
	public function updateMessageStatus(accountId: String, localId: String, status:borogove.Message.MessageStatus, statusText: Null<String>): Promise<ChatMessage>;

	/**
		Find a message by Chat ID and known IDs

		@param accountId the account that owns the message
		@param chatId Chat containing the message
		@param serverId authoritative server-assigned ID, if known
		@param localId client-assigned ID, if known
		@returns Promise resolving to the matching message or null
	**/
	public function getMessage(accountId: String, chatId: String, serverId: Null<String>, localId: Null<String>): Promise<Null<ChatMessage>>;

	/**
		Load messages older than a reference message

		@param accountId the account to load messages for
		@param chatId Chat to query
		@param before return messages older than this message, or start from the newest when null
		@returns Promise resolving to older messages
	**/
	public function getMessagesBefore(accountId: String, chatId: String, before: Null<ChatMessage>): Promise<Array<ChatMessage>>;

	/**
		Load messages newer than a reference message

		@param accountId the account to load messages for
		@param chatId Chat to query
		@param afterId return messages newer than this message, or start from the oldest when null
		@returns Promise resolving to newer messages
	**/
	public function getMessagesAfter(accountId: String, chatId: String, afterId: Null<ChatMessage>): Promise<Array<ChatMessage>>;

	/**
		Load messages surrounding a reference message

		@param accountId the account to load messages for
		@param around message to center the result set around
		@returns Promise resolving to nearby messages
	**/
	public function getMessagesAround(accountId: String, around: ChatMessage): Promise<Array<ChatMessage>>;

	/**
		Check whether a media blob is already stored

		@param hashAlgorithm hash algorithm for the content ID
		@param hash raw hash bytes
		@returns Promise resolving to true when the media exists
	**/
	public function hasMedia(hashAlgorithm:String, hash:BytesData): Promise<Bool>;

	/**
		Store media bytes and any metadata needed to retrieve them later

		@param mime MIME type of the media
		@param bytes raw media bytes
		@returns Promise resolving to true when storage succeeded
	**/
	public function storeMedia(mime:String, bytes:BytesData): Promise<Bool>;

	/**
		Delete previously stored media

		@param hashAlgorithm hash algorithm for the content ID
		@param hash raw hash bytes
	**/
	public function removeMedia(hashAlgorithm:String, hash:BytesData):Void;

	/**
		Store service discovery capabilities for later reuse

		@param caps capabilities record to save
	**/
	@HaxeCBridge.noemit
	public function storeCaps(caps:Caps):Void;

	/**
		Load previously stored service discovery capabilities

		@param ver capability version hash
		@returns Promise resolving to the stored capability record or null
	**/
	@HaxeCBridge.noemit
	public function getCaps(ver:String): Promise<Null<Caps>>;

	/**
		Store login-related state for an account

		@param accountId the account to store login state for
		@param clientId negotiated client ID
		@param displayName last known display name
		@param token persisted token or null to clear it
	**/
	public function storeLogin(accountId:String, clientId:String, displayName:String, token:Null<String>):Void;

	/**
		Load persisted login-related state for an account

		@param accountId the account to load login state for
		@returns Promise resolving to stored login data
	**/
	@HaxeCBridge.noemit
	public function getLogin(accountId:String): Promise<{ clientId:Null<String>, token:Null<String>, fastCount: Int, displayName:Null<String> }>;

	/**
		Remove stored data for an account

		@param accountId the account to remove
		@param completely true to delete all account data, false to keep recoverable state
	**/
	public function removeAccount(accountId: String, completely:Bool):Void;

	/**
		List all accounts present in storage

		@returns Promise resolving to stored account IDs
	**/
	public function listAccounts(): Promise<Array<String>>;

	/**
		Store stream management resumption data for an account

		@param accountId the account to store resumption data for
		@param data stream management payload, or null to clear it
	**/
	@HaxeCBridge.noemit
	public function storeStreamManagement(accountId:String, data:Null<BytesData>):Void;

	/**
		Load stream management resumption data for an account

		@param accountId the account to load resumption data for
		@returns Promise resolving to stored resumption data or null
	**/
	@HaxeCBridge.noemit
	public function getStreamManagement(accountId:String): Promise<Null<BytesData>>;

	/**
		Store metadata about a discovered service

		@param accountId the account that discovered the service
		@param serviceId ID of the service
		@param name advertised display name, if any
		@param node disco node, if any
		@param caps service capabilities
	**/
	@HaxeCBridge.noemit
	public function storeService(accountId:String, serviceId:String, name:Null<String>, node:Null<String>, caps:Caps):Void;

	/**
		Find known services that advertise a feature

		@param accountId the account to search services for
		@param feature disco feature to search for
		@returns Promise resolving to matching services
	**/
	@HaxeCBridge.noemit
	public function findServicesWithFeature(accountId:String, feature:String): Promise<Array<{serviceId:String, name:Null<String>, node:Null<String>, caps: Caps}>>;
#if !NO_OMEMO

	/**
		Load the local OMEMO device ID for an account
	**/
	public function getOmemoId(login:String): Promise<Null<Int>>;

	/**
		Store the local OMEMO device ID for an account
	**/
	public function storeOmemoId(login:String, omemoId:Int):Void;

	/**
		Store the local OMEMO identity key pair for an account
	**/
	public function storeOmemoIdentityKey(login:String, keypair:IdentityKeyPair):Void;

	/**
		Load the local OMEMO identity key pair for an account
	**/
	public function getOmemoIdentityKey(login:String): Promise<IdentityKeyPair>;

	/**
		Load the known OMEMO device list for a contact or account
	**/
	public function getOmemoDeviceList(identifier:String): Promise<Array<Int>>;

	/**
		Store the known OMEMO device list for a contact or account
	**/
	public function storeOmemoDeviceList(identifier:String, deviceIds:Array<Int>):Void;

	/**
		Store an OMEMO pre-key
	**/
	public function storeOmemoPreKey(identifier:String, keyId:Int, keyPair:PreKeyPair):Void;

	/**
		Load an OMEMO pre-key
	**/
	public function getOmemoPreKey(identifier:String, keyId:Int): Promise<PreKeyPair>;

	/**
		Remove an OMEMO pre-key
	**/
	public function removeOmemoPreKey(identifier:String, keyId:Int):Void;

	/**
		Store an OMEMO signed pre-key
	**/
	public function storeOmemoSignedPreKey(login:String, signedPreKey:SignedPreKey):Void;

	/**
		Load an OMEMO signed pre-key
	**/
	public function getOmemoSignedPreKey(login:String, keyId:Int): Promise<SignedPreKey>;

	/**
		List available OMEMO pre-keys for an account
	**/
	public function getOmemoPreKeys(login:String): Promise<Array<PreKey>>;

	/**
		Store a trusted identity key for a remote OMEMO contact
	**/
	public function storeOmemoContactIdentityKey(account:String, address:String, identityKey:IdentityPublicKey):Void;

	/**
		Load a stored identity key for a remote OMEMO contact
	**/
	public function getOmemoContactIdentityKey(account:String, address:String): Promise<IdentityPublicKey>;

	/**
		Load a stored OMEMO session for a remote device
	**/
	public function getOmemoSession(account:String, address:String): Promise<SignalSession>;

	/**
		Store an OMEMO session for a remote device
	**/
	public function storeOmemoSession(account:String, address:String, session:SignalSession):Void;

	/**
		Remove a stored OMEMO session for a remote device
	**/
	public function removeOmemoSession(account:String, address:String):Void;

	/**
		Store extra metadata associated with an OMEMO session
	**/
	public function storeOmemoMetadata(account:String, address:String, metadata:OMEMOSessionMetadata):Void;

	/**
		Load stored metadata associated with an OMEMO session
	**/
	public function getOmemoMetadata(account:String, address:String): Promise<OMEMOSessionMetadata>;
#end
}
