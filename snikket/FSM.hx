package snikket;

import haxe.Exception;

typedef FSMTransitionName = String;
typedef FSMStateName = String;

typedef FSMEvent = {
	var fsm : FSM;

	var ?name : FSMTransitionName;

	var to : FSMStateName;
	var ?toAttr : Dynamic;
	var ?from : FSMStateName;
	var ?fromAttr : Dynamic;
};

typedef FSMTransition = {
	var name : FSMTransitionName;
	var from : Array<FSMStateName>;
	var to : FSMStateName;
};

typedef FSMStateHandler = (FSMEvent)->Void;
typedef FSMTransitionHandler = (FSMEvent)->Bool;

typedef FSMDescription = {
	var transitions : Array<FSMTransition>;

	var ?state_handlers : Map<FSMStateName,FSMStateHandler>;
	var ?transition_handlers : Map<FSMTransitionName,FSMTransitionHandler>;
};

class FSM extends EventEmitter {
	private var states : Map<FSMStateName,Map<FSMTransitionName,FSMStateName>> = [];
	private var currentState : FSMStateName = null;
	private var currentStateAttributes : Dynamic = null;
	
	public function new(desc:FSMDescription, initialState:FSMStateName, ?initialAttr:Dynamic) {
		super();
		for(transition in desc.transitions) {
			var from_states = transition.from;
			for (from_state in from_states) {
				var from_state_def = states.get(from_state);
				if (from_state_def == null) {
					from_state_def = [];
					states.set(from_state, from_state_def);
				}
				var to_state_def = states.get(transition.to);
				if (to_state_def == null) {
					to_state_def = [];
					states.set(transition.to, to_state_def);
				}
				if (states.get(from_state).get(transition.name) != null) {
					throw new Exception("Duplicate transition in FSM specification: " + transition.name + " from " + from_state);
				}
				states.get(from_state).set(transition.name, transition.to);
			}
		}

		if(desc.state_handlers != null) {
			for (state => handler in desc.state_handlers) {
				this.on('enter/$state', function (data) {
					handler(data);
					return EventHandled;
				});
			}
		}

		if(desc.transition_handlers != null) {
			for (transition => handler in desc.transition_handlers) {
				this.on('transition/$transition', function (data) {
					if(handler(data) == false) {
						return EventStop;
					}
					return EventHandled;
				});
			}
		}
		
		currentState = initialState;
		currentStateAttributes = initialAttr;
		var initialEvent:FSMEvent = {
			fsm: this,
			to: initialState,
			toAttr: initialAttr,
		};
		this.notifyTransitioned(initialEvent, true);
	}

	public function can(name:FSMTransitionName):Bool {
		return states.get(currentState).get(name) != null;
	}

	public function getCurrentState():String {
		return currentState;
	}

	public function event(name:FSMTransitionName, ?attr:Dynamic):Bool {
		var newState = states.get(currentState).get(name);
		if(newState == null) {
			throw new Exception("Invalid state transition: " + currentState + " cannot " + name);
		}

		var event:FSMEvent = {
			fsm: this,

			name: name,
			to: newState,
			toAttr: attr,

			from: currentState,
			fromAttr: currentStateAttributes,
		};

		if(notifyTransition(event) == false) {
			return false;
		}

		this.currentState = newState;
		this.currentStateAttributes = attr;

		notifyTransitioned(event, false);
		return true;
	}

	private function notifyTransition(event:FSMEvent):Bool {
		var ret;
		ret = this.trigger("transition", event);
		if(ret == EventStop) {
			return false;
		}
		if(event.to != event.from) {
			ret = this.trigger("leave/"+event.from, event);
			if (ret == EventStop) {
				return false;
			}
		}
		ret = this.trigger("transition/"+event.name, event);
		if(ret == EventStop) {
			return false;
		}
		return true;
	}

	private function notifyTransitioned(event:FSMEvent, isInitial:Bool):Void {
		if(event.to != event.from) {
			this.trigger("enter/"+event.to, event);
		}
		if(isInitial == false) {
			if(event.name != null) {
				trigger("transitioned/"+event.name, event);
			}
			trigger("transitioned", event);
		}
	}
}
