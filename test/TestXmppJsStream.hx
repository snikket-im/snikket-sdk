package test;

import borogove.streams.XmppJsStream;
import js.lib.Promise;
import utest.Assert;
import utest.Async;

@:access(borogove.streams.XmppJsStream)
class TestXmppJsStream extends utest.Test {
	public function testTimeoutDisconnects(async:Async) {
		final createFakeClient = (options:Dynamic) -> {
			final client = new XmppJsClient(options);
			Reflect.setField(
				client,
				"start",
				() -> Promise.reject(timeoutError())
			);
			Reflect.setField(
				client,
				"disconnect",
				() -> {
					// I just want to check that we called disconnect.
					// async.done() isn't sufficient by itself because
					// my test needs at least one assertion.
					Assert.isTrue(true);
					async.done();
					return Promise.resolve(null);
				}
			);

			return client;
		};

		final stream = new XmppJsStream(createFakeClient);
		stream.connect("test@example.com/test", null);
	}

	private function timeoutError() {
		final error = new js.lib.Error();
		error.name = "TimeoutError";

		return error;
	}
}
