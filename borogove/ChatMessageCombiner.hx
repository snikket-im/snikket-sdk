package borogove;

using Lambda;

@:expose
class ChatMessageCombiner {
	public static function combine(messages: Array<ChatMessage>): Array<ChatMessage> {
		return messages
			.fold(
				(message, grouped:Map<String, Array<ChatMessage>>) -> {
					final key = correctionKey(message);
					final messages = grouped[key] ?? [];
					grouped.set(key, messages.concat([message]));
					grouped;
				},
				new Map<String, Array<ChatMessage>>()
			)
			.map(messages -> combineMessages(messages));
	}

	private static function correctionKey(message: ChatMessage): String {
		if (message.localId == null) return ID.unique();

		final sender = message.type == MessageCall ? "call" : message.senderId;
		return message.localId + "\n" + message.chatId() + "\n" + sender;
	}

	private static function combineMessages(messages: Array<ChatMessage>): ChatMessage {
		if (messages.length == 1) return messages[0];

		final original = messages.find(message -> message.versions.length == 0) ?? messages[0];
		final combinedVersions = combineVersions(original, messages);
		final newest = combinedVersions[0];

		final builder = ChatMessageBuilder.fromMessage(newest);
		builder.localId = original.localId;
		builder.serverId = original.serverId;
		builder.serverIdBy = original.serverIdBy;
		builder.sortId = original.sortId;
		builder.timestamp = original.timestamp;
		builder.replyId = original.replyId;
		builder.reactions = original.reactions;
		if (original.type == MessageCall) {
			builder.direction = original.direction;
			builder.senderId = original.senderId;
			builder.from = original.from;
			builder.to = original.to;
			builder.replyTo = original.replyTo.array();
			builder.recipients = original.recipients.array();
		}
		builder.versions = combinedVersions;
		return builder.build();
	}

	private static function combineVersions(
		original: ChatMessage,
		messages: Array<ChatMessage>,
	): Array<ChatMessage> {
		final versions = messages.flatMap(message -> message.versions.array());
		if (original.versions.length == 0) versions.push(original);

		final sortedVersions = versions.fold(
			(version, uniqueVersions:Map<String, ChatMessage>) -> {
				final id = identity(version);
				final previous = uniqueVersions[id];
				if (previous == null || version.timestamp > previous.timestamp) {
					uniqueVersions.set(id, version);
				}
				uniqueVersions;
			},
			new Map<String, ChatMessage>()
		).map(version -> version);
		sortedVersions.sort((a, b) -> Reflect.compare(b.timestamp, a.timestamp));
		return sortedVersions;
	}

	private static function identity(message: ChatMessage): String {
		return message.serverId == null
			? "local:" + message.localId
			: "server:" + message.serverId + "\n" + message.serverIdBy;
	}
}
