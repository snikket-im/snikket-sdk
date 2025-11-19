package borogove.queries;

import haxe.DynamicAccess;
import haxe.Exception;

import borogove.ID;
import borogove.ResultSet;
import borogove.Stanza;
import borogove.queries.GenericQuery;
import borogove.Caps;
import borogove.Command;
import borogove.DataForm;
using borogove.Util;
using Lambda;

class CommandExecute extends GenericQuery {
	public var xmlns(default, null) = "http://jabber.org/protocol/commands";
	public var queryId:String = null;
	public var responseStanza(default, null):Stanza;
	private var result: Null<CommandSession>;
	private final node: String;

	public function new(to: String, node: String, ?action: Null<String>, ?sessionid: Null<String>, ?payload: Null<Stanza>) {
		this.node = node;
		var attr: DynamicAccess<String> = { xmlns: xmlns, node: node };
		attr["action"] = action ?? "execute";
		if (sessionid != null) attr["sessionid"] = sessionid;
		/* Build basic query */
		queryId = ID.short();
		queryStanza = new Stanza(
			"iq",
			{ to: to, type: "set", id: queryId }
		).tag("command", attr);
		if (payload != null) queryStanza.addChild(payload);
		queryStanza.up();
	}

	public function handleResponse(stanza:Stanza) {
		responseStanza = stanza;
		finish();
	}

	@:access(borogove.Form.form)
	public function getResult(command: Command) {
		if (responseStanza == null) {
			return null;
		}
		if(result == null) {
			final cmd = responseStanza.getChild("command", xmlns);
			if (responseStanza.attr.get("type") == "error" || cmd == null) {
				result = new CommandSession(
					"error",
					queryStanza.attr.get("sessionid"),
					[],
					forms([responseStanza]),
					command
				);
				return result;
			}

			if (
				queryStanza.attr.get("sessionid") != null &&
				cmd.attr.get("sessionid") != queryStanza.attr.get("sessionid")
			) {
				trace("sessionid mismatch", queryStanza, cmd);
				return null;
			}
			final forms = forms(cmd.allTags());
			final execute = cmd.getChild("actions")?.attr?.get("execute");
			final extActionsField = forms[0]?.form?.field("http://jabber.org/protocol/commands#actions");
			if (extActionsField != null) extActionsField.type = "hidden";
			final extActions: Array<FormOption> = (extActionsField?.options ?? []).map(o -> o.toFormOption());
			final actions = extActions.length > 0 ? extActions : (cmd.getChild("actions")?.allTags()?.map(s -> new FormOption(s.name.capitalize(), s.name))?.filter(o -> o.value != "execute") ?? []);
			if (cmd.attr.get("status") == "executing") {
				if (actions.length < 1) actions.push(new FormOption("Go", "execute"));
				if (actions.find(a -> a.value == "cancel") == null) actions.push(new FormOption("Cancel", "cancel"));
			}
			actions.sort((x,y) -> x.value == execute ? -1 : (y.value == execute ? 1 : 0));
			result = new CommandSession(
				cmd.attr.get("status"),
				cmd.attr.get("sessionid"),
				actions,
				forms,
				command
			);
		}
		return result;
	}

	private function forms(els: Array<Stanza>): Array<Form> {
		final fs = [];
		for (el in els) {
			if (el.name == "x" && el.attr.get("xmlns") == "jabber:x:data") {
				fs.push(new Form(el, null));
			}
			if (el.name == "x" && el.attr.get("xmlns") == "jabber:x:oob") {
				fs.push(new Form(null, el));
			}
			if (el.name == "iq" && el.attr.get("type") == "error") {
				final error = el.getError();
				final formish = new Stanza("x", { xmlns: "jabber:x:data", type: "result" }).textTag("instructions", error.text ?? error.condition, { type: "error" });
				fs.push(new Form(formish, null));
			}
			if (el.name == "note") {
				final formish = new Stanza("x", { xmlns: "jabber:x:data", type: "result" }).textTag("instructions", el.getText(), { type: el.attr.get("type") });
				fs.push(new Form(formish, null));
			}
		}
		return fs;
	}
}
