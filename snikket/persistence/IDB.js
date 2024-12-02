// This example persistence driver is written in JavaScript
// so that SDK users can easily see how to write their own

import { snikket as enums } from "./snikket-enums.js";
import { snikket } from "./snikket.js";

export default (dbname, media, tokenize, stemmer) => {
	if (!tokenize) tokenize = function(s) { return s.split(" "); }
	if (!stemmer) stemmer = function(s) { return s; }

	var db = null;
	function openDb(version) {
		var dbOpenReq = indexedDB.open(dbname, version);
		dbOpenReq.onerror = console.error;
		dbOpenReq.onupgradeneeded = (event) => {
			const upgradeDb = event.target.result;
			if (!db.objectStoreNames.contains("messages")) {
				const messages = upgradeDb.createObjectStore("messages", { keyPath: ["account", "serverId", "serverIdBy", "localId"] });
				messages.createIndex("chats", ["account", "chatId", "timestamp"]);
				messages.createIndex("localId", ["account", "localId", "chatId"]);
				messages.createIndex("accounts", ["account", "timestamp"]);
			}
			if (!db.objectStoreNames.contains("keyvaluepairs")) {
				upgradeDb.createObjectStore("keyvaluepairs");
			}
			if (!db.objectStoreNames.contains("chats")) {
				upgradeDb.createObjectStore("chats", { keyPath: ["account", "chatId"] });
			}
			if (!db.objectStoreNames.contains("services")) {
				upgradeDb.createObjectStore("services", { keyPath: ["account", "serviceId"] });
			}
			if (!db.objectStoreNames.contains("reactions")) {
				const reactions = upgradeDb.createObjectStore("reactions", { keyPath: ["account", "chatId", "senderId", "updateId"] });
				reactions.createIndex("senders", ["account", "chatId", "messageId", "senderId", "timestamp"]);
			}
		};
		dbOpenReq.onsuccess = (event) => {
			db = event.target.result;
			window.db = db;
			if (!db.objectStoreNames.contains("messages") || !db.objectStoreNames.contains("keyvaluepairs") || !db.objectStoreNames.contains("chats") || !db.objectStoreNames.contains("services") || !db.objectStoreNames.contains("reactions")) {
				db.close();
				openDb(db.version + 1);
				return;
			}
		};
	}
	openDb();

	function promisifyRequest(request) {
		return new Promise((resolve, reject) => {
			request.oncomplete = request.onsuccess = () => resolve(request.result);
			request.onabort = request.onerror = () => reject(request.error);
		});
	}

	function hydrateStringReaction(r, senderId, timestamp) {
		if (r.startsWith("ni://")){
			return new snikket.CustomEmojiReaction(senderId, timestamp, "", r);
		} else {
			return new snikket.Reaction(senderId, timestamp, r);
		}
	}

	function hydrateObjectReaction(r) {
		if (r.uri) {
			return new snikket.CustomEmojiReaction(r.senderId, r.timestamp, r.text, r.uri, r.envelopeId);
		} else {
			return new snikket.Reaction(r.senderId, r.timestamp, r.text, r.envelopeId, r.key);
		}
	}

	function hydrateReactionsArray(reacts, senderId, timestamp) {
		if (!reacts) return reacts;
		return reacts.map(r => typeof r === "string" ? hydrateStringReaction(r, senderId, timestamp) : hydrateObjectReaction(r));
	}

	function hydrateReactions(map, timestamp) {
		if (!map) return new Map();
		const newMap = new Map();
		for (const [k, reacts] of map) {
			newMap.set(k, reacts.map(reactOrSender => typeof reactOrSender === "string" ? hydrateStringReaction(k, reactOrSender, timestamp) : hydrateObjectReaction(reactOrSender)));
		}
		return newMap;
	}

	function hydrateMessageSync(value) {
		if (!value) return null;

		const tx = db.transaction(["messages"], "readonly");
		const store = tx.objectStore("messages");

		const message = new snikket.ChatMessageBuilder();
		message.localId = value.localId ? value.localId : null;
		message.serverId = value.serverId ? value.serverId : null;
		message.serverIdBy = value.serverIdBy ? value.serverIdBy : null;
		message.replyId = value.replyId ? value.replyId : null;
		message.syncPoint = !!value.syncPoint;
		message.direction = value.direction;
		message.status = value.status;
		message.timestamp = value.timestamp && value.timestamp.toISOString();
		message.from = value.from && snikket.JID.parse(value.from);
		message.sender = value.sender && snikket.JID.parse(value.sender);
		message.senderId = value.senderId;
		message.recipients = value.recipients.map((r) => snikket.JID.parse(r));
		message.to = value.to ? snikket.JID.parse(value.to) : message.recipients[0];
		message.replyTo = value.replyTo.map((r) => snikket.JID.parse(r));
		message.threadId = value.threadId;
		message.attachments = value.attachments;
		message.reactions = hydrateReactions(value.reactions, message.timestamp);
		message.text = value.text;
		message.lang = value.lang;
		message.type = value.type || (value.isGroupchat || value.groupchat ? enums.MessageType.Channel : enums.MessageType.Chat);
		message.payloads = (value.payloads || []).map(snikket.Stanza.parse);
		message.stanza = value.stanza && snikket.Stanza.parse(value.stanza);
		if (!message.localId && !message.serverId) message.localId = "NO_ID"; // bad data
		return message.build();
	}

	async function hydrateMessage(value) {
		if (!value) return null;

		const message = hydrateMessageSync(value);
		const tx = db.transaction(["messages"], "readonly");
		const store = tx.objectStore("messages");
		const replyToMessage = value.replyToMessage && value.replyToMessage[1] !== message.serverId && value.replyToMessage[3] !== message.localId && await hydrateMessage((await promisifyRequest(store.openCursor(IDBKeyRange.only(value.replyToMessage))))?.value);

		message.replyToMessage = replyToMessage;
		message.versions = await Promise.all((value.versions || []).map(hydrateMessage));
		return message;
	}

	function serializeMessage(account, message) {
		return {
			...message,
			serverId: message.serverId || "",
			serverIdBy: message.serverIdBy || "",
			localId: message.localId || "",
			syncPoint: !!message.syncPoint,
			account: account,
			chatId: message.chatId(),
			to: message.to?.asString(),
			from: message.from?.asString(),
			senderId: message.senderId,
			recipients: message.recipients.map((r) => r.asString()),
			replyTo: message.replyTo.map((r) => r.asString()),
			timestamp: new Date(message.timestamp),
			replyToMessage: message.replyToMessage && [account, message.replyToMessage.serverId || "", message.replyToMessage.serverIdBy || "", message.replyToMessage.localId || ""],
			versions: message.versions.map((m) => serializeMessage(account, m)),
			payloads: message.payloads.map((p) => p.toString()),
			stanza: message.stanza?.toString(),
		}
	}

	function correctMessage(account, message, result) {
		// Newest (by timestamp) version wins for head
		const newVersions = message.versions.length < 2 ? [message] : message.versions;
		const storedVersions = result.value.versions || [];
		// TODO: dedupe? There shouldn't be dupes...
		const versions = (storedVersions.length < 1 ? [result.value] : storedVersions).concat(newVersions.filter(nv => !storedVersions.find(sv => nv.serverId === sv.serverId)).map((nv) => serializeMessage(account, nv))).sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime());
		const head = {...versions[0]};
		// Can't change primary key
		head.serverIdBy = result.value.serverIdBy;
		head.serverId = result.value.serverId;
		head.localId = result.value.localId;
		head.replyId = result.value.replyId;
		head.timestamp = result.value.timestamp; // Edited version is not newer
		head.versions = versions;
		head.reactions = result.value.reactions; // Preserve these, edit doesn't touch them
		// Calls can "edit" from multiple senders, but the original direction and sender holds
		if (result.value.type === enums.MessageType.MessageCall) {
			head.direction = result.value.direction;
			head.senderId = result.value.senderId;
			head.from = result.value.from;
			head.to = result.value.to;
			head.replyTo = result.value.replyTo;
			head.recipients = result.value.recipients;
		}
		result.update(head);
		return head;
	}

	function setReactions(reactionsMap, sender, reactions) {
		for (const [reaction, reacts] of reactionsMap) {
			const newReacts = reacts.filter((react) => react.senderId !== sender);
			if (newReacts.length < 1) {
				reactionsMap.delete(reaction);
			} else {
				reactionsMap.set(reaction, newReacts);
			}
		}
		for (const reaction of reactions) {
			reactionsMap.set(reaction.key, [...reactionsMap.get(reaction.key) || [], reaction]);
		}
		return reactionsMap;
	}

	const obj = {
		lastId: function(account, jid, callback) {
			const tx = db.transaction(["messages"], "readonly");
			const store = tx.objectStore("messages");
			var cursor = null;
			if (jid === null) {
				cursor = store.index("accounts").openCursor(
					IDBKeyRange.bound([account], [account, []]),
					"prev"
				);
			} else {
				cursor = store.index("chats").openCursor(
					IDBKeyRange.bound([account, jid], [account, jid, []]),
					"prev"
				);
			}
			cursor.onsuccess = (event) => {
				if (!event.target.result || (event.target.result.value.syncPoint && event.target.result.value.serverId && (jid || event.target.result.value.serverIdBy === account))) {
					callback(event.target.result ? event.target.result.value.serverId : null);
				} else {
					event.target.result.continue();
				}
			}
			cursor.onerror = (event) => {
				console.error(event);
				callback(null);
			}
		},

		storeChats: function(account, chats) {
			const tx = db.transaction(["chats"], "readwrite");
			const store = tx.objectStore("chats");

			for (const chat of chats) {
				store.put({
					account: account,
					chatId: chat.chatId,
					trusted: chat.trusted,
					avatarSha1: chat.avatarSha1,
					presence: new Map([...chat.presence.entries()].map(([k, p]) => [k, { caps: p.caps?.ver(), mucUser: p.mucUser?.toString() }])),
					displayName: chat.displayName,
					uiState: chat.uiState,
					isBlocked: chat.isBlocked,
					extensions: chat.extensions?.toString(),
					readUpToId: chat.readUpToId,
					readUpToBy: chat.readUpToBy,
					notificationSettings: chat.notificationsFiltered() ? { mention: chat.notifyMention(), reply: chat.notifyReply() } : null,
					disco: chat.disco,
					omemoDevices: chat.omemoContactDeviceIDs,
				class: chat instanceof snikket.DirectChat ? "DirectChat" : (chat instanceof snikket.Channel ? "Channel" : "Chat")
				});
			}
		},

		getChats: function(account, callback) {
			(async () => {
				const tx = db.transaction(["chats"], "readonly");
				const store = tx.objectStore("chats");
				const range = IDBKeyRange.bound([account], [account, []]);
				const result = await promisifyRequest(store.getAll(range));
				return await Promise.all(result.map(async (r) => new snikket.SerializedChat(
					r.chatId,
					r.trusted,
					r.avatarSha1,
					new Map(await Promise.all((r.presence instanceof Map ? [...r.presence.entries()] : Object.entries(r.presence)).map(
						async ([k, p]) => [k, new snikket.Presence(p.caps && await new Promise((resolve) => this.getCaps(p.caps, resolve)), p.mucUser && snikket.Stanza.parse(p.mucUser))]
					))),
					r.displayName,
					r.uiState,
					r.isBlocked,
					r.extensions,
					r.readUpToId,
					r.readUpToBy,
					r.notificationSettings === undefined ? null : r.notificationSettings != null,
					r.notificationSettings?.mention,
					r.notificationSettings?.reply,
					r.disco ? new snikket.Caps(r.disco.node, r.disco.identities, r.disco.features) : null,
					r.omemoDevices || [],
					r.class
				)));
			})().then(callback);
		},

		getChatsUnreadDetails: function(account, chatsArray, callback) {
			const tx = db.transaction(["messages"], "readonly");
			const store = tx.objectStore("messages");

			const cursor = store.index("accounts").openCursor(
				IDBKeyRange.bound([account], [account, []]),
				"prev"
			);
			const chats = {};
			chatsArray.forEach((chat) => chats[chat.chatId] = chat);
			const result = {};
			var rowCount = 0;
			cursor.onsuccess = (event) => {
				if (event.target.result && rowCount < 40000) {
					rowCount++;
					const value = event.target.result.value;
					if (result[value.chatId]) {
						result[value.chatId] = result[value.chatId].then((details) => {
							if (!details.foundAll) {
								const readUpTo = chats[value.chatId]?.readUpTo();
								if (readUpTo === value.serverId || readUpTo === value.localId || value.direction == enums.MessageDirection.MessageSent) {
									details.foundAll = true;
								} else {
									details.unreadCount++;
								}
							}
							return details;
						});
					} else {
						const readUpTo = chats[value.chatId]?.readUpTo();
						const haveRead = readUpTo === value.serverId || readUpTo === value.localId || value.direction == enums.MessageDirection.MessageSent;
						result[value.chatId] = hydrateMessage(value).then((m) => ({ chatId: value.chatId, message: m, unreadCount: haveRead ? 0 : 1, foundAll: haveRead }));
					}
					event.target.result.continue();
				} else {
					Promise.all(Object.values(result)).then(callback);
				}
			}
			cursor.onerror = (event) => {
				console.error(event);
				callback([]);
			}
		},

		getMessage: function(account, chatId, serverId, localId, callback) {
			const tx = db.transaction(["messages"], "readonly");
			const store = tx.objectStore("messages");
			(async function() {
				let result;
				if (serverId) {
					result = await promisifyRequest(store.openCursor(IDBKeyRange.bound([account, serverId], [account, serverId, []])));
				} else {
					result = await promisifyRequest(store.index("localId").openCursor(IDBKeyRange.only([account, localId, chatId])));
				}
				if (!result || !result.value) return null;
				const message = result.value;
				return await hydrateMessage(message);
			})().then(callback);
		},

		storeReaction: function(account, update, callback) {
			(async function() {
				const tx = db.transaction(["messages", "reactions"], "readwrite");
				const store = tx.objectStore("messages");
				const reactionStore = tx.objectStore("reactions");
				let result;
				if (update.serverId) {
					result = await promisifyRequest(store.openCursor(IDBKeyRange.bound([account, update.serverId, update.serverIdBy], [account, update.serverId, update.serverIdBy, []])));
				} else {
					result = await promisifyRequest(store.index("localId").openCursor(IDBKeyRange.only([account, update.localId, update.chatId])));
				}
				const lastFromSender = await promisifyRequest(reactionStore.index("senders").openCursor(IDBKeyRange.bound(
					[account, update.chatId, update.serverId || update.localId, update.senderId],
					[account, update.chatId, update.serverId || update.localId, update.senderId, []]
				), "prev"));
				const reactions = update.getReactions(hydrateReactionsArray(lastFromSender?.value?.reactions));
				await promisifyRequest(reactionStore.put({...update, reactions: reactions, append: (update.kind === enums.ReactionUpdateKind.AppendReactions ? update.reactions : null), messageId: update.serverId || update.localId, timestamp: new Date(update.timestamp), account: account}));
				if (!result || !result.value) return null;
				if (lastFromSender?.value && lastFromSender.value.timestamp > new Date(update.timestamp)) return;
				const message = result.value;
				setReactions(message.reactions, update.senderId, reactions);
				store.put(message);
				return await hydrateMessage(message);
			})().then(callback);
		},

		storeMessages(account, messages, callback) {
			Promise.all(messages.map(m =>
				new Promise(resolve => this.storeMessage(account, m, resolve))
			)).then(callback);
		},

		storeMessage: function(account, message, callback) {
			if (!message.chatId()) throw "Cannot store a message with no chatId";
			if (!message.serverId && !message.localId) throw "Cannot store a message with no id";
			if (!message.serverId && message.isIncoming()) throw "Cannot store an incoming message with no server id";
			if (message.serverId && !message.serverIdBy) throw "Cannot store a message with a server id and no by";

			new Promise((resolve) =>
				// Hydrate reply stubs
				message.replyToMessage && !message.replyToMessage.serverIdBy ? this.getMessage(account, message.chatId(), message.replyToMessage.serverId, message.replyToMessage.localId, resolve) : resolve(message.replyToMessage)
			).then((replyToMessage) => {
				message.replyToMessage = replyToMessage;
				const tx = db.transaction(["messages", "reactions"], "readwrite");
				const store = tx.objectStore("messages");
				return Promise.all([
					promisifyRequest(store.index("localId").openCursor(IDBKeyRange.only([account, message.localId || [], message.chatId()]))),
					promisifyRequest(tx.objectStore("reactions").openCursor(IDBKeyRange.only([account, message.chatId(), message.senderId, message.localId || ""])))
				]).then(([result, reactionResult]) => {
					if (reactionResult?.value?.append && message.html().trim() == "") {
						this.getMessage(account, message.chatId(), reactionResult.value.serverId, reactionResult.value.localId, (reactToMessage) => {
							const previouslyAppended = hydrateReactionsArray(reactionResult.value.append, reactionResult.value.senderId, reactionResult.value.timestamp).map(r => r.key);
							const reactions = [];
							for (const [k, reacts] of reactToMessage?.reactions || []) {
								for (const react of reacts) {
									if (react.senderId === message.senderId && !previouslyAppended.includes(k)) reactions.push(react);
								}
							}
							this.storeReaction(account, new snikket.ReactionUpdate(message.localId, reactionResult.value.serverId, reactionResult.value.serverIdBy, reactionResult.value.localId, message.chatId(), message.senderId, message.timestamp, reactions, enums.ReactionUpdateKind.CompleteReactions), callback);
						});
						return true;
					} else if (result?.value && !message.isIncoming() && result?.value.direction === enums.MessageDirection.MessageSent && message.versions.length < 1) {
						// Duplicate, we trust our own sent ids
						return promisifyRequest(result.delete());
					} else if (result?.value && (result.value.senderId == message.senderId || result.value.type == enums.MessageType.MessageCall) && (message.versions.length > 0 || (result.value.versions || []).length > 0)) {
						hydrateMessage(correctMessage(account, message, result)).then(callback);
						return true;
					}
				}).then((done) => {
					if (!done) {
						// There may be reactions already if we are paging backwards
						const cursor = tx.objectStore("reactions").index("senders").openCursor(IDBKeyRange.bound([account, message.chatId(), message.getReplyId() || ""], [account, message.chatId(), message.getReplyId() || "", []]), "prev");
						const reactions = new Map();
						const reactionTimes = new Map();
						cursor.onsuccess = (event) => {
							if (event.target.result && event.target.result.value) {
								const time = reactionTimes.get(event.target.result.senderId);
								if (!time || time < event.target.result.value.timestamp) {
									setReactions(reactions, event.target.result.value.senderId, hydrateReactionsArray(event.target.result.value.reactions, event.target.result.senderId, event.target.result.timestamp));
									reactionTimes.set(event.target.result.value.senderId, event.target.result.value.timestamp);
								}
								event.target.result.continue();
							} else {
								message.reactions = reactions;
								const req = store.put(serializeMessage(account, message));
								req.onerror = () => { window.mylog.push("MSG STORE ERROR: " + req.error.name + " " + req.error.message); }
								callback(message);
							}
						};
						cursor.onerror = console.error;
					}
				});
			});
		},

		updateMessage: function(account, message) {
			if (!message.chatId()) throw "Cannot store a message with no chatId";
			if (!message.serverId && !message.localId) throw "Cannot store a message with no id";
			if (!message.serverId && message.isIncoming()) throw "Cannot store an incoming message with no server id";
			if (message.serverId && !message.serverIdBy) throw "Cannot store a message with a server id and no by";

			const tx = db.transaction(["messages"], "readwrite");
			const store = tx.objectStore("messages");
			store.put(serializeMessage(account, message));
		},

		updateMessageStatus: function(account, localId, status, callback) {
			const tx = db.transaction(["messages"], "readwrite");
			const store = tx.objectStore("messages");
			promisifyRequest(store.index("localId").openCursor(IDBKeyRange.bound([account, localId], [account, localId, []]))).then((result) => {
				if (result?.value && result.value.direction === enums.MessageDirection.MessageSent && result.value.status !== enums.MessageStatus.MessageDeliveredToDevice) {
					const newStatus = { ...result.value, status: status };
					result.update(newStatus);
					hydrateMessage(newStatus).then(callback);
				}
			});
		},

		getMessagesBefore: function(account, chatId, beforeId, beforeTime, callback) {
			// TODO: if beforeId is present but beforeTime is null, lookup time
			const bound = beforeTime ? new Date(beforeTime) : [];
			const tx = db.transaction(["messages"], "readonly");
			const store = tx.objectStore("messages");
			const cursor = store.index("chats").openCursor(
				IDBKeyRange.bound([account, chatId], [account, chatId, bound]),
				"prev"
			);
			this.getMessagesFromCursor(cursor, beforeId, bound, (messages) => callback(messages.reverse()));
		},

		getMessagesAfter: function(account, chatId, afterId, afterTime, callback) {
			// TODO: if afterId is present but afterTime is null, lookup time
			const bound = afterTime ? [new Date(afterTime)] : [];
			const tx = db.transaction(["messages"], "readonly");
			const store = tx.objectStore("messages");
			const cursor = store.index("chats").openCursor(
				IDBKeyRange.bound([account, chatId].concat(bound), [account, chatId, []]),
				"next"
			);
			this.getMessagesFromCursor(cursor, afterId, bound[0], callback);
		},

		getMessagesAround: function(account, chatId, id, timeArg, callback) {
			if (!id && !timeArg) throw "Around what?";
			new Promise((resolve, reject) => {
				if (timeArg)  {
					resolve(timeArg);
				} else {
					this.getMessage(account, chatId, id, null, (m) => {
						m ? resolve(m.timestamp) : this.getMessage(account, chatId, null, id, (m2) => resolve(m2?.timestamp));
					});
				}
			}).then((time) => {
				if (!time) {
					callback([]);
					return;
				}
				const before = new Promise((resolve, reject) =>
					this.getMessagesBefore(account, chatId, id, time, resolve)
				);

				const tx = db.transaction(["messages"], "readonly");
				const store = tx.objectStore("messages");
				const cursor = store.index("chats").openCursor(
					IDBKeyRange.bound([account, chatId, new Date(time)], [account, chatId, []]),
					"next"
				);
				const aroundAndAfter = new Promise((resolve, reject) =>
					this.getMessagesFromCursor(cursor, null, null, resolve)
				);

				Promise.all([before, aroundAndAfter]).then((result) => {
					callback(result.flat());
				});
			});
		},

		getMessagesFromCursor: function(cursor, id, bound, callback) {
			const result = [];
			cursor.onsuccess = (event) => {
				if (event.target.result && result.length < 50) {
					const value = event.target.result.value;
					if (value.serverId === id || value.localId === id || (value.timestamp && value.timestamp.getTime() === (bound instanceof Date && bound.getTime()))) {
						event.target.result.continue();
						return;
					}

					result.push(hydrateMessage(value));
					event.target.result.continue();
				} else {
					Promise.all(result).then(callback);
				}
			}
			cursor.onerror = (event) => {
				console.error(event);
				callback([]);
			}
		},

		searchMessages: function(account, chatId, q, callback) {
			const tx = db.transaction(["messages"], "readonly");
			const store = tx.objectStore("messages");
			var cursor;
			if (chatId) {
				cursor = store.index("chats").openCursor(
					IDBKeyRange.bound([account, chatId], [account, chatId, []]),
					"prev"
				);
			} else if (account) {
				cursor = store.index("accounts").openCursor(
					IDBKeyRange.bound([account], [account, []]),
					"prev"
				);
			} else {
				cursor = store.openCursor(undefined, "prev");
			}
			const qTok = new Set(tokenize(q).map(stemmer));
			cursor.onsuccess = (event) => {
				if (event.target.result) {
					const value = event.target.result.value;
					if (value.text && new Set(tokenize(value.text).map(stemmer)).isSupersetOf(qTok)) {
						if (!callback(q, hydrateMessageSync(value))) return;
					}
					event.target.result.continue();
				} else {
					callback(null);
				}
			}
			cursor.onerror = (event) => {
				console.error(event);
				callback(null);
			}
		},

		hasMedia: function(hashAlgorithm, hash, callback) {
			media.hasMedia(hashAlgorithm, hash, callback);
		},

		removeMedia: function(hashAlgorithm, hash) {
			media.removeMedia(hashAlgorithm, hash);
		},

		storeMedia: function(mime, buffer, callback) {
		  media.storeMedia(mime, buffer, callback);
		},

		storeCaps: function(caps) {
			const tx = db.transaction(["keyvaluepairs"], "readwrite");
			const store = tx.objectStore("keyvaluepairs");
			store.put(caps, "caps:" + caps.ver()).onerror = console.error;
		},

		getCaps: function(ver, callback) {
			(async function() {
				const tx = db.transaction(["keyvaluepairs"], "readonly");
				const store = tx.objectStore("keyvaluepairs");
				const raw = await promisifyRequest(store.get("caps:" + ver));
				if (raw) {
					return (new snikket.Caps(raw.node, raw.identities.map((identity) => new snikket.Identity(identity.category, identity.type, identity.name)), raw.features));
				}

				return null;
			})().then(callback);
		},

		storeLogin: function(login, clientId, displayName, token) {
			const tx = db.transaction(["keyvaluepairs"], "readwrite");
			const store = tx.objectStore("keyvaluepairs");
			store.put(clientId, "login:clientId:" + login).onerror = console.error;
			store.put(displayName, "fn:" + login).onerror = console.error;
			if (token != null) {
				store.put(token, "login:token:" + login).onerror = console.error;
				store.put(0, "login:fastCount:" + login).onerror = console.error;
			}
		},

		storeStreamManagement: function(account, sm) {
			// Don't bother on ios, the indexeddb is too broken
			// https://bugs.webkit.org/show_bug.cgi?id=287876
			if (navigator.userAgent.match(/(iPad|iPhone|iPod)/g)) return;

			const tx = db.transaction(["keyvaluepairs"], "readwrite");
			const store = tx.objectStore("keyvaluepairs");
			const req = store.put(sm, "sm:" + account);
			req.onerror = () => { console.error("storeStreamManagement", req.error.name, req.error.message); }
		},

		getStreamManagement: function(account, callback) {
			const tx = db.transaction(["keyvaluepairs"], "readonly");
			const store = tx.objectStore("keyvaluepairs");
			promisifyRequest(store.get("sm:" + account)).then(
				(v) => {
					if (v instanceof ArrayBuffer) {
						callback(v);
					} else if(!v) {
						callback(null);
					} else {
						new Blob([JSON.stringify(v)], {type: "text/plain; charset=utf-8"}).arrayBuffer().then(callback);
					}
				},
				(e) => {
					console.error(e);
					callback(null);
				}
			);
		},

		getLogin: function(login, callback) {
			const tx = db.transaction(["keyvaluepairs"], "readwrite");
			const store = tx.objectStore("keyvaluepairs");
			Promise.all([
				promisifyRequest(store.get("login:clientId:" + login)),
				promisifyRequest(store.get("login:token:" + login)),
				promisifyRequest(store.get("login:fastCount:" + login)),
				promisifyRequest(store.get("fn:" + login)),
			]).then((result) => {
				if (result[1]) {
					store.put((result[2] || 0) + 1, "login:fastCount:" + login).onerror = console.error;
				}
				callback(result[0], result[1], result[2] || 0, result[3]);
			}).catch((e) => {
				console.error(e);
				callback(null, null, 0, null);
			});
		},

		removeAccount(account, completely) {
			const tx = db.transaction(["keyvaluepairs", "services", "messages", "chats", "reactions"], "readwrite");
			const store = tx.objectStore("keyvaluepairs");
			store.delete("login:clientId:" + account);
			store.delete("login:token:" + account);
			store.delete("login:fastCount:" + account);
			store.delete("fn:" + account);
			store.delete("sm:" + account);

			if (!completely) return;

			const servicesStore = tx.objectStore("services");
			const servicesCursor = servicesStore.openCursor(IDBKeyRange.bound([account], [account, []]));
			servicesCursor.onsuccess = (event) => {
				if (event.target.result) {
					event.target.result.delete();
					event.target.result.continue();
				}
			};

			const messagesStore = tx.objectStore("messages");
			const messagesCursor = messagesStore.openCursor(IDBKeyRange.bound([account], [account, []]));
			messagesCursor.onsuccess = (event) => {
				if (event.target.result) {
					event.target.result.delete();
					event.target.result.continue();
				}
			};

			const chatsStore = tx.objectStore("chats");
			const chatsCursor = chatsStore.openCursor(IDBKeyRange.bound([account], [account, []]));
			chatsCursor.onsuccess = (event) => {
				if (event.target.result) {
					event.target.result.delete();
					event.target.result.continue();
				}
			};

			const reactionsStore = tx.objectStore("reactions");
			const reactionsCursor = reactionsStore.openCursor(IDBKeyRange.bound([account], [account, []]));
			reactionsCursor.onsuccess = (event) => {
				if (event.target.result) {
					event.target.result.delete();
					event.target.result.continue();
				}
			};
		},

		storeService(account, serviceId, name, node, caps) {
			this.storeCaps(caps);

			const tx = db.transaction(["services"], "readwrite");
			const store = tx.objectStore("services");

			store.put({
				account: account,
				serviceId: serviceId,
				name: name,
				node: node,
				caps: caps.ver(),
			});
		},

		findServicesWithFeature(account, feature, callback) {
			const tx = db.transaction(["services"], "readonly");
			const store = tx.objectStore("services");

			// Almost full scan shouldn't be too expensive, how many services are we aware of?
			const cursor = store.openCursor(IDBKeyRange.bound([account], [account, []]));
			const result = [];
			cursor.onsuccess = (event) => {
				if (event.target.result) {
					const value = event.target.result.value;
					result.push(new Promise((resolve) => this.getCaps(value.caps, (caps) => resolve({ ...value, caps: caps }))));
					event.target.result.continue();
				} else {
					Promise.all(result).then((items) => items.filter((item) => item.caps && item.caps.features.includes(feature))).then(callback);
				}
			}
			cursor.onerror = (event) => {
				console.error(event);
				callback([]);
			}
		},

		get(k, callback) {
			const tx = db.transaction(["keyvaluepairs"], "readonly");
			const store = tx.objectStore("keyvaluepairs");
			promisifyRequest(store.get(k)).then(callback);
		},

		set(k, v, callback) {
			const tx = db.transaction(["keyvaluepairs"], "readwrite");
			const store = tx.objectStore("keyvaluepairs");
			promisifyRequest(store.put(v, k)).then(callback);
		}
	};

	media.setKV(obj);
	return obj;
};
