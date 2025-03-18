import IDBjs from "./IDB.js";
import MediaStoreCachejs from "./MediaStoreCache.js";
import { snikket as enums } from "./snikket-enums.js";
import { snikket } from "./snikket.js";

// TODO: should we autogenerate this?
export import AvailableChat = snikket.AvailableChat;
export import Caps = snikket.Caps;
export import Channel = snikket.Channel;
export import Chat = snikket.Chat;
export import ChatAttachment = snikket.ChatAttachment;
export import ChatMessage = snikket.ChatMessage;
export import ChatMessageBuilder = snikket.ChatMessageBuilder;
export import Client = snikket.Client;
export import Config = snikket.Config;
export import CustomEmojiReaction = snikket.CustomEmojiReaction;
export import DirectChat = snikket.DirectChat;
export import Hash = snikket.Hash;
export import Identicon = snikket.Identicon;
export import Identity = snikket.Identity;
export import Notification = snikket.Notification;
export import Participant = snikket.Participant;
export import Push = snikket.Push;
export import Reaction = snikket.Reaction;
export import SerializedChat = snikket.SerializedChat;
export import jingle = snikket.jingle;
export const VERSION = snikket.Version.HUMAN;

export import ChatMessageEvent = enums.ChatMessageEvent;
export import MessageDirection = enums.MessageDirection;
export import MessageStatus = enums.MessageStatus;
export import MessageType = enums.MessageType;
export import ReactionUpdateKind = enums.ReactionUpdateKind;
export import UiState = enums.UiState;
export import UserState = enums.UserState;

export namespace persistence {
	export import IDB = IDBjs;
	export import MediaStoreCache = MediaStoreCachejs;
	export import Dummy = snikket.persistence.Dummy;
	export import Sqlite = snikket.persistence.Sqlite;
}
