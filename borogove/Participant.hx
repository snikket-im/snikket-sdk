package borogove;

import thenshim.Promise;
import haxe.ds.ReadOnlyArray;

import borogove.Chat;
import borogove.queries.PubsubGet;

#if cpp
import HaxeCBridge;
#end

@:expose
@:nullSafety(Strict)
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class Participant {
	/**
		Display name to show for this participant
	**/
	public final displayName: String;

	/**
		Avatar URI for this participant, or null when none is known
	**/
	public final photoUri: Null<String>;

	/**
		Fallback avatar URI to use when no photo is available
	**/
	public final placeholderUri: String;

	/**
		True when this participant is the connected account
	**/
	public final isSelf: Bool;

	/**
		Chat metadata for this participant when it is available as a direct Chat
	**/
	public final chat: Null<AvailableChat>;

	/**
		Roles this participant has in the Chat
	**/
	public final roles: ReadOnlyArray<Role>;

	private final jid: JID;

	@:allow(borogove)
	private function new(displayName: String, photoUri: Null<String>, placeholderUri: String, isSelf: Bool, roles: Array<Role>, jid: JID, chat: Null<AvailableChat>) {
		this.displayName = displayName;
		this.photoUri = photoUri;
		this.placeholderUri = placeholderUri;
		this.isSelf = isSelf;
		this.roles = roles;
		this.chat = chat;
		this.jid = jid;
	}

	/**
		Load the participant's profile

		@param client connected client used to send the profile query
		@returns Promise resolving to the participant profile
	**/
	public function profile(client: Client): Promise<Profile> {
		return new Promise((resolve, reject) -> {
			final get = new PubsubGet(jid.asString(), "urn:xmpp:vcard4");
			get.onFinished(() -> {
				final item = get.getResult()[0];
				final fromItem = item?.getChild("vcard", "urn:ietf:params:xml:ns:vcard-4.0");
				final vcard = fromItem == null ? new Stanza("vcard", { xmlns: "urn:ietf:params:xml:ns:vcard-4.0" }) : fromItem;
				if (!vcard.hasChild("fn")) {
					vcard.insertChild(0, new Stanza("fn").textTag("text", displayName));
				}
				resolve(new Profile(vcard));
			});
			client.sendQuery(get);
		});
	}
}
