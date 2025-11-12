package borogove;

import thenshim.Promise;

import borogove.Form;
import borogove.Stanza;
import borogove.Stream;
import borogove.Util;

using StringTools;

#if cpp
import HaxeCBridge;
#end

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class Register {
	private final stream: GenericStream;
	private final username: Null<String>;
	private final domain: String;
	private final preAuth: Null<String>;
	private var form: Null<Form> = null;

	private function new(domain: String, preAuth: Null<String>, username: Null<String>) {
		stream = new Stream();
		this.domain = domain;
		this.preAuth = preAuth;
		this.username = username;
	}

	/**
		Start new registration flow for a given domain or invite URL
	**/
	public static function fromDomainOrInvite(domainOrInvite: String) {
		if (domainOrInvite.startsWith("xmpp:")) {
			return Promise.resolve(fromXmppURI(domainOrInvite));
		} else if (domainOrInvite.startsWith("https://")) {
			return xmppLinkHeader(domainOrInvite).then(xmppUri -> {
				return fromXmppURI(xmppUri);
			});
		} else {
			return Promise.resolve(new Register(domainOrInvite, null, null));
		}
	}

	private static function fromXmppURI(xmppUri: String) {
		final parts = xmppUri.substr(5).split("?");
		final authParts = parts[0].split("@");
		final domain = uriDecode(authParts.length > 1 ? authParts[1] : authParts[0]);
		var preAuth: Null<String> = null;
		var username: Null<String> = null;
		if (parts.length > 1) {
			final queryParts = parts[1].split(";");
			for (part in queryParts) {
				if (part == "register" && authParts.length > 1) username = uriDecode(authParts[0]);
				if (part.startsWith("preauth=")) {
					preAuth = uriDecode(part.substr(8));
				}
			}
		}
		return new Register(domain, preAuth, username);
	}

	/**
		Fetch registration form from the server.
		If you already know what fields your server wants, this is optional.
	**/
	public function getForm() {
		return stream.register(domain, preAuth).then(reply -> {
			final error = reply.getErrorText();
			if (error != null) return Promise.reject(error);

			final query = reply.getChild("query", "jabber:iq:register");
			final form: DataForm = query.getChild("x", "jabber:x:data");
			if (form == null) {
				return Promise.reject("No form found");
			}

			if (username != null) {
				final fuser = form.field("username");
				fuser.value = [username];
				(fuser : Stanza).attr.set("type", "fixed");
			}

			this.form = new Form(form);
			return Promise.resolve(this.form);
		});
	}

	/**
		Submit registration data to the server
	**/
	#if js
	public function submit(
		data: haxe.extern.EitherType<
			haxe.extern.EitherType<
				haxe.DynamicAccess<StringOrArray>,
				Map<String, StringOrArray>
			>,
			js.html.FormData
		>
	)
	#else
	public function submit(data: FormSubmitBuilder)
	#end
	: Promise<String> {
		return (form == null ? getForm() : Promise.resolve(null)).then(_ -> {
			final toSubmit: DataForm = form.submit(data);
			if (toSubmit == null) return Promise.reject("Invalid submission");

			return new Promise((resolve, reject) -> {
				stream.sendIq(
					new Stanza("iq", { type: "set", to: domain })
						.tag("query", { xmlns: "jabber:iq:register" })
						.addChild(toSubmit),
					(reply) -> {
						final error = reply.getErrorText();
						if (error != null) return reject(error);

						// It is conventional for username@domain to be the registered JID
						// IBR doesn't really give us a better option right now
						resolve(toSubmit.field("username")?.value?.join("") + "@" + domain);
					}
				);
			});
		});
	}

	/**
		Disconnect from the server after registration is done
	**/
	public function disconnect() {
		stream.disconnect();
	}
}
