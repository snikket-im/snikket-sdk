import IDBjs from "./IDB.js";
import MediaStoreCachejs from "./MediaStoreCache.js";
import { borogove as enums } from "./borogove-enums.js";
import { borogove } from "./borogove.js";

// TODO: should we autogenerate this?
export import AvailableChat = borogove.AvailableChat;
export import Caps = borogove.Caps;
export import Channel = borogove.Channel;
export import Chat = borogove.Chat;
export import ChatAttachment = borogove.ChatAttachment;
export import ChatMessage = borogove.ChatMessage;
export import ChatMessageBuilder = borogove.ChatMessageBuilder;
export import Client = borogove.Client;
export import Config = borogove.Config;
export import CustomEmojiReaction = borogove.CustomEmojiReaction;
export import DirectChat = borogove.DirectChat;
export import Hash = borogove.Hash;
export import Identicon = borogove.Identicon;
export import Identity = borogove.Identity;
export import Notification = borogove.Notification;
export import Participant = borogove.Participant;
export import Push = borogove.Push;
export import Reaction = borogove.Reaction;
export import SerializedChat = borogove.SerializedChat;
export const VERSION = borogove.Version.HUMAN;
export import calls = borogove.calls;

export import CallStatus = enums.calls.CallStatus;
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
	export import Dummy = borogove.persistence.Dummy;
	export import Sqlite = borogove.persistence.Sqlite;
}
