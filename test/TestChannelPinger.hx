package test;

import borogove.ChannelPinger;
import borogove.Chat.Channel;
import borogove.Chat.UiState;
import borogove.EventEmitter.EventResult;
import borogove.JID;
import borogove.Stanza;
import borogove.persistence.Dummy;
import utest.Assert;

@:access(borogove)
class TestChannelPinger extends utest.Test {
	private var client: borogove.Client;

	public function setup() {
		client = new borogove.Client("test@example.com", new Dummy());
	}

	public function testStartTimerErrorsIfCalledTwice() {
		final pinger = new ChannelPinger();
		pinger.startTimer();
		Assert.raises(pinger.startTimer);
	}

	public function testScheduleAddsChannel() {
		final now = 1000.0;
		final channel = channel(client, "room@example.com");
		final pinger = new ChannelPinger(() -> now);

		Assert.isNull(pinger.scheduledChannels[channel.chatId]);

		pinger.schedule(channel);

		final scheduled = pinger.scheduledChannels[channel.chatId];
		Assert.equals(channel, scheduled.channel);
		Assert.equals(now + ChannelPinger.PING_INTERVAL_MS, scheduled.deadline);
	}

	public function testScheduleUpdatesDeadline() {
		var now = 1000.0;
		final channel = channel(client, "room@example.com");
		final pinger = new ChannelPinger(() -> now);

		pinger.schedule(channel);
		Assert.equals(
			now + ChannelPinger.PING_INTERVAL_MS,
			pinger.scheduledChannels[channel.chatId].deadline,
		);

		now += 1000;

		pinger.schedule(channel);
		Assert.equals(
			now + ChannelPinger.PING_INTERVAL_MS,
			pinger.scheduledChannels[channel.chatId].deadline,
		);
	}

	public function testScheduleAcceptsCustomDeadline() {
		final channel = channel(client, "room@example.com");
		final pinger = new ChannelPinger();
		final deadline = 5000;

		pinger.schedule(channel, deadline);

		Assert.equals(
			deadline,
			pinger.scheduledChannels[channel.chatId].deadline,
		);
	}

	public function testScheduleOnlySchedulesOpenChannels() {
		final channel = channel(client, "room@example.com", Closed);
		final pinger = new ChannelPinger();
		pinger.schedule(channel);

		Assert.isNull(pinger.scheduledChannels[channel.chatId]);
	}

	public function testRemoveRemovesScheduledChannel() {
		final channel = channel(client, "room@example.com");
		final pinger = new ChannelPinger();

		pinger.schedule(channel);
		Assert.notNull(pinger.scheduledChannels[channel.chatId]);

		pinger.remove(channel);
		Assert.isNull(pinger.scheduledChannels[channel.chatId]);
	}

	public function testPingPastDue() {
		final now = 1000.0;
		final pastDue = channel(client, "room1@example.com");
		final dueNow = channel(client, "room2@example.com");
		final dueInFuture = channel(client, "room3@example.com");
		final pinger = new ChannelPinger(() -> now);

		pinger.schedule(pastDue, now - 1);
		pinger.schedule(dueNow, now);
		pinger.schedule(dueInFuture, now + 1);

		final pinged = capturePings(pinger.pingPastDue);

		assertSameList([pastDue.chatId, dueNow.chatId], pinged);
	}

	public function testPingDueInWindowSendsEverythingIn60SecondsIfSomeIn30Seconds() {
		final now = 1000.0;
		final dueInNext30 = channel(client, "room1@example.com");
		final dueInNext60 = channel(client, "room2@example.com");
		final dueGreaterThan60 = channel(client, "room3@example.com");
		final pinger = new ChannelPinger(() -> now);

		pinger.schedule(dueInNext30, now + 30 * 1000);
		pinger.schedule(dueInNext60, now + 60 * 1000);
		pinger.schedule(dueGreaterThan60, now + 60 * 1000 + 1);

		final pinged = capturePings(pinger.pingDueInWindow);

		assertSameList([dueInNext30.chatId, dueInNext60.chatId], pinged);
	}

	public function testPingDueInWindowDoesNothingIfNothingDueInNext30() {
		final now = 1000.0;
		final room = channel(client, "room@example.com");
		final pinger = new ChannelPinger(() -> now);
		pinger.schedule(room, now + 30 * 1000 + 1);

		final pinged = capturePings(pinger.pingDueInWindow);

		Assert.same([], pinged);
	}

	private function channel(client, id: String, state: UiState = Open): Channel {
		return new Channel(client, client.stream, client.persistence, id, state);
	}

	private function capturePings(operation: Void->Void): Array<String> {
		final pinged = [];
		client.stream.on("sendStanza", (stanza: Stanza) -> {
			if (stanza.name == "iq" && stanza.getChild("ping", "urn:xmpp:ping") != null) {
				pinged.push(JID.parse(stanza.attr.get("to")).asBare().asString());
			}
			return EventHandled;
		});

		operation();

		return pinged;
	}

	private function assertSameList<T>(expected: Array<T>, actual: Array<T>) {
		expected.sort(Reflect.compare);
		actual.sort(Reflect.compare);
		Assert.same(expected, actual);
	}
}
