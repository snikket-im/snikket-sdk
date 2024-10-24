package snikket;

using Lambda;

@:nullSafety(Strict)
@:expose
class ReactionUpdate {
	public final updateId: String;
	public final serverId: Null<String>;
	public final serverIdBy: Null<String>;
	public final localId: Null<String>;
	public final chatId: String;
	public final timestamp: String;
	public final senderId: String;
	public final reactions: Array<String>;
	public final append: Bool;

	public function new(updateId: String, serverId: Null<String>, serverIdBy: Null<String>, localId: Null<String>, chatId: String, timestamp: String, senderId: String, reactions: Array<String>, ?append: Bool = false) {
		if (serverId == null && localId == null) throw "ReactionUpdate serverId and localId cannot both be null";
		if (serverId != null && serverIdBy == null) throw "serverId requires serverIdBy";
		this.updateId = updateId;
		this.serverId = serverId;
		this.serverIdBy = serverIdBy;
		this.localId = localId;
		this.chatId = chatId;
		this.timestamp = timestamp;
		this.senderId = senderId;
		this.reactions = reactions;
		this.append = append ?? false;
	}

	public function getReactions(existingReactions: Null<Array<String>>): Array<String> {
		if (append) {
			final set: Map<String, Bool> = [];
			for (r in existingReactions ?? []) {
				set[r] = true;
			}
			for (r in reactions) {
				set[r] = true;
			}
			return { iterator: () -> set.keys() }.array();
		} else {
			return reactions;
		}
	}

	@:allow(snikket)
	private function inlineHashReferences() {
		final hashes = [];
		for (r in reactions) {
			final hash = Hash.fromUri(r);
			if (hash != null) hashes.push(hash);
		}
		return hashes;
	}

	// Note that using this version means you don't get any fallbacks!
	@:allow(snikket)
	private function asStanza():Stanza {
		if (append) throw "Cannot make a reaction XEP stanza for an append";

		var attrs: haxe.DynamicAccess<String> = { type: serverId == null ? "chat" : "groupchat", id: updateId };
		var stanza = new Stanza("message", attrs);

		stanza.tag("reactions", { xmlns: "urn:xmpp:reactions:0", id: localId ?? serverId });
		for (reaction in reactions) {
			stanza.textTag("reaction", reaction);
		}
		stanza.up();

		return stanza;
	}
}
