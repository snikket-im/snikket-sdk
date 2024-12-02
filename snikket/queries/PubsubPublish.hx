package snikket.queries;

import haxe.DynamicAccess;
import haxe.Exception;

import snikket.ID;
import snikket.ResultSet;
import snikket.Stanza;
import snikket.Stream;
import snikket.queries.GenericQuery;

@:structInit
class PubsubConfig {
	public var max_items:Null<Int>;
	public var persist_items:Null<Bool>;
	public var access_model:Null<String>;
	public var publish_model:Null<String>;
	public var send_last_published_item:Null<String>;

	public function toDataform():Stanza {
		var form = new Stanza("x", { xmlns: "jabber:x:data", type: "submit" })
			.tag("field", { "var": "FORM_TYPE", "type": "hidden"})
				.textTag("value", "http://jabber.org/protocol/pubsub#publish-options")
			.up();
		if(max_items != null) {
			form.tag("field", { "var": "pubsub#max_items" })
				.textTag("value", Std.string(max_items))
				.up();
		}
		if(persist_items != null) {
			form.tag("field", { "var": "pubsub#persist_items"})
				.textTag("value", persist_items?"true":"false")
				.up();
		}
		if(access_model != null) {
			form.tag("field", { "var": "pubsub#access_model"})
				.textTag("value", access_model)
				.up();
		}
		if(publish_model != null) {
			form.tag("field", { "var": "pubsub#publish_model"})
				.textTag("value", publish_model)
				.up();
		}
		if(send_last_published_item != null) {
			form.tag("field", { "var": "pubsub#send_last_published_item"})
				.textTag("value", send_last_published_item)
				.up();
		}
		form.up();
		return form;
	}
}

class PubsubPublish extends GenericQuery {
	public var xmlns(default, null) = "http://jabber.org/protocol/pubsub";
	public var queryId:String = null;
	public var ver:String = null;
	public var itemId:String = null;
	public var success:Bool = false;
	public var error:StanzaError = null;

	public function new(to: Null<String>, node: String, ?itemId_: String, ?payload: Stanza, ?config: PubsubConfig) {
		/* Build basic query */
		queryId = ID.short();
		itemId = itemId_;
		queryStanza = new Stanza("iq", { to: to, type: "set", id: queryId });
		final items = queryStanza
			.tag("pubsub", { xmlns: xmlns })
			.tag("publish", { node: node })
			.tag("item", { id: itemId });
		if (payload != null) {
			queryStanza.addChild(payload);
		}
		queryStanza.up().up();
		if(config != null) {
			queryStanza.tag("publish-options")
				.addChild(config.toDataform())
				.up();
		}
		queryStanza.up();
	}

	public function handleResponse(stanza:Stanza) {
		if(stanza.attr.get("type") == "error") {
			success = false;
			error = stanza.getError();
		} else {
			success = true;
			var returnedItemId = stanza.findText("{http://jabber.org/protocol/pubsub}pubsub/publish/item@id");
			if (returnedItemId != null) {
				itemId = returnedItemId;
			}
		}
		finish();
	}
}
