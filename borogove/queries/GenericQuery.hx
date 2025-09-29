package borogove.queries;

import haxe.Exception;

import borogove.Stanza;

abstract class GenericQuery {
	private var queryStanza:Stanza;
	private var handleFinished:()->Void;
	private var isFinished:Bool = false;

	public function getQueryStanza():Stanza {
		if(queryStanza == null) {
			throw new Exception("Query has not been initialized");
		}
		return queryStanza;
	}

	private function finish() {
		isFinished = true;
		if(handleFinished != null) {
			handleFinished();
		}
	}

	abstract public function handleResponse(response:Stanza):Void;

	public function onFinished(handler:()->Void):Void {
		handleFinished = handler;
		if(isFinished) {
			handleFinished();
		}
	}
}
