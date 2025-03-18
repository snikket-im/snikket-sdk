 
export declare namespace borogove {
    const enum UiState {
        Pinned = 0,
        Open = 1,
        Closed = 2
    }
}
export declare namespace borogove.calls {
    const enum CallStatus {
        NoCall = 0,
        Incoming = 1,
        Outgoing = 2,
        Connecting = 3,
        Ongoing = 4,
        Failed = 5
    }
}
export declare namespace borogove {
    const enum MessageDirection {
        MessageReceived = 0,
        MessageSent = 1
    }
}
export declare namespace borogove {
    const enum EncryptionStatus {
        DecryptionSuccess = 0,
        DecryptionFailure = 1
    }
}
export declare namespace borogove {
    const enum MessageStatus {
        MessagePending = 0,
        MessageDeliveredToServer = 1,
        MessageDeliveredToDevice = 2,
        MessageFailedToSend = 3
    }
}
export declare namespace borogove {
    const enum MessageType {
        MessageChat = 0,
        MessageCall = 1,
        MessageChannel = 2,
        MessageChannelPrivate = 3
    }
}
export declare namespace borogove {
    const enum UserState {
        Gone = 0,
        Inactive = 1,
        Active = 2,
        Composing = 3,
        Paused = 4
    }
}
export declare namespace borogove {
    const enum ChatMessageEvent {
        DeliveryEvent = 0,
        CorrectionEvent = 1,
        ReactionEvent = 2,
        StatusEvent = 3
    }
}
export declare namespace borogove {
    const enum ReactionUpdateKind {
        EmojiReactions = 0,
        AppendReactions = 1,
        CompleteReactions = 2
    }
}
