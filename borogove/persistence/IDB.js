// This example persistence driver is written in JavaScript
// so that SDK users can easily see how to write their own

import { borogove as enums } from "./borogove-enums.js";
import { borogove } from "./borogove.js";

export default async (dbname, media, tokenize, stemmer) => {
	if (!tokenize) tokenize = function(s) { return s.split(" "); }
	if (!stemmer) stemmer = function(s) { return s; }

	// Helper functions to convert binary data to storage-safe strings
	// Uint8Array.to/fromBase64() is not yet widely available
	function arrayBufferToBase64 (ab) {
		return btoa((new Uint8Array(ab)).reduce((data, byte) => data + String.fromCharCode(byte), ''));
	}

	function base64ToArrayBuffer (b64) {
		const binary_string = atob(b64);
		const len = binary_string.length;
		const bytes = new Uint8Array(len);

		for (let i = 0; i < len; i++) {
			bytes[i] = binary_string.charCodeAt(i);
		}
		return bytes.buffer;
	}

	function openDb(version) {
		return new Promise((resolve, reject) => {
			var dbOpenReq = indexedDB.open(dbname, version);
			dbOpenReq.onerror = console.error;
			dbOpenReq.onupgradeneeded = (event) => {
				const db = event.target.result;
				if (!db.objectStoreNames.contains("messages")) {
					const messages = db.createObjectStore("messages", { keyPath: ["account", "serverId", "serverIdBy", "localId"] });
					messages.createIndex("chats", ["account", "chatId", "timestamp"]);
					messages.createIndex("localId", ["account", "localId", "chatId"]);
					messages.createIndex("accounts", ["account", "timestamp"]);
				}
				if (!db.objectStoreNames.contains("keyvaluepairs")) {
					db.createObjectStore("keyvaluepairs");
				}
				if (!db.objectStoreNames.contains("chats")) {
					db.createObjectStore("chats", { keyPath: ["account", "chatId"] });
				}
				if (!db.objectStoreNames.contains("services")) {
					db.createObjectStore("services", { keyPath: ["account", "serviceId"] });
				}
				if (!db.objectStoreNames.contains("reactions")) {
					const reactions = db.createObjectStore("reactions", { keyPath: ["account", "chatId", "senderId", "updateId"] });
					reactions.createIndex("senders", ["account", "chatId", "messageId", "senderId", "timestamp"]);
				}
				if (!db.objectStoreNames.contains("omemo_identities")) {
					db.createObjectStore("omemo_identities", { keyPath: ["account", "address"] });
				}
				if (!db.objectStoreNames.contains("omemo_prekeys")) {
					db.createObjectStore("omemo_prekeys", { keyPath: ["account", "keyId"] });
				}
				if (!db.objectStoreNames.contains("omemo_sessions")) {
					db.createObjectStore("omemo_sessions", { keyPath: ["account", "address"] });
				}
				if (!db.objectStoreNames.contains("omemo_sessions_meta")) {
					db.createObjectStore("omemo_sessions_meta", { keyPath: ["account", "address"] });
				}
			};
			dbOpenReq.onsuccess = (event) => {
				const db = event.target.result;
				const storeNames = [
					"messages",
					"keyvaluepairs",
					"chats",
					"services",
					"reactions",
					"omemo_identities",
					"omemo_sessions",
					"omemo_sessions_meta"
				];
				for(let storeName of storeNames) {
					if(!db.objectStoreNames.contains(storeName)) {
						db.close();
						openDb(db.version + 1).then(resolve, reject);
						return;
					}
				}
				resolve(db);
			};
		});
	}
	const db = await openDb();

	function promisifyRequest(request) {
		return new Promise((resolve, reject) => {
			request.oncomplete = request.onsuccess = () => resolve(request.result);
			request.onabort = request.onerror = () => reject(request.error);
		});
	}

	function hydrateStringReaction(r, senderId, timestamp) {
		if (r.startsWith("ni://")){
			return new borogove.CustomEmojiReaction(senderId, timestamp, "", r);
		} else {
			return new borogove.Reaction(senderId, timestamp, r);
		}
	}

	function hydrateObjectReaction(r) {
		if (r.uri) {
			return new borogove.CustomEmojiReaction(r.senderId, r.timestamp, r.text, r.uri, r.envelopeId);
		} else {
			return new borogove.Reaction(r.senderId, r.timestamp, r.text, r.envelopeId, r.key);
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

		const message = new borogove.ChatMessageBuilder();
		message.localId = value.localId ? value.localId : null;
		message.serverId = value.serverId ? value.serverId : null;
		message.serverIdBy = value.serverIdBy ? value.serverIdBy : null;
		message.replyId = value.replyId ? value.replyId : null;
		message.syncPoint = !!value.syncPoint;
		message.direction = value.direction;
		message.status = value.status;
		message.timestamp = value.timestamp && value.timestamp.toISOString();
		message.from = value.from && borogove.JID.parse(value.from);
		message.sender = value.sender && borogove.JID.parse(value.sender);
		message.senderId = value.senderId;
		message.recipients = value.recipients.map((r) => borogove.JID.parse(r));
		message.to = value.to ? borogove.JID.parse(value.to) : message.recipients[0];
		message.replyTo = value.replyTo.map((r) => borogove.JID.parse(r));
		message.threadId = value.threadId;
		message.attachments = value.attachments;
		message.reactions = hydrateReactions(value.reactions, message.timestamp);
		message.text = value.text;
		message.lang = value.lang;
		message.type = value.type || (value.isGroupchat || value.groupchat ? enums.MessageType.Channel : enums.MessageType.Chat);
		message.payloads = (value.payloads || []).map(borogove.Stanza.parse);
		message.stanza = value.stanza && borogove.Stanza.parse(value.stanza);
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
		const newVersions = message.versions.length < 1 ? [message] : message.versions;
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
		lastId: async function(account, jid) {
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
			while (true) {
				const result = await promisifyRequest(cursor);
				if (!result || (result.value.syncPoint && result.value.serverId && (jid || result.value.serverIdBy === account))) {
					return result ? result.value.serverId : null;
				} else {
					result.continue();
				}
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
				class: chat instanceof borogove.DirectChat ? "DirectChat" : (chat instanceof borogove.Channel ? "Channel" : "Chat")
				});
			}
		},

		getChats: async function(account) {
			const tx = db.transaction(["chats"], "readonly");
			const store = tx.objectStore("chats");
			const range = IDBKeyRange.bound([account], [account, []]);
			const result = await promisifyRequest(store.getAll(range));
			return await Promise.all(result.map(async (r) => new borogove.SerializedChat(
				r.chatId,
				r.trusted,
				r.avatarSha1,
				new Map(await Promise.all((r.presence instanceof Map ? [...r.presence.entries()] : Object.entries(r.presence)).map(
					async ([k, p]) => [k, new borogove.Presence(p.caps && await this.getCaps(p.caps), p.mucUser && borogove.Stanza.parse(p.mucUser))]
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
				r.disco ? new borogove.Caps(r.disco.node, r.disco.identities, r.disco.features) : null,
            r.omemoDevices || [],
				r.class
			)));
		},

		getChatsUnreadDetails: async function(account, chatsArray) {
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
			while (true) {
				const cresult = await promisifyRequest(cursor);
				if (cresult && rowCount < 40000) {
					rowCount++;
					const value = cresult.value;
					if (chats[value.chatId]) {
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
					}
					cresult.continue();
				} else {
					return await Promise.all(Object.values(result));
				}
			}
		},

		getMessage: async function(account, chatId, serverId, localId) {
			const tx = db.transaction(["messages"], "readonly");
			const store = tx.objectStore("messages");
			let result;
			if (serverId) {
				result = await promisifyRequest(store.openCursor(IDBKeyRange.bound([account, serverId], [account, serverId, []])));
			} else {
				result = await promisifyRequest(store.index("localId").openCursor(IDBKeyRange.only([account, localId, chatId])));
			}
			if (!result || !result.value) return null;
			const message = result.value;
			return await hydrateMessage(message);
		},

		storeReaction: async function(account, update) {
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
		},

		storeMessages(account, messages, callback) {
			return Promise.all(messages.map(m =>
				new Promise(resolve => this.storeMessage(account, m, resolve))
			));
		},

		storeMessage: function(account, message, callback) {
			if (!message.chatId()) throw "Cannot store a message with no chatId";
			if (!message.serverId && !message.localId) throw "Cannot store a message with no id";
			if (!message.serverId && message.isIncoming()) throw "Cannot store an incoming message with no server id";
			if (message.serverId && !message.serverIdBy) throw "Cannot store a message with a server id and no by";

			(
				// Hydrate reply stubs
				message.replyToMessage && !message.replyToMessage.serverIdBy ? this.getMessage(account, message.chatId(), message.replyToMessage.serverId, message.replyToMessage.localId) : Promise.resolve(message.replyToMessage)
			).then((replyToMessage) => {
				message.replyToMessage = replyToMessage;
				const tx = db.transaction(["messages", "reactions"], "readwrite");
				const store = tx.objectStore("messages");
				return Promise.all([
					promisifyRequest(store.index("localId").openCursor(IDBKeyRange.only([account, message.localId || [], message.chatId()]))),
					promisifyRequest(tx.objectStore("reactions").openCursor(IDBKeyRange.only([account, message.chatId(), message.senderId, message.localId || ""])))
				]).then(([result, reactionResult]) => {
					if (reactionResult?.value?.append && message.html().trim() == "") {
						this.getMessage(account, message.chatId(), reactionResult.value.serverId, reactionResult.value.localId).then((reactToMessage) => {
							const previouslyAppended = hydrateReactionsArray(reactionResult.value.append, reactionResult.value.senderId, reactionResult.value.timestamp).map(r => r.key);
							const reactions = [];
							for (const [k, reacts] of reactToMessage?.reactions || []) {
								for (const react of reacts) {
									if (react.senderId === message.senderId && !previouslyAppended.includes(k)) reactions.push(react);
								}
							}
							this.storeReaction(account, new borogove.ReactionUpdate(message.localId, reactionResult.value.serverId, reactionResult.value.serverIdBy, reactionResult.value.localId, message.chatId(), message.senderId, message.timestamp, reactions, enums.ReactionUpdateKind.CompleteReactions), callback);
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

		updateMessageStatus: async function(account, localId, status) {
			const tx = db.transaction(["messages"], "readwrite");
			const store = tx.objectStore("messages");
			const result = await promisifyRequest(store.index("localId").openCursor(IDBKeyRange.bound([account, localId], [account, localId, []])));
			if (result?.value && result.value.direction === enums.MessageDirection.MessageSent && result.value.status !== enums.MessageStatus.MessageDeliveredToDevice) {
				const newStatus = { ...result.value, status: status };
				result.update(newStatus);
				return await hydrateMessage(newStatus);
			}
			throw "Message not found: " + localId;
		},

		getMessagesBefore: async function(account, chatId, beforeId, beforeTime) {
			// TODO: if beforeId is present but beforeTime is null, lookup time
			const bound = beforeTime ? new Date(beforeTime) : [];
			const tx = db.transaction(["messages"], "readonly");
			const store = tx.objectStore("messages");
			const cursor = store.index("chats").openCursor(
				IDBKeyRange.bound([account, chatId], [account, chatId, bound]),
				"prev"
			);
			const messages = await this.getMessagesFromCursor(cursor, beforeId, bound);
			return messages.reverse();
		},

		getMessagesAfter: async function(account, chatId, afterId, afterTime) {
			// TODO: if afterId is present but afterTime is null, lookup time
			const bound = afterTime ? [new Date(afterTime)] : [];
			const tx = db.transaction(["messages"], "readonly");
			const store = tx.objectStore("messages");
			const cursor = store.index("chats").openCursor(
				IDBKeyRange.bound([account, chatId].concat(bound), [account, chatId, []]),
				"next"
			);
			return this.getMessagesFromCursor(cursor, afterId, bound[0]);
		},

		getMessagesAround: async function(account, chatId, id, timeArg) {
			if (!id && !timeArg) throw "Around what?";

			const time = await (
				timeArg ? Promise.resolve(timeArg) :
					this.getMessage(account, chatId, id, null).then((m) =>
						m ? m.timestamp : this.getMessage(account, chatId, null, id).then((m2) => m2?.timestamp)
					)
			);
			if (!time) return [];

			const before = this.getMessagesBefore(account, chatId, id, time);
			const tx = db.transaction(["messages"], "readonly");
			const store = tx.objectStore("messages");
			const cursor = store.index("chats").openCursor(
				IDBKeyRange.bound([account, chatId, new Date(time)], [account, chatId, []]),
				"next"
			);
			const aroundAndAfter = this.getMessagesFromCursor(cursor, null, null);

			return Promise.all([before, aroundAndAfter]).then(result => result.flat());
		},

		getMessagesFromCursor: async function(cursor, id, bound) {
			const result = [];
			while (true) {
				const cresult = await promisifyRequest(cursor);
				if (cresult && result.length < 50) {
					const value = cresult.value;
					if (value.serverId === id || value.localId === id || (value.timestamp && value.timestamp.getTime() === (bound instanceof Date && bound.getTime()))) {
						cresult.continue();
						continue;
					}

					result.push(hydrateMessage(value));
					cresult.continue();
				} else {
					return await Promise.all(result);
				}
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

		hasMedia: function(hashAlgorithm, hash) {
			return media.hasMedia(hashAlgorithm, hash);
		},

		removeMedia: function(hashAlgorithm, hash) {
			media.removeMedia(hashAlgorithm, hash);
		},

		storeMedia: function(mime, buffer) {
			return media.storeMedia(mime, buffer);
		},

		storeCaps: function(caps) {
			const tx = db.transaction(["keyvaluepairs"], "readwrite");
			const store = tx.objectStore("keyvaluepairs");
			store.put(caps, "caps:" + caps.ver()).onerror = console.error;
		},

		getCaps: async function(ver) {
			const tx = db.transaction(["keyvaluepairs"], "readonly");
			const store = tx.objectStore("keyvaluepairs");
			const raw = await promisifyRequest(store.get("caps:" + ver));
			if (raw) {
				return new borogove.Caps(raw.node, raw.identities.map((identity) => new borogove.Identity(identity.category, identity.type, identity.name)), raw.features);
			}

			return null;
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

		storeOmemoId: function(account, omemoId) {
			const tx = db.transaction(["keyvaluepairs"], "readwrite");
			const store = tx.objectStore("keyvaluepairs");
			store.put(omemoId, "omemo:id:" + account).onerror = console.error;
		},

		storeOmemoIdentityKey: function (account, keypair) {
			const tx = db.transaction(["keyvaluepairs"], "readwrite");
			const store = tx.objectStore("keyvaluepairs");
			store.put(keypair, "omemo:key:" + account).onerror = console.error;
		},

		storeOmemoDeviceList: function (chatId, deviceIds) {
			const tx = db.transaction(["keyvaluepairs"], "readwrite");
			const store = tx.objectStore("keyvaluepairs");
			const key = "omemo:devices:"+chatId;
			if(deviceIds.length>0) {
				store.put(deviceIds, key);
			} else {
				store.delete(key);
			}
		},

		getOmemoDeviceList: function (chatId, callback) {
			const tx = db.transaction(["keyvaluepairs"], "readonly");
			const store = tx.objectStore("keyvaluepairs");
			promisifyRequest(store.get("omemo:devices:"+chatId)).then((result) => {
				if (result === undefined) {
					callback([]);
				} else {
					callback(result);
				}
			}).catch((e) => {
				console.error(e);
				callback([]);
			});
		},

		storeOmemoPreKey: function (account, keyId, keyPair) {
			const tx = db.transaction(["keyvaluepairs"], "readwrite");
			const store = tx.objectStore("keyvaluepairs");
			const storedKeyPair = {
				"privKey": arrayBufferToBase64(keyPair.privKey),
				"pubKey": arrayBufferToBase64(keyPair.pubKey),
			};
			store.put(storedKeyPair, "omemo:prekeys:"+account+":"+keyId.toString());
		},

		removeOmemoPreKey: function (account, keyId) {
			const tx = db.transaction(["keyvaluepairs"], "readwrite");
			const store = tx.objectStore("keyvaluepairs");
			const keyName = "omemo:prekeys:"+account+":"+keyId.toString();
			store.delete(keyName);
		},

		getOmemoPreKey: function (account, keyId, callback) {
			const tx = db.transaction(["keyvaluepairs"], "readonly");
			const store = tx.objectStore("keyvaluepairs");
			promisifyRequest(store.get("omemo:prekeys:"+account+":"+keyId.toString())).then((result) => {
				if(result === undefined) {
					callback(null);
				} else {
					callback({
						"privKey": base64ToArrayBuffer(result.privKey),
						"pubKey": base64ToArrayBuffer(result.pubKey),
					});
				}
			}).catch((e) => {
				console.error(e);
				callback(null);
			});
		},

		getOmemoPreKeys: function (account, callback) {
			const tx = db.transaction(["keyvaluepairs"], "readonly");
			const store = tx.objectStore("keyvaluepairs");
			const prefix = "omemo:prekeys:"+account+":";
			const keyRange = IDBKeyRange.bound(prefix, prefix + '\uffff');

			const prekeys = [];
			const req = store.openCursor(keyRange);

			req.onsuccess = (event) => {
				const cursor = event.target.result;
				if(cursor) {
					const splitDbKey = cursor.key.split(":");
					const keyId = parseInt(splitDbKey[splitDbKey.length - 1], 10);
					prekeys.push({
						keyId: keyId,
						keyPair: {
							"privKey": base64ToArrayBuffer(cursor.value.privKey),
							"pubKey": base64ToArrayBuffer(cursor.value.pubKey),
						},
					});
					cursor.continue();
				} else {
					callback(prekeys);
				}
			}

			req.onerror = (e) => {
				console.error(e);
				callback(null);
			};
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

		async getStreamManagement(account) {
			const tx = db.transaction(["keyvaluepairs"], "readonly");
			const store = tx.objectStore("keyvaluepairs");
			const v = await promisifyRequest(store.get("sm:" + account));
			if (v instanceof ArrayBuffer) {
				return v;
			} else if(!v) {
				return null;
			} else {
				return new Blob([JSON.stringify(v)], {type: "text/plain; charset=utf-8"}).arrayBuffer();
			}
		},

		getLogin: function(login, callback) {
			const tx = db.transaction(["keyvaluepairs"], "readwrite");
			const store = tx.objectStore("keyvaluepairs");
			return Promise.all([
				promisifyRequest(store.get("login:clientId:" + login)),
				promisifyRequest(store.get("login:token:" + login)),
				promisifyRequest(store.get("login:fastCount:" + login)),
				promisifyRequest(store.get("fn:" + login)),
			]).then((result) => {
				if (result[1]) {
					store.put((result[2] || 0) + 1, "login:fastCount:" + login).onerror = console.error;
				}
				return { clientId: result[0], token: result[1], fastCount: result[2] || 0, displayName: result[3] };
			});
		},

		getOmemoId: function(account, callback) {
			const tx = db.transaction(["keyvaluepairs"], "readonly");
			const store = tx.objectStore("keyvaluepairs");
			promisifyRequest(store.get("omemo:id:"+account)).then((result) => {
				callback(result);
			}).catch((e) => {
				console.error(e);
				callback(null);
			});
		},

		getOmemoIdentityKey: function(account, callback) {
			const tx = db.transaction(["keyvaluepairs"], "readonly");
			const store = tx.objectStore("keyvaluepairs");
			promisifyRequest(store.get("omemo:key:"+account)).then((result) => {
				callback(result);
			}).catch((e) => {
				console.error(e);
				callback(null);
			});
		},

		getOmemoSignedPreKey: function(account, keyId, callback) {
			const tx = db.transaction(["keyvaluepairs"], "readonly");
			const store = tx.objectStore("keyvaluepairs");
			const dbKey = "omemo:signed-prekey:"+account+":"+keyId.toString();
			console.log("OMEMO: Fetching signed prekey " + dbKey);
			promisifyRequest(store.get(dbKey)).then((result) => {
				if(!result) {
					callback(null);
				} else {
					console.log("OMEMO: Loaded signed prekey " + dbKey);
					callback({
						keyId: keyId,
						keyPair: {
							privKey: base64ToArrayBuffer(result.privKey),
							pubKey: base64ToArrayBuffer(result.pubKey),
						},
						signature: base64ToArrayBuffer(result.signature),
					});
				}
			}).catch((e) => {
				console.error("OMEMO: Error loading signed prekey " + dbKey, e);
				callback(null);
			});
		},

		storeOmemoSignedPreKey: function (account, signedKey) {
			const tx = db.transaction(["keyvaluepairs"], "readwrite");
			const store = tx.objectStore("keyvaluepairs");
			const dbKey = "omemo:signed-prekey:"+account+":"+signedKey.keyId.toString();
			console.log("OMEMO: Storing signed prekey", dbKey);
			const storedKey = {
				privKey: arrayBufferToBase64(signedKey.keyPair.privKey),
				pubKey: arrayBufferToBase64(signedKey.keyPair.pubKey),
				signature: arrayBufferToBase64(signedKey.signature),
			};
			store.put(storedKey, dbKey);
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

		async listAccounts() {
			const tx = db.transaction(["keyvaluepairs"], "readonly");
			const store = tx.objectStore("keyvaluepairs");
			const keys = await promisifyRequest(store.getAllKeys(IDBKeyRange.bound("login:clientId:", "login:clientId:\uffff")));
			return keys.map(k => k.substring(15));
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

		async findServicesWithFeature(account, feature) {
			const tx = db.transaction(["services"], "readonly");
			const store = tx.objectStore("services");

			// Almost full scan shouldn't be too expensive, how many services are we aware of?
			const cursor = store.openCursor(IDBKeyRange.bound([account], [account, []]));
			const result = [];
			while (true) {
				const cresult = await promisifyRequest(cursor);
				if (cresult) {
					const value = cresult.value;
					result.push(this.getCaps(value.caps).then((caps) => ({ ...value, caps: caps })));
					cresult.continue();
				} else {
					return await Promise.all(result).then((items) => items.filter((item) => item.caps && item.caps.features.includes(feature)));
				}
			}
		},

		// Return the IdentityKey stored for the given address
		// Opposite of storeOmemoContactIdentityKey()
		getOmemoContactIdentityKey: function (account, address, callback) {
			const tx = db.transaction(["omemo_identities"], "readonly");
			const store = tx.objectStore("omemo_identities");
			promisifyRequest(store.get([account, address])).then((result) => {
				if(!result) {
					callback(undefined);
				} else {
					callback(base64ToArrayBuffer(result.pubKey));
				}
			}).catch((e) => {
				console.error(e);
				callback(undefined);
			});
		},

		storeOmemoContactIdentityKey: function (account, address, identityKey) {
			const tx = db.transaction(["omemo_identities"], "readwrite");
			const store = tx.objectStore("omemo_identities");
			promisifyRequest(store.put({
				account: account,
				address: address,
				pubKey: arrayBufferToBase64(identityKey),
			})).catch((e) => {
				console.error("Failed to store contact identity key: " + e);
			});
		},

		getOmemoSession: function (account, address, callback) {
			const tx = db.transaction(["omemo_sessions"], "readonly");
			const store = tx.objectStore("omemo_sessions");
			promisifyRequest(store.get([account, address])).then((result) => {
				if(!result) {
					callback(undefined);
				} else {
					callback(result.session);
				}
			}).catch((e) => {
				console.error("Failed to load OMEMO session: " + e);
			});
		},

		storeOmemoSession: function (account, address, session) {
			const tx = db.transaction(["omemo_sessions"], "readwrite");
			const store = tx.objectStore("omemo_sessions");
			promisifyRequest(store.put({
				account: account,
				address: address,
				session: session,
			})).catch((e) => {
				console.error("Failed to store OMEMO session: " + e);
			});
		},

		storeOmemoMetadata: function (account, address, metadata) {
			const tx = db.transaction(["omemo_sessions_meta"], "readwrite");
			const store = tx.objectStore("omemo_sessions_meta");
			promisifyRequest(store.put({
				account: account,
				address: address,
				metadata: metadata,
			})).catch((e) => {
				console.error("Failed to store OMEMO session metadata: " + e);
			});
		},

		getOmemoMetadata: function (account, address, callback) {
			const tx = db.transaction(["omemo_sessions_meta"], "readonly");
			const store = tx.objectStore("omemo_sessions_meta");
			promisifyRequest(store.get([account, address])).then((result) => {
				if(!result) {
					callback(undefined);
				} else {
					callback(result.metadata);
				}
			}).catch((e) => {
				console.error("Failed to load OMEMO session: " + e);
			});
		},

		removeOmemoSession: function (account, address) {
			// Remove session and any stored metadata
			const tx = db.transaction(["omemo_sessions", "omemo_sessions_meta"], "readwrite");
			const path = [account, address];
			tx.objectStore("omemo_sessions").delete(path);
			tx.objectStore("omemo_sessions_meta").delete(path);
		},

		get(k) {
			const tx = db.transaction(["keyvaluepairs"], "readonly");
			const store = tx.objectStore("keyvaluepairs");
			return promisifyRequest(store.get(k));
		},

		set(k, v) {
			const tx = db.transaction(["keyvaluepairs"], "readwrite");
			const store = tx.objectStore("keyvaluepairs");
			return promisifyRequest(store.put(v, k));
		}
	};

	media.setKV(obj);
	return obj;
};
