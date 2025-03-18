export class AvailableChat {
    		protected constructor(chatId: string, displayName: string | null, note: string, caps: borogove.Caps);
    		/**
     		 * The ID of the Chat this search result represents
     		 */
    		chatId: string;
    		/**
     		 * The display name of this search result
     		 */
    		displayName: string | null;
    		/**
     		 * A human-readable note associated with this search result
     		 */
    		note: string;
    		/**
     		 * Is this search result a channel?
     		 */
    		isChannel(): boolean;
    	}

declare namespace borogove {
    const enum UiState {
        Pinned = 0,
        Open = 1,
        Closed = 2
    }
}

declare namespace borogove.calls {
    const enum CallStatus {
        NoCall = 0,
        Incoming = 1,
        Outgoing = 2,
        Connecting = 3,
        Ongoing = 4,
        Failed = 5
    }
}

declare namespace borogove {
    const enum MessageDirection {
        MessageReceived = 0,
        MessageSent = 1
    }
}

declare namespace borogove {
    const enum EncryptionStatus {
        DecryptionSuccess = 0,
        DecryptionFailure = 1
    }
}

declare namespace borogove {
    const enum MessageStatus {
        MessagePending = 0,
        MessageDeliveredToServer = 1,
        MessageDeliveredToDevice = 2,
        MessageFailedToSend = 3
    }
}

declare namespace borogove {
    const enum MessageType {
        MessageChat = 0,
        MessageCall = 1,
        MessageChannel = 2,
        MessageChannelPrivate = 3
    }
}

declare namespace borogove {
    const enum UserState {
        Gone = 0,
        Inactive = 1,
        Active = 2,
        Composing = 3,
        Paused = 4
    }
}

declare namespace borogove {
    const enum ChatMessageEvent {
        DeliveryEvent = 0,
        CorrectionEvent = 1,
        ReactionEvent = 2,
        StatusEvent = 3
    }
}

declare namespace borogove {
    const enum ReactionUpdateKind {
        EmojiReactions = 0,
        AppendReactions = 1,
        CompleteReactions = 2
    }
}

calls {
    	export class OutgoingProposedSession implements borogove.calls.Session {
        		protected constructor(client: borogove.Client, to: borogove.JID);
        		hangup(): void;
        		accept(): void;
        		addMedia(_: MediaStream[]): void;
        		callStatus(): borogove.calls.CallStatus;
        		audioTracks(): MediaStreamTrack[];
        		videoTracks(): MediaStreamTrack[];
        		dtmf(): RTCDTMFSender | null | null;
        		get_sid(): string;
        		get_chatId(): string;
        		static __meta__: any;
        	}
}

calls {
    	export interface Session {
        		get_sid(): string;
        		get_chatId(): string;
        		accept(): void;
        		hangup(): void;
        		addMedia(streams: MediaStream[]): void;
        		callStatus(): borogove.calls.CallStatus;
        		audioTracks(): MediaStreamTrack[];
        		videoTracks(): MediaStreamTrack[];
        		dtmf(): RTCDTMFSender | null;
        	}
}

calls {
    	export class Attribute {
        		constructor(key: string, value: string);
        		readonly key: string;
        		readonly value: string;
        		toSdp(): string;
        		toString(): string;
        		static parse(input: string): borogove.calls.Attribute;
        	}
}

calls {
    	export class Media {
        		constructor(mid: string, media: string, connectionData: string, port: string, protocol: string, attributes: borogove.calls.Attribute[], formats: number[]);
        		readonly mid: string;
        		readonly media: string;
        		readonly connectionData: string;
        		readonly port: string;
        		readonly protocol: string;
        		readonly attributes: borogove.calls.Attribute[];
        		readonly formats: number[];
        		toSdp(): string;
        		contentElement(initiator: boolean): borogove.Stanza;
        		toElement(sessionAttributes: borogove.calls.Attribute[], initiator: boolean): borogove.Stanza;
        		getUfragPwd(sessionAttributes?: borogove.calls.Attribute[] | null): {pwd: string, ufrag: string};
        		toTransportElement(sessionAttributes: borogove.calls.Attribute[]): borogove.Stanza;
        		static fromElement(content: borogove.Stanza, initiator: boolean, hasGroup: boolean, existingDescription?: borogove.calls.SessionDescription | null): borogove.calls.Media;
        	}
}

calls {
    	export class SessionDescription {
        		constructor(version: number, name: string, media: borogove.calls.Media[], attributes: borogove.calls.Attribute[], identificationTags: string[]);
        		readonly version: number;
        		readonly name: string;
        		readonly media: borogove.calls.Media[];
        		readonly attributes: borogove.calls.Attribute[];
        		readonly identificationTags: string[];
        		getUfragPwd(): {pwd: string, ufrag: string} | null;
        		getFingerprint(): borogove.calls.Attribute | null;
        		getDtlsSetup(): string;
        		addContent(newDescription: borogove.calls.SessionDescription): borogove.calls.SessionDescription;
        		toSdp(): string;
        		toStanza(action: string, sid: string, initiator: boolean): borogove.Stanza;
        		static parse(input: string): borogove.calls.SessionDescription;
        		static fromStanza(iq: borogove.Stanza, initiator: boolean, existingDescription?: borogove.calls.SessionDescription | null): borogove.calls.SessionDescription;
        	}
}

