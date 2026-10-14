package test;

import borogove.Chat;
import borogove.ChatUpdateBatcher;
import borogove.Client;
import borogove.persistence.Dummy;
import utest.Assert;

@:access(borogove)
class TestChatUpdateBatcher extends utest.Test {
	private function chat(id: String): Chat {
		final client = new Client("test@example.com", new Dummy());
		return client.getDirectChat(id, false);
	}

	public function testEmptyUpdateDoesNotStartDeliveryWindow() {
		final first = chat("first@example.com");
		final batches: Array<Array<Chat>> = [];
		final batcher = new ChatUpdateBatcher(batch -> batches.push(batch));

		batcher.add([]);
		Assert.equals(0, batches.length);
		batcher.add([first]);
		Assert.equals(1, batches.length);
		if (batches.length == 1) Assert.equals(first, batches[0][0]);
	}

	public function testEmptyUpdateDoesNotPostponePendingDelivery() {
		final first = chat("first@example.com");
		final last = chat("last@example.com");
		final batches: Array<Array<Chat>> = [];
		final interval = ChatUpdateBatcher.BATCH_INTERVAL_MS;
		final justBeforeDelivery = interval - 1;
		final deliveryDue = interval;
		final afterNextWindow = deliveryDue + interval + 1;
		var now = 0.0;
		final batcher = new ChatUpdateBatcher(batch -> batches.push(batch), () -> now);
		batcher.add([first]);
		batcher.add([last]);
		final pending = batcher.timer;

		now = justBeforeDelivery;
		batcher.add([]);
		Assert.equals(pending, batcher.timer);
		Assert.equals(1, batches.length);
		now = deliveryDue;
		batcher.timer.run();
		Assert.equals(2, batches.length);
		if (batches.length == 2) {
			Assert.equals(1, batches[1].length);
			Assert.equals(last, batches[1][0]);
		}
		now = afterNextWindow;
		batcher.add([]);
		Assert.equals(2, batches.length);
		Assert.equals(pending, batcher.timer);
	}

	public function testFirstBatchIsImmediateAndDeduplicated() {
		final first = chat("first@example.com");
		final latest = chat("first@example.com");
		final second = chat("second@example.com");
		final batches: Array<Array<Chat>> = [];
		final batcher = new ChatUpdateBatcher(batch -> batches.push(batch));

		batcher.add([first, second, latest]);

		Assert.equals(1, batches.length);
		Assert.equals(2, batches[0].length);
		Assert.isTrue(batches[0].contains(latest));
		Assert.isTrue(batches[0].contains(second));
		Assert.isFalse(batches[0].contains(first));
	}

	public function testInstancesHaveIndependentWindows() {
		final first = chat("first@example.com");
		final second = chat("second@example.com");
		final batches: Array<Array<Chat>> = [];
		final otherBatches: Array<Array<Chat>> = [];
		final batcher = new ChatUpdateBatcher(batch -> batches.push(batch));
		final other = new ChatUpdateBatcher(batch -> otherBatches.push(batch));

		batcher.add([first]);
		batcher.add([second]);
		other.add([second]);
		Assert.equals(1, batches.length);
		Assert.equals(1, otherBatches.length);
		Assert.equals(second, otherBatches[0][0]);

		batcher.timer.run();
		Assert.equals(2, batches.length);
		Assert.equals(1, otherBatches.length);
		if (batches.length == 2) Assert.equals(second, batches[1][0]);
	}

	public function testTrailingTimerRestartsAndDeliversLatestChat() {
		final first = chat("first@example.com");
		final replacement = chat("first@example.com");
		final last = chat("last@example.com");
		final batches: Array<Array<Chat>> = [];
		final interval = ChatUpdateBatcher.BATCH_INTERVAL_MS;
		final anotherUpdateAt = interval / 2;
		final trailingDeliveryAt = anotherUpdateAt + interval;
		var now = 0.0;
		final batcher = new ChatUpdateBatcher(batch -> batches.push(batch), () -> now);
		batcher.add([first]);
		batcher.add([first]);
		final previous = batcher.timer;

		now = anotherUpdateAt;
		batcher.add([replacement, last]);
		Assert.isFalse(previous == batcher.timer);
		Assert.equals(1, batches.length);
		now = trailingDeliveryAt;
		batcher.timer.run();
		Assert.equals(2, batches.length);
		if (batches.length == 2) {
			Assert.equals(2, batches[1].length);
			Assert.isTrue(batches[1].contains(replacement));
			Assert.isTrue(batches[1].contains(last));
			Assert.isFalse(batches[1].contains(first));
		}
	}

	public function testContinuousBurstFlushesBeforeItStops() {
		final first = chat("first@example.com");
		final last = chat("last@example.com");
		final batches: Array<Array<Chat>> = [];
		final interval = ChatUpdateBatcher.BATCH_INTERVAL_MS;
		final halfwayToDelivery = interval / 2;
		final justBeforeDelivery = interval - 1;
		final deliveryDue = interval;
		final lastUpdateAt = deliveryDue + halfwayToDelivery;
		final trailingDeliveryAt = lastUpdateAt + interval;
		var now = 0.0;
		final batcher = new ChatUpdateBatcher(batch -> batches.push(batch), () -> now);
		batcher.add([first]);
		for (updateAt in [halfwayToDelivery, justBeforeDelivery]) {
			now = updateAt;
			batcher.add([first]);
			Assert.equals(1, batches.length);
		}
		now = deliveryDue;
		batcher.add([first]);
		Assert.equals(2, batches.length);
		now = lastUpdateAt;
		batcher.add([last]);
		Assert.equals(2, batches.length);
		now = trailingDeliveryAt;
		batcher.timer.run();
		Assert.equals(3, batches.length);
		if (batches.length == 3) Assert.equals(last, batches[2][0]);
	}

	public function testUpdateAddedDuringDeliveryIsEventuallyDelivered() {
		final first = chat("first@example.com");
		final last = chat("last@example.com");
		final batches: Array<Array<Chat>> = [];
		var batcher: ChatUpdateBatcher = null;
		batcher = new ChatUpdateBatcher(batch -> {
			batches.push(batch);
			if (batches.length == 1) batcher.add([last]);
		});
		batcher.add([first]);
		Assert.equals(1, batches.length);

		batcher.timer.run();
		Assert.equals(2, batches.length);
		if (batches.length == 2) {
			Assert.equals(1, batches[1].length);
			Assert.equals(last, batches[1][0]);
		}
	}
}
