package borogove;

import thenshim.Promise;

import borogove.DataForm;
import borogove.Form;

@:expose
@:allow(borogove.CommandSession)
class Command {
	public final name: String;
	private final jid: JID;
	private final node: String;
	private final client: Client;

	@:allow(borogove)
	private function new(client: Client, params: { jid: JID, name: Null<String>, node: String }) {
		jid = params.jid;
		node = params.node;
		name = params.name ?? params.node;
		this.client = client;
	}
}
