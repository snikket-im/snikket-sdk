package borogove;

import thenshim.Promise;

import borogove.Chat;
import borogove.queries.DiscoInfoGet;
import borogove.queries.JabberIqGatewayGet;
import borogove.Util;
using Lambda;
using StringTools;

#if cpp
import HaxeCBridge;
#end

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
@:HaxeSwiftBridge.asyncSequence(AvailableChat)
#end
class AvailableChatIterator {
	/**
		The query that this iterator is returning results for
	**/
	public final q: String;
	private final query: String;
	private final client: Client;
	private final persistence: Persistence;
	private var results: Array<Promise<Null<AvailableChat>>> = [];
	private var dedup: Map<String, Bool> = [];

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

				return Promise.resolve(null);
			}));
		}

		final lowerQ = query.toLowerCase();
		for (chat in client.chats) {
			if (chat.chatId != client.accountId()) {
				if (chat.chatId.contains(lowerQ) || chat.getDisplayName().toLowerCase().contains(lowerQ) || Util.existsFast(chat.getTags(), t -> t.toLowerCase() == lowerQ)) {
					final channel = Util.downcast(chat, Channel);
					results.push(Promise.resolve(new AvailableChat(chat.chatId, chat.getDisplayName(), chat.chatId, channel == null || channel.disco == null ? new Caps("", [], [], []) : channel.disco)));
				}

				for (p in chat.getParticipants()) {
					final details = chat.getParticipantDetails(p);
					if (details.chat != null && (details.chat.chatId.contains(lowerQ) || (details.chat.displayName ?? "").toLowerCase().contains(lowerQ))) {
						results.push(Promise.resolve(details.chat));
					}
				}
			}
			if (chat.isTrusted()) {
				final resources:Map<String, Bool> = [];
				for (resource in Caps.withIdentity(chat.getCaps(), "gateway", null)) {
					// Sometimes gateway items also have id "gateway" for whatever reason
					final identities = chat.getResourceCaps(resource)?.identities ?? [];
					if (
						(chat.chatId.indexOf("@") < 0 || identities.find(i -> i.category == "conference") == null) &&
						identities.find(i -> i.category == "client") == null
					) {
						resources[resource] = true;
					}
				}
				/* Gajim advertises this, so just go with identity instead
				for (resource in Caps.withFeature(chat.getCaps(), "jabber:iq:gateway")) {
					resources[resource] = true;
				}*/
				if (!client.sendAvailable && JID.parse(chat.chatId).isDomain()) {
					resources[null] = true;
				}
				for (resource in resources.keys()) {
					final bareJid = JID.parse(chat.chatId);
					final fullJid = new JID(bareJid.node, bareJid.domain, bareJid.isDomain() && resource == "" ? null : resource);
					final jigGet = new JabberIqGatewayGet(fullJid.asString(), query);
					results.push(new Promise((resolve, reject) -> {
						jigGet.onFinished(() -> {
							final result = jigGet.getResult();
							if (result == null) {
								final caps = chat.getResourceCaps(resource);
								if (bareJid.isDomain() && caps.features.contains("jid\\20escaping")) {
									check(new JID(query, bareJid.domain)).then(resolve);
								} else if (bareJid.isDomain()) {
									check(new JID(StringTools.replace(query, "@", "%"), bareJid.domain)).then(resolve);
								}
							} else {
								switch (result) {
									case Left(error): resolve(null);
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
	}

	private function check(jid: JID) {
		return new Promise((resolve, reject) -> {
			final discoGet = new DiscoInfoGet(jid.asString());
			discoGet.onFinished(() -> {
				final resultCaps = discoGet.getResult();
				if (resultCaps == null) {
					final err = discoGet.responseStanza?.getChild("error")?.getChild(null, "urn:ietf:params:xml:ns:xmpp-stanzas");
					if (err == null || err?.name == "service-unavailable" || err?.name == "feature-not-implemented") {
						resolve(new AvailableChat(jid.asString(), jid.node == null ? query : jid.node, jid.asString(), new Caps("", [], [], [])));
					} else {
						resolve(null);
					}
				} else {
					client.capsRepo.add(resultCaps);
					final identity = resultCaps.identities[0];
					final displayName = identity?.name ?? query;
					final note = jid.asString() + (identity == null ? "" : " (" + identity.type + ")");
					resolve(new AvailableChat(jid.asString(), displayName, note, resultCaps));
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

	public function next(): Promise<{ done: Bool, ?value: AvailableChat }> {
		return internalNext().then(v -> {
			return { done: v == null, value: v };
		});
	}
	#else
	public function next(): Promise<Null<AvailableChat>> {
		return internalNext();
	}
	#end

	private function internalNext(): Promise<Null<AvailableChat>> {
		if (results.length < 1) return Promise.resolve(null);

		return results.shift().then(available -> {
			if (available == null || dedup[available.chatId]) {
				return this.internalNext();
			} else {
				dedup[available.chatId] = true;
				return Promise.resolve(available);
			}
		});
	}
}
