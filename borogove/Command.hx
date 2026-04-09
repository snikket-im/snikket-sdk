package borogove;

import thenshim.Promise;

import borogove.DataForm;
import borogove.Form;
import borogove.queries.CommandExecute;

#if cpp
import HaxeCBridge;
#end

@:expose
@:allow(borogove.CommandSession)
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class Command {
	/**
		Human-readable name for this command
	**/
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

	/**
		Start a new session for this command. May have side effects!
	**/
	public function execute(): Promise<CommandSession> {
		return new CommandSession("executing", null, [], [], this).execute();
	}
}

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class CommandSession {
	/**
		Human-readable title for the current command session
	**/
	public final name: String;
	/**
		Current command execution status
	**/
	public final status: String;
	/**
		Actions the server currently allows for this session
	**/
	public final actions: Array<FormOption>;
	/**
		Forms to display for the current session step
	**/
	public final forms: Array<Form>;
	private final sessionid: String;
	private final command: Command;

	@:allow(borogove)
	private function new(status: String, sessionid: String, actions: Array<FormOption>, forms: Array<Form>, command: Command) {
		this.name = forms[0]?.title() != null ? forms[0].title() : command.name;
		this.status = status;
		this.sessionid = sessionid;
		this.actions = actions;
		this.forms = forms;
		this.command = command;
	}

	/**
		Continue this command session, optionally submitting form data

		@param action requested action, or null for the default action
		@param data form values to submit for the selected form
		@param formIdx index of the form in `forms` to submit
		@returns Promise resolving to the next command session state
	**/
	#if js
	public function execute(
		action: Null<String> = null,
		data: Null<haxe.extern.EitherType<
			haxe.extern.EitherType<
				haxe.DynamicAccess<StringOrArray>,
				Map<String, StringOrArray>
			>,
			js.html.FormData
		>> = null,
		formIdx: Int = 0
	)
	#else
	public function execute(
		action: Null<String> = null,
		data: Null<FormSubmitBuilder> = null,
		formIdx: Int = 0
	)
	#end
	: Promise<CommandSession> {
		final extendedAction = action != null && !["prev", "next", "complete", "execute", "cancel"].contains(action);
		var toSubmit = null;
		if (data != null || extendedAction) {
			toSubmit = forms[formIdx].submit(data);
			if (toSubmit == null && action != "cancel" && action != "prev") return Promise.reject("Invalid submission");
		}

		if (extendedAction) {
			if (toSubmit == null) toSubmit = new Stanza("x", { xmlns: "jabber:x:data", type: "submit" });
			final dataForm: DataForm = toSubmit;
			final fld = dataForm.field("http://jabber.org/protocol/commands#actions");
			if (fld == null) {
				toSubmit.tag("field", { "var": "http://jabber.org/protocol/commands#actions" }).textTag("value", action).up();
			} else {
				fld.value = [action];
			}
			action = null;
		}

		return new Promise((resolve, reject) -> {
			final exe = new CommandExecute(command.jid.asString(), command.node, action, sessionid, toSubmit);
			exe.onFinished(() -> {
				if (exe.getResult(command) == null) {
					reject(exe.responseStanza);
				} else {
					resolve(exe.getResult(command));
				}
			});
			command.client.sendQuery(exe);
		});
	}
}
