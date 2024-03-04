package snikket.queries;

import haxe.DynamicAccess;
import haxe.Exception;
import haxe.crypto.Base64;
import haxe.io.Bytes;

import snikket.ID;
import snikket.ResultSet;
import snikket.Stanza;
import snikket.Stream;
import snikket.queries.GenericQuery;

class VcardTempGet extends GenericQuery {
	public var xmlns(default, null) = "vcard-temp";
	public var queryId:String = null;
	public var ver:String = null;
	private var responseStanza:Stanza;
	private var result: {photo:Null<{mime:String, data:Bytes}>};

	public function new(to: JID) {
		/* Build basic query */
		queryId = ID.short();
		queryStanza = new Stanza("iq", { to: to.asString(), type: "get", id: queryId });
		queryStanza.tag("vCard", { xmlns: xmlns }).up();
	}

	public function handleResponse(stanza:Stanza) {
		responseStanza = stanza;
		finish();
	}

	public function getResult() {
		if (responseStanza == null) {
			return {photo: null};
		}
		if(result == null) {
			final vcard = responseStanza.getChild("vCard", xmlns);
			if(vcard == null) {
				return {photo: null};
			}
			final photoMime = vcard.findText("PHOTO/TYPE#");
			final photoBinval = vcard.findText("PHOTO/BINVAL#");
			if (photoMime != null && photoBinval != null) {
				result = {photo: { mime: photoMime, data: Base64.decode(StringTools.replace(photoBinval, "\n", "")) } };
			} else {
				result = {photo: null};
			}
		}
		return result;
	}
}
