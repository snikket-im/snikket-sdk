// This example persistence driver is written in JavaScript
// so that SDK users can easily see how to write their own

exports.xmpp.persistence = {
	browser: (dbname) => {
		var db = null;
		var dbOpenReq = indexedDB.open(dbname, 1);
		dbOpenReq.onerror = console.error;
		dbOpenReq.onupgradeneeded = (event) => {
			const upgradeDb = event.target.result;
			const store = upgradeDb.createObjectStore("messages", { keyPath: "serverId" });
			store.createIndex("account", ["account", "timestamp"]);
			store.createIndex("conversation", ["account", "conversation", "timestamp"]);
		};
		dbOpenReq.onsuccess = (event) => {
			db = event.target.result;
		};

		return {
			lastId: function(account, jid, callback) {
				const tx = db.transaction(["messages"], "readonly");
				const store = tx.objectStore("messages");
				var cursor = null;
				if (jid === null) {
					cursor = store.index("account").openCursor(
					IDBKeyRange.bound([account, new Date(0)], [account, new Date("9999-01-01")]),
					"prev"
					);
				} else {
					cursor = store.index("conversation").openCursor(
					IDBKeyRange.bound([account, jid, new Date(0)], [account, jid, new Date("9999-01-01")]),
					"prev"
					);
				}
				cursor.onsuccess = (event) => {
					callback(event.target.result ? event.target.result.value.serverId : null);
				}
				cursor.onerror = (event) => {
					console.error(event);
					callback(null);
				}
			},

			storeMessage: function(account, message) {
				const tx = db.transaction(["messages"], "readwrite");
				const store = tx.objectStore("messages");
				store.put({
					...message,
					account: account,
					conversation: message.conversation(),
					timestamp: new Date(message.timestamp),
					direction: message.direction.toString()
				});
			},

			getMessages: function(account, conversation, _beforeId, beforeTime, callback) {
				const beforeDate = beforeTime ? new Date(beforeTime) : new Date("9999-01-01");
				const tx = db.transaction(["messages"], "readonly");
				const store = tx.objectStore("messages");
				const cursor = store.index("conversation").openCursor(
					IDBKeyRange.bound([account, conversation, new Date(0)], [account, conversation, beforeDate]),
					"prev"
				);
				const result = [];
				cursor.onsuccess = (event) => {
					if (event.target.result && result.length < 50) {
						const value = event.target.result.value;
						if (value.timestamp && value.timestamp.getTime() === beforeDate.getTime()) {
							event.target.result.continue();
							return;
						}

						const message = new xmpp.ChatMessage();
						message.localId = value.localId;
						message.serverId = value.serverId;
						message.timestamp = value.timestamp && value.timestamp.toISOString();
						message.to = value.to;
						message.from = value.from;
						message.threadId = value.threadId;
						message.replyTo = value.replyTo;
						message.attachments = value.attachments;
						message.text = value.text;
						message.direction = value.direction == "MessageReceived" ? xmpp.MessageDirection.MessageReceived : xmpp.MessageDirection.MessageSent;
						result.push(message);
						event.target.result.continue();
					} else {
						callback(result.reverse());
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
