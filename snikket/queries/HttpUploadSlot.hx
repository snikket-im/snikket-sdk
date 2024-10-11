package snikket.queries;

import haxe.DynamicAccess;
import haxe.Exception;
import haxe.crypto.Base64;
import haxe.io.Bytes;
import haxe.io.BytesData;

import snikket.ID;
import snikket.JID;
import snikket.ResultSet;
import snikket.Stanza;
import snikket.Stream;
import snikket.queries.GenericQuery;

class HttpUploadSlot extends GenericQuery {
	public var xmlns(default, null) = "urn:xmpp:http:upload:0";
	public var queryId:String = null;
	public var responseStanza(default, null):Stanza;
	private var result: { put: String, putHeaders: Array<tink.http.Header.HeaderField>, get: String };

	public function new(to: String, filename: String, size: Int, mime: String, hashes: Array<Hash>) {
		/* Build basic query */
		queryId = ID.short();
		queryStanza = new Stanza(
			"iq",
			{ to: to, type: "get", id: queryId }
		).tag("request", { xmlns: xmlns, filename: filename, size: Std.string(size), "content-type": mime });
		for (hash in hashes) {
			queryStanza.textTag("hash", Base64.encode(Bytes.ofData(hash.hash)), { xmlns: "urn:xmpp:hashes:2", algo: hash.algorithm });
		}
		queryStanza.up();
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
			final q = responseStanza.getChild("slot", xmlns);
			if(q == null) {
				return null;
			}
			final get = q.findText("get@url");
			if (get == null) return null;
			final put = q.findText("put@url");
			if (put == null) return null;
			final headers = [];
			for (header in q.getChild("put").allTags("header")) {
				headers.push(new tink.http.Header.HeaderField(header.attr.get("name"), header.getText()));
			}
			result = { get: get, put: put, putHeaders: headers };
		}
		return result;
	}
}
