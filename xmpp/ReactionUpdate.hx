package xmpp;

@:nullSafety(Strict)
class ReactionUpdate {
	public final updateId: String;
	public final serverId: Null<String>;
	public final localId: Null<String>;
	public final chatId: String;
	public final timestamp: String;
	public final senderId: String;
	public final reactions: Array<String>;

	public function new(updateId: String, serverId: Null<String>, localId: Null<String>, chatId: String, timestamp: String, senderId: String, reactions: Array<String>) {
		if (serverId == null && localId == null) throw "ReactionUpdate serverId and localId cannot both be null";
		this.updateId = updateId;
		this.serverId = serverId;
		this.localId = localId;
		this.chatId = chatId;
		this.timestamp = timestamp;
		this.senderId = senderId;
		this.reactions = reactions;
	}

	// Note that using this version means you don't get any fallbacks!
	public function asStanza():Stanza {
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
