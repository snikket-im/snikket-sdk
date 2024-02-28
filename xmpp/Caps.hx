package xmpp;

import haxe.crypto.Base64;
import haxe.crypto.Sha1;
import haxe.io.Bytes;
using Lambda;

@:expose
class Caps {
	private final node: String;
	public final identities: Array<Identity>;
	public final features : Array<String>;
	// TODO: data forms

	public static function withIdentity(caps:KeyValueIterator<String, Null<Caps>>, category:Null<String>, type:Null<String>):Array<String> {
		final result = [];
		for (cap in caps) {
			if (cap.value != null) {
				for (identity in cap.value.identities) {
					if ((category == null || category == identity.category) && (type == null || type == identity.type)) {
						result.push(cap.key);
					}
				}
			}
		}
		return result;
	}

	public static function withFeature(caps:KeyValueIterator<String, Null<Caps>>, feature:String):Array<String> {
		final result = [];
		for (cap in caps) {
			if (cap.value != null) {
				for (feat in cap.value.features) {
					if (feature == feat) {
						result.push(cap.key);
					}
				}
			}
		}
		return result;
	}

	public function new(node: String, identities: Array<Identity>, features: Array<String>) {
		this.node = node;
		this.identities = identities;
		this.features = features;
	}

	public function isChannel(chatId: String) {
		if (chatId.indexOf("@") < 0) return false; // MUC must have a localpart
		return features.contains("http://jabber.org/protocol/muc") && identities.find((identity) -> identity.category == "conference") != null;
	}

	public function discoReply():Stanza {
		final query = new Stanza("query", { xmlns: "http://jabber.org/protocol/disco#info" });
		for (identity in identities) {
			identity.addToDisco(query);
		}
		for (feature in features) {
			query.tag("feature", { "var": feature }).up();
		}
		return query;
	}

	public function addC(stanza: Stanza): Stanza {
		stanza.tag("c", {
			xmlns: "http://jabber.org/protocol/caps",
			hash: "sha-1",
			node: node,
			ver: ver()
		}).up();
		return stanza;
	}

	public function verRaw(): Bytes {
		features.sort((x, y) -> x == y ? 0 : (x < y ? -1 : 1));
		identities.sort((x, y) -> x.ver() == y.ver() ? 0 : (x.ver() < y.ver() ? -1 : 1));
		var s = "";
		for (identity in identities) {
			s += identity.ver() + "<";
		}
		for (feature in features) {
			s += feature + "<";
		}
		return Sha1.make(Bytes.ofString(s));
	}

	public function ver(): String {
		return Base64.encode(verRaw(), true);
	}
}

@:expose
class Identity {
	public final category:String;
	public final type:String;
	public final name:String;

	public function new(category:String, type: String, name: String) {
		this.category = category;
		this.type = type;
		this.name = name;
	}

	public function addToDisco(stanza: Stanza) {
		stanza.tag("identity", { category: category, type: type, name: name }).up();
	}

	public function ver(): String {
		return category + "/" + type + "//" + name;
	}
}
