package borogove;

import borogove.Chat;

using Lambda;

private typedef ScheduledChannel = {
	final channel: Channel;
	var deadline: Float;
}

class ChannelPinger {
	private static inline final PING_INTERVAL_MS = 5 * 60 * 1000;
	private static inline final CHECK_INTERVAL_MS = 60 * 1000;
	private static inline final PING_TRIGGER_WINDOW_MS = 30 * 1000;
	private static inline final COALESCE_WINDOW_MS = PING_TRIGGER_WINDOW_MS * 2;

	private final now: ()->Float;
	private final scheduledChannels = new Map<String, ScheduledChannel>();
	private var timer: Null<haxe.Timer> = null;

	public function new(?now: ()->Float) {
		this.now = now ?? (() -> haxe.Timer.stamp() * 1000);
	}

	public function startTimer(): Void {
		if (timer != null) throw "ChannelPinger timer already exists";
		timer = new haxe.Timer(CHECK_INTERVAL_MS);
		timer.run = pingPastDue;
	}

	public function stopTimer(): Void {
		timer?.stop();
		timer = null;
	}

	public function schedule(channel: Channel, ?deadline: Float): Void {
		if (channel.uiState != Open) return;

		scheduledChannels.set(channel.chatId, {
			channel: channel,
			deadline: deadline ?? now() + PING_INTERVAL_MS,
		});
	}

	public function remove(channel: Channel): Void {
		scheduledChannels.remove(channel.chatId);
	}

	public function pingPastDue(): Void {
		pingDueBy(now());
	}

	public function pingDueInWindow(): Void {
		final currentTime = now();
		if (getDueBy(currentTime + PING_TRIGGER_WINDOW_MS).length > 0) {
			pingDueBy(currentTime + COALESCE_WINDOW_MS);
		}
	}

	private function pingDueBy(cutoff: Float): Void {
		final due = getDueBy(cutoff);

		for (scheduled in due) scheduled.channel.selfPing(false);
	}

	private function getDueBy(cutoff: Float): Array<ScheduledChannel> {
		return scheduledChannels.filter(sc -> sc.deadline <= cutoff);
	}
}
