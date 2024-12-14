package snikket;

class ModerationAction {
	public final chatId: String;
	public final moderateServerId: String;
	public final timestamp: String;
	public final moderatorId: Null<String>;
	public final reason: Null<String>;

	public function new(chatId: String, moderateServerId: String, timestamp: String, moderatorId: Null<String>, reason: Null<String>) {
		this.chatId = chatId;
		this.moderateServerId = moderateServerId;
		this.timestamp = timestamp;
		this.moderatorId = moderatorId;
		this.reason = reason;
	}
}
