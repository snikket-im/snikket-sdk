package borogove;

class Outbox {
	private final items = [];
	private var paused = true;

	public function new() { }

	public function newItem() {
		final item = new OutboxItem(this);
		items.push(item);
		return item;
	}

	@:allow(borogove.OutboxItem)
	private function next() {
		if (paused) return;
		if (items.length < 1) return;
		if (items[0].run()) {
			items.shift();
			next();
		}
	}

	public function pause() {
		paused = true;
	}

	public function start() {
		paused = false;
		next();
	}
}

class OutboxItem {
	private final outbox: Outbox;
	private var _handle: Null<()->Void> = null;

	@:allow(borogove.Outbox)
	private function new(outbox: Outbox) {
		this.outbox = outbox;
	}

	public function handle(f: ()->Void) {
		_handle = f;
		outbox.next();
	}

	@:allow(borogove.Outbox)
	private function run() {
		if (_handle == null) return false;

		_handle();
		return true;
	}
}
