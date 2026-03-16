package borogove;

import thenshim.Promise;

class AsyncLock {
	private var p: Promise<Any>;

	public function new() {
		p = Promise.resolve(null);
	}

	public function run<T>(fn: () -> Promise<T>): Promise<T> {
		final next = p.then(_ -> fn());
		p = next.then(_->{}, _->{}); // prevent chain break
		return next;
	}
}
