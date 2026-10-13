package borogove;

class ChatUpdateBatcher {
	private static inline final BATCH_INTERVAL_MS = 500;
	private final deliver: Array<Chat>->Void;
	private final now: ()->Float;
	private final buffer: Map<String, Chat> = new Map();
	private var lastDelivery = -1.0;
	private var timer: Null<haxe.Timer> = null;

	public function new(deliver: Array<Chat>->Void, ?now: ()->Float) {
		this.deliver = deliver;
		this.now = now ?? (() -> haxe.Timer.stamp() * 1000);
	}

	public function add(chats: Array<Chat>): Void {
		if (chats.length == 0) return;

		timer?.stop();

		for (chat in chats) buffer[chat.chatId] = chat;

		if (shouldSendNow()) {
			flush();
		} else {
			timer = haxe.Timer.delay(flush, BATCH_INTERVAL_MS);
		}
	}

	private function shouldSendNow(): Bool {
		return neverSent() || dueForSend();
	}

	private function neverSent() {
		return lastDelivery < 0;
	}

	private function dueForSend() {
		return now() - lastDelivery >= BATCH_INTERVAL_MS;
	}

	private function flush(): Void {
		lastDelivery = now();
		final batch = Lambda.array(buffer);
		buffer.clear();
		deliver(batch);
	}

}
