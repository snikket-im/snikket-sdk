package borogove;

class ModerationAction {
	public final chatId: String;
	public final moderateServerId: String;
	public final timeSent: String;
	public final timeReceived: String;
	public final moderatorId: Null<String>;
	public final reason: Null<String>;

	public function new(chatId: String, moderateServerId: String, timeSent: String, timeReceived: String, moderatorId: Null<String>, reason: Null<String>) {
		this.chatId = chatId;
		this.moderateServerId = moderateServerId;
		this.timeSent = timeSent;
		this.timeReceived = timeReceived;
		this.moderatorId = moderatorId;
		this.reason = reason;
	}
}
