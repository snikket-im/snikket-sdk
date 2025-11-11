package borogove;

import haxe.Exception;
import borogove.Client;
import borogove.Message;
import borogove.GenericStream;
import borogove.ResultSet;
import borogove.queries.MAMQuery;

import thenshim.Promise;
import thenshim.PromiseTools;
using StringTools;

#if !NO_OMEMO
import borogove.OMEMO;
#end

typedef MessageList = {
	var sync:MessageSync;
	var messages:Array<MessageStanza>;
}

typedef MessageListHandler = (MessageList) -> Void;
typedef MessageFilter = MAMQueryParams;

class MessageSync {
	private var client:Client;
	private var stream:GenericStream;
	private var chatId:String;
	private var filter:MessageFilter;
	private var serviceJID:String;
	private var handler:MessageListHandler;
	private var contextHandler:(ChatMessageBuilder, Stanza)->ChatMessageBuilder = (b,_)->b;
	private var errorHandler:(Stanza)->Void;
	public var lastPage(default, null):ResultSetPageResult;
	public var progress(default, null): Int = 0;
	private var complete:Bool = false;
	private var newestPageFirst:Bool = true;
	public var jmi(default, null): Map<String, Stanza> = [];

	public function new(client:Client, stream:GenericStream, filter:MessageFilter, ?serviceJID:String) {
		this.client = client;
		this.stream = stream;
		this.filter = Reflect.copy(filter);
		this.serviceJID = serviceJID != null ? serviceJID : client.accountId();
	}

	public function fetchNext():Void {
		if (handler == null) {
			throw new Exception("Attempt to fetch messages, but no handler has been set");
		}
		if (complete) {
			throw new Exception("Attempt to fetch messages, but already complete");
		}
		final promisedMessages:Array<Promise<MessageStanza>> = [];
		if (lastPage == null) {
			if (newestPageFirst == true && (filter.page == null || (filter.page.before == null && filter.page.after == null))) {
				if (filter.page == null)
					filter.page = {};
				filter.page.before = ""; // Request last page of results
			}
		} else {
			if (filter.page == null)
				filter.page = {};
			if (newestPageFirst == true) {
				filter.page.before = lastPage.first;
			} else {
				filter.page.after = lastPage.last;
			}
		}
		var query = new MAMQuery(filter, serviceJID);
		var previousMessageTime = "";
		var counterSameTime = 0;
		final eventToken = stream.on("message", function (event) {
			progress++;
			var message:Stanza = event.stanza;
			var from = message.attr.exists("from") ? message.attr.get("from") : client.accountId();
			if (from != serviceJID) { // Only listen for results from the JID we queried
				return EventUnhandled;
			}
			var result = message.getChild("result", query.xmlns);
			if (result == null || result.attr.get("queryid") != query.queryId) { // Not (a|our) MAM result
				return EventUnhandled;
			}
			var originalMessage = result.findChild("{urn:xmpp:forward:0}forwarded/{jabber:client}message");
			if (originalMessage == null) { // No message, nothing for us to do
				return EventHandled;
			}
			var timestamp = result.findText("{urn:xmpp:forward:0}forwarded/{urn:xmpp:delay}delay@stamp");
			if (timestamp == null) {
				trace("MAM result with no timestamp", result);
			} else {
				// If no subseconds, fix them to at least sort right
				timestamp = ~/([0-9][0-9]:[0-9][0-9]:[0-9][0-9])(\.[0-9][0-9][0-9])?/.map(timestamp, (ereg) -> {
					if (ereg.matched(2) == null || ereg.matched(2) == ".000") {
						if (ereg.matched(1) == previousMessageTime) {
							counterSameTime++;
						} else {
							previousMessageTime = ereg.matched(1);
							counterSameTime = 1;
						}

						return ereg.matched(1) + "." + Std.string(counterSameTime).lpad("0", 3);
					}

					return ereg.matched(0);
				});
			}

			final jmiChildren = originalMessage.allTags(null, "urn:xmpp:jingle-message:0");
			if (jmiChildren.length > 0) {
				jmi.set(jmiChildren[0].attr.get("id"), originalMessage);
			}

			if (originalMessage.hasChild("encrypted", NS.OMEMO)) {
#if !NO_OMEMO
				trace("MAM: Processing OMEMO message from " + originalMessage.attr.get("from"));
				promisedMessages.push(client.omemo.decryptMessage(originalMessage, null).then((decryptionResult) -> {
					final decryptedStanza = decryptionResult.stanza;
					trace("MAM: Decrypted stanza: "+decryptedStanza);

					final msg = Message.fromStanza(decryptedStanza, client.jid, (builder, stanza) -> {
						builder.serverId = result.attr.get("id");
						builder.serverIdBy = serviceJID;
						builder.encryption = decryptionResult.encryptionInfo;
						if (timestamp != null && builder.timestamp == null) builder.timestamp = timestamp;
						return contextHandler(builder, stanza);
					}).parsed;

					return msg;
				}, (err) -> {
					trace("MAM: Decryption failed: "+err);
					final msg = Message.fromStanza(originalMessage, client.jid, (builder, stanza) -> {
							builder.serverId = result.attr.get("id");
							builder.serverIdBy = serviceJID;
							if (timestamp != null && builder.timestamp == null) builder.timestamp = timestamp;
							return contextHandler(builder, stanza);
						},
						new EncryptionInfo(DecryptionFailure, NS.OMEMO, "OMEMO", "internal-error", Std.string(err))
					).parsed;
					return msg;
				}));
#end
				return EventHandled;
			} else {
				trace("MAM: Processing non-OMEMO message from " + originalMessage.attr.get("from"));

				final msg = Message.fromStanza(originalMessage, client.jid, (builder, stanza) -> {
					builder.serverId = result.attr.get("id");
					builder.serverIdBy = serviceJID;
					if (timestamp != null && builder.timestamp == null) builder.timestamp = timestamp;
					return contextHandler(builder, stanza);
				}).parsed;

				promisedMessages.push(Promise.resolve(msg));
				//messages.push(msg);
			}

			return EventHandled;
		});
		query.onFinished(function() {
			stream.removeEventListener(eventToken);
			var result = query.getResult();
			if (result == null) {
				trace("Error from MAM, stopping sync");
				complete = true;
				if (errorHandler != null)
					errorHandler(query.responseStanza);
			} else {
				complete = result.complete;
				lastPage = result.page;
			}
			if (result != null || errorHandler == null) {
				PromiseTools.all(promisedMessages).then((messages) -> {
					handler({
						sync: this,
						messages: messages,
					});
				});
			}
		});
		client.sendQuery(query);
	}

	public function hasMore():Bool {
		return !complete;
	}

	public function addContext(handler: (ChatMessageBuilder, Stanza)->ChatMessageBuilder) {
		this.contextHandler = handler;
	}

	public function onMessages(handler:MessageListHandler):Void {
		this.handler = handler;
	}

	public function onError(handler:(Stanza)->Void) {
		this.errorHandler = handler;
	}

	public function setNewestPageFirst(newestPageFirst:Bool):Void {
		this.newestPageFirst = newestPageFirst;
	}
}
