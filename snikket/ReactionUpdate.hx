package snikket;

import snikket.Reaction;
using Lambda;

enum abstract ReactionUpdateKind(Int) {
	var EmojiReactions;
	var AppendReactions;
	var CompleteReactions;
}

@:nullSafety(Strict)
@:expose
class ReactionUpdate {
	public final updateId: String;
	public final serverId: Null<String>;
	public final serverIdBy: Null<String>;
	public final localId: Null<String>;
	public final chatId: String;
	public final senderId: String;
	public final timestamp: String;
	public final reactions: Array<Reaction>;
	public final kind: ReactionUpdateKind;

	public function new(updateId: String, serverId: Null<String>, serverIdBy: Null<String>, localId: Null<String>, chatId: String, senderId: String, timestamp: String, reactions: Array<Reaction>, kind: ReactionUpdateKind) {
		if (serverId == null && localId == null) throw "ReactionUpdate serverId and localId cannot both be null";
		if (serverId != null && serverIdBy == null) throw "serverId requires serverIdBy";
		this.updateId = updateId;
		this.serverId = serverId;
		this.serverIdBy = serverIdBy;
		this.localId = localId;
		this.chatId = chatId;
		this.senderId = senderId;
		this.timestamp = timestamp;
		this.reactions = reactions;
		this.kind = kind;
	}

	public function getReactions(existingReactions: Null<Array<Reaction>>): Array<Reaction> {
		if (kind == AppendReactions) { // TODO: make sure a new non-custom react doesn't override any customs we've added
			final set: Map<String, Bool> = [];
			final list = [];
			for (r in existingReactions ?? []) {
				if (!set.exists(r.key)) list.push(r);
				set[r.key] = true;
			}
			for (r in reactions) {
				if (!set.exists(r.key)) list.push(r);
				set[r.key] = true;
			}
			return list;
		} else if (kind == EmojiReactions) {
			// Complete set of emoji but lacks any customs added before now
			final list = reactions.array();
			for (r in existingReactions ?? []) {
				final custom = Util.downcast(r, CustomEmojiReaction);
				if (custom != null) list.push(custom);
			}
			return list;
		} else if (kind == CompleteReactions) {
			return reactions;
		}
		throw "Unknown kind of reaction update";
	}

	@:allow(snikket)
	private function inlineHashReferences() {
		final hashes = [];
		for (r in reactions) {
			final custom = Util.downcast(r, CustomEmojiReaction);
			if (custom != null) {
				final hash = Hash.fromUri(custom.uri);
				if (hash != null) hashes.push(hash);
			}
		}
		return hashes;
	}

	// Note that using this version means you don't get any fallbacks!
	// It also won't update any custom emoji reactions at all
	@:allow(snikket)
	private function asStanza():Stanza {
		if (kind != EmojiReactions) throw "Cannot make a reaction XEP stanza for this kind";

		var attrs: haxe.DynamicAccess<String> = { type: serverId == null ? "chat" : "groupchat", id: updateId };
		var stanza = new Stanza("message", attrs);

		stanza.tag("reactions", { xmlns: "urn:xmpp:reactions:0", id: localId ?? serverId });
		for (reaction in reactions) {
			if (!Std.is(reaction, CustomEmojiReaction)) stanza.textTag("reaction", reaction.text);
		}
		stanza.up();

		return stanza;
	}
}
