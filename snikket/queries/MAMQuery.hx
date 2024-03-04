package snikket.queries;

import haxe.Exception;

import snikket.ID;
import snikket.ResultSet;
import snikket.Stanza;
import snikket.Stream;
import snikket.queries.GenericQuery;

typedef MAMQueryParams = {
	var ?startTime : String;
	var ?endTime : String;
	var ?with : String;
	var ?beforeId : String;
	var ?afterId : String;
	var ?ids : Array<String>;

	var ?page : {
		var ?before : String;
		var ?after : String;
		var ?limit : Int;
	};
};

typedef MAMQueryResult = {
	var complete : Bool;
	var page : ResultSetPageResult;
};

class MAMQuery extends GenericQuery {
	public var xmlns(default, null) = "urn:xmpp:mam:2";
	public var queryId:String = null;
	public var responseStanza(default, null):Stanza;
	private var result:MAMQueryResult;

	private function addStringField(name:String, value:String) {
		if(value == null) {
			return;
		}
		queryStanza
			.tag("field", { "var": name })
				.textTag("value", value)
			.up();
	}

	private function addArrayField(name:String, values:Array<String>) {
		if(values == null) {
			return;
		}
		queryStanza.tag("field", { "var": name });
		for (value in values) {
			queryStanza.textTag("value", value);
		}
		queryStanza.up();
	}

	public function new(params:MAMQueryParams, ?jid:String) {
		/* Build basic query */
		queryId = ID.short();
		queryStanza = new Stanza("iq", { type: "set", to: jid })
			.tag("query", { xmlns: xmlns, queryid: queryId })
				.tag("x", { xmlns: "jabber:x:data", type: "submit" })
					.tag("field", { "var": "FORM_TYPE", type: "hidden" })
						.textTag("value", xmlns)
						.up();

		/* Add filter parameters to query form */
		addStringField("start", params.startTime);
		addStringField("end", params.endTime);
		addStringField("with", params.with);
		addStringField("before-id", params.beforeId);
		addStringField("after-id", params.afterId);
		addArrayField("ids", params.ids);

		queryStanza.up(); // Out of <x/> form

		if(params.page != null) {
			var page = params.page;
			queryStanza.tag("set", { xmlns: "http://jabber.org/protocol/rsm" });
			if(page.limit != null) {
				queryStanza.textTag("max", Std.string(page.limit));
			}
			if(page.before != null && page.after != null) {
				throw new Exception("It is not allowed to request a page before AND a page after");
			}
			if(page.before != null) {
				queryStanza.textTag("before", page.before);
			} else if(page.after != null) {
				queryStanza.textTag("after", page.after);
			}
			queryStanza.up(); // out of <set/>
		}
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
			var fin = responseStanza.getFirstChild();
			if(fin == null || fin.name != "fin" || fin.attr.get("xmlns") != xmlns) {
				return null;
			}
			var rsmInfo = fin.getChild("set", "http://jabber.org/protocol/rsm");
			result = {
				complete: fin.attr.get("complete") == "true" || fin.attr.get("complete") == "1",
				page: {
					first: rsmInfo.getChildText("first"),
					last: rsmInfo.getChildText("last"),
				}
			};
		}
		return result;
	}
}