calls {
    	export class InitiatedSession implements borogove.calls.Session {
        		protected constructor(client: borogove.Client, counterpart: borogove.JID, sid: string, remoteDescription: borogove.calls.SessionDescription | null);
        		get_sid(): string;
        		get_chatId(): string;
        		accept(): void;
        		hangup(): void;
        		addMedia(streams: MediaStream[]): void;
        		callStatus(): borogove.calls.CallStatus;
        		audioTracks(): MediaStreamTrack[];
        		videoTracks(): MediaStreamTrack[];
        		dtmf(): RTCDTMFSender | null;
        		supplyMedia(streams: MediaStream[]): void;
        	}
}

export const enum CallStatus {
    NoCall = 0,
    Incoming = 1,
    Outgoing = 2,
    Connecting = 3,
    Ongoing = 4,
    Failed = 5
}

export class Caps {
    		constructor(node: string, identities: borogove.Identity[], features: string[], ver?: ArrayBuffer | null);
    		node: string;
    		identities: borogove.Identity[];
    		features: string[];
    		isChannel(chatId: string): boolean;
    		discoReply(): borogove.Stanza;
    		addC(stanza: borogove.Stanza): borogove.Stanza;
    		verRaw(): borogove.Hash;
    		ver(): string;
    	}

export class Channel extends borogove.Chat {
    		protected constructor(client: borogove.Client, stream: borogove.GenericStream, persistence: borogove.Persistence, chatId: string, uiState?: borogove.UiState, isBlocked?: boolean, extensions?: borogove.Stanza | null, readUpToId?: string | null, readUpToBy?: string | null, disco?: borogove.Caps | null);
    		setPresence(resource: string, presence: borogove.Presence): void;
    		isTrusted(): boolean;
    		isPrivate(): boolean;
    		preview(): string;
    		syncing(): boolean;
    		canAudioCall(): boolean;
    		canVideoCall(): boolean;
    		getParticipants(): string[];
    		getParticipantDetails(participantId: string): borogove.Participant;
    		getMessagesBefore(beforeId: string | null, beforeTime: string | null): Promise<borogove.ChatMessage[]>;
    		getMessagesAfter(afterId: string | null, afterTime: string | null): Promise<borogove.ChatMessage[]>;
    		getMessagesAround(aroundId: string | null, aroundTime: string | null): Promise<borogove.ChatMessage[]>;
    		correctMessage(localId: string, message: borogove.ChatMessageBuilder): void;
    		sendMessage(message: borogove.ChatMessageBuilder): void;
    		removeReaction(m: borogove.ChatMessage, reaction: borogove.Reaction): void;
    		lastMessageId(): string | null;
    		markReadUpTo(message: borogove.ChatMessage): void;
    		bookmark(): void;
    		close(): void;
    	}

