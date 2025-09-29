package borogove;

enum EventResult {
	EventHandled;
	EventUnhandled;
	EventStop;
	EventValue(result:Dynamic);
}

typedef EventCallback = (Dynamic)->EventResult;

class EventHandler {
	private var handlers:Array<EventHandler> = null;
	private var callback:EventCallback = null;
	private var onlyOnce:Bool = false;

	public function new(handlers:Array<EventHandler>, callback:EventCallback, ?onlyOnce:Bool) {
		this.handlers = handlers;
		this.callback = callback;
		if(onlyOnce != null) {
			this.onlyOnce = onlyOnce;
		}
	}

	public function call(data:Dynamic):EventResult {
		if(onlyOnce) {
			this.unsubscribe();
		}
		return callback(data);
	}

	public function once():EventHandler {
		onlyOnce = true;
		return this;
	}

	public function unsubscribe():Void {
		this.handlers.remove(this);
	}

}
