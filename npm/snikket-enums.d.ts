 
export declare namespace snikket {
    const enum UiState {
        Pinned = 0,
        Open = 1,
        Closed = 2
    }
}
export declare namespace snikket {
    const enum MessageType {
        MessageChat = 0,
        MessageCall = 1,
        MessageChannel = 2,
        MessageChannelPrivate = 3
    }
}
export declare namespace snikket {
    const enum MessageDirection {
        MessageReceived = 0,
        MessageSent = 1
    }
}
export declare namespace snikket {
    const enum MessageStatus {
        MessagePending = 0,
        MessageDeliveredToServer = 1,
        MessageDeliveredToDevice = 2,
        MessageFailedToSend = 3
    }
}
export declare namespace snikket {
    const enum UserState {
        Gone = 0,
        Inactive = 1,
        Active = 2,
        Composing = 3,
        Paused = 4
    }
}
export declare namespace snikket {
    const enum ChatMessageEvent {
        DeliveryEvent = 0,
        CorrectionEvent = 1,
        ReactionEvent = 2,
        StatusEvent = 3
    }
}
export declare namespace snikket {
    const enum ReactionUpdateKind {
        EmojiReactions = 0,
        AppendReactions = 1,
        CompleteReactions = 2
    }
}
