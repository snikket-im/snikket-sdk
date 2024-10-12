package snikket.queries;

import haxe.crypto.Base64;
import haxe.io.Bytes;
using StringTools;

class BoB extends GenericQuery {
	private static inline function uri(hash: Hash):String {
		final algo = hash.algorithm == "sha-1" ? "sha1" : hash.algorithm;
		return "cid:" + algo.urlEncode() + "+" + hash.toHex() + "@bob.xmpp.org";
	}

	public final xmlns = "urn:xmpp:bob";
	public final queryId: String;
	private var responseStanza:Stanza;
	private var result: {bytes: Bytes, type: String, maxAge: Null<Int>};

	public function new(to: Null<String>, uri: String) {
		if (!uri.startsWith("cid:") || !uri.endsWith("@bob.xmpp.org") || !uri.contains("+")) throw "invalid BoB URI";

		queryId = ID.short();
		queryStanza = new Stanza("iq", { to: to, type: "get", id: queryId })
			.tag("data", { xmlns: xmlns, cid: uri.substr(4) }).up();
	}

	public static function forHash(to: Null<String>, hash: Hash) {
		return new BoB(to, uri(hash));
	}

	public function handleResponse(stanza:Stanza) {
		responseStanza = stanza;
		finish();
	}

	public function getResult() {
		if (responseStanza == null) {
			return null;
		}
		if(result == null) {
			final data = responseStanza.getChild("data", xmlns);
			if(data == null) {
				return null;
			}
			final maxAge = data.attr.get("max-age");
			result = {
				bytes: Base64.decode(data.getText().replace("\n", "")),
				type: data.attr.get("type"),
				maxAge: maxAge == null ? null : Std.parseInt(maxAge)
			};
		}
		return result;
	}
}
