package borogove;

#if cpp
import HaxeCBridge;
#end

enum EventResult {
	EventHandled;
	EventUnhandled;
	EventStop;
	EventValue(result:Dynamic);
}

typedef EventCallback = (Dynamic)->EventResult;

typedef EventHandlerToken = Int;

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class EventEmitter {
	private var nextEventHandlerToken = 0;
	private var eventHandlers:Map<String,Map<EventHandlerToken, EventCallback>> = [];

	private function new() { }

	@:allow(borogove)
	private function on(eventName:String, callback:EventCallback):EventHandlerToken {
		var handlers = eventHandlers.get(eventName);
		if(handlers == null) {
			handlers = [];
			eventHandlers.set(eventName, handlers);
		}
		final token = nextEventHandlerToken++;
		handlers[token] = callback;
		return token;
	}

	@:allow(borogove)
	private function once(eventName:String, callback:EventCallback):Void {
		var token = null;
		token = this.on(eventName, (e) -> {
			if (token == null) throw "Somehow token was not ready";
			this.removeEventListener(token);
			return callback(e);
		});
	}

	@:allow(borogove)
	private function trigger(eventName:String, eventData:Dynamic):EventResult {
		var handlers = eventHandlers.get(eventName);
		trace("firing event: "+eventName);
		var handled = false;
		for (handler in handlers) {
			var ret = handler(eventData);
			switch(ret) {
				case EventHandled: handled = true;
				case EventUnhandled: continue;
				case EventStop | EventValue(_): return ret;
			}
		}
		return handled ? EventHandled : EventUnhandled;
	}

	/**
		Remove an event listener of any type, no matter how it was added
		or what event it is for.

		@param token the token that was returned when the listener was added
	**/
	public function removeEventListener(token:EventHandlerToken) {
		for (handlers in eventHandlers) {
			handlers.remove(token);
		}
	}
}
