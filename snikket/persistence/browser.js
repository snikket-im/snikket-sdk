// This example persistence driver is written in JavaScript
// so that SDK users can easily see how to write their own

exports.xmpp.persistence = {
	browser: (dbname) => {
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
				if (!db.objectStoreNames.contains("messages") || !db.objectStoreNames.contains("keyvaluepairs") || !db.objectStoreNames.contains("chats") || !db.objectStoreNames.contains("services") || !db.objectStoreNames.contains("reactions")) {
					db.close();
					openDb(db.version + 1);
					return;
				}
			};
		}
		openDb();

		var cache = null;
		caches.open(dbname).then((c) => cache = c);

		function mkNiUrl(hashAlgorithm, hashBytes) {
			const b64url = btoa(Array.from(new Uint8Array(hashBytes), (x) => String.fromCodePoint(x)).join("")).replace(/\+/, "-").replace(/\//, "_").replace(/=/, "");
			return "/.well-known/ni/" + hashAlgorithm + "/" + b64url;
		}

		function promisifyRequest(request) {
			return new Promise((resolve, reject) => {
				request.oncomplete = request.onsuccess = () => resolve(request.result);
				request.onabort = request.onerror = () => reject(request.error);
			});
		}

		async function hydrateMessage(value) {
			if (!value) return null;

			const tx = db.transaction(["messages"], "readonly");
			const store = tx.objectStore("messages");
			let replyToMessage = value.replyToMessage && await hydrateMessage((await promisifyRequest(store.openCursor(IDBKeyRange.only(value.replyToMessage))))?.value);

			const message = new xmpp.ChatMessage();
			message.localId = value.localId ? value.localId : null;
			message.serverId = value.serverId ? value.serverId : null;
			message.serverIdBy = value.serverIdBy ? value.serverIdBy : null;
			message.syncPoint = !!value.syncPoint;
			message.timestamp = value.timestamp && value.timestamp.toISOString();
			message.to = value.to && xmpp.JID.parse(value.to);
			message.from = value.from && xmpp.JID.parse(value.from);
			message.sender = value.sender && xmpp.JID.parse(value.sender);
			message.recipients = value.recipients.map((r) => xmpp.JID.parse(r));
			message.replyTo = value.replyTo.map((r) => xmpp.JID.parse(r));
			message.replyToMessage = replyToMessage;
			message.threadId = value.threadId;
			message.attachments = value.attachments;
			message.reactions = value.reactions;
			message.text = value.text;
			message.lang = value.lang;
			message.isGroupchat = value.isGroupchat || value.groupchat;
			message.direction = value.direction == "MessageReceived" ? xmpp.MessageDirection.MessageReceived : xmpp.MessageDirection.MessageSent;
			switch (value.status) {
				case "MessagePending":
					message.status = xmpp.MessageStatus.MessagePending;
					break;
				case "MessageDeliveredToServer":
					message.status = xmpp.MessageStatus.MessageDeliveredToServer;
					break;
				case "MessageDeliveredToDevice":
					message.status = xmpp.MessageStatus.MessageDeliveredToDevice;
					break;
				case "MessageFailedToSend":
					message.status = xmpp.MessageStatus.MessageFailedToSend;
					break;
				default:
					message.status = message.serverId ? xmpp.MessageStatus.MessageDeliveredToServer : xmpp.MessageStatus.MessagePending;
			}
			message.versions = await Promise.all((value.versions || []).map(hydrateMessage));
			message.payloads = (value.payloads || []).map(xmpp.Stanza.parse);
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
				sender: message.sender?.asString(),
				recipients: message.recipients.map((r) => r.asString()),
				replyTo: message.replyTo.map((r) => r.asString()),
				timestamp: new Date(message.timestamp),
				replyToMessage: message.replyToMessage && [account, message.replyToMessage.serverId || "", message.replyToMessage.serverIdBy || "", message.replyToMessage.localId || ""],
				direction: message.direction.toString(),
				status: message.status.toString(),
				versions: message.versions.map((m) => serializeMessage(account, m)),
				payloads: message.payloads.map((p) => p.toString()),
			}
		}

		function correctMessage(account, message, result) {
			// Newest (by timestamp) version wins for head
			const newVersions = message.versions.length < 1 ? [message] : message.versions;
			const storedVersions = result.value.versions || [];
			// TODO: dedupe? There shouldn't be dupes...
			const versions = (storedVersions.length < 1 ? [result.value] : storedVersions).concat(newVersions.map((nv) => serializeMessage(account, nv))).sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime());
			const head = {...versions[0]};
			// Can't change primary key
			head.serverIdBy = result.value.serverIdBy;
			head.serverId = result.value.serverId;
			head.localId = result.value.localId;
			head.timestamp = result.value.timestamp; // Edited version is not newer
			head.versions = versions;
			head.reactions = result.value.reactions; // Preserve these, edit doesn't touch them
			result.update(head);
			return head;
		}

		function setReactions(reactionsMap, sender, reactions) {
			for (const [reaction, senders] of reactionsMap) {
				if (!reactions.includes(reaction) && senders.includes(sender)) {
					if (senders.length === 1) {
						reactionsMap.delete(reaction);
					} else {
						reactionsMap.set(reaction, senders.filter((asender) => asender != sender));
					}
				}
			}
			for (const reaction of reactions) {
				reactionsMap.set(reaction, [...new Set([...reactionsMap.get(reaction) || [], sender])].sort());
			}
			return reactionsMap;
		}

		return {
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

			storeChat: function(account, chat) {
				const tx = db.transaction(["chats"], "readwrite");
				const store = tx.objectStore("chats");

				store.put({
					account: account,
					chatId: chat.chatId,
					trusted: chat.trusted,
					avatarSha1: chat.avatarSha1,
					presence: new Map([...chat.presence.entries()].map(([k, p]) => [k, { caps: p.caps?.ver(), mucUser: p.mucUser?.toString() }])),
					displayName: chat.displayName,
					uiState: chat.uiState?.toString(),
					extensions: chat.extensions?.toString(),
					disco: chat.disco,
					class: chat instanceof xmpp.DirectChat ? "DirectChat" : (chat instanceof xmpp.Channel ? "Channel" : "Chat")
				});
			},

			getChats: function(account, callback) {
				(async () => {
					const tx = db.transaction(["chats"], "readonly");
					const store = tx.objectStore("chats");
					const range = IDBKeyRange.bound([account], [account, []]);
					const result = await promisifyRequest(store.getAll(range));
					return await Promise.all(result.map(async (r) => new xmpp.SerializedChat(
						r.chatId,
						r.trusted,
						r.avatarSha1,
						new Map(await Promise.all((r.presence instanceof Map ? [...r.presence.entries()] : Object.entries(r.presence)).map(
							async ([k, p]) => [k, new xmpp.Presence(p.caps && await new Promise((resolve) => this.getCaps(p.caps, resolve)), p.mucUser && xmpp.Stanza.parse(p.mucUser))]
						))),
						r.displayName,
						r.uiState,
						r.extensions,
						r.disco,
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
							if (!result[value.chatId].foundAll) {
								const readUpTo = chats[value.chatId]?.readUpTo();
								if (readUpTo === value.serverId || readUpTo === value.localId || value.direction == "MessageSent") {
									result[value.chatId].foundAll = true;
								} else {
									result[value.chatId] = result[value.chatId].then((details) => { details.unreadCount++; return details; });
								}
							}
						} else {
							const readUpTo = chats[value.chatId]?.readUpTo();
							const haveRead = readUpTo === value.serverId || readUpTo === value.localId || value.direction == "MessageSent";
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
						result = await promisifyRequest(store.openCursor(IDBKeyRange.bound([account, update.serverId], [account, update.serverId, []])));
					} else {
						result = await promisifyRequest(store.index("localId").openCursor(IDBKeyRange.only([account, update.localId, update.chatId])));
					}
					await promisifyRequest(reactionStore.put({...update, messageId: update.serverId || update.localId, timestamp: new Date(update.timestamp), account: account}));
					if (!result || !result.value) {
						return null;
					}
					const message = result.value;
					const lastFromSender = promisifyRequest(reactionStore.index("senders").openCursor(IDBKeyRange.bound(
						[account, update.chatId, update.serverId || update.localId, update.senderId],
						[account, update.chatId, update.serverId || update.localId, update.senderId, []]
					), "prev"));
					if (lastFromSender?.value && lastFromSender.value.timestamp > new Date(update.timestamp)) return;
					setReactions(message.reactions, update.senderId, update.reactions);
					store.put(message);
					return await hydrateMessage(message);
				})().then(callback);
			},

			storeMessage: function(account, message, callback) {
				if (!message.chatId()) throw "Cannot store a message with no chatId";
				if (!message.serverId && !message.localId) throw "Cannot store a message with no id";
				if (!message.serverId && message.isIncoming()) throw "Cannot store an incoming message with no server id";
				if (message.serverId && !message.serverIdBy) throw "Cannot store a message with a server id and no by";
				new Promise((resolve) =>
					// Hydrate reply stubs
					message.replyToMessage && !message.replyToMessage.serverIdBy ? this.getMessage(account, message.chatId(), message.replyToMessage?.serverId, message.replyToMessage?.localId, resolve) : resolve(message.replyToMessage)
				).then((replyToMessage) => {
					message.replyToMessage = replyToMessage;
					const tx = db.transaction(["messages", "reactions"], "readwrite");
					const store = tx.objectStore("messages");
					return promisifyRequest(store.index("localId").openCursor(IDBKeyRange.only([account, message.localId || [], message.chatId()]))).then((result) => {
						if (result?.value && !message.isIncoming() && result?.value.direction === "MessageSent") {
							// Duplicate, we trust our own sent ids
							return promisifyRequest(result.delete());
						} else if (result?.value && result.value.sender == message.senderId() && (message.versions.length > 0 || (result.value.versions || []).length > 0)) {
							hydrateMessage(correctMessage(account, message, result)).then(callback);
							return true;
						}
					}).then((done) => {
						if (!done) {
							// There may be reactions already if we are paging backwards
							const cursor = tx.objectStore("reactions").index("senders").openCursor(IDBKeyRange.bound([account, message.chatId(), (message.isGroupchat ? message.serverId : message.localId) || ""], [account, message.chatId(), (message.isGroupchat ? message.serverId : message.localId) || "", []]), "prev");
							const reactions = new Map();
							const reactionTimes = new Map();
							cursor.onsuccess = (event) => {
								if (event.target.result && event.target.result.value) {
									const time = reactionTimes.get(event.target.result.senderId);
									if (!time || time < event.target.result.value.timestamp) {
										setReactions(reactions, event.target.result.value.senderId, event.target.result.value.reactions);
										reactionTimes.set(event.target.result.value.senderId, event.target.result.value.timestamp);
									}
									event.target.result.continue();
								} else {
									message.reactions = reactions;
									store.put(serializeMessage(account, message));
									callback(message);
								}
							};
							cursor.onerror = console.error;
						}
					});
				});
			},

			updateMessageStatus: function(account, localId, status, callback) {
				const tx = db.transaction(["messages"], "readwrite");
				const store = tx.objectStore("messages");
				promisifyRequest(store.index("localId").openCursor(IDBKeyRange.bound([account, localId], [account, localId, []]))).then((result) => {
					if (result?.value && result.value.direction === "MessageSent" && result.value.status !== "MessageDeliveredToDevice") {
						const newStatus = { ...result.value, status: status.toString() };
						result.update(newStatus);
						hydrateMessage(newStatus).then(callback);
					}
				});
			},

			getMessages: function(account, chatId, beforeId, beforeTime, callback) {
				const beforeDate = beforeTime ? new Date(beforeTime) : [];
				const tx = db.transaction(["messages"], "readonly");
				const store = tx.objectStore("messages");
				const cursor = store.index("chats").openCursor(
					IDBKeyRange.bound([account, chatId], [account, chatId, beforeDate]),
					"prev"
				);
				const result = [];
				cursor.onsuccess = (event) => {
					if (event.target.result && result.length < 50) {
						const value = event.target.result.value;
						if (value.serverId === beforeId || (value.timestamp && value.timestamp.getTime() === (beforeDate instanceof Date && beforeDate.getTime()))) {
							event.target.result.continue();
							return;
						}

						result.unshift(hydrateMessage(value));
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

			getMediaUri: function(hashAlgorithm, hash, callback) {
				(async function() {
					var niUrl;
					if (hashAlgorithm == "sha-256") {
						niUrl = mkNiUrl(hashAlgorithm, hash);
					} else {
						const tx = db.transaction(["keyvaluepairs"], "readonly");
						const store = tx.objectStore("keyvaluepairs");
						niUrl = await promisifyRequest(store.get(mkNiUrl(hashAlgorithm, hash)));
						if (!niUrl) {
							return null;
						}
					}

					const response = await cache.match(niUrl);
					if (response) {
						// NOTE: the application needs to call URL.revokeObjectURL on this when done
					  return URL.createObjectURL(await response.blob());
					}

					return null;
				})().then(callback);
			},

			storeMedia: function(mime, buffer, callback) {
				(async function() {
					const sha256 = await crypto.subtle.digest("SHA-256", buffer);
					const sha512 = await crypto.subtle.digest("SHA-512", buffer);
					const sha1 = await crypto.subtle.digest("SHA-1", buffer);
					const sha256NiUrl = mkNiUrl("sha-256", sha256);
					await cache.put(sha256NiUrl, new Response(buffer, { headers: { "Content-Type": mime } }));

					const tx = db.transaction(["keyvaluepairs"], "readwrite");
					const store = tx.objectStore("keyvaluepairs");
					await promisifyRequest(store.put(sha256NiUrl, mkNiUrl("sha-1", sha1)));
					await promisifyRequest(store.put(sha256NiUrl, mkNiUrl("sha-512", sha512)));
				})().then(callback);
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
						return (new xmpp.Caps(raw.node, raw.identities.map((identity) => new xmpp.Identity(identity.category, identity.type, identity.name)), raw.features));
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

			storeStreamManagement: function(account, id, outbound, inbound, outbound_q) {
				const tx = db.transaction(["keyvaluepairs"], "readwrite");
				const store = tx.objectStore("keyvaluepairs");
				store.put({ id: id, outbound: outbound, inbound: inbound, outbound_q }, "sm:" + account).onerror = console.error;
			},

			getStreamManagement: function(account, callback) {
				const tx = db.transaction(["keyvaluepairs"], "readonly");
				const store = tx.objectStore("keyvaluepairs");
				promisifyRequest(store.get("sm:" + account)).then(
					(v) => {
						callback(v?.id, v?.outbound, v?.inbound, v?.outbound_q || []);
					},
					(e) => {
						console.error(e);
						callback(null, -1, -1, []);
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
			}
		}
	}
};
