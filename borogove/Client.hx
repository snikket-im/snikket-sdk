package borogove;

import sha.SHA256;

import haxe.crypto.Base64;
import haxe.io.Bytes;
import haxe.io.BytesData;
import thenshim.Promise;
import borogove.Caps;
import borogove.Chat;
import borogove.ChatMessage;
import borogove.Message;
import borogove.EventEmitter;
import borogove.EncryptionPolicy;
#if !NO_OMEMO
import borogove.OMEMO;
#end
import borogove.Profile;
import borogove.PubsubEvent;
import borogove.Stream;
import borogove.Util;
#if !NO_JINGLE
import borogove.calls.IceServer;
import borogove.calls.PeerConnection;
import borogove.calls.Session;
#end
import borogove.queries.BlocklistGet;
import borogove.queries.BoB;
import borogove.queries.DiscoInfoGet;
import borogove.queries.DiscoItemsGet;
import borogove.queries.ExtDiscoGet;
import borogove.queries.GenericQuery;
import borogove.queries.HttpUploadSlot;
import borogove.queries.JabberIqGatewayGet;
import borogove.queries.PubsubGet;
import borogove.queries.Push2Disable;
import borogove.queries.Push2Enable;
import borogove.queries.RosterGet;
import borogove.queries.VcardTempGet;
using Lambda;
using StringTools;

#if cpp
import HaxeCBridge;
#end