export class Chat {
    		protected constructor(client: borogove.Client, stream: borogove.GenericStream, persistence: borogove.Persistence, chatId: string, uiState?: borogove.UiState, isBlocked?: boolean, extensions?: borogove.Stanza | null, readUpToId?: string | null, readUpToBy?: string | null, omemoContactDeviceIDs?: number[] | null);
    		/**
     		 * ID of this Chat
     		 */
    		readonly chatId: string;
    		/**
     		 * Current state of this chat
     		 */
    		readonly uiState: borogove.UiState;
    		/**
     		 * Is this chat blocked?
     		 */
    		readonly isBlocked: boolean;
    		/**
     		 * The most recent message in this chat
     		 */
    		readonly lastMessage: borogove.ChatMessage | null;
    		/**
     		 * Fetch a page of messages before some point
     		 * @param beforeId id of the message to look before
     		 * @param beforeTime timestamp of the message to look before,
     		 * String in format YYYY-MM-DDThh:mm:ss[.sss]+00:00
     		 * @returns Promise resolving to an array of ChatMessage that are found
     		 */
    		getMessagesBefore(beforeId: string | null, beforeTime: string | null): Promise<borogove.ChatMessage[]>;
    		/**
     		 * Fetch a page of messages after some point
     		 * @param afterId id of the message to look after
     		 * @param afterTime timestamp of the message to look after,
     		 * String in format YYYY-MM-DDThh:mm:ss[.sss]+00:00
     		 * @returns Promise resolving to an array of ChatMessage that are found
     		 */
    		getMessagesAfter(afterId: string | null, afterTime: string | null): Promise<borogove.ChatMessage[]>;
    		/**
     		 * Fetch a page of messages around (before, including, and after) some point
     		 * @param aroundId id of the message to look around
     		 * @param aroundTime timestamp of the message to look around,
     		 * String in format YYYY-MM-DDThh:mm:ss[.sss]+00:00
     		 * @returns Promise resolving to an array of ChatMessage that are found
     		 */
    		getMessagesAround(aroundId: string | null, aroundTime: string | null): Promise<borogove.ChatMessage[]>;
    		/**
     		 * Send a ChatMessage to this Chat
     		 * @param message the ChatMessage to send
     		 */
    		sendMessage(message: borogove.ChatMessageBuilder): void;
    		/**
     		 * Signals that all messages up to and including this one have probably
     		 * been displayed to the user
     		 * @param message the ChatMessage most recently displayed
     		 */
    		markReadUpTo(message: borogove.ChatMessage): void;
    		/**
     		 * Save this Chat on the server
     		 */
    		bookmark(): void;
    		/**
     		 * Get the list of IDs of participants in this Chat
     		 * @returns array of IDs
     		 */
    		getParticipants(): string[];
    		/**
     		 * Get the details for one participant in this Chat
     		 * @param participantId the ID of the participant to look up
     		 */
    		getParticipantDetails(participantId: string): borogove.Participant;
    		/**
     		 * Correct an already-send message by replacing it with a new one
     		 * @param localId the localId of the message to correct
     		 * must be the localId of the first version ever sent, not a subsequent correction
     		 * @param message the new ChatMessage to replace it with
     		 */
    		correctMessage(localId: string, message: borogove.ChatMessageBuilder): void;
    		/**
     		 * Add new reaction to a message in this Chat
     		 * @param m ChatMessage to react to
     		 * @param reaction emoji of the reaction
     		 */
    		addReaction(m: borogove.ChatMessage, reaction: borogove.Reaction): void;
    		/**
     		 * Remove an already-sent reaction from a message
     		 * @param m ChatMessage to remove the reaction from
     		 * @param reaction the emoji to remove
     		 */
    		removeReaction(m: borogove.ChatMessage, reaction: borogove.Reaction): void;
    		/**
     		 * Call this whenever the user is typing, can call on every keystroke
     		 * @param threadId optional, what thread the user has selected if any
     		 * @param content optional, what the user has typed so far
     		 */
    		typing(threadId: string | null, content: string | null): void;
    		/**
     		 * Call this whenever the user makes a chat or thread "active" in your UX
     		 * If you call this with true you MUST later call it will false
     		 * @param active true if the chat is "active", false otherwise
     		 * @param threadId optional, what thread the user has selected if any
     		 */
    		setActive(active: boolean, threadId: string | null): void;
    		/**
     		 * Archive this chat
     		 */
    		close(): void;
    		/**
     		 * Pin or unpin this chat
     		 */
    		togglePinned(): void;
    		/**
     		 * Block this chat so it will not re-open
     		 */
    		block(reportSpam?: borogove.ChatMessage | null, onServer?: boolean): void;
    		/**
     		 * Unblock this chat so it will open again
     		 */
    		unblock(onServer: boolean): void;
    		/**
     		 * Update notification preferences
     		 */
    		setNotifications(filtered: boolean, mention: boolean, reply: boolean): void;
    		/**
     		 * Should notifications be filtered?
     		 */
    		notificationsFiltered(): boolean;
    		/**
     		 * Should a mention produce a notification?
     		 */
    		notifyMention(): boolean;
    		/**
     		 * Should a reply produce a notification?
     		 */
    		notifyReply(): boolean;
    		/**
     		 * An ID of the most recent message in this chat
     		 */
    		lastMessageId(): string | null;
    		/**
     		 * Get the URI image to represent this Chat, or null
     		 */
    		getPhoto(): string | null;
    		/**
     		 * Get the URI to a placeholder image to represent this Chat
     		 */
    		getPlaceholder(): string;
    		/**
     		 * An ID of the last message displayed to the user
     		 */
    		readUpTo(): string | null;
    		/**
     		 * The number of message that have not yet been displayed to the user
     		 */
    		unreadCount(): number;
    		/**
     		 * A preview of the chat, such as the most recent message body
     		 */
    		preview(): string;
    		/**
     		 * Set the display name to use for this chat
     		 * @param displayName String to use as display name
     		 */
    		setDisplayName(displayName: string): void;
    		/**
     		 * The display name of this Chat
     		 */
    		getDisplayName(): string;
    		/**
     		 * Set if this chat is to be trusted with our presence, etc
     		 * @param trusted Bool if trusted or not
     		 */
    		setTrusted(trusted: boolean): void;
    		/**
     		 * Is this a chat with an entity we trust to see our online status?
     		 */
    		isTrusted(): boolean;
    		/**
     		 * @returns if this chat is currently syncing with the server
     		 */
    		syncing(): boolean;
    		/**
     		 * Can audio calls be started in this Chat?
     		 */
    		canAudioCall(): boolean;
    		/**
     		 * Can video calls be started in this Chat?
     		 */
    		canVideoCall(): boolean;
    		/**
     		 * Start a new call in this Chat
     		 * @param audio do we want audio in this call
     		 * @param video do we want video in this call
     		 */
    		startCall(audio: boolean, video: boolean): borogove.calls.OutgoingProposedSession;
    		addMedia(streams: MediaStream[]): void;
    		/**
     		 * Accept any incoming calls in this Chat
     		 */
    		acceptCall(): void;
    		/**
     		 * Hangup or reject any calls in this chat
     		 */
    		hangup(): void;
    		/**
     		 * The current status of a call in this chat
     		 */
    		callStatus(): borogove.calls.CallStatus;
    		/**
     		 * A DTMFSender for a call in this chat, or NULL
     		 */
    		dtmf(): RTCDTMFSender | null;
    		/**
     		 * All video tracks in all active calls in this chat
     		 */
    		videoTracks(): MediaStreamTrack[];
    		/**
     		 * Get encryption mode for this chat
     		 */
    		encryptionMode(): string;
    	}

export class ChatAttachment {
    		constructor(name: string | null, mime: string, size: number | null, uris: string[], hashes: borogove.Hash[]);
    		/**
     		 * Filename
     		 */
    		name: string | null;
    		/**
     		 * MIME Type
     		 */
    		mime: string;
    		/**
     		 * Size in bytes
     		 */
    		size: number | null;
    		/**
     		 * URIs to data
     		 */
    		uris: string[];
    		/**
     		 * Hashes of data
     		 */
    		hashes: borogove.Hash[];
    	}

