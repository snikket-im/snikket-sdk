package test;

import utest.Assert;

import borogove.CapsRepo;
import borogove.Chat.AvailableChat;
import borogove.JID;
import borogove.Member;
import borogove.MemberUpdate;
import borogove.Presence;
import borogove.Role;
import borogove.Stanza;

@:access(borogove)
class TestMemberUpdate extends utest.Test {
	function role(id: String, title = "") {
		return new Role(id, title == "" ? id : title);
	}

	function member(?roles: Array<Role>, ?presence: Map<String, Presence>, ?isSelf = false) {
		return new Member(
			"room@example.com/occ-1",
			"Alice",
			null,
			isSelf,
			roles ?? [],
			JID.parse("alice@example.com"),
			presence ?? new Map(),
			new AvailableChat("alice@example.com", "Alice", "", CapsRepo.empty)
		);
	}

	public function testApplyToNull() {
		final update = new MemberUpdate(
			"room@example.com/occ-1",
			JID.parse("alice@example.com"),
			"Alice",
			false,
			Role.forAffiliation("admin"),
			["desk" => Stanza.parse('<presence><show>away</show></presence>')]
		);
		final applied = update.applyTo(null);

		Assert.equals("room@example.com/occ-1", applied.id);
		Assert.equals("Alice", applied.displayName);
		Assert.equals("alice@example.com", applied.jid.asString());
		Assert.equals(1, applied.roles.length);
		Assert.equals("admin", applied.roles[0].id);
		Assert.notNull(applied.chat);
		Assert.equals("alice@example.com", applied.chat.chatId);
		Assert.notNull(applied.presence.get("desk"));
	}

	public function testApplyToNoneKeepsNonAffiliationRoles() {
		final update = new MemberUpdate(
			"room@example.com/occ-1",
			JID.parse("alice@example.com"),
			null,
			false,
			Role.forAffiliation("none"),
			new Map()
		);
		final applied = update.applyTo(member([
			role("admin", "Admin"),
			role("urn:xmpp:hats:test", "Tea Host")
		]));

		Assert.equals(1, applied.roles.length);
		Assert.equals("none", applied.roles[0].id);
	}

	public function testApplyToMergesPresence() {
		final update = new MemberUpdate(
			"room@example.com/occ-1",
			JID.parse("alice@example.com"),
			null,
			false,
			null,
			["mobile" => Stanza.parse('<presence><priority>5</priority></presence>')]
		);
		final applied = update.applyTo(member([], [
			"desktop" => Stanza.parse('<presence><show>away</show></presence>')
		]));

		Assert.notNull(applied.presence.get("desktop"));
		Assert.notNull(applied.presence.get("mobile"));
	}

	public function testApplyToMismatchedIdThrows() {
		final update = new MemberUpdate(
			"room@example.com/occ-2",
			JID.parse("mallory@example.com"),
			null,
			false,
			null,
			new Map()
		);

		Assert.raises(() -> update.applyTo(member()), String);
	}

	public function testApplyToMismatchedSelfThrows() {
		final update = new MemberUpdate(
			"room@example.com/occ-1",
			JID.parse("alice@example.com"),
			null,
			true,
			null,
			new Map()
		);

		Assert.raises(() -> update.applyTo(member([], new Map(), false)), String);
	}
}
