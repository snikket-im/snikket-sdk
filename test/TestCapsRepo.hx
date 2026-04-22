package test;

import utest.Assert;
import utest.Async;
import thenshim.Promise;
import borogove.Caps;
import borogove.CapsRepo;
import borogove.Presence;
import borogove.Stanza;
import borogove.persistence.Dummy;

class CapsRepoMockPersistence extends Dummy {
	public var storedCaps: Array<Caps> = [];
	public var capsMap: Map<String, Caps> = [];

	public function new() {
		super();
	}

	override public function storeCaps(caps: Caps) {
		storedCaps.push(caps);
		capsMap[caps.ver()] = caps;
	}

	override public function getCaps(ver: String): Promise<Caps> {
		return Promise.resolve(capsMap[ver]);
	}
}

class TestCapsRepo extends utest.Test {
	public function testAddAndGet(async: Async) {
		final persistence = new CapsRepoMockPersistence();
		final repo = new CapsRepo(persistence);
		final caps = new Caps("node1", [], ["feat1"], []);
		final ver = caps.ver();

		repo.add(caps);
		Assert.equals(1, persistence.storedCaps.length);
		Assert.equals(caps, persistence.storedCaps[0]);

		final presence = Stanza.parse('<presence><c xmlns="http://jabber.org/protocol/caps" node="node1" ver="$ver"/></presence>');

		repo.getAsync(presence).then(retrieved -> {
			Assert.equals(caps, retrieved);

			// Should be cached now, no second call to persistence
			persistence.capsMap.remove(ver);
			return repo.getAsync(presence);
		}).then(retrieved -> {
			Assert.equals(caps, retrieved);
			async.done();
		});
	}

	public function testGetSync() {
		final persistence = new CapsRepoMockPersistence();
		final repo = new CapsRepo(persistence);
		final caps = new Caps("node1", [], ["feat1"], []);
		final ver = caps.ver();

		repo.add(caps);

		final presence = Stanza.parse('<presence><c xmlns="http://jabber.org/protocol/caps" node="node1" ver="$ver"/></presence>');
		final retrieved = repo.get(presence);
		Assert.equals(caps, retrieved);
	}

	public function testGetSyncNotCached(async: Async) {
		final persistence = new CapsRepoMockPersistence();
		final repo = new CapsRepo(persistence);
		final caps = new Caps("node1", [], ["feat1"], []);
		final ver = caps.ver();

		// Not adding to repo, but adding to persistence
		persistence.storeCaps(caps);

		final presence = Stanza.parse('<presence><c xmlns="http://jabber.org/protocol/caps" node="node1" ver="$ver"/></presence>');
		final retrieved = repo.get(presence);
		// Should return empty caps initially
		Assert.equals("", retrieved.node);

		// But it should have triggered an async fetch, so it should be in cache soon
		haxe.Timer.delay(() -> {
			final retrieved2 = repo.get(presence);
			Assert.equals(caps.node, retrieved2.node);
			async.done();
		}, 1);
	}
}
