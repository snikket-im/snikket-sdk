package xmpp;

import haxe.Exception;

import xmpp.Client;
import xmpp.ChatMessage;
import xmpp.GenericStream;
import xmpp.ResultSet;
import xmpp.queries.MAMQuery;

typedef MessageList = {
	var sync : MessageSync;
	var messages : Array<ChatMessage>;
}

typedef MessageListHandler = (MessageList)->Void;

typedef MessageFilter = MAMQueryParams;

class MessageSync {
	private var client:Client;
	private var stream:GenericStream;
	private var chatId:String;
	private var filter:MessageFilter;
	private var serviceJID:String;
	private var handler:MessageListHandler;
	private var lastPage:ResultSetPageResult;
	private var complete:Bool = false;
	private var newestPageFirst:Bool = true;

	public function new(client:Client, stream:GenericStream, chatId:String, filter:MessageFilter, ?serviceJID:String) {
		this.client = client;
		this.stream = stream;
		this.chatId = chatId;
		this.filter = Reflect.copy(filter);
		this.serviceJID = serviceJID != null ? serviceJID : client.jid;
	}

	public function fetchNext():Void {
		if(handler == null) {
			throw new Exception("Attempt to fetch messages, but no handler has been set");
		}
		var messages:Array<ChatMessage> = [];
		if(lastPage == null) {
			if(newestPageFirst == true) {
				filter.page = {
					before: "", // Request last page of results
				};
			} else {
				filter.page = null;
			}
		} else {
			if(newestPageFirst == true) {
				filter.page = {
					before: lastPage.first,
				};
			} else {
				filter.page = {
					after: lastPage.last,
				};
			}
		}
		var query = new MAMQuery(filter);
		var resultHandler = stream.on("message", function (event) {
			var message:Stanza = event.stanza;
			var from = message.attr.exists("from") ? message.attr.get("from") : client.jid;
			if(from != serviceJID) { // Only listen for results from the JID we queried
				return EventUnhandled;
			}
			var result = message.getChild("result", query.xmlns);
			if(result == null || result.attr.get("queryid") != query.queryId) { // Not (a|our) MAM result
				return EventUnhandled;
			}
			var originalMessage = result.findChild("{urn:xmpp:forward:0}forwarded/{jabber:client}message");
			if(originalMessage == null) { // No message, nothing for us to do
				return EventHandled;
			}
			var timestamp = result.findText("{urn:xmpp:forward:0}forwarded/{urn:xmpp:delay}delay@stamp");

			var msg = ChatMessage.fromStanza(originalMessage, client.jid);
			msg.set_serverId(result.attr.get("id"));
			msg.set_timestamp(timestamp);

			messages.push(msg);

			return EventHandled;
		});
		query.onFinished(function () {
			resultHandler.unsubscribe();
			var result = query.getResult();
			if(result != null) {
				complete = result.complete;
			}
			handler({
				sync: this,
				messages: messages,
			});
		});
		client.sendQuery(query);
	}

	public function hasMore():Bool {
		return !complete;
	}

	public function onMessages(handler:MessageListHandler):Void {
		this.handler = handler;
	}

	public function setNewestPageFirst(newestPageFirst:Bool):Void {
		this.newestPageFirst = newestPageFirst;
	}
}
