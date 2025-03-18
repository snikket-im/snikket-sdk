export class borogove_persistence_Sqlite implements borogove_persistence_KeyValueStore, borogove_Persistence {
	/**
	 * Create a basic persistence layer based on sqlite
	 * @param dbfile path to sqlite database
	 * @params media a MediaStore to use for media
	 * @returns new persistence layer
	 */
	constructor(dbfile: string, media: borogove_persistence_MediaStore);
	get(k: string): Promise<string | null>;
	set(k: string, v: string | null): Promise<boolean>;
	syncPoint(accountId: string, chatId: string | null): Promise<borogove_ChatMessage | null>;
	storeChats(accountId: string, chats: borogove_Chat[]): void;
	getChats(accountId: string): Promise<borogove_SerializedChat[]>;
	storeMessages(accountId: string, messages: borogove_ChatMessage[]): Promise<borogove_ChatMessage[]>;
	updateMessage(accountId: string, message: borogove_ChatMessage): void;
	/**
	 * Get a single message
	 * @param accountId the account the message was sent or received on
	 * @param chatId the chat the message was sent or received on
	 * @param serverId the serverId of the message (optional if localId is specified)
	 * @param localId the localId of the message (optional if serverId is specified)
	 * @returns Promise resolving to the message or null
	 */
	getMessage(accountId: string, chatId: string, serverId: string | null, localId: string | null): Promise<borogove_ChatMessage | null>;
	getMessagesBefore(accountId: string, chatId: string, before: borogove_ChatMessage | null): Promise<borogove_ChatMessage[]>;
	getMessagesAfter(accountId: string, chatId: string, after: borogove_ChatMessage | null): Promise<borogove_ChatMessage[]>;
	getMessagesAround(accountId: string, around: borogove_ChatMessage): Promise<borogove_ChatMessage[]>;
	getChatsUnreadDetails(accountId: string, chats: borogove_Chat[]): Promise<{chatId: string, message: borogove_ChatMessage, unreadCount: number}[]>;
	storeReaction(accountId: string, update: borogove_ReactionUpdate): Promise<borogove_ChatMessage | null>;
	updateMessageStatus(accountId: string, localId: string, status: borogove_MessageStatus, statusText: string | null): Promise<borogove_ChatMessage>;
	hasMedia(hashAlgorithm: string, hash: ArrayBuffer): Promise<boolean>;
	removeMedia(hashAlgorithm: string, hash: ArrayBuffer): void;
	storeMedia(mime: string, bd: ArrayBuffer): Promise<boolean>;
	storeCaps(caps: borogove_Caps): void;
	getCaps(ver: string): Promise<borogove_Caps>;
	storeLogin(accountId: string, clientId: string, displayName: string, token: string | null): void;
	getLogin(accountId: string): Promise<{clientId: string | null, displayName: string | null, fastCount: number, token: string | null}>;
	/**
	 * Remove an account from storage
	 * @param accountId the account to remove
	 * @param completely if message history, etc should be removed also
	 */
	removeAccount(accountId: string, completely: boolean): void;
	/**
	 * List all known accounts
	 * @returns Promise resolving to array of account IDs
	 */
	listAccounts(): Promise<string[]>;
	storeStreamManagement(accountId: string, sm: ArrayBuffer | null): void;
	getStreamManagement(accountId: string): Promise<ArrayBuffer | null>;
	storeService(accountId: string, serviceId: string, name: string | null, node: string | null, caps: borogove_Caps): void;
	findServicesWithFeature(accountId: string, feature: string): Promise<{caps: borogove_Caps, name: string | null, node: string | null, serviceId: string}[]>;
}
export class borogove_persistence_Sqlite implements borogove_persistence_KeyValueStore, borogove_Persistence {
	/**
	 * Create a basic persistence layer based on sqlite
	 * @param dbfile path to sqlite database
	 * @param media a MediaStore to use for media
	 * @returns new persistence layer
	 */
	constructor(dbfile: string, media: borogove_persistence_MediaStore);
	get(k: string): Promise<string | null>;
	set(k: string, v: string | null): Promise<boolean>;
	syncPoint(accountId: string, chatId: string | null): Promise<borogove_ChatMessage | null>;
	storeChats(accountId: string, chats: borogove_Chat[]): void;
	getChats(accountId: string): Promise<borogove_SerializedChat[]>;
	storeMessages(accountId: string, messages: borogove_ChatMessage[]): Promise<borogove_ChatMessage[]>;
	updateMessage(accountId: string, message: borogove_ChatMessage): void;
	/**
	 * Get a single message
	 * @param accountId the account the message was sent or received on
	 * @param chatId the chat the message was sent or received on
	 * @param serverId the serverId of the message (optional if localId is specified)
	 * @param localId the localId of the message (optional if serverId is specified)
	 * @returns Promise resolving to the message or null
	 */
	getMessage(accountId: string, chatId: string, serverId: string | null, localId: string | null): Promise<borogove_ChatMessage | null>;
	getMessagesBefore(accountId: string, chatId: string, before: borogove_ChatMessage | null): Promise<borogove_ChatMessage[]>;
	getMessagesAfter(accountId: string, chatId: string, after: borogove_ChatMessage | null): Promise<borogove_ChatMessage[]>;
	getMessagesAround(accountId: string, around: borogove_ChatMessage): Promise<borogove_ChatMessage[]>;
	getChatsUnreadDetails(accountId: string, chats: borogove_Chat[]): Promise<{chatId: string, message: borogove_ChatMessage, unreadCount: number}[]>;
	storeReaction(accountId: string, update: borogove_ReactionUpdate): Promise<borogove_ChatMessage | null>;
	updateMessageStatus(accountId: string, localId: string, status: borogove_MessageStatus, statusText: string | null): Promise<borogove_ChatMessage>;
	hasMedia(hashAlgorithm: string, hash: ArrayBuffer): Promise<boolean>;
	removeMedia(hashAlgorithm: string, hash: ArrayBuffer): void;
	storeMedia(mime: string, bd: ArrayBuffer): Promise<boolean>;
	storeCaps(caps: borogove_Caps): void;
	getCaps(ver: string): Promise<borogove_Caps>;
	storeLogin(accountId: string, clientId: string, displayName: string, token: string | null): void;
	getLogin(accountId: string): Promise<{clientId: string | null, displayName: string | null, fastCount: number, token: string | null}>;
	/**
	 * Remove an account from storage
	 * @param accountId the account to remove
	 * @param completely if message history, etc should be removed also
	 */
	removeAccount(accountId: string, completely: boolean): void;
	/**
	 * List all known accounts
	 * @returns Promise resolving to array of account IDs
	 */
	listAccounts(): Promise<string[]>;
	storeStreamManagement(accountId: string, sm: ArrayBuffer | null): void;
	getStreamManagement(accountId: string): Promise<ArrayBuffer | null>;
	storeService(accountId: string, serviceId: string, name: string | null, node: string | null, caps: borogove_Caps): void;
	findServicesWithFeature(accountId: string, feature: string): Promise<{caps: borogove_Caps, name: string | null, node: string | null, serviceId: string}[]>;
}
export class borogove_persistence_Sqlite implements borogove_persistence_KeyValueStore, borogove_Persistence {
	/**
	 * Create a basic persistence layer based on sqlite
	 * @param dbfile path to sqlite database
	 * @param media a MediaStore to use for media
	 * @returns new persistence layer
	 */
	constructor(dbfile: string, media: borogove_persistence_MediaStore);
	get(k: string): Promise<string | null>;
	set(k: string, v: string | null): Promise<boolean>;
	syncPoint(accountId: string, chatId: string | null): Promise<borogove_ChatMessage | null>;
	storeChats(accountId: string, chats: borogove_Chat[]): void;
	getChats(accountId: string): Promise<borogove_SerializedChat[]>;
	storeMessages(accountId: string, messages: borogove_ChatMessage[]): Promise<borogove_ChatMessage[]>;
	updateMessage(accountId: string, message: borogove_ChatMessage): void;
	/**
	 * Get a single message
	 * @param accountId the account the message was sent or received on
	 * @param chatId the chat the message was sent or received on
	 * @param serverId the serverId of the message (optional if localId is specified)
	 * @param localId the localId of the message (optional if serverId is specified)
	 * @returns Promise resolving to the message or null
	 */
	getMessage(accountId: string, chatId: string, serverId: string | null, localId: string | null): Promise<borogove_ChatMessage | null>;
	getMessagesBefore(accountId: string, chatId: string, before: borogove_ChatMessage | null): Promise<borogove_ChatMessage[]>;
	getMessagesAfter(accountId: string, chatId: string, after: borogove_ChatMessage | null): Promise<borogove_ChatMessage[]>;
	getMessagesAround(accountId: string, around: borogove_ChatMessage): Promise<borogove_ChatMessage[]>;
	getChatsUnreadDetails(accountId: string, chats: borogove_Chat[]): Promise<{chatId: string, message: borogove_ChatMessage, unreadCount: number}[]>;
	storeReaction(accountId: string, update: borogove_ReactionUpdate): Promise<borogove_ChatMessage | null>;
	updateMessageStatus(accountId: string, localId: string, status: borogove_MessageStatus, statusText: string | null): Promise<borogove_ChatMessage>;
	hasMedia(hashAlgorithm: string, hash: ArrayBuffer): Promise<boolean>;
	removeMedia(hashAlgorithm: string, hash: ArrayBuffer): void;
	storeMedia(mime: string, bd: ArrayBuffer): Promise<boolean>;
	storeCaps(caps: borogove_Caps): void;
	getCaps(ver: string): Promise<borogove_Caps>;
	storeLogin(accountId: string, clientId: string, displayName: string, token: string | null): void;
	getLogin(accountId: string): Promise<{clientId: string | null, displayName: string | null, fastCount: number, token: string | null}>;
	/**
	 * Remove an account from storage
	 * @param accountId the account to remove
	 * @param completely if message history, etc should be removed also
	 */
	removeAccount(accountId: string, completely: boolean): void;
	/**
	 * List all known accounts
	 * @returns Promise resolving to array of account IDs
	 */
	listAccounts(): Promise<string[]>;
	storeStreamManagement(accountId: string, sm: ArrayBuffer | null): void;
	getStreamManagement(accountId: string): Promise<ArrayBuffer | null>;
	storeService(accountId: string, serviceId: string, name: string | null, node: string | null, caps: borogove_Caps): void;
	findServicesWithFeature(accountId: string, feature: string): Promise<{caps: borogove_Caps, name: string | null, node: string | null, serviceId: string}[]>;
}
export class borogove_persistence_Sqlite implements borogove_persistence_KeyValueStore, borogove_Persistence {
	/**
	 * Create a basic persistence layer based on sqlite
	 * @param dbfile path to sqlite database
	 * @param media a MediaStore to use for media
	 * @returns new persistence layer
	 */
	constructor(dbfile: string, media: borogove_persistence_MediaStore);
	get(k: string): Promise<string | null>;
	set(k: string, v: string | null): Promise<boolean>;
	syncPoint(accountId: string, chatId: string | null): Promise<borogove_ChatMessage | null>;
	storeChats(accountId: string, chats: borogove_Chat[]): void;
	getChats(accountId: string): Promise<borogove_SerializedChat[]>;
	storeMessages(accountId: string, messages: borogove_ChatMessage[]): Promise<borogove_ChatMessage[]>;
	updateMessage(accountId: string, message: borogove_ChatMessage): void;
	/**
	 * Get a single message
	 * @param accountId the account the message was sent or received on
	 * @param chatId the chat the message was sent or received on
	 * @param serverId the serverId of the message (optional if localId is specified)
	 * @param localId the localId of the message (optional if serverId is specified)
	 * @returns Promise resolving to the message or null
	 */
	getMessage(accountId: string, chatId: string, serverId: string | null, localId: string | null): Promise<borogove_ChatMessage | null>;
	getMessagesBefore(accountId: string, chatId: string, before: borogove_ChatMessage | null): Promise<borogove_ChatMessage[]>;
	getMessagesAfter(accountId: string, chatId: string, after: borogove_ChatMessage | null): Promise<borogove_ChatMessage[]>;
	getMessagesAround(accountId: string, around: borogove_ChatMessage): Promise<borogove_ChatMessage[]>;
	getChatsUnreadDetails(accountId: string, chats: borogove_Chat[]): Promise<{chatId: string, message: borogove_ChatMessage, unreadCount: number}[]>;
	storeReaction(accountId: string, update: borogove_ReactionUpdate): Promise<borogove_ChatMessage | null>;
	updateMessageStatus(accountId: string, localId: string, status: borogove_MessageStatus, statusText: string | null): Promise<borogove_ChatMessage>;
	hasMedia(hashAlgorithm: string, hash: ArrayBuffer): Promise<boolean>;
	removeMedia(hashAlgorithm: string, hash: ArrayBuffer): void;
	storeMedia(mime: string, bd: ArrayBuffer): Promise<boolean>;
	storeCaps(caps: borogove_Caps): void;
	getCaps(ver: string): Promise<borogove_Caps>;
	storeLogin(accountId: string, clientId: string, displayName: string, token: string | null): void;
	getLogin(accountId: string): Promise<{clientId: string | null, displayName: string | null, fastCount: number, token: string | null}>;
	/**
	 * Remove an account from storage
	 * @param accountId the account to remove
	 * @param completely if message history, etc should be removed also
	 */
	removeAccount(accountId: string, completely: boolean): void;
	/**
	 * List all known accounts
	 * @returns Promise resolving to array of account IDs
	 */
	listAccounts(): Promise<string[]>;
	storeStreamManagement(accountId: string, sm: ArrayBuffer | null): void;
	getStreamManagement(accountId: string): Promise<ArrayBuffer | null>;
	storeService(accountId: string, serviceId: string, name: string | null, node: string | null, caps: borogove_Caps): void;
	findServicesWithFeature(accountId: string, feature: string): Promise<{caps: borogove_Caps, name: string | null, node: string | null, serviceId: string}[]>;
}
export class borogove_persistence_Sqlite implements borogove_persistence_KeyValueStore, borogove_Persistence {
	/**
	 * Create a basic persistence layer based on sqlite
	 * @param dbfile path to sqlite database
	 * @param media a MediaStore to use for media
	 * @returns new persistence layer
	 */
	constructor(dbfile: string, media: borogove_persistence_MediaStore);
	get(k: string): Promise<string | null>;
	set(k: string, v: string | null): Promise<boolean>;
	syncPoint(accountId: string, chatId: string | null): Promise<borogove_ChatMessage | null>;
	storeChats(accountId: string, chats: borogove_Chat[]): void;
	getChats(accountId: string): Promise<borogove_SerializedChat[]>;
	storeMessages(accountId: string, messages: borogove_ChatMessage[]): Promise<borogove_ChatMessage[]>;
	updateMessage(accountId: string, message: borogove_ChatMessage): void;
	/**
	 * Get a single message
	 * @param accountId the account the message was sent or received on
	 * @param chatId the chat the message was sent or received on
	 * @param serverId the serverId of the message (optional if localId is specified)
	 * @param localId the localId of the message (optional if serverId is specified)
	 * @returns Promise resolving to the message or null
	 */
	getMessage(accountId: string, chatId: string, serverId: string | null, localId: string | null): Promise<borogove_ChatMessage | null>;
	getMessagesBefore(accountId: string, chatId: string, before: borogove_ChatMessage | null): Promise<borogove_ChatMessage[]>;
	getMessagesAfter(accountId: string, chatId: string, after: borogove_ChatMessage | null): Promise<borogove_ChatMessage[]>;
	getMessagesAround(accountId: string, around: borogove_ChatMessage): Promise<borogove_ChatMessage[]>;
	getChatsUnreadDetails(accountId: string, chats: borogove_Chat[]): Promise<{chatId: string, message: borogove_ChatMessage, unreadCount: number}[]>;
	storeReaction(accountId: string, update: borogove_ReactionUpdate): Promise<borogove_ChatMessage | null>;
	updateMessageStatus(accountId: string, localId: string, status: borogove_MessageStatus, statusText: string | null): Promise<borogove_ChatMessage>;
	hasMedia(hashAlgorithm: string, hash: ArrayBuffer): Promise<boolean>;
	removeMedia(hashAlgorithm: string, hash: ArrayBuffer): void;
	storeMedia(mime: string, bd: ArrayBuffer): Promise<boolean>;
	storeCaps(caps: borogove_Caps): void;
	getCaps(ver: string): Promise<borogove_Caps>;
	storeLogin(accountId: string, clientId: string, displayName: string, token: string | null): void;
	getLogin(accountId: string): Promise<{clientId: string | null, displayName: string | null, fastCount: number, token: string | null}>;
	/**
	 * Remove an account from storage
	 * @param accountId the account to remove
	 * @param completely if message history, etc should be removed also
	 */
	removeAccount(accountId: string, completely: boolean): void;
	/**
	 * List all known accounts
	 * @returns Promise resolving to array of account IDs
	 */
	listAccounts(): Promise<string[]>;
	storeStreamManagement(accountId: string, sm: ArrayBuffer | null): void;
	getStreamManagement(accountId: string): Promise<ArrayBuffer | null>;
	storeService(accountId: string, serviceId: string, name: string | null, node: string | null, caps: borogove_Caps): void;
	findServicesWithFeature(accountId: string, feature: string): Promise<{caps: borogove_Caps, name: string | null, node: string | null, serviceId: string}[]>;
}
export class borogove_persistence_Sqlite implements borogove_persistence_KeyValueStore, borogove_Persistence {
	/**
	 * Create a basic persistence layer based on sqlite
	 * @param dbfile path to sqlite database
	 * @param media a MediaStore to use for media
	 * @returns new persistence layer
	 */
	constructor(dbfile: string, media: borogove_persistence_MediaStore);
	get(k: string): Promise<string | null>;
	set(k: string, v: string | null): Promise<boolean>;
	syncPoint(accountId: string, chatId: string | null): Promise<borogove_ChatMessage | null>;
	storeChats(accountId: string, chats: borogove_Chat[]): void;
	getChats(accountId: string): Promise<borogove_SerializedChat[]>;
	storeMessages(accountId: string, messages: borogove_ChatMessage[]): Promise<borogove_ChatMessage[]>;
	updateMessage(accountId: string, message: borogove_ChatMessage): void;
	/**
	 * Get a single message
	 * @param accountId the account the message was sent or received on
	 * @param chatId the chat the message was sent or received on
	 * @param serverId the serverId of the message (optional if localId is specified)
	 * @param localId the localId of the message (optional if serverId is specified)
	 * @returns Promise resolving to the message or null
	 */
	getMessage(accountId: string, chatId: string, serverId: string | null, localId: string | null): Promise<borogove_ChatMessage | null>;
	getMessagesBefore(accountId: string, chatId: string, before: borogove_ChatMessage | null): Promise<borogove_ChatMessage[]>;
	getMessagesAfter(accountId: string, chatId: string, after: borogove_ChatMessage | null): Promise<borogove_ChatMessage[]>;
	getMessagesAround(accountId: string, around: borogove_ChatMessage): Promise<borogove_ChatMessage[]>;
	getChatsUnreadDetails(accountId: string, chats: borogove_Chat[]): Promise<{chatId: string, message: borogove_ChatMessage, unreadCount: number}[]>;
	storeReaction(accountId: string, update: borogove_ReactionUpdate): Promise<borogove_ChatMessage | null>;
	updateMessageStatus(accountId: string, localId: string, status: borogove_MessageStatus, statusText: string | null): Promise<borogove_ChatMessage>;
	hasMedia(hashAlgorithm: string, hash: ArrayBuffer): Promise<boolean>;
	removeMedia(hashAlgorithm: string, hash: ArrayBuffer): void;
	storeMedia(mime: string, bd: ArrayBuffer): Promise<boolean>;
	storeCaps(caps: borogove_Caps): void;
	getCaps(ver: string): Promise<borogove_Caps>;
	storeLogin(accountId: string, clientId: string, displayName: string, token: string | null): void;
	getLogin(accountId: string): Promise<{clientId: string | null, displayName: string | null, fastCount: number, token: string | null}>;
	/**
	 * Remove an account from storage
	 * @param accountId the account to remove
	 * @param completely if message history, etc should be removed also
	 */
	removeAccount(accountId: string, completely: boolean): void;
	/**
	 * List all known accounts
	 * @returns Promise resolving to array of account IDs
	 */
	listAccounts(): Promise<string[]>;
	storeStreamManagement(accountId: string, sm: ArrayBuffer | null): void;
	getStreamManagement(accountId: string): Promise<ArrayBuffer | null>;
	storeService(accountId: string, serviceId: string, name: string | null, node: string | null, caps: borogove_Caps): void;
	findServicesWithFeature(accountId: string, feature: string): Promise<{caps: borogove_Caps, name: string | null, node: string | null, serviceId: string}[]>;
}
