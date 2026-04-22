package borogove;

import thenshim.Promise;

@:nullSafety(StrictThreaded)
class CapsRepo {
	private final persistence: Persistence;
	private final cache: Map<String, Caps> = [];

	public function new(persistence: Persistence) {
		this.persistence = persistence;
	}

	public function add(caps: Caps) {
		persistence.storeCaps(caps);
		cache[caps.ver()] = caps;
	}

	public function getAsync(presence: Presence): Promise<Null<Caps>> {
		final ver = presence.ver;
		if (ver == null) return Promise.resolve(cast null);

		final cached = cache[ver];
		if (cached != null) return Promise.resolve(cached);

		return persistence.getCaps(ver).then(result -> {
			final caps = result;
			if (caps != null) cache[caps.ver()] = caps;
			return Promise.resolve(cast caps);
		});
	}

	public function get(presence: Presence) {
		final ver = presence.ver;
		if (ver != null) {
			final cached = cache[ver];
			if (cached != null) return cached;

			getAsync(presence); // Fetch and put in cache for later
		}

		return new Caps("", [], [], []);
	}
}
