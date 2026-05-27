package borogove;

import thenshim.Promise;

import borogove.Chat;
import borogove.queries.DiscoInfoGet;
import borogove.queries.JabberIqGatewayGet;
import borogove.Util;
using Lambda;
using StringTools;
using borogove.Util;

#if cpp
import HaxeCBridge;
#end

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
@:HaxeSwiftBridge.asyncSequence(AvailableChat)
#end
@:nullSafety(StrictThreaded)
class AvailableChatIterator {
	/**
		The query that this iterator is returning results for
	**/
	public final q: String;
	private final query: String;
	private final client: Client;
	private final persistence: Persistence;
	private var results: Array<Promise<Array<AvailableChat>>> = [];
	private var head: Array<AvailableChat> = [];
	private var dedup: Map<String, Bool> = new Map();

	@:allow(borogove)
	private function new(q: String, client: Client, persistence: Persistence) {
		this.q = q;
		this.client = client;
		this.persistence = persistence;
		this.query = q.trim();

		final vcard_regex = ~/\nIMPP[^:]*:xmpp:(.+)\n/;
		final jid = if (StringTools.startsWith(query, "xmpp:")) {
			final parts = query.substr(5).split("?");
			JID.parse(uriDecode(parts[0]));
		} else if (StringTools.startsWith(query, "BEGIN:VCARD") && vcard_regex.match(query)) {
			final parts = vcard_regex.matched(1).split("?");
			JID.parse(uriDecode(parts[0]));
		} else if (StringTools.startsWith(query, "https://")) {
			final hashParts = query.split("#");
			if (hashParts.length > 1) {
				JID.parse(uriDecode(hashParts[1]));
			} else {
				final pathParts = hashParts[0].split("/");
				JID.parse(uriDecode(pathParts[pathParts.length - 1]));
			}
		} else {
			JID.parse(query);
		}
		if (jid.isValid()) {
			results.push(check(jid));
		}

		if (StringTools.startsWith(query, "https://")) {
			results.push(xmppLinkHeader(query).then(xmppUri -> {
				final parts = xmppUri.substr(5).split("?");
				final jid = JID.parse(uriDecode(parts[0]));
				if (jid.isValid()) return check(jid);

				return Promise.resolve([]);
			}));
		}

		final lowerQ = query.toLowerCase();
		final laterResults = [];
		for (chat in client.chats) {
			if (chat.chatId != client.accountId()) {
				if (chat.chatId.contains(lowerQ) || chat.getDisplayName().toLowerCase().contains(lowerQ) || Util.existsFast(chat.getTags(), t -> t.toLowerCase() == lowerQ)) {
					final caps = chat.getCaps();
					final available = Promise.resolve([new AvailableChat(chat.chatId, chat.getDisplayName(), chat.chatId, caps.hasNext() ? caps.next().value : CapsRepo.empty)]);
					if (chat.isTrusted()) {
						results.push(available);
					} else {
						laterResults.push(available);
					}
				}

				laterResults.push(chat.members().then(members ->
					members.map(member -> member.chat).filterOutNulls(chat ->
						chat != null && (chat.chatId.contains(lowerQ) || (chat.displayName ?? "").toLowerCase().contains(lowerQ))
					)
				));
			}
			if (chat.isTrusted()) {
				final resources:StringMapNullableKey<Caps> = new StringMapNullableKey();
				for (resource => caps in Caps.withIdentity(chat.getCaps(), "gateway", null)) {
					// Sometimes gateway items also have id "gateway" for whatever reason
					final identities = caps.identities;
					if (
						(chat.chatId.indexOf("@") < 0 || identities.find(i -> i.category == "conference") == null) &&
						identities.find(i -> i.category == "client") == null
					) {
						resources[resource] = caps;
					}
				}
				/* Gajim advertises this, so just go with identity instead
				for (resource => caps in Caps.withFeature(chat.getCaps(), "jabber:iq:gateway")) {
					resources[resource] = true;
				}*/
				if (!resources.exists(null) && !client.sendAvailable && JID.parse(chat.chatId).isDomain()) {
					resources[null] = CapsRepo.empty;
				}
				for (resource => caps in resources) {
					final bareJid = JID.parse(chat.chatId);
					final fullJid = new JID(bareJid.node, bareJid.domain, bareJid.isDomain() && resource == "" ? null : resource);
					final jigGet = new JabberIqGatewayGet(fullJid.asString(), query);
					results.unshift(new Promise((resolve, reject) -> {
						jigGet.onFinished(() -> {
							final result = jigGet.getResult();
							if (result == null) {
								if (bareJid.isDomain() && caps.features.contains("jid\\20escaping")) {
									check(new JID(query, bareJid.domain)).then(resolve);
								} else if (bareJid.isDomain()) {
									check(new JID(StringTools.replace(query, "@", "%"), bareJid.domain)).then(resolve);
								}
							} else {
								switch (result) {
									case Left(error): resolve([]);
									case Right(result):
										check(JID.parse(result)).then(resolve);
								}
							}
						});
						client.sendQuery(jigGet);
					}));
				}
			}
		}

		// Sort some results to the end
		for (later in laterResults) {
			results.push(later);
		}
	}

	private function check(jid: JID) {
		return new Promise((resolve, reject) -> {
			final discoGet = new DiscoInfoGet(jid.asString());
			discoGet.onFinished(() -> {
				final resultCaps = discoGet.getResult();
				if (resultCaps == null) {
					final err = discoGet.responseStanza?.getChild("error")?.getChild(null, "urn:ietf:params:xml:ns:xmpp-stanzas");
					if (err == null || err?.name == "service-unavailable" || err?.name == "feature-not-implemented") {
						resolve([new AvailableChat(jid.asString(), jid.node == null ? query : jid.node, jid.asString(), CapsRepo.empty)]);
					} else {
						resolve([]);
					}
				} else {
					final caps = client.capsRepo.add(resultCaps);
					final identity = resultCaps.identities[0];
					final displayName = identity?.name ?? query;
					final note = jid.asString() + (identity == null ? "" : " (" + identity.type + ")");
					resolve([new AvailableChat(jid.asString(), displayName, note, caps)]);
				}
			});
			client.sendQuery(discoGet);
		});
	}

	/**
		Get the next AvailableChat from this iterator
	**/
	#if js
	@:native("[Symbol.asyncIterator]")
	public function asyncIterator() {
		return this;
	}

	/**
		Get the next AvailableChat from this iterator for JavaScript async iteration.

		@returns Promise resolving to the next iterator result
	**/
	public function next(): Promise<{ done: Bool, ?value: AvailableChat }> {
		return internalNext().then(v -> {
			return { done: v == null, value: v };
		});
	}
	#else
	/**
		Get the next AvailableChat from this iterator.

		@returns Promise resolving to the next result, or null when exhausted
	**/
	public function next(): Promise<Null<AvailableChat>> {
		return internalNext();
	}
	#end

	private function internalNext(): Promise<Null<AvailableChat>> {
		if (head.length > 0) {
			final available = head.shift();

			if (available != null) {
				if (dedup.exists(available.chatId)) return internalNext();

				dedup[available.chatId] = true;
				return Promise.resolve(available);
			}
		}

		final promise = results.shift();
		if (promise == null) return Promise.resolve(cast null);

		return promise.then(availables -> {
			head = availables;
			return internalNext();
		});
	}
}