export class ChatMessage {
    		protected constructor(params: {attachments?: borogove.ChatAttachment[] | null, direction?: borogove.MessageDirection | null, encryption?: borogove.EncryptionInfo | null, from: borogove.JID, lang?: string | null, localId?: string | null, payloads?: borogove.Stanza[] | null, reactions?: Map<string,borogove.Reaction[]> | null, recipients?: borogove.JID[] | null, replyId?: string | null, replyTo?: borogove.JID[] | null, replyToMessage?: borogove.ChatMessage | null, senderId: string, serverId?: string | null, serverIdBy?: string | null, stanza?: borogove.Stanza | null, status?: borogove.MessageStatus | null, syncPoint?: boolean | null, text?: string | null, threadId?: string | null, timestamp: string, to: borogove.JID, type?: borogove.MessageType | null, versions?: borogove.ChatMessage[] | null});
    		/**
     		 * The ID as set by the creator of this message
     		 */
    		localId: string | null;
    		/**
     		 * The ID as set by the authoritative server
     		 */
    		serverId: string | null;
    		/**
     		 * The ID of the server which set the serverId
     		 */
    		serverIdBy: string | null;
    		/**
     		 * The type of this message (Chat, Call, etc)
     		 */
    		type: borogove.MessageType;
    		/**
     		 * The timestamp of this message, in format YYYY-MM-DDThh:mm:ss[.sss]Z
     		 */
    		timestamp: string;
    		/**
     		 * The ID of the sender of this message
     		 */
    		senderId: string;
    		/**
     		 * Message this one is in reply to, or NULL
     		 */
    		readonly replyToMessage: borogove.ChatMessage | null;
    		/**
     		 * ID of the thread this message is in, or NULL
     		 */
    		threadId: string | null;
    		/**
     		 * Array of attachments to this message
     		 */
    		attachments: borogove.ChatAttachment[];
    		/**
     		 * Map of reactions to this message
     		 */
    		readonly reactions: Map<string,borogove.Reaction[]>;
    		/**
     		 * Body text of this message or NULL
     		 */
    		text: string | null;
    		/**
     		 * Language code for the body text
     		 */
    		lang: string | null;
    		/**
     		 * Direction of this message
     		 */
    		direction: borogove.MessageDirection;
    		/**
     		 * Status of this message
     		 */
    		status: borogove.MessageStatus;
    		/**
     		 * Array of past versions of this message, if it has been edited
     		 */
    		versions: borogove.ChatMessage[];
    		/**
     		 * Information about the encryption used by the sender of
     		 * this message.
     		 */
    		encryption: borogove.EncryptionInfo | null;
    		/**
     		 * Create a new ChatMessage in reply to this one
     		 */
    		reply(): borogove.ChatMessageBuilder;
    		/**
     		 * Get HTML version of the message body
     		 * WARNING: this is possibly untrusted HTML. You must parse or sanitize appropriately!
     		 * @param sender optionally specify the full details of the sender
     		 */
    		html(sender?: borogove.Participant | null): string;
    		/**
     		 * The ID of the Chat this message is associated with
     		 */
    		chatId(): string;
    		/**
     		 * The ID of the account associated with this message
     		 */
    		account(): string;
    		/**
     		 * Is this an incoming message?
     		 */
    		isIncoming(): boolean;
    		/**
     		 * The URI of an icon for the thread associated with this message, or NULL
     		 */
    		threadIcon(): string | null | null;
    		/**
     		 * The last status of the call if this message is related to a call
     		 */
    		callStatus(): string | null;
    		/**
     		 * The session id of the call if this message is related to a call
     		 */
    		callSid(): string | null;
    		/**
     		 * The duration of the call if this message is related to a call
     		 */
    		callDuration(): string | null;
    	}

