package borogove;

import thenshim.Promise;
import haxe.ds.ReadOnlyArray;

import borogove.Chat;
import borogove.queries.PubsubGet;

#if cpp
import HaxeCBridge;
#end

// Some updates are partial
// We encode the more low-level values here
@:nullSafety(Strict)
class MemberUpdate {
	public final id: Null<String>;
	public final jid: Null<JID>;
	private final displayName: Null<String>;
	private final isSelf: Bool;
	private final affiliation: Null<Role>; // Null means "member"
	private final presence: Map<String, Presence>;

	@:allow(borogove)
	private function new(id: Null<String>, jid: Null<JID>, displayName: Null<String>, isSelf: Bool, affiliation: Null<Role>, presence: Map<String, Presence>) {
		this.id = id;
		this.jid = jid;
		this.displayName = displayName;
		this.isSelf = isSelf;
		this.affiliation = affiliation;
		this.presence = presence;
	}

	public function applyTo(member: Null<Member>) {
		if (id != null || jid != null) {
			if (member != null && member?.id != id && member?.chat?.chatId != jid?.asString()) throw "Member does not match this update";
		}
		if (member != null && isSelf != member?.isSelf) throw "Member does not match this update";
		final filteredRoles = affiliation?.id == "none" ? [] : (member?.roles ?? []).filter(r -> !["owner", "admin", "member", "none", "outcast"].contains(r.id));
		final mergedPresence = new Map();

		for (resource => p in member?.presence ?? new Map()) {
			mergedPresence.set(resource, p);
		}

		for (resource => p in presence) {
			mergedPresence.set(resource, p);
		}

		return {
			id: id ?? member?.id,
			displayName: displayName ?? (member?.displayName == "" ? null : member?.displayName) ?? jid?.asString(),
			photoUri: member?.photoUri,
			isSelf: isSelf,
			roles: filteredRoles.concat(affiliation == null ? [] : [affiliation]),
			jid: member?.jid ?? jid,
			presence: mergedPresence,
			chat: jid == null ? null : new AvailableChat(jid.asBare().asString(), displayName, "", CapsRepo.empty)
		};
	}

	static public function extractUpdates(accountId: String, chat: Chat, stanza: Stanza) {
		final updates = [];
		final mucUser = stanza.getChild("x", "http://jabber.org/protocol/muc#user");
		if (mucUser != null) {
			final sOccupantId = stanza.getChild("occupant-id", "urn:xmpp:occupant-id:0")?.attr?.get("id");
			final from = stanza.attr.get("from");
			final resource = stanza.name == "presence" && from != null ? JID.parse(from).resource : null;
			final channel = Util.downcast(chat, Channel);
			for (item in mucUser.allTags("item")) {
				final jidS = item.attr.get("jid");
				final jid = jidS == null ? null : JID.parse(jidS).asBare();
				final occupantId: Null<String> = item.getChild("occupant-id", "urn:xmpp:occupant-id:0")?.attr?.get("id") ?? sOccupantId;
				final id = occupantId == null ? null : chat.chatId + "/" + occupantId;
				final aff = item.attr.get("affiliation");
				if (aff == null) {
					trace("No affiliation on affiliation update", stanza);
				} else {
					updates.push(new MemberUpdate(
						id,
						jid,
						item.attr.get("nick") ?? resource,
						jid?.asString() == accountId || channel?.self?.id == id,
						Role.forAffiliation(aff),
						stanza.name == "presence" ? [ resource ?? "" => stanza ] : new Map()
					));
				}
			}
		}

		return updates;
	}
}
