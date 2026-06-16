package borogove;

import thenshim.Promise;
import borogove.Command;
import borogove.DataForm;
import borogove.Form;
import borogove.queries.MucSettingsGet;
import borogove.queries.MucSettingsSubmit;

#if cpp
import HaxeCBridge;
#end

class MucSettingsCommand extends Command {
	@:allow(borogove)
	public function new(client: Client, jid: JID) {
		super(client, { jid: jid, name: "Settings", node: "muc-settings" });
	}

	override public function execute(): Promise<CommandSession> {
		return new Promise<CommandSession>((resolve, reject) -> {
			final q = new MucSettingsGet(this.jid.asString());
			q.onFinished(() -> {
				if (q.error != null) {
					final formish = new Stanza("x", { xmlns: "jabber:x:data", type: "result" }).textTag("instructions", q.error, { type: "error" });
					resolve(new MucSettingsCommandSession("error", null, [], [new Form(formish, null)], this));
					return;
				}

				final form = q.getResult();
				if (form == null) {
					reject("Failed to get settings form");
					return;
				}

				resolve(new MucSettingsCommandSession("executing", null, [new FormOption("Submit", "execute"), new FormOption("Cancel", "cancel")], [new Form(form, null)], this));
			});
			this.client.sendQuery(q);
		});
	}
}

class MucSettingsCommandSession extends CommandSession {
	#if js
	override public function execute(
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
	override public function execute(
		action: Null<String> = null,
		data: Null<FormSubmitBuilder> = null,
		formIdx: Int = 0
	)
	#end
	: Promise<CommandSession> {
		if (action == "cancel" || action == "prev") {
			return Promise.resolve((new MucSettingsCommandSession("canceled", null, [], [], command) : CommandSession));
		}

		final toSubmit = forms[formIdx].submit(data);
		if (toSubmit == null) return Promise.reject("Invalid submission");

		return new Promise<CommandSession>((resolve, reject) -> {
			final q = new MucSettingsSubmit(this.command.jid.asString(), toSubmit);
			q.onFinished(() -> {
				if (q.error != null) {
					final formish = new Stanza("x", { xmlns: "jabber:x:data", type: "result" }).textTag("instructions", q.error, { type: "error" });
					resolve(new MucSettingsCommandSession("error", null, [], [new Form(formish, null)], this.command));
					return;
				}

				if (!q.getResult()) {
					reject("Failed to submit settings");
					return;
				}

				resolve(new MucSettingsCommandSession("completed", null, [], [], this.command));
			});
			this.command.client.sendQuery(q);
		});
	}
}