export class ChatMessageBuilder {
    		/**
     		 * @returns a new blank ChatMessageBuilder
     		 */
    		constructor(params?: {attachments?: borogove.ChatAttachment[] | null, direction?: borogove.MessageDirection | null, encryption?: borogove.EncryptionInfo | null, html?: string | null, lang?: string | null, localId?: string | null, payloads?: borogove.Stanza[] | null, reactions?: Map<string,borogove.Reaction[]> | null, replyId?: string | null, replyToMessage?: borogove.ChatMessage | null, senderId?: string | null, serverId?: string | null, serverIdBy?: string | null, status?: borogove.MessageStatus | null, syncPoint?: boolean | null, text?: string | null, threadId?: string | null, timestamp?: string | null, type?: borogove.MessageType | null, versions?: borogove.ChatMessage[] | null} | null);
    		/**
     		 * The ID as set by the creator of this message
     		 */
    		localId: string | null;
    		/**
     		 * The ID as set by the authoritative server
     		 */
    		serverId: string | null;
    		/**
     		 * The ID of the server which set the serverId
     		 */
    		serverIdBy: string | null;
    		/**
     		 * The type of this message (Chat, Call, etc)
     		 */
    		type: borogove.MessageType;
    		/**
     		 * The timestamp of this message, in format YYYY-MM-DDThh:mm:ss[.sss]+00:00
     		 */
    		timestamp: string | null;
    		/**
     		 * The ID of the message sender
     		 */
    		/**
     		 * Message this one is in reply to, or NULL
     		 */
    		replyToMessage: borogove.ChatMessage | null;
    		/**
     		 * ID of the thread this message is in, or NULL
     		 */
    		threadId: string | null;
    		/**
     		 * Array of attachments to this message
     		 */
    		readonly attachments: borogove.ChatAttachment[];
    		/**
     		 * Map of reactions to this message
     		 */
    		reactions: Map<string,borogove.Reaction[]>;
    		/**
     		 * Body text of this message or NULL
     		 */
    		text: string | null;
    		/**
     		 * Language code for the body text
     		 */
    		lang: string | null;
    		/**
     		 * Direction of this message
     		 */
    		direction: borogove.MessageDirection;
    		/**
     		 * Status of this message
     		 */
    		status: borogove.MessageStatus;
    		/**
     		 * Array of past versions of this message, if it has been edited
     		 */
    		versions: borogove.ChatMessage[];
    		/**
     		 * Information about the encryption used by the sender of
     		 * this message.
     		 */
    		encryption: borogove.EncryptionInfo | null;
    		/**
     		 * Add an attachment to this message
     		 * @param attachment The ChatAttachment to add
     		 */
    		addAttachment(attachment: borogove.ChatAttachment): void;
    		/**
     		 * Set rich text using an HTML string
     		 * Also sets the plain text body appropriately
     		 */
    		setHtml(html: string): void;
    		/**
     		 * The ID of the Chat this message is associated with
     		 */
    		chatId(): string;
    		/**
     		 * The ID of the sender of this message
     		 */
    		get_senderId(): string;
    		/**
     		 * Build this builder into an immutable ChatMessage
     		 * @returns the ChatMessage
     		 */
    		build(): borogove.ChatMessage;
    	}

export const enum ChatMessageEvent {
    DeliveryEvent = 0,
    CorrectionEvent = 1,
    ReactionEvent = 2,
    StatusEvent = 3
}

