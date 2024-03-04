package snikket;

import snikket.EventHandler;

class EventEmitter {
	private var eventHandlers:Map<String,Array<EventHandler>> = [];

	private function new() { }
	
	public function on(eventName:String, callback:EventCallback):EventHandler {
		var handlers = eventHandlers.get(eventName);
		if(handlers == null) {
			handlers = [];
			eventHandlers.set(eventName, handlers);
		}
		var newHandler = new EventHandler(handlers, callback);
		handlers.push(newHandler);
		return newHandler;
	}

	public function once(eventName:String, callback:EventCallback) {
		return this.on(eventName, callback).once();
	}

	public function trigger(eventName:String, eventData:Dynamic):EventResult {
		var handlers = eventHandlers.get(eventName);
		if(handlers == null || handlers.length == 0) {
			trace('no event handlers for $eventName');
			return EventUnhandled;
		}
		trace("firing event: "+eventName);
		var handled = false;
		for (handler in handlers) {
			var ret = handler.call(eventData);
			switch(ret) {
				case EventHandled: handled = true;
				case EventUnhandled: continue;
				case EventStop | EventValue(_): return ret;
			}
		}
		return handled ? EventHandled : EventUnhandled;
	}
}
