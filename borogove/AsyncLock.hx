package borogove;

import thenshim.Promise;

@:expose
class AsyncLock {
	private var p: Promise<Any>;

	/**
		Create a new lock with no pending work.
	**/
	public function new() {
		p = Promise.resolve(null);
	}

	/**
		Run one async operation at a time in call order.

		@param fn operation to enqueue
		@returns Promise resolving or rejecting with the result of `fn`
	**/
	public function run<T>(fn: () -> Promise<T>): Promise<T> {
		final next = p.then(_ -> fn());
		p = next.then(_->{}, _->{}); // prevent chain break
		return next;
	}
}