export class Client extends borogove.EventEmitter {
    		/**
     		 * Create a new Client to connect to a particular account
     		 * @param address the account to connect to
     		 * @param persistence the persistence layer to use for storage
     		 */
    		constructor(address: string, persistence: borogove.Persistence);
    		/**
     		 * Set to false to suppress sending available presence
     		 */
    		sendAvailable: boolean;
    		/**
     		 * Start this client running and trying to connect to the server
     		 */
    		start(): void;
    		/**
     		 * Gets the client ready to use but does not connect to the server
     		 * @returns Promise resolving to true once the Client is ready
     		 */
    		startOffline(): Promise<boolean>;
    		/**
     		 * Destroy local data for this account
     		 * @param completely if true chats, messages, etc will be deleted as well
     		 */
    		logout(completely: boolean): void;
    		/**
     		 * Sets the password to be used in response to the password needed event
     		 * @param password
     		 */
    		usePassword(password: string): void;
    		/**
     		 * Get the account ID for this Client
     		 * @returns account id
     		 */
    		accountId(): string;
    		/**
     		 * Get the current display name for this account
     		 * @returns display name
     		 */
    		displayName(): string;
    		/**
     		 * Set the current display name for this account on the server
     		 * @param display name to set (ignored if empty or NULL)
     		 */
    		setDisplayName(displayName: string): void;
    		/**
     		 * Turn a file into a ChatAttachment for attaching to a ChatMessage
     		 * @param source The AttachmentSource to use
     		 * @returns Promise resolving to a ChatAttachment or null
     		 */
    		prepareAttachment(source: File): Promise<borogove.ChatAttachment | null>;
    		/**
     		 * @returns array of open chats, sorted by last activity
     		 */
    		getChats(): borogove.Chat[];
    		/**
     		 * Search for chats the user can start or join
     		 * @param q the search query to use
     		 * @param callback takes two arguments, the query that was used and the array of results
     		 */
    		findAvailableChats(q: string, callback: (arg0: string, arg1: borogove.AvailableChat[]) => boolean): void;
    		/**
     		 * Start or join a chat from the search results
     		 * @returns the chat that was started
     		 */
    		startChat(availableChat: borogove.AvailableChat): borogove.Chat;
    		/**
     		 * Find a chat by id
     		 * @returns the chat if known, or NULL
     		 */
    		getChat(chatId: string): borogove.Chat | null;
    		subscribePush(reg: ServiceWorkerRegistration, push_service: string, vapid_key: {privateKey: CryptoKey, publicKey: CryptoKey}, grace?: number | null): void;
    		/**
     		 * Enable push notifications
     		 * @param push_service the address of a push proxy
     		 * @param vapid_private_pkcs8 the private key for signing JWT of the push service
     		 * @param endpoint the final target for the push proxy to forward to
     		 * @param p256dh A P-256 uncompressed point in ANSI X9.62 format
     		 * @param auth Random 16 octed value
     		 * @param grace Grace period during which not to generate push if another app is active for same account, in seconds (negative for none)
     		 * @param claims Optional additional JWT claims as key then value
     		 */
    		enablePush(push_service: string, endpoint: string, p256dh: ArrayBuffer, auth: ArrayBuffer, grace: number, vapid_private_pkcs8?: ArrayBuffer | null, claims?: string[] | null): void;
    		/**
     		 * Event fired when client needs a password for authentication
     		 * @param handler takes one argument, the Client that needs a password
     		 * @returns token for use with removeEventListener
     		 */
    		addPasswordNeededListener(handler: (arg0: borogove.Client) => void): number;
    		/**
     		 * Event fired when client is connected and fully synchronized
     		 * @param handler takes no arguments
     		 * @returns token for use with removeEventListener
     		 */
    		addStatusOnlineListener(handler: () => void): number;
    		/**
     		 * Event fired when client is disconnected
     		 * @param handler takes no arguments
     		 * @returns token for use with removeEventListener
     		 */
    		addStatusOfflineListener(handler: () => void): number;
    		/**
     		 * Event fired when connection fails with a fatal error and will not be retried
     		 * @param handler takes no arguments
     		 * @returns token for use with removeEventListener
     		 */
    		addConnectionFailedListener(handler: () => void): number;
    		/**
     		 * Event fired when TLS checks fail, to give client the chance to override
     		 * @param handler takes two arguments, the PEM of the cert and an array of DNS names, and must return true to accept or false to reject
     		 * @returns token for use with removeEventListener
     		 */
    		addTlsCheckListener(handler: (arg0: string, arg1: string[]) => boolean): number;
    		addUserStateListener(handler: (arg0: string, arg1: string, arg2: string | null, arg3: borogove.UserState) => void): number;
    		/**
     		 * Event fired when a new ChatMessage comes in on any Chat
     		 * Also fires when status of a ChatMessage changes,
     		 * when a ChatMessage is edited, or when a reaction is added
     		 * @param handler takes two arguments, the ChatMessage and ChatMessageEvent enum describing what happened
     		 * @returns token for use with removeEventListener
     		 */
    		addChatMessageListener(handler: (arg0: borogove.ChatMessage, arg1: borogove.ChatMessageEvent) => void): number;
    		/**
     		 * Event fired when syncing a new ChatMessage that was send when offline.
     		 * Normally you don't want this, but it may be useful if you want to notify on app start.
     		 * @param handler takes one argument, the ChatMessage
     		 * @returns token for use with removeEventListener
     		 */
    		addSyncMessageListener(handler: (arg0: borogove.ChatMessage) => void): number;
    		/**
     		 * Event fired when a Chat's metadata is updated, or when a new Chat is added
     		 * @param handler takes one argument, an array of Chats that were updated
     		 * @returns token for use with removeEventListener
     		 */
    		addChatsUpdatedListener(handler: (arg0: borogove.Chat[]) => void): number;
    		/**
     		 * Event fired when a new call comes in
     		 * @param handler takes one argument, the call Session
     		 * @returns token for use with removeEventListener
     		 */
    		addCallRingListener(handler: (arg0: borogove.calls.Session) => void): number;
    		/**
     		 * Event fired when a call is retracted or hung up
     		 * @param handler takes two arguments, the associated Chat ID and Session ID
     		 * @returns token for use with removeEventListener
     		 */
    		addCallRetractListener(handler: (arg0: string, arg1: string) => void): number;
    		/**
     		 * Event fired when an outgoing call starts ringing
     		 * @param handler takes two arguments, the associated Chat ID and Session ID
     		 * @returns token for use with removeEventListener
     		 */
    		addCallRingingListener(handler: (arg0: borogove.calls.Session) => void): number;
    		/**
     		 * Event fired when an existing call changes status (connecting, failed, etc)
     		 * @param handler takes one argument, the associated Session
     		 * @returns token for use with removeEventListener
     		 */
    		addCallUpdateStatusListener(handler: (arg0: borogove.calls.InitiatedSession) => void): number;
    		/**
     		 * Event fired when a call is asking for media to send
     		 * @param handler takes three arguments, the call Session,
     		 * a boolean indicating if audio is desired,
     		 * and a boolean indicating if video is desired
     		 * @returns token for use with removeEventListener
     		 */
    		addCallMediaListener(handler: (arg0: borogove.calls.InitiatedSession, arg1: boolean, arg2: boolean) => void): number;
    		/**
     		 * Event fired when call has a new MediaStreamTrack to play
     		 * @param handler takes three arguments, the associated Chat ID,
     		 * the new MediaStreamTrack, and an array of any associated MediaStreams
     		 * @returns token for use with removeEventListener
     		 */
    		addCallTrackListener(handler: (arg0: borogove.calls.InitiatedSession, arg1: MediaStreamTrack, arg2: MediaStream[]) => void): number;
    		/**
     		 * Let the SDK know the UI is in the foreground
     		 */
    		setInForeground(): void;
    		/**
     		 * Let the SDK know the UI is in the foreground
     		 */
    		setNotInForeground(): void;
    	}

export class Config {
    		protected constructor();
    		/**
     		 * Produce /.well-known/ni/ paths instead of ni:/// URIs
     		 * for referencing media by hash.
     		 * This can be useful eg for intercepting with a Service Worker.
     		 */
    		static relativeHashUri: boolean;
    	}

export class CustomEmojiReaction extends borogove.Reaction {
    		protected constructor(senderId: string, timestamp: string, text: string, uri: string, envelopeId?: string | null);
    		uri: string;
    		render<T>(forText: (arg0: string) => T, forImage: (arg0: string, arg1: string) => T): T;
    		/**
     		 * Create a new custom emoji reaction to send
     		 * @param text name of custom emoji
     		 * @param uri URI for media of custom emoji
     		 * @returns Reaction
     		 */
    		static custom(text: string, uri: string): borogove.CustomEmojiReaction;
    	}