enum abstract ChatMessageEvent(Int) {
	var DeliveryEvent;
	var CorrectionEvent;
	var ReactionEvent;
	var StatusEvent;
}

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class Client extends EventEmitter {
	/**
		Set to false to suppress sending available presence
	**/
	public var sendAvailable(null, default): Bool = true;
	private var stream:GenericStream;
	@:allow(borogove)
	private var jid(default,null):JID;
	private var chats: Array<Chat> = [];
	private var persistence: Persistence;
	private final caps = new Caps(
		"https://borogove.dev",
		[],
		[
			"http://jabber.org/protocol/disco#info",
			"http://jabber.org/protocol/caps",
			"urn:xmpp:caps",
			"urn:xmpp:avatar:metadata+notify",
			"http://jabber.org/protocol/nick+notify",
			"urn:xmpp:bookmarks:1+notify",
			"urn:xmpp:mds:displayed:0+notify",
#if !NO_JINGLE
			"urn:xmpp:jingle-message:0",
			"urn:xmpp:jingle:1",
			"urn:xmpp:jingle:apps:dtls:0",
			"urn:xmpp:jingle:apps:rtp:1",
			"urn:xmpp:jingle:apps:rtp:audio",
			"urn:xmpp:jingle:apps:rtp:video",
			"urn:xmpp:jingle:transports:ice-udp:1",
#end
#if !NO_OMEMO
			"eu.siacs.conversations.axolotl.devicelist+notify"
#end
		],
		[]
	);
	private var _displayName: String;
	private var fastMechanism: Null<String> = null;
	private var token: Null<String> = null;
	private var fastCount: Null<Int> = null;
	private final pendingCaps: Map<String, Array<(Null<Caps>)->Chat>> = [];
	@:allow(borogove)
	private final encryptionPolicy:EncryptionPolicy = {
		allowUnencryptedOutgoing: true,
		allowUnencryptedIncoming: true,
		preferEncryptedOutgoing: true,
	};

#if !NO_OMEMO
	@:allow(borogove)
	private final omemo: OMEMO;
#end

	@:allow(borogove)
	private var inSync(default, null) = false;

	/**
		Create a new Client to connect to a particular account

		@param accountId the account to connect to
		@param persistence the persistence layer to use for storage
	**/
	public function new(accountId: String, persistence: Persistence) {
		if (accountId == null || accountId == "") {
			throw "accountId cannot be empty";
		}
		Util.setupTrace();
		#if (!js && target.threaded)
		final mainLoop = sys.thread.Thread.current().events;
		var promiseFactory = cast(Promise.factory, thenshim.fallback.FallbackPromiseFactory);
		promiseFactory.scheduler.addNext = mainLoop.run;
		#end
		super();
		this.jid = JID.parse(accountId);
		this._displayName = this.jid.node ?? this.jid.asString();
		this.persistence = persistence;
#if !NO_OMEMO
		this.omemo = new OMEMO(this, persistence);
#end
		stream = new Stream();
		stream.on("status/online", this.onConnected);
		stream.on("status/offline", (data) -> {
			this.trigger("status/offline", {});
		});

		stream.on("fast-token", (data) -> {
			token = data.token;
			persistence.storeLogin(this.jid.asBare().asString(), stream.clientId ?? this.jid.resource, displayName(), token);
			return EventHandled;
		});

		this.on("chats/update", (data: Array<Chat>) -> {
			stream.emitSMupdates = !Util.existsFast(chats, chat -> chat.uiState != Closed && chat.syncing());
			return EventHandled;
		});

		stream.on("sm/update", (data) -> {
			persistence.storeStreamManagement(this.accountId(), stream.emitSMupdates ? data.sm : null);
			return EventHandled;
		});

		stream.on("sm/ack", (data) -> {
			persistence.updateMessageStatus(
				this.accountId(),
				data.id,
				MessageDeliveredToServer,
				null
			).then((m) -> notifyMessageHandlers(m, StatusEvent), _ -> null);
			return EventHandled;
		});

		stream.on("sm/fail", (data) -> {
			persistence.updateMessageStatus(
				this.accountId(),
				data.id,
				MessageFailedToSend,
				null
			).then((m) -> notifyMessageHandlers(m, StatusEvent), _ -> null);
			return EventHandled;
		});

		stream.on("message", function(event) {
			final stanza:Stanza = event.stanza;

			if (stanza.getChild("result", "urn:xmpp:mam:2") != null) {
				// We don't want to process MAM messages here
				return EventUnhandled;
			}

			final from = stanza.attr.get("from") == null ? null : JID.parse(stanza.attr.get("from"));
			var fwd = null;
			if (from != null && from.asBare().asString() == this.accountId()) {
				var carbon = stanza.getChild("received", "urn:xmpp:carbons:2");
				if (carbon == null) carbon = stanza.getChild("sent", "urn:xmpp:carbons:2");
				if (carbon != null) {
					fwd = carbon.getChild("forwarded", "urn:xmpp:forward:0")?.getFirstChild();
				}
			}

#if !NO_OMEMO
			if((fwd??stanza).hasChild("encrypted", NS.OMEMO)) {
				omemo.decryptMessage(stanza, fwd).then((decryptionResult) -> {
					trace("OMEMO: Decrypted message, now processing...");
					processLiveMessage(decryptionResult.stanza, fwd, decryptionResult.encryptionInfo);
					return true;
				});
				return EventHandled;
			}
#end
			processLiveMessage(stanza, fwd);
			return EventHandled;
		});

#if !NO_JINGLE
		stream.onIq(Set, "jingle", "urn:xmpp:jingle:1", (stanza) -> {
			final from = stanza.attr.get("from") == null ? null : JID.parse(stanza.attr.get("from"));
			final jingle = stanza.getChild("jingle", "urn:xmpp:jingle:1");
			final chat = getDirectChat(from.asBare().asString());
			final session = chat.jingleSessions.get(jingle.attr.get("sid"));

			if (jingle.attr.get("action") == "session-initiate") {
				if (session != null) {
					try {
						chat.jingleSessions.set(session.sid, session.initiate(stanza));
					} catch (e) {
						trace("Bad session-inititate", e);
						chat.jingleSessions.remove(session.sid);
					}
				} else {
					final newSession = borogove.calls.InitiatedSession.fromSessionInitiate(this, stanza);
					chat.jingleSessions.set(newSession.sid, newSession);
					chatActivity(chat);
					newSession.ring();
				}
			}

			if (session != null && jingle.attr.get("action") == "session-accept") {
				try {
					chat.jingleSessions.set(session.sid, session.initiate(stanza));
				} catch (e) {
					trace("session-accept failed", e);
				}
			}

			if (session != null && jingle.attr.get("action") == "session-terminate") {
				session.terminate();
				chat.jingleSessions.remove(jingle.attr.get("sid"));
			}

			if (session != null && jingle.attr.get("action") == "content-add") {
				session.contentAdd(stanza);
			}

			if (session != null && jingle.attr.get("action") == "content-accept") {
				session.contentAccept(stanza);
			}

			if (session != null && jingle.attr.get("action") == "transport-info") {
				session.transportInfo(stanza);
			}

			// jingle requires useless replies to every iq
			return IqResult;
		});
#end

		stream.onIq(Get, "query", "http://jabber.org/protocol/disco#info", (stanza) -> {
			return IqResultElement(caps.discoReply());
		});

		stream.onIq(Set, "query", "jabber:iq:roster", (stanza) -> {
			if (
				stanza.attr.get("from") != null &&
				stanza.attr.get("from") != jid.domain
			) {
				return IqNoResult;
			}

			var roster = new RosterGet();
			roster.handleResponse(stanza);
			var items = roster.getResult();
			if (items.length == 0) return IqNoResult;

			final chatsToUpdate = [];
			for (item in items) {
				if (item.subscription != "remove") {
					final chat = getDirectChat(item.jid, false);
					chat.updateFromRoster(item);
					chatsToUpdate.push(cast (chat, Chat));
				}
			}
			persistence.storeChats(this.accountId(), chatsToUpdate);
			this.trigger("chats/update", chatsToUpdate);

			return IqResult;
		});

		stream.onIq(Set, "block", "urn:xmpp:blocking", (stanza) -> {
			if (
				stanza.attr.get("from") != null &&
				stanza.attr.get("from") != jid.domain
			) {
				return IqNoResult;
			}

			for (item in stanza.getChild("block", "urn:xmpp:blocking")?.allTags("item") ?? []) {
				if (item.attr.get("jid") != null) serverBlocked(item.attr.get("jid"));
			}

			return IqResult;
		});

		stream.onIq(Set, "unblock", "urn:xmpp:blocking", (stanza) -> {
			if (
				stanza.attr.get("from") != null &&
				stanza.attr.get("from") != jid.domain
			) {
				return IqNoResult;
			}

			final unblocks = stanza.getChild("unblock", "urn:xmpp:blocking")?.allTags("item");
			if (unblocks == null) {
				// unblock all
				for (chat in chats) {
					if (chat.isBlocked) chat.unblock(false);
				}
			} else {
				for (item in unblocks) {
					if (item.attr.get("jid") != null) getChat(item.attr.get("jid"))?.unblock(false);
				}
			}

			return IqResult;
		});

		stream.on("presence", function(event) {
			final stanza:Stanza = event.stanza;
			final c = stanza.getChild("c", "http://jabber.org/protocol/caps");
			if (stanza.attr.get("from") != null && stanza.attr.get("type") == null) {
				final from = JID.parse(stanza.attr.get("from"));
				final chat = getChat(from.asBare().asString());
				if (chat == null) {
					trace("Presence for unknown JID: " + stanza.attr.get("from"));
					return EventUnhandled;
				}

				final mucUser = stanza.getChild("x", "http://jabber.org/protocol/muc#user");
				final avatarSha1Hex = stanza.findText("{vcard-temp:x:update}x/photo#");
				final avatarSha1 = avatarSha1Hex == null || avatarSha1Hex == "" ? null : Hash.fromHex("sha-1", avatarSha1Hex);

				if (c == null) {
					chat.setPresence(JID.parse(stanza.attr.get("from")).resource, new Presence(null, mucUser, avatarSha1));
					persistence.storeChats(this.accountId(), [chat]);
					if (chat.livePresence()) this.trigger("chats/update", [chat]);
				} else {
					final handleCaps = (caps) -> {
						chat.setPresence(JID.parse(stanza.attr.get("from")).resource, new Presence(caps, mucUser, avatarSha1));
						if (mucUser == null || chat.livePresence()) persistence.storeChats(this.accountId(), [chat]);
						return chat;
					};

					persistence.getCaps(c.attr.get("ver")).then((caps) -> {
						if (caps == null) {
							final pending = pendingCaps.get(c.attr.get("ver"));
							if (pending == null) {
								pendingCaps.set(c.attr.get("ver"), [handleCaps]);
								final discoGet = new DiscoInfoGet(stanza.attr.get("from"), c.attr.get("node") + "#" + c.attr.get("ver"));
								discoGet.onFinished(() -> {
									final chatsToUpdate: Map<String, Chat> = [];
									final handlers = pendingCaps.get(c.attr.get("ver")) ?? [];
									pendingCaps.remove(c.attr.get("ver"));
									if (discoGet.getResult() != null) persistence.storeCaps(discoGet.getResult());
									for (handler in handlers) {
										final c = handler(discoGet.getResult());
										if (c.livePresence()) chatsToUpdate.set(c.chatId, c);
									}
									this.trigger("chats/update", Lambda.array({ iterator: () -> chatsToUpdate.iterator() }));
								});
								sendQuery(discoGet);
							} else {
								pending.push(handleCaps);
							}
						} else {
							handleCaps(caps);
						}
					});
				}
				if (avatarSha1 != null) {
					if (from.isBare()) {
						chat.setAvatarSha1(avatarSha1.hash);
						persistence.storeChats(this.accountId(), [chat]);
					}
					persistence.hasMedia("sha-1", avatarSha1.hash).then((has) -> {
						if (has) {
							if (chat.livePresence()) this.trigger("chats/update", [chat]);
						} else {
							final vcardGet = new VcardTempGet(from);
							vcardGet.onFinished(() -> {
								final vcard = vcardGet.getResult();
								if (vcard.photo == null) return;
								persistence.storeMedia(vcard.photo.mime, vcard.photo.data.getData()).then(_ -> {
									this.trigger("chats/update", [chat]);
								});
							});
							sendQueryLazy(vcardGet);
						}
					});
				}
				return EventHandled;
			}

			if (stanza.attr.get("from") != null && stanza.attr.get("type") == "unavailable") {
				final chat = getChat(JID.parse(stanza.attr.get("from")).asBare().asString());
				if (chat == null) {
					trace("Presence for unknown JID: " + stanza.attr.get("from"));
					return EventUnhandled;
				}
				// Maybe in the future record it as offine rather than removing it
				chat.removePresence(JID.parse(stanza.attr.get("from")).resource);
				persistence.storeChats(this.accountId(), [chat]);
				this.trigger("chats/update", [chat]);
			}

			if (stanza.attr.get("from") != null && stanza.attr.get("type") == "subscribe") {
				final from = JID.parse(stanza.attr.get("from"));
				final chat = getChat(from.asBare().asString());
				final nick = stanza.getChildText("nick", "http://jabber.org/protocol/nick");
				if (chat == null) {
					startChatWith(from.asBare().asString(), _-> Invited, (chat) -> {
						if (chat.displayName == chat.chatId && nick != null) chat.displayName = nick;
					});
				} else if (chat.uiState == Closed) {
					chat.uiState = Invited;
					if (chat.displayName == chat.chatId && nick != null) chat.displayName = nick;
				}
			}

			return EventUnhandled;
		});
	}

	@:allow(borogove)
	private function processLiveMessage(stanza:Stanza, fwd:Null<Stanza>, ?encryptionInfo:EncryptionInfo):Void {
		final from = stanza.attr.get("from") == null ? null : JID.parse(stanza.attr.get("from"));

		if (stanza.attr.get("type") == "error" && from != null) {
			final chat = getChat(from.asBare().asString());
			final channel = Std.downcast(chat, Channel);
			if (channel != null) channel.selfPing(true);
		}

		final message = Message.fromStanza(stanza, this.jid, (builder, stanza) -> {
			var chat = getChat(builder.chatId());
			if (chat == null && stanza.attr.get("type") != "groupchat") chat = getDirectChat(builder.chatId());
			if (chat == null) return builder;
			return chat.prepareIncomingMessage(builder, stanza);
		}, encryptionInfo);

		switch (message.parsed) {
			case ChatMessageStanza(chatMessage):
				for (hash in chatMessage.inlineHashReferences()) {
					fetchMediaByHash([hash], [chatMessage.from]);
				}
				final chat = getChat(chatMessage.chatId());
				if (chat != null) {
					final updateChat = (chatMessage) -> {
						notifyMessageHandlers(chatMessage, chatMessage.versions.length > 1 ? CorrectionEvent : DeliveryEvent);
						if (chatMessage.versions.length < 1 || chat.lastMessageId() == chatMessage.serverId || chat.lastMessageId() == chatMessage.localId) {
							chat.setLastMessage(chatMessage);
							if (chatMessage.versions.length < 1) chat.setUnreadCount(chatMessage.isIncoming() ? chat.unreadCount() + 1 : 0);
							chatActivity(chat);
						}
					};
					if (chatMessage.serverId == null) {
						updateChat(chatMessage);
					} else {
						storeMessages([chatMessage]).then((stored) -> updateChat(stored[0]));
					}
				}
			case ReactionUpdateStanza(update):
				for (hash in update.inlineHashReferences()) {
					fetchMediaByHash([hash], [from]);
				}
				persistence.storeReaction(accountId(), update).then((stored) -> if (stored != null) notifyMessageHandlers(stored, ReactionEvent));
			case ModerateMessageStanza(action):
				moderateMessage(action).then((stored) -> if (stored != null) notifyMessageHandlers(stored, CorrectionEvent));
			case ErrorMessageStanza(localId, stanza):
				persistence.updateMessageStatus(
					this.accountId(),
					localId,
					MessageFailedToSend,
					stanza.getErrorText(),
				).then((m) -> notifyMessageHandlers(m, StatusEvent), _ -> null);
			case MucInviteStanza(serverId, serverIdBy, reason, password):
				mucInvite(message.chatId, getChat(message.chatId), message.senderId, message.threadId, serverId, serverIdBy, reason, password);
			default:
				// ignore
				trace("Ignoring non-chat message: " + stanza.toString());
		}

#if !NO_JINGLE
		final jmiP = stanza.getChild("propose", "urn:xmpp:jingle-message:0");
		if (jmiP != null && jmiP.attr.get("id") != null) {
			final session = new IncomingProposedSession(this, from, jmiP.attr.get("id"));
			final chat = getDirectChat(from.asBare().asString());
			if (!chat.jingleSessions.exists(session.sid)) {
				chat.jingleSessions.set(session.sid, session);
				chatActivity(chat);
				session.ring();
			}
		}

		final jmiR = stanza.getChild("retract", "urn:xmpp:jingle-message:0");
		if (jmiR != null && jmiR.attr.get("id") != null) {
			final chat = getDirectChat(from.asBare().asString());
			final session = chat.jingleSessions.get(jmiR.attr.get("id"));
			if (session != null) {
				session.retract();
				chat.jingleSessions.remove(session.sid);
			}
		}

		// Another resource picked this up
		final jmiProFwd = fwd?.getChild("proceed", "urn:xmpp:jingle-message:0");
		if (jmiProFwd != null && jmiProFwd.attr.get("id") != null) {
			final chat = getDirectChat(JID.parse(fwd.attr.get("to")).asBare().asString());
			final session = chat.jingleSessions.get(jmiProFwd.attr.get("id"));
			if (session != null) {
				session.retract();
				chat.jingleSessions.remove(session.sid);
			}
		}

		final jmiPro = stanza.getChild("proceed", "urn:xmpp:jingle-message:0");
		if (jmiPro != null && jmiPro.attr.get("id") != null) {
			final chat = getDirectChat(from.asBare().asString());
			final session = chat.jingleSessions.get(jmiPro.attr.get("id"));
			if (session != null) {
				try {
					chat.jingleSessions.set(session.sid, session.initiate(stanza));
				} catch (e) {
					trace("JMI proceed failed", e);
				}
			}
		}

		final jmiRej = stanza.getChild("reject", "urn:xmpp:jingle-message:0");
		if (jmiRej != null && jmiRej.attr.get("id") != null) {
			final chat = getDirectChat(from.asBare().asString());
			final session = chat.jingleSessions.get(jmiRej.attr.get("id"));
			if (session != null) {
				session.retract();
				chat.jingleSessions.remove(session.sid);
			}
		}
#end

		if (stanza.attr.get("type") != "error") {
			final chatState = stanza.getChild(null, "http://jabber.org/protocol/chatstates");
			final userState = switch (chatState?.name) {
				case "active": UserState.Active;
				case "inactive": UserState.Inactive;
				case "gone": UserState.Gone;
				case "composing": UserState.Composing;
				case "paused": UserState.Paused;
				default: null;
			};
			if (userState != null) {
				final chat = getChat(from.asBare().asString());
				if (chat == null || !chat.getParticipantDetails(message.senderId).isSelf) {
					this.trigger("chat-state/update", { message: message, userState: userState });
				}
			}
		}

		final pubsubEvent = PubsubEvent.fromStanza(stanza);
		if (pubsubEvent != null && pubsubEvent.getFrom() != null && pubsubEvent.getNode() == "urn:xmpp:avatar:metadata" && pubsubEvent.getItems().length > 0) {
			final item = pubsubEvent.getItems()[0];
			final avatarSha1Hex = pubsubEvent.getItems()[0].attr.get("id");
			final avatarSha1 = Hash.fromHex("sha-1", avatarSha1Hex)?.hash;
			final metadata = item.getChild("metadata", "urn:xmpp:avatar:metadata");
			var mime = "image/png";
			if (metadata != null) {
				final info = metadata.getChild("info"); // should have xmlns matching metadata
				if (info != null && info.attr.get("type") != null) {
					mime = info.attr.get("type");
				}
			}
			if (avatarSha1 != null) {
				final chat = this.getDirectChat(JID.parse(pubsubEvent.getFrom()).asBare().asString(), false);
				chat.setAvatarSha1(avatarSha1);
				persistence.storeChats(accountId(), [chat]);
				persistence.hasMedia("sha-1", avatarSha1).then((has) -> {
					if (has) {
						this.trigger("chats/update", [chat]);
					} else {
						final pubsubGet = new PubsubGet(pubsubEvent.getFrom(), "urn:xmpp:avatar:data", avatarSha1Hex);
						pubsubGet.onFinished(() -> {
							final item = pubsubGet.getResult()[0];
							if (item == null) return;
							final dataNode = item.getChild("data", "urn:xmpp:avatar:data");
							if (dataNode == null) return;
							persistence.storeMedia(mime, Base64.decode(StringTools.replace(dataNode.getText(), "\n", "")).getData()).then(_ -> {
								this.trigger("chats/update", [chat]);
							});
						});
						sendQueryLazy(pubsubGet);
					}
				});
			}
		}

		trace("pubsubEvent "+Std.string(pubsubEvent!=null));
		if (pubsubEvent != null && pubsubEvent.getFrom() != null) {
			final fromBare = JID.parse(pubsubEvent.getFrom()).asBare();
			final isOwnAccount = fromBare.asString() == accountId();
			final pubsubNode = pubsubEvent.getNode();

			if (isOwnAccount && pubsubNode == "http://jabber.org/protocol/nick" && pubsubEvent.getItems().length > 0) {
				updateDisplayName(pubsubEvent.getItems()[0].getChildText("nick", "http://jabber.org/protocol/nick"));
			}

			if (isOwnAccount && pubsubNode == "urn:xmpp:mds:displayed:0" && pubsubEvent.getItems().length > 0) {
				for (item in pubsubEvent.getItems()) {
					if (item.attr.get("id") != null) {
						final upTo = item.getChild("displayed", "urn:xmpp:mds:displayed:0")?.getChild("stanza-id", "urn:xmpp:sid:0");
						final chat = getChat(item.attr.get("id"));
						if (chat == null) {
							startChatWith(item.attr.get("id"), _ -> Closed, (chat) -> chat.markReadUpToId(upTo.attr.get("id"), upTo.attr.get("by")));
						} else {
							chat.markReadUpToId(upTo.attr.get("id"), upTo.attr.get("by")).then(_ -> {
								persistence.storeChats(accountId(), [chat]);
								this.trigger("chats/update", [chat]);
								return;
							}, e -> e != null ? Promise.reject(e) : null);
						}
					}
				}
			}
			trace("pubsubNode == "+pubsubNode);

#if !NO_OMEMO
			if(pubsubNode == "eu.siacs.conversations.axolotl.devicelist") {
				if(isOwnAccount) {
					omemo.onAccountUpdatedDeviceList(pubsubEvent.getItems());
				} else {
					omemo.onContactUpdatedDeviceList(fromBare, pubsubEvent.getItems());
				}
			}
#end
		}
	}

	/**
		Start this client running and trying to connect to the server
	**/
	public function start() {
		stream.emitSMupdates = false; // We don't care until after sync
		startOffline().then(_ ->
			persistence.getStreamManagement(accountId())
		).then((sm) -> {
			stream.on("auth/password-needed", (data) -> {
				fastMechanism = data.mechanisms?.find((mech) -> mech.canFast)?.name;
				if (token == null || (fastMechanism == null && data.mechanimsms != null)) {
					this.trigger("auth/password-needed", { accountId: accountId() });
				} else {
					this.stream.trigger("auth/password", { password: token, mechanism: fastMechanism, fastCount: fastCount });
				}
			});
			stream.on("auth/fail", (data) -> {
				if (token != null) {
					token = null;
					stream.connect(jid.asString(), sm);
				} else {
					stream.connect(jid.asString(), sm);
				}
				return EventHandled;
			});
			stream.connect(jid.asString(), sm);
		});
	}

	/**
		Gets the client ready to use but does not connect to the server

		@returns Promise resolving to true once the Client is ready
	**/
	public function startOffline(): Promise<Bool> {
		#if cpp
		// Do a big GC before starting a new client
		cpp.NativeGc.run(true);
		#end
		return persistence.getLogin(accountId()).then(login -> {
			token = login.token;
			fastCount = login.fastCount;
			stream.clientId = login.clientId ?? ID.long();
			jid = jid.withResource(stream.clientId);
			if (!updateDisplayName(login.displayName) && login.clientId == null) {
				persistence.storeLogin(jid.asBare().asString(), stream.clientId, this.displayName(), null);
			}

			return persistence.getChats(accountId());
		}).then((protoChats) -> {
			var oneProtoChat = null;
			while ((oneProtoChat = protoChats.pop()) != null) {
				chats.push(oneProtoChat.toChat(this, stream, persistence));
			}
			getDirectChat(accountId()); // Ensure self chat exists
			return persistence.getChatsUnreadDetails(accountId(), chats);
		}).then((details) -> {
			for (detail in details) {
				var chat = getChat(detail.chatId);
				if (chat != null) {
					chat.setLastMessage(detail.message);
					chat.setUnreadCount(detail.unreadCount);
				}
			}
			sortChats();
			this.trigger("chats/update", chats);
			true;
		});
	}

	/**
		Destroy local data for this account

		@param completely if true chats, messages, etc will be deleted as well
	**/
	public function logout(completely: Bool) {
		persistence.removeAccount(accountId(), completely);
		final disable = new Push2Disable(jid.asBare().asString());
		disable.onFinished(() -> {
			stream.disconnect();
		});
		sendQuery(disable);
		// TODO: FAST invalidate https://xmpp.org/extensions/xep-0484.html#invalidation
	}

	/**
		Sets the password to be used in response to the password needed event

		@param password
	**/
	public function usePassword(password: String):Void {
		this.stream.trigger("auth/password", { password: password, requestToken: fastMechanism });
	}

	/**
		Get the account ID for this Client

		@returns account id
	**/
	public function accountId() {
		return jid.asBare().asString();
	}

	/**
		Get the current display name for this account

		@returns display name
	**/
	public function displayName() {
		return _displayName;
	}

	/**
		Set the current profile for this account on the server

		@param profile to set
		@param publicAccess set the access for the profile to public
	**/
	public function setProfile(profile: ProfileBuilder, publicAccess: Bool) {
		final fn = profile.build().items.find(item -> item.key == "fn");
		if (fn != null) {
			final fnText = fn.text()[0];
			if (fnText != null && fnText != "" && fnText != this.displayName()) {
				stream.sendIq(
					new Stanza("iq", { type: "set" })
						.tag("pubsub", { xmlns: "http://jabber.org/protocol/pubsub" })
						.tag("publish", { node: "http://jabber.org/protocol/nick" })
						.tag("item")
						.textTag("nick", fnText, { xmlns: "http://jabber.org/protocol/nick" })
						.up().up().up(),
					(response) -> { }
				);
			}
		}

		publishWithOptions(
			new Stanza("iq", { type: "set" })
				.tag("pubsub", { xmlns: "http://jabber.org/protocol/pubsub" })
				.tag("publish", { node: "urn:xmpp:vcard4" })
				.tag("item", { id: ID.long() })
				.addChild(profile.buildStanza()),
			new Stanza("x", { xmlns: "jabber:x:data", type: "submit" })
				.tag("field", { "var": "FORM_TYPE", type: "hidden" }).textTag("value", "http://jabber.org/protocol/pubsub#publish-options").up()
				.tag("field", { "var": "pubsub#title" }).textTag("value", "Profile").up()
				.tag("field", { "var": "pubsub#type" }).textTag("value", "urn:ietf:params:xml:ns:vcard-4.0").up()
				.tag("field", { "var": "pubsub#deliver_payloads" }).textTag("value", "false").up()
				.tag("field", { "var": "pubsub#persist_items" }).textTag("value", "true").up()
				.tag("field", { "var": "pubsub#max_items" }).textTag("value", "1").up()
				.tag("field", { "var": "pubsub#access_model" }).textTag("value", publicAccess ? "open" : "presence").up(),
		);
	}

	private function updateDisplayName(fn: String) {
		if (fn == null || fn == "" || fn == displayName()) return false;
		_displayName = fn;
		persistence.storeLogin(jid.asBare().asString(), stream.clientId ?? jid.resource, fn, null);
		pingAllChannels(false);
		return true;
	}

	private function onConnected(data) { // Fired on connect or reconnect
		if (data != null && data.jid != null) {
			jid = JID.parse(data.jid);
			if (stream.clientId == null && !jid.isBare()) persistence.storeLogin(jid.asBare().asString(), jid.resource, displayName(), null);
		}

		if (data.resumed) {
			inSync = true;
			for (chat in getChats()) {
				final channel = Std.downcast(chat, Channel);
				if (channel != null) {
					channel.inSync = true;
				}
			}

			stream.emitSMupdates = true;
			this.trigger("status/online", {});
			this.trigger("chats/update", chats);
			return EventHandled;
		}


		discoverServices(new JID(null, jid.domain), (service, caps) -> {
			persistence.storeService(accountId(), service.jid.asString(), service.name, service.node, caps);
		});
		rosterGet();
		trace("SYNC: bookmarks");
		bookmarksGet(() -> {
			trace("SYNC: MAM");
			sync((syncFinished) -> {
				if (!syncFinished) {
					trace("SYNC: failed");
					inSync = false;
					stream.disconnect();
					// TODO: retry?
					return;
				}

				trace("SYNC: details");
				inSync = true;
				persistence.getChatsUnreadDetails(accountId(), chats).then((details) -> {
					for (detail in details) {
						var chat = getChat(detail.chatId) ?? getDirectChat(detail.chatId, false);
						final initialLastId = chat.lastMessageId();
						if (detail.message != null) chat.setLastMessage(detail.message);
						chat.setUnreadCount(detail.unreadCount);
						if (detail.unreadCount > 0 && initialLastId != chat.lastMessageId()) {
							chatActivity(chat, false);
						}
					}
					sortChats();
					this.trigger("chats/update", chats);
					// Set self to online
					if (sendAvailable) {
						// Enable carbons
						sendStanza(
							new Stanza("iq", { type: "set", id: ID.short() })
								.tag("enable", { xmlns: "urn:xmpp:carbons:2" })
								.up()
						);
						sendPresence();
						joinAllChannels();
					}
					this.trigger("status/online", {});
					trace("SYNC: done");
				});
			});
		});

		this.trigger("session-started", {});

		return EventHandled;
	}

	/**
		Turn a file into a ChatAttachment for attaching to a ChatMessage

		@param source The AttachmentSource to use
		@returns Promise resolving to a ChatAttachment or null
	**/
	public function prepareAttachment(source: AttachmentSource): Promise<Null<ChatAttachment>> {
		return persistence.findServicesWithFeature(accountId(), "urn:xmpp:http:upload:0").then((services) -> {
			final sha256 = new sha.SHA256();
			return new Promise((resolve, reject) -> {
				source.tinkSource().chunked().forEach((chunk) -> {
					sha256.update(chunk);
					return tink.streams.Stream.Handled.Resume;
				}).handle((o) -> switch o {
					case Depleted:
						prepareAttachmentFor(source, services, [new Hash("sha-256", sha256.digest().getData())], resolve);
					default:
						trace("Error computing attachment hash", o);
						reject(o);
				});
			});
		});
	}

	private function prepareAttachmentFor(source: AttachmentSource, services: Array<{ serviceId: String }>, hashes: Array<Hash>, callback: (Null<ChatAttachment>)->Void) {
		if (services.length < 1) {
			trace("No HTTP upload service found");
			callback(null);
			return;
		}
		final httpUploadSlot = new HttpUploadSlot(services[0].serviceId, source.name, source.size, source.type, hashes);
		httpUploadSlot.onFinished(() -> {
			final slot = httpUploadSlot.getResult();
			if (slot == null) {
				prepareAttachmentFor(source, services.slice(1), hashes, callback);
			} else {
				tink.http.Client.fetch(slot.put, { method: PUT, headers: slot.putHeaders.concat([new tink.http.Header.HeaderField("Content-Length", source.size)]), body: tink.io.Source.RealSourceTools.idealize(source.tinkSource(), (e) -> { trace("WUT", e); throw e; }) }).all()
					.handle((o) -> switch o {
						case Success(res) if (res.header.statusCode == 201):
							callback(new ChatAttachment(source.name, source.type, source.size, [slot.get], hashes));
						default:
							prepareAttachmentFor(source, services.slice(1), hashes, callback);
					});
			}
		});
		sendQuery(httpUploadSlot);
	}

	/**
		@returns array of open chats, sorted by last activity
	**/
	public function getChats():Array<Chat> {
		return chats.filter((chat) -> chat.uiState != Closed);
	}

	/**
		Search for chats the user can start or join

		@param q the search query to use
		@param callback takes two arguments, the query that was used and the array of results, and returns true if we should stop searching
	**/
	public function findAvailableChats(q:String, callback:(String, Array<AvailableChat>) -> Bool) {
		var haveJid: Map<String, Bool> = [];
		var results = [];
		final query = StringTools.trim(q);
		final checkAndAdd = (jid: JID, prepend = false) -> {
			if (haveJid[jid.asString()]) return;
			haveJid[jid.asString()] = true;

			final add = (item) -> prepend ? results.unshift(item) : results.push(item);
			final discoGet = new DiscoInfoGet(jid.asString());
			discoGet.onFinished(() -> {
				final resultCaps = discoGet.getResult();
				if (resultCaps == null) {
					final err = discoGet.responseStanza?.getChild("error")?.getChild(null, "urn:ietf:params:xml:ns:xmpp-stanzas");
					if (err == null || err?.name == "service-unavailable" || err?.name == "feature-not-implemented") {
						add(new AvailableChat(jid.asString(), jid.node == null ? query : jid.node, jid.asString(), new Caps("", [], [], [])));
					}
				} else {
					persistence.storeCaps(resultCaps);
					final identity = resultCaps.identities[0];
					final displayName = identity?.name ?? query;
					final note = jid.asString() + (identity == null ? "" : " (" + identity.type + ")");
					add(new AvailableChat(jid.asString(), displayName, note, resultCaps));
				}
				if (callback != null && callback(q, results)) callback = null;
			});
			sendQuery(discoGet);
		};
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
			checkAndAdd(jid, true);
		}

		if (StringTools.startsWith(query, "https://")) {
			xmppLinkHeader(query).then(xmppUri -> {
				final parts = xmppUri.substr(5).split("?");
				final jid = JID.parse(uriDecode(parts[0]));
				if (jid.isValid()) checkAndAdd(jid, true);
			});
		}

		for (chat in chats) {
			if (chat.chatId != jid.asBare().asString()) {
				if (chat.chatId.contains(query.toLowerCase()) || chat.getDisplayName().toLowerCase().contains(query.toLowerCase())) {
					final channel = Util.downcast(chat, Channel);
					results.push(new AvailableChat(chat.chatId, chat.getDisplayName(), chat.chatId, channel == null || channel.disco == null ? new Caps("", [], [], []) : channel.disco));
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
				if (!sendAvailable && JID.parse(chat.chatId).isDomain()) {
					resources[null] = true;
				}
				for (resource in resources.keys()) {
					final bareJid = JID.parse(chat.chatId);
					final fullJid = new JID(bareJid.node, bareJid.domain, bareJid.isDomain() && resource == "" ? null : resource);
					final jigGet = new JabberIqGatewayGet(fullJid.asString(), query);
					jigGet.onFinished(() -> {
						if (jigGet.getResult() == null) {
							final caps = chat.getResourceCaps(resource);
							if (bareJid.isDomain() && caps.features.contains("jid\\20escaping")) {
								checkAndAdd(new JID(query, bareJid.domain));
							} else if (bareJid.isDomain()) {
								checkAndAdd(new JID(StringTools.replace(query, "@", "%"), bareJid.domain));
							}
						} else {
							switch (jigGet.getResult()) {
								case Left(error): return;
								case Right(result):
									checkAndAdd(JID.parse(result));
							}
						}
					});
					sendQuery(jigGet);
				}
			}
		}
		if (!jid.isValid() && results.length > 0) {
			if (callback != null && callback(q, results)) callback = null;
		}
	}

	/**
		Start or join a chat from the search results

		@returns the chat that was started
	**/
	public function startChat(availableChat: AvailableChat):Chat {
		final existingChat = getChat(availableChat.chatId);
		if (existingChat != null) {
			final channel = Std.downcast(existingChat, Channel);
			if ((channel == null && availableChat.isChannel()) || (channel != null && !availableChat.isChannel())) {
				chats = chats.filter((chat) -> chat.chatId != availableChat.chatId);
			} else {
				if (existingChat.uiState == Closed) existingChat.uiState = Open;
				channel?.selfPing(true);
				persistence.storeChats(accountId(), [existingChat]);
				this.trigger("chats/update", [existingChat]);
				return existingChat;
			}
		}

		final chat = if (availableChat.isChannel()) {
			final channel = new Channel(this, this.stream, this.persistence, availableChat.chatId, Open, false, null, availableChat.caps);
			channel.setupNotifications();
			chats.unshift(channel);
			channel.selfPing(false);
			channel;
		} else {
			getDirectChat(availableChat.chatId, false);
		}
		persistence.storeChats(accountId(), [chat]);
		this.trigger("chats/update", [chat]);
		return chat;
	}

	/**
		Find a chat by id

		@returns the chat if known, or NULL
	**/
	public function getChat(chatId:String):Null<Chat> {
		return Util.findFast(chats, (chat) -> chat.chatId == chatId);
	}

	@:allow(borogove)
	private function moderateMessage(action: ModerationAction): Promise<Null<ChatMessage>> {
		return new thenshim.Promise((resolve, reject) ->
			persistence.getMessage(accountId(), action.chatId, action.moderateServerId, null).then((moderateMessage) -> {
				if (moderateMessage == null) return resolve(null);
				for(attachment in moderateMessage.attachments) {
					for(hash in attachment.hashes) {
						persistence.removeMedia(hash.algorithm, hash.hash);
					}
				}
				moderateMessage = ChatMessageBuilder.makeModerated(moderateMessage, action.timestamp, action.moderatorId, action.reason);
				persistence.updateMessage(accountId(), moderateMessage);
				resolve(moderateMessage);
			})
		);
	}

	@:allow(borogove)
	private function getDirectChat(chatId:String, triggerIfNew:Bool = true):DirectChat {
		for (chat in chats) {
			if (Std.isOfType(chat, DirectChat) && chat.chatId == chatId) {
				return Std.downcast(chat, DirectChat);
			}
		}
		final chat = new DirectChat(this, this.stream, this.persistence, chatId);
		persistence.storeChats(accountId(), [chat]);
		chats.unshift(chat);
		if (triggerIfNew) this.trigger("chats/update", [chat]);
		return chat;
	}

	#if js
	public function subscribePush(reg: js.html.ServiceWorkerRegistration, push_service: String, vapid_key: { publicKey: js.html.CryptoKey, privateKey: js.html.CryptoKey }, ?grace: Int) {
		js.Browser.window.crypto.subtle.exportKey("raw", vapid_key.publicKey).then((vapid_public_raw) -> {
			reg.pushManager.subscribe(untyped {
				userVisibleOnly: true,
				applicationServerKey: vapid_public_raw
			}).then((pushSubscription) -> {
				if (pushSubscription == null) {
					trace("WebPush subscription failed");
					return;
				}
				js.Browser.window.crypto.subtle.exportKey("pkcs8", vapid_key.privateKey).then((vapid_private_pkcs8) -> {
					enablePush(
						push_service,
						pushSubscription.endpoint,
						pushSubscription.getKey(js.html.push.PushEncryptionKeyName.P256DH),
						pushSubscription.getKey(js.html.push.PushEncryptionKeyName.AUTH),
						grace ?? -1,
						vapid_private_pkcs8,
						[]
					);
				});
			});
		});
	}
	#end

	private var enabledPushData: Null<{ push_service: String, endpoint: String, p256dh: BytesData, auth: BytesData, grace: Int, vapid_private_pkcs8: Null<BytesData>, claims: Array<String> }> = null;

	/**
		Enable push notifications

		@param push_service the address of a push proxy
		@param vapid_private_pkcs8 the private key for signing JWT of the push service
		@param endpoint the final target for the push proxy to forward to
		@param p256dh A P-256 uncompressed point in ANSI X9.62 format
		@param auth Random 16 octed value
		@param grace Grace period during which not to generate push if another app is active for same account, in seconds (negative for none)
		@param claims Optional additional JWT claims as key then value
	**/
	public function enablePush(push_service: String, endpoint: String, p256dh: BytesData, auth: BytesData, grace: Int, ?vapid_private_pkcs8: BytesData, ?claims: Array<String>) {
		enabledPushData = { push_service: push_service, vapid_private_pkcs8: vapid_private_pkcs8, endpoint: endpoint, p256dh: p256dh, auth: auth, grace: grace, claims: claims ?? [] };

		final filters = [];
		for (chat in chats) {
			if (chat.notificationsFiltered()) {
				filters.push({ jid: chat.chatId, mention: chat.notifyMention(), reply: chat.notifyReply() });
			}
		}

		final claimMap = [ "aud" => tink.Url.parse(endpoint).host.toString() ];
		for (i in 0...(claims ?? []).length) {
			if (i % 2 == 0) {
				claimMap[claims[i]] = claims[i+1];
			}
		}

		sendQuery(new Push2Enable(
			jid.asBare().asString(),
			push_service,
			endpoint,
			Bytes.ofData(p256dh),
			Bytes.ofData(auth),
			vapid_private_pkcs8 == null ? null : "ES256",
			vapid_private_pkcs8 == null ? null : Bytes.ofData(vapid_private_pkcs8),
			claimMap,
			grace,
			filters
		));
	}

	@:allow(borogove)
	private function updatePushIfEnabled() {
		if (enabledPushData == null) return;
		enablePush(enabledPushData.push_service, enabledPushData.endpoint, enabledPushData.p256dh, enabledPushData.auth, enabledPushData.grace, enabledPushData.vapid_private_pkcs8, enabledPushData.claims);
	}

	/**
		Event fired when client needs a password for authentication

		@param handler takes one argument, the Client that needs a password
		@returns token for use with removeEventListener
	**/
	public function addPasswordNeededListener(handler:Client->Void) {
		return this.on("auth/password-needed", (data) -> {
			handler(this);
			return EventHandled;
		});
	}

	/**
		Event fired when client is connected and fully synchronized

		@param handler takes no arguments
		@returns token for use with removeEventListener
	**/
	public function addStatusOnlineListener(handler:()->Void) {
		return this.on("status/online", (data) -> {
			handler();
			return EventHandled;
		});
	}

	/**
		Event fired when client is disconnected

		@param handler takes no arguments
		@returns token for use with removeEventListener
	**/
	public function addStatusOfflineListener(handler:()->Void) {
		return this.on("status/offline", (data) -> {
			handler();
			return EventHandled;
		});
	}

	/**
		Event fired when connection fails with a fatal error and will not be retried

		@param handler takes no arguments
		@returns token for use with removeEventListener
	**/
	public function addConnectionFailedListener(handler:()->Void) {
		return stream.on("status/error", (data) -> {
			handler();
			return EventHandled;
		});
	}

	/**
		Event fired when TLS checks fail, to give client the chance to override

		@param handler takes two arguments, the PEM of the cert and an array of DNS names, and must return true to accept or false to reject
		@returns token for use with removeEventListener
	**/
	public function addTlsCheckListener(handler:(String, Array<String>)->Bool) {
		return stream.on("tls/check", (data) -> {
			return EventValue(handler(data.pem, data.dnsNames));
		});
	}

	#if !cpp
	// TODO: haxe cpp erases enum into int, so using it as a callback arg is hard
	// could just use int in C bindings, or need to come up with a good strategy
	// for the wrapper
	public function addUserStateListener(handler: (String,String,Null<String>,UserState)->Void):EventHandlerToken {
		return this.on("chat-state/update", (data) -> {
			handler(data.message.senderId, data.message.chatId, data.message.threadId, data.userState);
			return EventHandled;
		});
	}
	#end

	/**
		Event fired when a new ChatMessage comes in on any Chat
		Also fires when status of a ChatMessage changes,
		when a ChatMessage is edited, or when a reaction is added

		@param handler takes two arguments, the ChatMessage and ChatMessageEvent enum describing what happened
		@returns token for use with removeEventListener
	**/
	#if cpp
		// HaxeCBridge doesn't support "secondary" enums yet
		public function addChatMessageListener(handler:(ChatMessage, Int)->Void) {
	#else
		public function addChatMessageListener(handler:(ChatMessage, ChatMessageEvent)->Void):EventHandlerToken {
	#end
		return this.on("message/new", (data) -> {
			handler(data.message, data.event);
			return EventHandled;
		});
	}

	/**
		Event fired when syncing a new ChatMessage that was send when offline.
		Normally you don't want this, but it may be useful if you want to notify on app start.

		@param handler takes one argument, the ChatMessage
		@returns token for use with removeEventListener
	**/
	public function addSyncMessageListener(handler:(ChatMessage)->Void):EventHandlerToken {
		return this.on("message/sync", (data) -> {
			handler(data);
			return EventHandled;
		});
	}

	/**
		Event fired when a Chat's metadata is updated, or when a new Chat is added

		@param handler takes one argument, an array of Chats that were updated
		@returns token for use with removeEventListener
	**/
	public function addChatsUpdatedListener(handler:Array<Chat>->Void) {
		final updateChatBuffer: Map<String, Chat> = [];
		var lastCall = -1.0;
		var updateChatTimer = null;
		return this.on("chats/update", (data: Array<Chat>) -> {
			final now = haxe.Timer.stamp() * 1000;
			if (updateChatTimer != null) {
				updateChatTimer.stop();
			}
			for (chat in data) {
				updateChatBuffer[chat.chatId] = chat;
			}
			if (lastCall < 0 || now - lastCall >= 500) {
				lastCall = now;
				handler({ iterator: updateChatBuffer.iterator }.array());
				updateChatTimer = null;
				updateChatBuffer.clear();
			} else {
				updateChatTimer = haxe.Timer.delay(() -> {
					lastCall = haxe.Timer.stamp() * 1000;
					handler({ iterator: updateChatBuffer.iterator }.array());
					updateChatTimer = null;
					updateChatBuffer.clear();
				}, 500);
			}
			return EventHandled;
		});
	}

#if !NO_JINGLE
	/**
		Event fired when a new call comes in

		@param handler takes one argument, the call Session
		@returns token for use with removeEventListener
	**/
	public function addCallRingListener(handler:(Session)->Void) {
		return this.on("call/ring", (data) -> {
			handler(data.session);
			return EventHandled;
		});
	}

	/**
		Event fired when a call is retracted or hung up

		@param handler takes two arguments, the associated Chat ID and Session ID
		@returns token for use with removeEventListener
	**/
	public function addCallRetractListener(handler:(String,String)->Void) {
		return this.on("call/retract", (data) -> {
			handler(data.chatId, data.sid);
			return EventHandled;
		});
	}

	/**
		Event fired when an outgoing call starts ringing

		@param handler takes one argument, the associated Session
		@returns token for use with removeEventListener
	**/
	public function addCallRingingListener(handler:(Session)->Void) {
		return this.on("call/ringing", (data) -> {
			handler(data);
			return EventHandled;
		});
	}

	/**
		Event fired when an existing call changes status (connecting, failed, etc)

		@param handler takes one argument, the associated Session
		@returns token for use with removeEventListener
	**/
	public function addCallUpdateStatusListener(handler:(InitiatedSession)->Void) {
		return this.on("call/updateStatus", (data) -> {
			handler(data.session);
			return EventHandled;
		});
	}

	/**
		Event fired when a call is asking for media to send

		@param handler takes three arguments, the call Session,
		       a boolean indicating if audio is desired,
		       and a boolean indicating if video is desired
		@returns token for use with removeEventListener
	**/
	public function addCallMediaListener(handler:(InitiatedSession,Bool,Bool)->Void) {
		return this.on("call/media", (data) -> {
			handler(data.session, data.audio, data.video);
			return EventHandled;
		});
	}

	/**
		Event fired when call has a new MediaStreamTrack to play

		@param handler takes three arguments, the associated Chat ID,
		       the new MediaStreamTrack, and an array of any associated MediaStreams
		@returns token for use with removeEventListener
	**/
	public function addCallTrackListener(handler:(InitiatedSession,MediaStreamTrack,Array<MediaStream>)->Void) {
		return this.on("call/track", (data) -> {
			handler(data.session, data.track, data.streams);
			return EventHandled;
		});
	}
#end

	/**
		Let the SDK know the UI is in the foreground
	**/
	public function setInForeground() {
		if (!stream.csi) return;
		stream.sendStanza(new Stanza("active", { xmlns: "urn:xmpp:csi:0" }));
	}

	/**
		Let the SDK know the UI is in the foreground
	**/
	public function setNotInForeground() {
		if (!stream.csi) return;
		stream.sendStanza(new Stanza("inactive", { xmlns: "urn:xmpp:csi:0" }));
	}

	@:allow(borogove)
	private function fetchMediaByHash(hashes: Array<Hash>, counterparts: Array<JID>) {
		// TODO: only for counterparts who can infer our presence
		// So MUCs, roster entires, anyone we've sent a message to in the past (from this client?)
		if (hashes.length < 1 || counterparts.length < 1) return thenshim.Promise.reject("no counterparts left");
		return fetchMediaByHashOneCounterpart(hashes, counterparts[0]).then(x -> x, (_) -> fetchMediaByHash(hashes, counterparts.slice(1)));
	}

	private function fetchMediaByHashOneCounterpart(hashes: Array<Hash>, counterpart: JID) {
		if (hashes.length < 1) return thenshim.Promise.reject("no hashes left");

		return persistence.hasMedia(hashes[0].algorithm, hashes[0].hash).then (has -> {
			if (has) return Promise.resolve(null);

			return new Promise((resolve, reject) -> {
				final q = BoB.forHash(counterpart.asString(), hashes[0]);
				q.onFinished(() -> {
					final r = q.getResult();
					if (r == null) {
						reject("bad or no result from BoB query");
					} else {
						persistence.storeMedia(r.type, r.bytes.getData()).then(_ -> resolve(null));
					}
				});
				sendQueryLazy(q);
			}).then(x -> x, (_) -> fetchMediaByHashOneCounterpart(hashes.slice(1), counterpart));
		});
	}

	@:allow(borogove)
	private function chatActivity(chat: Chat, trigger = true) {
		if (chat.isBlocked) return; // Don't notify blocked chats
		if (chat.uiState == Closed) {
			chat.uiState = Open;
			persistence.storeChats(accountId(), [chat]);
		}
		final pinnedCount = chat.uiState == Pinned ? 0 : chats.fold((item, result) -> result + (item.uiState == Pinned ? 1 : 0), 0);
		var idx = chats.findIndex(c -> c.chatId == chat.chatId);
		if (idx > pinnedCount) {
			chats.splice(idx, 1);
			chats.insert(pinnedCount, chat);
		}
		if (trigger) this.trigger("chats/update", [chat]);
	}

	@:allow(borogove)
	private function sortChats() {
		chats.sort((a, b) -> {
			if (a.uiState == b.uiState) {
				final tcompare = -Reflect.compare(a.lastMessage?.timestamp ?? "0", b.lastMessage?.timestamp ?? "0");
				if (tcompare != 0) return tcompare;
				return Reflect.compare(a.getDisplayName(), b.getDisplayName());
			} else {
				return Reflect.compare(a.uiState, b.uiState);
			}
		});
	}

	@:allow(borogove)
	private function storeMessages(messages: Array<ChatMessage>): Promise<Null<Array<ChatMessage>>> {
		return persistence.storeMessages(accountId(), messages);
	}

	@:allow(borogove)
	private function sendQuery(query:GenericQuery) {
		this.stream.sendIq(query.getQueryStanza(), query.handleResponse);
	}

	private var lazyQueryTimer = null;
	private final queriesToSend = [];
	private function sendNextLazyQuery() {
		if (lazyQueryTimer != null) return;
		lazyQueryTimer = haxe.Timer.delay(() -> {
			final query = queriesToSend.shift();
			if (query != null) sendQuery(query);

			lazyQueryTimer = null;
			if (queriesToSend.length > 0) sendNextLazyQuery();
		}, 2000);
	}

	@:allow(borogove)
	private function sendQueryLazy(query:GenericQuery) {
		queriesToSend.push(query);
		sendNextLazyQuery();
	}

	@:allow(borogove)
	private function publishWithOptions(stanza:Stanza, options:Stanza) {
		final clone = stanza.clone();
		clone.findChild("{http://jabber.org/protocol/pubsub}pubsub/publish").tag("publish-options").addChild(options);
		stream.sendIq(
			clone,
			(response) -> {
				if (response.attr.get("type") == "error") {
					final preconditionError = response.getChild("error")?.getChild("precondition-not-met", "http://jabber.org/protocol/pubsub#errors");
					if (preconditionError != null) {
						// publish options failed, so force them to be right, what a silly workflow
						stream.sendIq(
							new Stanza("iq", { type: "set" })
								.tag("pubsub", { xmlns: "http://jabber.org/protocol/pubsub#owner" })
								.tag("configure", { node: stanza.findText("{http://jabber.org/protocol/pubsub}pubsub/publish@node") })
								.addChild(options),
							(response) -> {
								if (response.attr.get("type") == "result") {
									publishWithOptions(stanza, options);
								}
							}
						);
					}
				}
			}
		);
	}

	@:allow(borogove)
	private function sendStanza(stanza:Stanza) {
		if (stanza.attr.get("id") == null) stanza.attr.set("id", ID.long());
		stream.sendStanza(stanza);
	}

	@:allow(borogove)
	private function sendPresence(?to: String, ?augment: (Stanza)->Stanza) {
		sendStanza(
			(augment ?? (s)->s)(
				caps.addC(new Stanza("presence", to == null ? {} : { to: to }))
					.textTag("nick", displayName(), { xmlns: "http://jabber.org/protocol/nick" })
			)
		);
	}

#if !NO_JINGLE
	@:allow(borogove)
	private function getIceServers(callback: (Array<IceServer>)->Void) {
		final extDiscoGet = new ExtDiscoGet(jid.domain);
		extDiscoGet.onFinished(() -> {
			final didUrl: Map<String, Bool> = [];
			final servers = [];
			for (service in extDiscoGet.getResult() ?? []) {
				if (!["stun", "stuns", "turn", "turns"].contains(service.attr.get("type"))) continue;
				final host = service.attr.get("host");
				if (host == null || host == "") continue;
				final port = Std.parseInt(service.attr.get("port"));
				if (port == null || port < 1 || port > 65535) continue;
				final isTurn = ["turn", "turns"].contains(service.attr.get("type"));
				final url = service.attr.get("type") + ":" + (host.indexOf(":") >= 0 ? "[" + host + "]" : host) + ":" + port + (isTurn ? "?transport=" + service.attr.get("transport") : "");
				if (!didUrl.exists(url)) {
					servers.push({
						username: service.attr.get("username"),
						credential: service.attr.get("password"),
						urls: [url]
					});
					didUrl[url] = true;
				}
			}
			callback(servers);
		});
		sendQuery(extDiscoGet);
	}
#end

	@:allow(borogove)
	private function discoverServices(target: JID, ?node: String, callback: ({ jid: JID, name: Null<String>, node: Null<String> }, Caps)->Void) {
		final itemsGet = new DiscoItemsGet(target.asString(), node);
		itemsGet.onFinished(()-> {
			for (item in itemsGet.getResult() ?? []) {
				final infoGet = new DiscoInfoGet(item.jid.asString(), item.node);
				infoGet.onFinished(() -> {
					callback(item, infoGet.getResult() ?? new Caps("", [], [], []));
				});
				sendQuery(infoGet);
			}
		});
		sendQuery(itemsGet);
	}

	@:allow(borogove)
	private function notifyMessageHandlers(message: ChatMessage, event: ChatMessageEvent) {
		final chat = getChat(message.chatId());
		if (chat != null && chat.isBlocked) return; // Don't notify blocked chats
		this.trigger("message/new", { message: message, event: event });
	}

	@:allow(borogove)
	private function notifySyncMessageHandlers(message: ChatMessage) {
		if (message == null || message.versions.length > 1) return;
		final chat = getChat(message.chatId());
		if (chat != null && chat.isBlocked) return; // Don't notify blocked chats
		this.trigger("message/sync", message);
	}

	private function rosterGet() {
		var rosterGet = new RosterGet();
		rosterGet.onFinished(() -> {
			final chatsToUpdate = [];
			for (item in rosterGet.getResult()) {
				var chat = getDirectChat(item.jid, false);
				chat.updateFromRoster(item);
				chatsToUpdate.push(cast (chat, Chat));
			}
			persistence.storeChats(accountId(), chatsToUpdate);
			this.trigger("chats/update", chatsToUpdate);
		});
		sendQuery(rosterGet);
	}

	private function startChatWith(jid: String, handleCaps: (Null<Caps>)->UiState, handleChat: (Chat)->Void) {
		final discoGet = new DiscoInfoGet(jid);
		discoGet.onFinished(() -> {
			final resultCaps = discoGet.getResult();
			final uiState = handleCaps(resultCaps);
			if (resultCaps == null) {
				final err = discoGet.responseStanza?.getChild("error")?.getChild(null, "urn:ietf:params:xml:ns:xmpp-stanzas");
				if (err == null || err?.name == "service-unavailable" || err?.name == "feature-not-implemented") {
					final chat = getDirectChat(jid, false);
					chat.uiState = uiState;
					handleChat(chat);
					persistence.storeChats(accountId(), [chat]);
					this.trigger("chats/update", [chat]);
				}
			} else {
				persistence.storeCaps(resultCaps);
				if (resultCaps.isChannel(jid)) {
					final chat = new Channel(this, this.stream, this.persistence, jid, uiState, false, null, resultCaps);
					chat.setupNotifications();
					chats.unshift(chat);
					if (inSync && sendAvailable) chat.selfPing(false);
					handleChat(chat);
					persistence.storeChats(accountId(), [chat]);
					this.trigger("chats/update", [chat]);
				} else {
					final chat = getDirectChat(jid, false);
					chat.uiState = uiState;
					handleChat(chat);
					persistence.storeChats(accountId(), [chat]);
					this.trigger("chats/update", [chat]);
				}
			}
		});
		sendQuery(discoGet);
	}

	private function mucInvite(chatId: String, chat: Null<Chat>, senderId: String, threadId: Null<String>, serverId: Null<String>, serverIdBy: Null<String>, reason: Null<String>, password: Null<String>) {
		if (chat == null) {
			startChatWith(chatId, _ -> Invited, (chat) -> {
				mucInvite(chatId, chat, senderId, threadId, serverId, serverIdBy, reason, password);
			});
			return;
		}

		// Already open so keep it that way
		if (chat.uiState != Closed && chat.uiState != Invited) return;

		chat.extensions.removeChildren("invite", "http://jabber.org/protocol/muc#user");
		final inviteExt = chat.extensions.tag("invite", { xmlns: "http://jabber.org/protocol/muc#user", from: senderId });
		if (reason != null) inviteExt.textTag("reason", reason);
		if (password != null) inviteExt.textTag("password", password);
		if (threadId != null) inviteExt.tag("continue", { thread: threadId }).up();
		if (serverId != null && serverIdBy != null) {
			inviteExt.tag("stanza-id", { xmlns: "urn:xmpp:sid:0", by: serverIdBy, id: serverId }).up();
		}
		inviteExt.up();
		chat.uiState = Invited;
		this.trigger("chats/update", [chat]);
		persistence.storeChats(accountId(), [chat]);
	}

	private function serverBlocked(blocked: String) {
		final chat = getChat(blocked) ?? getDirectChat(blocked, false);
		chat.block(false, null, false);
	}

	// This is called right before we're going to trigger for all chats anyway, so don't bother with single triggers
	private function bookmarksGet(callback: ()->Void) {
		final blockingGet = new BlocklistGet();
		blockingGet.onFinished(() -> {
			for (blocked in blockingGet.getResult()) {
				serverBlocked(blocked);
			}
		});
		sendQuery(blockingGet);

		final mdsGet = new PubsubGet(null, "urn:xmpp:mds:displayed:0");
		mdsGet.onFinished(() -> {
			final chatsToUpdate = [];
			for (item in mdsGet.getResult()) {
				if (item.attr.get("id") != null) {
					final upTo = item.getChild("displayed", "urn:xmpp:mds:displayed:0")?.getChild("stanza-id", "urn:xmpp:sid:0");
					final chat = getChat(item.attr.get("id"));
					if (chat == null) {
						startChatWith(item.attr.get("id"), _ -> Closed, (chat) -> chat.markReadUpToId(upTo.attr.get("id"), upTo.attr.get("by")));
					} else {
						chat.markReadUpToId(upTo.attr.get("id"), upTo.attr.get("by")).then(_ -> null, e -> e != null ? Promise.reject(e) : null);
						chatsToUpdate.push(chat);
					}
				}
			}
			persistence.storeChats(accountId(), chatsToUpdate);
		});
		sendQuery(mdsGet);

		final pubsubGet = new PubsubGet(null, "urn:xmpp:bookmarks:1");
		pubsubGet.onFinished(() -> {
			final chatsToUpdate = [];
			for (item in pubsubGet.getResult()) {
				if (item.attr.get("id") != null) {
					final chat = getChat(item.attr.get("id"));
					if (chat == null) {
						startChatWith(
							item.attr.get("id"),
							(caps) -> {
								if (caps == null) return Open;

								final identity = caps.identities[0];
								final conf = item.getChild("conference", "urn:xmpp:bookmarks:1");
								if (conf.attr.get("name") == null) {
									conf.attr.set("name", identity?.name);
								}
								return (conf.attr.get("autojoin") == "1" || conf.attr.get("autojoin") == "true" || !caps.isChannel(item.attr.get("id"))) ? Open : Closed;
							},
							(chat) -> {
								chat.updateFromBookmark(item);
							}
						);
					} else {
						chat.updateFromBookmark(item);
						chatsToUpdate.push(chat);
					}
				}
			}
			persistence.storeChats(accountId(), chatsToUpdate);
			callback();
		});
		sendQuery(pubsubGet);
	}

	private function sync(?callback: (Bool)->Void) {
		if (Std.isOfType(persistence, borogove.persistence.Dummy)) {
			callback(true); // No reason to sync if we're not storing anyway
		} else {
			persistence.lastId(accountId(), null).then((lastId) -> doSync(callback, lastId));
		}
	}

#if !NO_JINGLE
	private function onMAMJMI(sid: String, stanza: Stanza) {
		if (stanza.attr.get("from") == null) return;
		final from = JID.parse(stanza.attr.get("from"));
		final chat = getDirectChat(from.asBare().asString());
		if (chat.jingleSessions.exists(sid)) return; // Already know about this session
		final jmiP = stanza.getChild("propose", "urn:xmpp:jingle-message:0");
		if (jmiP == null) return;
		final session = new IncomingProposedSession(this, from, sid);
		chat.jingleSessions.set(session.sid, session);
		chatActivity(chat);
		session.ring();
	}
#end

	private function doSync(callback: Null<(Bool)->Void>, lastId: Null<String>) {
		var thirtyDaysAgo = Date.format(
			DateTools.delta(std.Date.now(), DateTools.days(-30))
		);
		var sync = new MessageSync(
			this,
			stream,
			lastId == null ? { startTime: thirtyDaysAgo } : { page: { after: lastId } }
		);
		sync.setNewestPageFirst(false);
		sync.addContext((builder, stanza) -> {
			builder.syncPoint = true;
			return builder;
		});
		final chatIds: Map<String, Bool> = [];
		sync.onMessages((messageList) -> {
			final promises = [];
			final chatMessages = [];
			for (m in messageList.messages) {
				switch (m.parsed) {
					case ChatMessageStanza(message):
						chatMessages.push(message);
						if (message.type == MessageChat) chatIds[message.chatId()] = true;
					case ReactionUpdateStanza(update):
						promises.push(
							persistence.storeReaction(accountId(), update).then(_ -> null)
						);
					case ModerateMessageStanza(action):
						promises.push(new thenshim.Promise((resolve, reject) -> {
							moderateMessage(action).then((_) -> resolve(null));
						}));
					case ErrorMessageStanza(localId, stanza):
						promises.push(persistence.updateMessageStatus(
							accountId(),
							localId,
							MessageFailedToSend,
							stanza.getErrorText(),
						).then(m -> [m], _ -> []));
					case MucInviteStanza(serverId, serverIdBy, reason, password):
						mucInvite(m.chatId, getChat(m.chatId), m.senderId, m.threadId, serverId, serverIdBy, reason, password);
					default:
						// ignore
				}
			}
			promises.push(persistence.storeMessages(accountId(), chatMessages));
			trace("SYNC: MAM page wait for writes");
			thenshim.PromiseTools.all(promises).then((results) -> {
				for (messages in results) {
					if (messages != null) {
						for (message in messages) {
							this.trigger("message/sync", message);
						}
					}
				}

				if (sync.hasMore()) {
					sync.fetchNext();
				} else {
#if !NO_JINGLE
					for (sid => stanza in sync.jmi) {
						onMAMJMI(sid, stanza);
					}
#end
					for (chatId => _ in chatIds) {
						// If this is a message from a prevoiusly unknown direct chat, record the chat
						final chat = getChat(chatId);
						if (chat == null) getDirectChat(chatId);
					}
					if (callback != null) callback(true);
				}
			},
			(e) -> {
				trace("SYNC: error", e);
				callback(false);
			});
		});
		sync.onError((stanza) -> {
			if (lastId != null) {
				// Gap in sync, out newest message has expired from server
				doSync(callback, null);
			} else {
				trace("SYNC: error", stanza);
				if (callback != null) callback(false);
			}
		});
		sync.fetchNext();
	}

	private function pingAllChannels(refresh: Bool) {
		for (chat in getChats()) {
			final channel = Std.downcast(chat, Channel);
			channel?.selfPing(refresh || channel?.disco == null);
		}
	}

	private function joinAllChannels() {
		for (chat in getChats()) {
			final channel = Std.downcast(chat, Channel);
			if (channel != null) {
				if (channel.disco.identities.length < 1) {
					channel.refreshDisco(() -> {
						channel.join();
					});
				} else {
					channel.join();
					haxe.Timer.delay(() -> channel.refreshDisco(), 30000);
				}
			}
		}
	}
}
