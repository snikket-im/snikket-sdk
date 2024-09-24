import browserp from "./browser";
import { snikket as enums } from "./snikket-enums";
import { snikket } from "./snikket";

// TODO: should we autogenerate this?
export import AvailableChat = snikket.AvailableChat;
export import Caps = snikket.Caps;
export import Channel = snikket.Channel;
export import Chat = snikket.Chat;
export import ChatAttachment = snikket.ChatAttachment;
export import ChatMessage = snikket.ChatMessage;
export import Client = snikket.Client;
export import DirectChat = snikket.DirectChat;
export import Identicon = snikket.Identicon;
export import Identity = snikket.Identity;
export import Notification = snikket.Notification;
export import SerializedChat = snikket.SerializedChat;
export import jingle = snikket.jingle;

export import UiState = enums.UiState;
export import MessageStatus = enums.MessageStatus;
export import MessageDirection = enums.MessageDirection;
export import UserState = enums.UserState;

export namespace persistence {
	 export import browser = browserp;
	 export import Dummy = snikket.persistence.Dummy;
}