export class DirectChat extends borogove.Chat {
    		protected constructor(client: borogove.Client, stream: borogove.GenericStream, persistence: borogove.Persistence, chatId: string, uiState?: borogove.UiState, isBlocked?: boolean, extensions?: borogove.Stanza | null, readUpToId?: string | null, readUpToBy?: string | null, omemoContactDeviceIDs?: number[] | null);
    		getParticipants(): string[];
    		getParticipantDetails(participantId: string): borogove.Participant;
    		getMessagesBefore(beforeId: string | null, beforeTime: string | null): Promise<borogove.ChatMessage[]>;
    		getMessagesAfter(afterId: string | null, afterTime: string | null): Promise<borogove.ChatMessage[]>;
    		getMessagesAround(aroundId: string | null, aroundTime: string | null): Promise<borogove.ChatMessage[]>;
    		correctMessage(localId: string, message: borogove.ChatMessageBuilder): void;
    		sendMessage(message: borogove.ChatMessageBuilder): void;
    		removeReaction(m: borogove.ChatMessage, reaction: borogove.Reaction): void;
    		lastMessageId(): string | null;
    		markReadUpTo(message: borogove.ChatMessage): void;
    		bookmark(): void;
    		close(): void;
    	}

export class EventEmitter {
    		protected constructor();
    		/**
     		 * Remove an event listener of any type, no matter how it was added
     		 * or what event it is for.
     		 * @param token the token that was returned when the listener was added
     		 */
    		removeEventListener(token: number): void;
    	}

export class Hash {
    		protected constructor(algorithm: string, hash: ArrayBuffer);
    		/**
     		 * Hash algorithm name
     		 */
    		algorithm: string;
    		/**
     		 * Represent this Hash as a URI
     		 * @returns URI as a string
     		 */
    		toUri(): string;
    		/**
     		 * Represent this Hash as a hex string
     		 * @returns hex string
     		 */
    		toHex(): string;
    		/**
     		 * Represent this Hash as a Base64 string
     		 * @returns Base64-encoded string
     		 */
    		toBase64(): string;
    		/**
     		 * Represent this Hash as a Base64url string
     		 * @returns Base64url-encoded string
     		 */
    		toBase64Url(): string;
    		/**
     		 * Create a new Hash from a hex string
     		 * @param algorithm name per https://xmpp.org/extensions/xep-0300.html
     		 * @param hash in hex format
     		 * @returns Hash or null on error
     		 */
    		static fromHex(algorithm: string, hash: string): borogove.Hash | null;
    		/**
     		 * Create a new Hash from a ni:, cid: or similar URI
     		 * @param uri The URI
     		 * @returns Hash or null on error
     		 */
    		static fromUri(uri: string): borogove.Hash | null;
    	}

export class Identicon {
    		protected constructor();
    		static svg(source: string): string;
    	}

export class Identity {
    		constructor(category: string, type: string, name: string);
    		category: string;
    		type: string;
    		name: string;
    		addToDisco(stanza: borogove.Stanza): void;
    		ver(): string;
    	}

export const enum MessageDirection {
    MessageReceived = 0,
    MessageSent = 1
}

export const enum MessageStatus {
    MessagePending = 0,
    MessageDeliveredToServer = 1,
    MessageDeliveredToDevice = 2,
    MessageFailedToSend = 3
}

export const enum MessageType {
    MessageChat = 0,
    MessageCall = 1,
    MessageChannel = 2,
    MessageChannelPrivate = 3
}

class Notification_2 {
    		protected constructor(title: string, body: string, accountId: string, chatId: string, senderId: string, messageId: string, type: borogove.MessageType, callStatus: string | null, callSid: string | null, imageUri: string | null, lang: string | null, timestamp: string | null);
    		/**
     		 * The title
     		 */
    		title: string;
    		/**
     		 * The body text
     		 */
    		body: string;
    		/**
     		 * The ID of the associated account
     		 */
    		accountId: string;
    		/**
     		 * The ID of the associated chat
     		 */
    		chatId: string;
    		/**
     		 * The ID of the message sender
     		 */
    		senderId: string;
    		/**
     		 * The serverId of the message
     		 */
    		messageId: string;
    		/**
     		 * The type of the message
     		 */
    		type: borogove.MessageType;
    		/**
     		 * If this is a call notification, the call status
     		 */
    		callStatus: string | null;
    		/**
     		 * If this is a call notification, the call session ID
     		 */
    		callSid: string | null;
    		/**
     		 * Optional image URI
     		 */
    		imageUri: string | null;
    		/**
     		 * Optional language code
     		 */
    		lang: string | null;
    		/**
     		 * Optional date and time of the event
     		 */
    		timestamp: string | null;
    	}
export { Notification_2 as Notification }

export class Participant {
    		protected constructor(displayName: string, photoUri: string | null, placeholderUri: string, isSelf: boolean);
    		displayName: string;
    		photoUri: string | null;
    		placeholderUri: string;
    		isSelf: boolean;
    	}

export interface Persistence {
    		lastId(accountId: string, chatId: string | null): Promise<string | null>;
    		storeChats(accountId: string, chats: borogove.Chat[]): void;
    		getChats(accountId: string): Promise<borogove.SerializedChat[]>;
    		getChatsUnreadDetails(accountId: string, chats: borogove.Chat[]): Promise<{chatId: string, message: borogove.ChatMessage, unreadCount: number}[]>;
    		storeReaction(accountId: string, update: borogove.ReactionUpdate): Promise<borogove.ChatMessage | null>;
    		storeMessages(accountId: string, message: borogove.ChatMessage[]): Promise<borogove.ChatMessage[]>;
    		updateMessage(accountId: string, message: borogove.ChatMessage): void;
    		updateMessageStatus(accountId: string, localId: string, status: borogove.MessageStatus): Promise<borogove.ChatMessage>;
    		getMessage(accountId: string, chatId: string, serverId: string | null, localId: string | null): Promise<borogove.ChatMessage | null>;
    		getMessagesBefore(accountId: string, chatId: string, beforeId: string | null, beforeTime: string | null): Promise<borogove.ChatMessage[]>;
    		getMessagesAfter(accountId: string, chatId: string, afterId: string | null, afterTime: string | null): Promise<borogove.ChatMessage[]>;
    		getMessagesAround(accountId: string, chatId: string, aroundId: string | null, aroundTime: string | null): Promise<borogove.ChatMessage[]>;
    		hasMedia(hashAlgorithm: string, hash: ArrayBuffer): Promise<boolean>;
    		storeMedia(mime: string, bytes: ArrayBuffer): Promise<boolean>;
    		removeMedia(hashAlgorithm: string, hash: ArrayBuffer): void;
    		storeCaps(caps: borogove.Caps): void;
    		getCaps(ver: string): Promise<borogove.Caps | null>;
    		storeLogin(login: string, clientId: string, displayName: string, token: string | null): void;
    		getLogin(login: string): Promise<{clientId: string | null, displayName: string | null, fastCount: number, token: string | null}>;
    		removeAccount(accountId: string, completely: boolean): void;
    		listAccounts(): Promise<string[]>;
    		storeStreamManagement(accountId: string, data: ArrayBuffer | null): void;
    		getStreamManagement(accountId: string): Promise<ArrayBuffer | null>;
    		storeService(accountId: string, serviceId: string, name: string | null, node: string | null, caps: borogove.Caps): void;
    		findServicesWithFeature(accountId: string, feature: string): Promise<{caps: borogove.Caps, name: string | null, node: string | null, serviceId: string}[]>;
    	}

export declare namespace persistence {
    const IDB: any;
    import KeyValueStore = borogove.persistence.KeyValueStore;
    import MediaStore = borogove.persistence.MediaStore;
    const MediaStoreCache: any;
    import Dummy = borogove.persistence.Dummy;
    import Sqlite = borogove.persistence.Sqlite;
}

export class Push {
    		protected constructor();
    		/**
     		 * Receive a new push notification from some external system
     		 * @param data the raw data from the push
     		 * @param persistence the persistence layer to write into
     		 * @returns a Notification representing the push data
     		 */
    		static receive(data: string, persistence: borogove.Persistence): borogove.Notification | null;
    	}

export class Reaction {
    		protected constructor(senderId: string, timestamp: string, text: string, envelopeId?: string | null, key?: string | null);
    		/**
     		 * ID of who sent this Reaction
     		 */
    		senderId: string;
    		/**
     		 * Date and time when this Reaction was sent,
     		 * in format YYYY-MM-DDThh:mm:ss[.sss]+00:00
     		 */
    		timestamp: string;
    		/**
     		 * Key for grouping reactions
     		 */
    		key: string;
    		/**
     		 * Create a new Unicode reaction to send
     		 * @param forText Callback called if this is a textual reaction.
     		 * Called with the unicode String.
     		 * @param forImage Callback called if this is a custom/image reaction.
     		 * Called with the name and the URI to the image.
     		 * @returns the return value of the callback
     		 */
    		render<T>(forText: (arg0: string) => T, forImage: (arg0: string, arg1: string) => T): T;
    		/**
     		 * Create a new Unicode reaction to send
     		 * @param unicode emoji of the reaction
     		 * @returns Reaction
     		 */
    		static unicode(unicode: string): borogove.Reaction;
    	}

export const enum ReactionUpdateKind {
    EmojiReactions = 0,
    AppendReactions = 1,
    CompleteReactions = 2
}

export class SerializedChat {
    		constructor(chatId: string, trusted: boolean, avatarSha1: ArrayBuffer | null, presence: Map<string,borogove.Presence>, displayName: string | null, uiState: borogove.UiState | null, isBlocked: boolean | null, extensions: string | null, readUpToId: string | null, readUpToBy: string | null, notificationsFiltered: boolean | null, notifyMention: boolean, notifyReply: boolean, disco: borogove.Caps | null, omemoContactDeviceIDs: number[], klass: string);
    		chatId: string;
    		trusted: boolean;
    		avatarSha1: ArrayBuffer | null;
    		presence: Map<string,borogove.Presence>;
    		displayName: string | null;
    		uiState: borogove.UiState;
    		isBlocked: boolean;
    		extensions: string;
    		readUpToId: string | null;
    		readUpToBy: string | null;
    		disco: borogove.Caps | null;
    		omemoContactDeviceIDs: number[];
    		klass: string;
    		notificationsFiltered: boolean | null;
    		notifyMention: boolean;
    		notifyReply: boolean;
    		toChat(client: borogove.Client, stream: borogove.GenericStream, persistence: borogove.Persistence): borogove.Chat;
    	}

export const enum UiState {
    Pinned = 0,
    Open = 1,
    Closed = 2
}

export const enum UserState {
    Gone = 0,
    Inactive = 1,
    Active = 2,
    Composing = 3,
    Paused = 4
}

export declare const VERSION: string;

export { }
