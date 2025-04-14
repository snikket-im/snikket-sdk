package snikket.persistence;

#if cpp
import HaxeCBridge;
#end
import haxe.DynamicAccess;
import haxe.Json;
import haxe.crypto.Base64;
import haxe.io.Bytes;
import haxe.io.BytesData;
import thenshim.Promise;
import snikket.Caps;
import snikket.Chat;
import snikket.Message;
import snikket.Reaction;
import snikket.ReactionUpdate;
using Lambda;

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class Sqlite implements Persistence implements KeyValueStore {
	final db: SqliteDriver;
	final media: MediaStore;

	/**
		Create a basic persistence layer based on sqlite

		@param dbfile path to sqlite database
		@params media a MediaStore to use for media
		@returns new persistence layer
	**/
	public function new(dbfile: String, media: MediaStore) {
		this.media = media;
		media.setKV(this);
		db = new SqliteDriver(dbfile);
		db.exec("PRAGMA user_version;").then(iter -> {
			final version = Std.parseInt(iter.next()?.user_version) ?? 0;
			return if (version < 1) {
				db.exec(["CREATE TABLE messages (
					account_id TEXT NOT NULL,
					mam_id TEXT NOT NULL,
					mam_by TEXT NOT NULL,
					stanza_id TEXT NOT NULL,
					correction_id TEXT NOT NULL,
					sync_point INTEGER NOT NULL,
					chat_id TEXT NOT NULL,
					sender_id TEXT NOT NULL,
					created_at INTEGER NOT NULL,
					status INTEGER NOT NULL,
					direction INTEGER NOT NULL,
					type INTEGER NOT NULL,
					stanza TEXT NOT NULL,
					PRIMARY KEY (account_id, mam_id, mam_by, stanza_id)
				) STRICT;",
				"CREATE INDEX messages_created_at ON messages (account_id, chat_id, created_at);",
				"CREATE INDEX messages_correction_id ON messages (correction_id);",
				"CREATE TABLE chats (
					account_id TEXT NOT NULL,
					chat_id TEXT NOT NULL,
					trusted INTEGER NOT NULL,
					avatar_sha1 BLOB,
					fn TEXT,
					ui_state INTEGER NOT NULL,
					blocked INTEGER NOT NULL,
					extensions TEXT,
					read_up_to_id TEXT,
					read_up_to_by TEXT,
					caps_ver BLOB,
					presence BLOB NOT NULL,
					class TEXT NOT NULL,
					PRIMARY KEY (account_id, chat_id)
				) STRICT;",
				"CREATE TABLE keyvaluepairs (
					k TEXT NOT NULL PRIMARY KEY,
					v TEXT NOT NULL
				) STRICT;",
				"CREATE TABLE caps (
					sha1 BLOB NOT NULL PRIMARY KEY,
					caps BLOB NOT NULL
				) STRICT;",
				"CREATE TABLE services (
					account_id TEXT NOT NULL,
					service_id TEXT NOT NULL,
					name TEXT,
					node TEXT,
					caps BLOB NOT NULL,
					PRIMARY KEY (account_id, service_id)
				) STRICT;",
				"CREATE TABLE accounts (
					account_id TEXT NOT NULL,
					client_id TEXT NOT NULL,
					display_name TEXT,
					token TEXT,
					fast_count INTEGER NOT NULL DEFAULT 0,
					sm_state BLOB,
					PRIMARY KEY (account_id)
				) STRICT;",
				"CREATE TABLE reactions (
					account_id TEXT NOT NULL,
					update_id TEXT NOT NULL,
					mam_id TEXT,
					mam_by TEXT,
					stanza_id TEXT,
					chat_id TEXT NOT NULL,
					sender_id TEXT NOT NULL,
					created_at INTEGER NOT NULL,
					reactions BLOB NOT NULL,
					kind INTEGER NOT NULL,
					PRIMARY KEY (account_id, chat_id, sender_id, update_id)
				) STRICT;",
				"PRAGMA user_version = 1;"]);
			} else if (version < 2) {
				db.exec(["ALTER TABLE chats ADD COLUMN notifications_filtered INTEGER;",
				"ALTER TABLE chats ADD COLUMN notify_mention INTEGER NOT NULL DEFAULT 0;",
				"ALTER TABLE chats ADD COLUMN notify_reply INTEGER NOT NULL DEFAULT 0;",
				"PRAGMA user_version = 2;"]);
			} else {
				Promise.resolve(null);
			}
		});
	}

	@HaxeCBridge.noemit
	public function get(k: String, callback: (Null<String>)->Void) {
		db.exec("SELECT v FROM keyvaluepairs WHERE k=? LIMIT 1", [k]).then(iter -> {
			for (row in iter) {
				callback(row.v);
				return;
			}
			callback(null);
		});
	}

	@HaxeCBridge.noemit
	public function set(k: String, v: Null<String>, callback: ()->Void) {
		if (v == null) {
			db.exec("DELETE FROM keyvaluepairs WHERE k=?", [k]).then(_ -> {
				callback();
			});
		} else {
			db.exec("INSERT OR REPLACE INTO keyvaluepairs VALUES (?,?)", [k, v]).then(_ -> {
				callback();
			});
		}
	}

	@HaxeCBridge.noemit
	public function lastId(accountId: String, chatId: Null<String>, callback:(Null<String>)->Void):Void {
		final params = [accountId];
		var q = "SELECT mam_id FROM messages WHERE mam_id IS NOT NULL AND sync_point AND account_id=?";
		if (chatId == null) {
			q += " AND mam_by=?";
			params.push(accountId);
		} else {
			q += " AND chat_id=?";
			params.push(chatId);
		}
		q += " ORDER BY ROWID DESC LIMIT 1";
		db.exec(q, params).then(iter -> callback(iter.next()?.mam_id), (_) -> callback(null));
	}

	private final storeChatBuffer: Map<String, Chat> = [];
	private var storeChatTimer = null;

	@HaxeCBridge.noemit
	public function storeChats(accountId: String, chats: Array<Chat>) {
		if (storeChatTimer != null) {
			storeChatTimer.stop();
		}

		for (chat in chats) {
			storeChatBuffer[accountId + "\n" + chat.chatId] = chat;
		}

		storeChatTimer = haxe.Timer.delay(() -> {
			final mapPresence = (chat: Chat) -> {
				final storePresence: DynamicAccess<{ ?caps: String, ?mucUser: String }> = {};
				for (resource => presence in chat.presence) {
					storePresence[resource] = {};
					if (presence.caps != null) {
						storeCaps(presence.caps);
						storePresence[resource].caps = presence.caps.ver();
					}
					if (presence.mucUser != null) {
						storePresence[resource].mucUser = presence.mucUser.toString();
					}
				}
				return storePresence;
			};
			final q = new StringBuf();
			q.add("INSERT OR REPLACE INTO chats VALUES ");
			var first = true;
			for (_ in storeChatBuffer) {
				if (!first) q.add(",");
				first = false;
				q.add("(?,?,?,?,?,?,?,?,?,?,?,jsonb(?),?,?,?,?)");
			}
			db.exec(
				q.toString(),
				storeChatBuffer.flatMap(chat -> {
					final channel = Std.downcast(chat, Channel);
					if (channel != null) storeCaps(channel.disco);
					final row: Array<Dynamic> = [
						accountId, chat.chatId, chat.isTrusted(), chat.avatarSha1,
						chat.getDisplayName(), chat.uiState, chat.isBlocked,
						chat.extensions.toString(), chat.readUpTo(), chat.readUpToBy,
						channel?.disco?.verRaw().hash, Json.stringify(mapPresence(chat)),
						Type.getClassName(Type.getClass(chat)).split(".").pop(),
						chat.notificationsFiltered(), chat.notifyMention(), chat.notifyReply()
					];
					return row;
				})
			);
			storeChatTimer = null;
			storeChatBuffer.clear();
		}, 100);
	}

	@HaxeCBridge.noemit
	public function getChats(accountId: String, callback: (Array<SerializedChat>)->Void) {
		db.exec(
			"SELECT chat_id, trusted, avatar_sha1, fn, ui_state, blocked, extensions, read_up_to_id, read_up_to_by, notifications_filtered, notify_mention, notify_reply, json(caps) AS caps, json(presence) AS presence, class FROM chats LEFT JOIN caps ON chats.caps_ver=caps.sha1 WHERE account_id=?",
			[accountId]
		).then(result -> {
			final fetchCaps: Map<BytesData, Bool> = [];
			final chats: Array<Dynamic> = [];
			for (row in result) {
				final capsJson = row.caps == null ? null : Json.parse(row.caps);
				row.capsObj = capsJson == null ? null : new Caps(capsJson.node, capsJson.identities.map(i -> new Identity(i.category, i.type, i.name)), capsJson.features);
				final presenceJson: DynamicAccess<Dynamic> = Json.parse(row.presence);
				row.presenceJson = presenceJson;
				for (resource => presence in presenceJson) {
					if (presence.caps) fetchCaps[Base64.decode(presence.caps).getData()] = true;
				}
				chats.push(row);
			}
			final fetchCapsSha1s = { iterator: () -> fetchCaps.keys() }.array();
			return db.exec(
				"SELECT sha1, json(caps) AS caps FROM caps WHERE sha1 IN (" + fetchCapsSha1s.map(_ -> "?").join(",") + ")",
				fetchCapsSha1s
			).then(capsResult -> { chats: chats, caps: capsResult });
		}).then(result -> {
			final capsMap: Map<String, Caps> = [];
			for (row in result.caps) {
				final json = Json.parse(row.caps);
				capsMap[Base64.encode(Bytes.ofData(row.sha1))] = new Caps(json.node, json.identities.map(i -> new Identity(i.category, i.type, i.name)), json.features);
			}
			final chats = [];
			for (row in result.chats) {
				final presenceMap: Map<String, Presence> = [];
				final presenceJson: DynamicAccess<Dynamic> = row.presenceJson;
				for (resource => presence in presenceJson) {
					presenceMap[resource] = new Presence(
						presence.caps == null ? null : capsMap[presence.caps],
						presence.mucUser == null ? null : Stanza.parse(presence.mucUser)
					);
				}
				chats.push(new SerializedChat(row.chat_id, row.trusted != 0, row.avatar_sha1, presenceMap, row.fn, row.ui_state, row.blocked != 0, row.extensions, row.read_up_to_id, row.read_up_to_by, row.notifications_filtered == null ? null : row.notifications_filtered != 0, row.notify_mention != 0, row.notify_reply != 0, row.capsObj, Reflect.field(row, "class")));
			}
			callback(chats);
		});
	}

	@HaxeCBridge.noemit
	public function storeMessages(accountId: String, messages: Array<ChatMessage>, callback: (Array<ChatMessage>)->Void) {
		if (messages.length < 1) {
			callback(messages);
			return;
		}

		final chatIds = [];
		final localIds = [];
		final replyTos = [];
		for (message in messages) {
			if (message.serverId == null && message.localId == null) throw "Cannot store a message with no id";
			if (message.serverId == null && message.isIncoming()) throw "Cannot store an incoming message with no server id";
			if (message.serverId != null && message.serverIdBy == null) throw "Cannot store a message with a server id and no by";

			if (!message.isIncoming() && message.versions.length < 1) {
				// Duplicate, we trust our own sent ids
				// Ideally this would be in a transaction with the insert, but then we can't use bind with async api
				chatIds.push(message.chatId());
				localIds.push(message.localId);
			}
			if (message.replyToMessage != null && message.replyToMessage.serverIdBy == null) {
				replyTos.push({ chatId: message.chatId(), serverId: message.replyToMessage.serverId, localId: message.replyToMessage.localId });
			}
		}

		(if (chatIds.length > 0 && localIds.length > 0) {
			final q = new StringBuf();
			q.add("DELETE FROM messages WHERE account_id=? AND direction=? AND chat_id IN (");
			q.add(chatIds.map(_ -> "?").join(","));
			q.add(") AND stanza_id IN (");
			q.add(localIds.map(_ -> "?").join(","));
			q.add(")");
			db.exec(q.toString(), ([accountId, MessageSent] : Array<Dynamic>).concat(chatIds).concat(localIds));
		} else {
			Promise.resolve(null);
		}).then(_ ->
			db.exec(
				"INSERT OR REPLACE INTO messages VALUES " + messages.map(_ -> "(?,?,?,?,?,?,?,?,CAST(unixepoch(?, 'subsec') * 1000 AS INTEGER),?,?,?,?)").join(","),
				messages.flatMap(m -> {
					final correctable = m;
					final message = m.versions.length == 1 ? m.versions[0] : m; // TODO: storing multiple versions at once? We never do that right now
					([
						accountId, message.serverId ?? "", message.serverIdBy ?? "",
						message.localId ?? "", correctable.localId ?? correctable.serverId, correctable.syncPoint,
						correctable.chatId(), correctable.senderId,
						message.timestamp, message.status, message.direction, message.type,
						message.asStanza().toString()
					] : Array<Dynamic>);
				})
			)
		).then(_ ->  {
			hydrateReplyTo(accountId, messages, replyTos).then(ms -> hydrateReactions(accountId, ms)).then(callback);
		});

		// TODO: retract custom emoji?
	}

	@HaxeCBridge.noemit
	public function updateMessage(accountId: String, message: ChatMessage) {
		storeMessages(accountId, [message], (_)->{});
	}

	public function getMessage(accountId: String, chatId: String, serverId: Null<String>, localId: Null<String>, callback: (Null<ChatMessage>)->Void) {
		var q = "SELECT stanza, direction, type, strftime('%FT%H:%M:%fZ', created_at / 1000.0, 'unixepoch') AS timestamp, sender_id, mam_id, mam_by, sync_point FROM messages WHERE account_id=? AND chat_id=?";
		final params = [accountId, chatId];
		if (serverId != null) {
			q += " AND mam_id=?";
			params.push(serverId);
		} else if (localId != null) {
			q += " AND stanza_id=?";
			params.push(localId);
		}
		q += "LIMIT 1";
		db.exec(q, params).then(result -> hydrateMessages(accountId, result)).then(messages -> {
			for (message in messages) {
				(if (message.replyToMessage != null) {
					hydrateReplyTo(accountId, [message], [{ chatId: chatId, serverId: message.replyToMessage.serverId, localId: message.replyToMessage.localId }]);
				} else {
					Promise.resolve([message]);
				}).then(messages -> hydrateReactions(accountId, messages)).then(hydrated -> callback(hydrated[0]));
				return;
			}
			callback(null);
		});
	}

	private function getMessages(accountId: String, chatId: String, time: Null<String>, op: String): Promise<Array<ChatMessage>> {
		var q = "SELECT
			correction_id AS stanza_id,
			versions.stanza,
			json_group_object(CASE WHEN versions.mam_id IS NULL OR versions.mam_id='' THEN versions.stanza_id ELSE versions.mam_id END, strftime('%FT%H:%M:%fZ', versions.created_at / 1000.0, 'unixepoch')) AS version_times,
			json_group_object(CASE WHEN versions.mam_id IS NULL OR versions.mam_id='' THEN versions.stanza_id ELSE versions.mam_id END, versions.stanza) AS versions,
			messages.direction,
			messages.type,
			strftime('%FT%H:%M:%fZ', messages.created_at / 1000.0, 'unixepoch') AS timestamp,
			messages.sender_id,
			messages.mam_id,
			messages.mam_by,
			messages.sync_point,
			MAX(versions.created_at)
			FROM messages INNER JOIN messages versions USING (correction_id) WHERE (messages.stanza_id IS NULL OR messages.stanza_id='' OR messages.stanza_id=correction_id) AND messages.account_id=? AND messages.chat_id=?";
		final params = [accountId, chatId];
		if (time != null) {
			q += " AND messages.created_at " + op + "CAST(unixepoch(?, 'subsec') * 1000 AS INTEGER)";
			params.push(time);
		}
		q += " GROUP BY correction_id ORDER BY messages.created_at";
		if (op == "<" || op == "<=") q += " DESC";
		q += ", messages.ROWID";
		if (op == "<" || op == "<=") q += " DESC";
		q += " LIMIT 50";
		return db.exec(q, params).then(result -> hydrateMessages(accountId, result)).then(iter -> {
			final arr = [];
			final replyTos = [];
			for (message in iter) {
				arr.push(message);
				if (message.replyToMessage != null && message.replyToMessage.serverIdBy == null) {
					replyTos.push({ chatId: message.chatId(), serverId: message.replyToMessage.serverId, localId: message.replyToMessage.localId });
				}
			}
			if (op == "<" || op == "<=") {
				arr.reverse();
			}
			return hydrateReplyTo(accountId, arr, replyTos);
		}).then(messages -> hydrateReactions(accountId, messages));
	}

	@HaxeCBridge.noemit
	public function getMessagesBefore(accountId: String, chatId: String, beforeId: Null<String>, beforeTime: Null<String>, callback: (Array<ChatMessage>)->Void) {
		getMessages(accountId, chatId, beforeTime, "<").then(callback);
	}

	@HaxeCBridge.noemit
	public function getMessagesAfter(accountId: String, chatId: String, afterId: Null<String>, afterTime: Null<String>, callback: (Array<ChatMessage>)->Void) {
		getMessages(accountId, chatId, afterTime, ">").then(callback);
	}

	@HaxeCBridge.noemit
	public function getMessagesAround(accountId: String, chatId: String, aroundId: Null<String>, aroundTime: Null<String>, callback: (Array<ChatMessage>)->Void) {
		(if (aroundTime == null) {
			new Promise((resolve, reject) -> getMessage(accountId, chatId, aroundId, null, resolve)).then(m ->
				if (m != null) {
					Promise.resolve(m.timestamp);
				} else {
					new Promise((resolve, reject) -> getMessage(accountId, chatId, null, aroundId, resolve)).then(m -> m?.timestamp);
				}
			);
		} else {
			Promise.resolve(aroundTime);
		}).then(aroundTime ->
			thenshim.PromiseTools.all([
				getMessages(accountId, chatId, aroundTime, "<"),
				getMessages(accountId, chatId, aroundTime, ">=")
			])
		).then(results ->
			callback(results.flatMap(arr -> arr))
		);
	}

	@HaxeCBridge.noemit
	public function getChatsUnreadDetails(accountId: String, chats: Array<Chat>, callback: (Array<{ chatId: String, message: ChatMessage, unreadCount: Int }>)->Void) {
		if (chats == null || chats.length < 1) {
			callback([]);
			return;
		}

		final params: Array<Dynamic> = [accountId]; // subq is first in final q, so subq params first

		final subq = new StringBuf();
		subq.add("SELECT chat_id, ROWID as row, MAX(created_at) AS created_at FROM messages WHERE account_id=?");
		subq.add(" AND chat_id IN (");
		for (i => chat in chats) {
			if (i != 0) subq.add(",");
			subq.add("?");
			params.push(chat.chatId);
		}
		subq.add(") AND (mam_id IN (");
		var didOne = false;
		for (chat in chats) {
			if (chat.readUpTo() != null) {
				if (didOne) subq.add(",");
				subq.add("?");
				params.push(chat.readUpTo());
				didOne = true;
			}
		}
		subq.add(") OR direction=?) GROUP BY chat_id");
		params.push(MessageSent);

		final q = new StringBuf();
		q.add("SELECT chat_id AS chatId, stanza, direction, type, sender_id, mam_id, mam_by, sync_point, CASE WHEN subq.created_at IS NULL THEN COUNT(*) ELSE COUNT(*) - 1 END AS unreadCount, strftime('%FT%H:%M:%fZ', MAX(messages.created_at) / 1000.0, 'unixepoch') AS timestamp FROM messages LEFT JOIN (");
		q.add(subq.toString());
		q.add(") subq USING (chat_id) WHERE account_id=? AND (stanza_id IS NULL OR stanza_id='' OR stanza_id=correction_id) AND chat_id IN (");
		params.push(accountId);
		for (i => chat in chats) {
			if (i != 0) q.add(",");
			q.add("?");
			params.push(chat.chatId);
		}
		q.add(") AND (subq.created_at IS NULL OR messages.created_at > subq.created_at OR (messages.created_at=subq.created_at AND messages.ROWID >= subq.row)) GROUP BY chat_id;");
		db.exec(q.toString(), params).then(result -> {
			final details = [];
			final rows: Array<Dynamic> = { iterator: () -> result }.array();
			Promise.resolve(hydrateMessages(accountId, rows.iterator())).then(messages -> {
				for (i => m in messages) {
					details.push({
						unreadCount: rows[i].unreadCount,
						chatId: rows[i].chatId,
						message: m
					});
				}
				callback(details);
			});
		});
	}

	@HaxeCBridge.noemit
	public function storeReaction(accountId: String, update: ReactionUpdate, callback: (Null<ChatMessage>)->Void) {
		db.exec(
			"INSERT OR REPLACE INTO reactions VALUES (?,?,?,?,?,?,?,CAST(unixepoch(?, 'subsec') * 1000 AS INTEGER),jsonb(?),?)",
			[
				accountId, update.updateId, update.serverId, update.serverIdBy,
				update.localId, update.chatId, update.senderId, update.timestamp,
				Json.stringify(update.reactions), update.kind
			]
		).then(_ ->
			this.getMessage(accountId, update.chatId, update.serverId, update.localId, callback)
		);
	}

	@HaxeCBridge.noemit
	public function updateMessageStatus(accountId: String, localId: String, status:MessageStatus, callback: (ChatMessage)->Void) {
		db.exec(
			"UPDATE messages SET status=? WHERE account_id=? AND stanza_id=? AND direction=? AND status <> ?",
			[status, accountId, localId, MessageSent, MessageDeliveredToDevice]
		).then(_ ->
			db.exec(
				"SELECT stanza, direction, type, strftime('%FT%H:%M:%fZ', created_at / 1000.0, 'unixepoch') AS timestamp, sender_id, mam_id, mam_by, sync_point FROM messages WHERE account_id=? AND stanza_id=? AND direction=?",
				[accountId, localId, MessageSent]
			)
		).then(result -> hydrateMessages(accountId, result)).then(messages -> {
			for (message in messages) {
				(if (message.replyToMessage != null) {
					hydrateReplyTo(accountId, [message], [{ chatId: message.chatId(), serverId: message.replyToMessage.serverId, localId: message.replyToMessage.localId }]);
				} else {
					Promise.resolve([message]);
				}).then(messages -> hydrateReactions(accountId, messages)).then(hydrated -> callback(hydrated[0]));
				return;
			}
		});
	}

	@HaxeCBridge.noemit
	public function hasMedia(hashAlgorithm:String, hash:BytesData, callback: (Bool)->Void) {
		media.hasMedia(hashAlgorithm, hash, callback);
	}

	@HaxeCBridge.noemit
	public function removeMedia(hashAlgorithm:String, hash:BytesData) {
		media.removeMedia(hashAlgorithm, hash);
	}

	@HaxeCBridge.noemit
	public function storeMedia(mime: String, bd: BytesData, callback: ()->Void) {
		media.storeMedia(mime, bd, callback);
	}

	@HaxeCBridge.noemit
	public function storeCaps(caps:Caps) {
		db.exec(
			"INSERT OR IGNORE INTO caps VALUES (?,jsonb(?))",
			[caps.verRaw().hash, Json.stringify({ node: caps.node, identities: caps.identities, features: caps.features })]
		);
	}

	@HaxeCBridge.noemit
	public function getCaps(ver:String, callback: (Caps)->Void) {
		final verData = try {
			Base64.decode(ver).getData();
		} catch (e) {
			callback(null);
			return;
		}
		db.exec(
			"SELECT json(caps) AS caps FROM caps WHERE sha1=? LIMIT 1",
			[verData]
		).then(result -> {
			for (row in result) {
				final json = Json.parse(row.caps);
				callback(new Caps(json.node, json.identities.map(i -> new Identity(i.category, i.type, i.name)), json.features));
				return;
			}
			callback(null);
		});
	}

	@HaxeCBridge.noemit
	public function storeLogin(accountId:String, clientId:String, displayName:String, token:Null<String>) {
		final params = [accountId, clientId, displayName];
		final q = new StringBuf();
		q.add("INSERT INTO accounts (account_id, client_id, display_name");
		if (token != null) {
			q.add(", token, fast_count");
		}
		q.add(") VALUES (?,?,?");
		if (token != null) {
			q.add(",?");
			params.push(token);
			q.add(",0"); // reset count to zero on new token
		}
		q.add(") ON CONFLICT DO UPDATE SET client_id=?");
		params.push(clientId);
		q.add(", display_name=?");
		params.push(displayName);
		if (token != null) {
			q.add(", token=?");
			params.push(token);
			q.add(", fast_count=0"); // reset count to zero on new token
		}
		db.exec(q.toString(), params);
	}

	@HaxeCBridge.noemit
	public function getLogin(accountId:String, callback:(Null<String>, Null<String>, Int, Null<String>)->Void) {
		db.exec(
			"SELECT client_id, display_name, token, fast_count FROM accounts WHERE account_id=? LIMIT 1",
			[accountId]
		).then(result -> {
			for (row in result) {
				if (row.token != null) {
					db.exec("UPDATE accounts SET fast_count=fast_count+1 WHERE account_id=?", [accountId]);
				}
				callback(row.client_id, row.token, row.fast_count ?? 0, row.display_name);
				return;
			}

			callback(null, null, 0, null);
		});
	}

	public function removeAccount(accountId:String, completely:Bool) {
		db.exec("DELETE FROM accounts WHERE account_id=?", [accountId]);

		if (!completely) return;

		db.exec("DELETE FROM messages WHERE account_id=?", [accountId]);
		db.exec("DELETE FROM chats WHERE account_id=?", [accountId]);
		db.exec("DELETE FROM services WHERE account_id=?", [accountId]);
	}


	public function listAccounts(callback:(Array<String>)->Void) {
		db.exec("SELECT account_id FROM accounts").then(result ->
			callback(result == null ? [] :  { iterator: () -> result }.map(row -> row.account_id))
		);
	}

	private var smStoreInProgress = false;
	private var smStoreNext: Null<BytesData> = null;
	@HaxeCBridge.noemit
	public function storeStreamManagement(accountId:String, sm:Null<BytesData>) {
		smStoreNext = sm;
		if (!smStoreInProgress) {
			smStoreInProgress = true;
			db.exec(
				"UPDATE accounts SET sm_state=? WHERE account_id=?",
				[sm, accountId]
			).then(_ -> {
				smStoreInProgress = false;
				if (smStoreNext != sm) storeStreamManagement(accountId, sm);
			});
		}
	}

	@HaxeCBridge.noemit
	public function getStreamManagement(accountId:String, callback: (Null<BytesData>)->Void) {
		db.exec("SELECT sm_state FROM accounts  WHERE account_id=?", [accountId]).then(result -> {
			for (row in result) {
				callback(row.sm_state);
				return;
			}

			callback(null);
		});
	}

	@HaxeCBridge.noemit
	public function storeService(accountId:String, serviceId:String, name:Null<String>, node:Null<String>, caps:Caps) {
		storeCaps(caps);

		db.exec(
			"INSERT OR REPLACE INTO services VALUES (?,?,?,?,?)",
			[accountId, serviceId, name, node, caps.verRaw().hash]
		);
	}

	@HaxeCBridge.noemit
	public function findServicesWithFeature(accountId:String, feature:String, callback:(Array<{serviceId:String, name:Null<String>, node:Null<String>, caps: Caps}>)->Void) {
		// Almost full scan shouldn't be too expensive, how many services are we aware of?
		db.exec(
			"SELECT service_id, name, node, json(caps.caps) AS caps FROM services INNER JOIN caps ON services.caps=caps.sha1 WHERE account_id=?",
			[accountId]
		).then(result -> {
			final services = [];
			for (row in result) {
				final json = Json.parse(row.caps);
				final features = json?.features ?? [];
				if (features.contains(feature)) {
					services.push({
						serviceId: row.service_id,
						name: row.name,
						node: row.node,
						caps: new Caps(json.node, (json.identities ?? []).map(i -> new Identity(i.category, i.type, i.name)), features)
					});
				}
			}
			callback(services);
		});
	}

	private function hydrateReactions(accountId: String, messages: Array<ChatMessage>) {
		return fetchReactions(accountId, messages.map(m -> ({ chatId: m.chatId(), serverId: m.serverId, serverIdBy: m.serverIdBy, localId: m.localId }))).then(result -> {
			for (id => reactions in result) {
				final m = messages.find(m -> ((m.serverId == null ? m.localId : m.serverId + "\n" + m.serverIdBy) + "\n" + m.chatId()) == id);
				if (m != null) m.set_reactions(reactions);
			}
			return messages;
		});
	}

	private function fetchReactions(accountId: String, ids: Array<{ chatId: String, serverId: Null<String>, serverIdBy: Null<String>, localId: Null<String> }>) {
		final q = new StringBuf();
		q.add("SELECT kind, chat_id, mam_id, mam_by, stanza_id, sender_id, json(reactions) AS reactions FROM reactions WHERE 1=0");
		final params = [];
		for (item in ids) {
			if (item.serverId != null) {
				q.add(" OR (mam_id=? AND mam_by=?)");
				params.push(item.serverId);
				params.push(item.serverIdBy);
			} else {
				q.add(" OR stanza_id=?");
				params.push(item.localId);
			}
		}
		q.add(" ORDER BY created_at, ROWID");
		return db.exec(q.toString(), params).then(rows -> {
			final agg: Map<String, Map<String, Array<Dynamic>>> = [];
			for (row in rows) {
				final reactions: Array<Dynamic> = Json.parse(row.reactions);
				final mapId = (row.mam_id == null || row.mam_id == "" ? row.stanza_id : row.mam_id + "\n" + row.mam_by) + "\n" + row.chat_id;
				if (!agg.exists(mapId)) agg.set(mapId, []);
				final map = agg[mapId];
				if (!map.exists(row.sender_id)) map[row.sender_id] = [];
				if (row.kind == AppendReactions) {
					for (reaction in reactions) map[row.sender_id].push(reaction);
				} else if (row.kind == EmojiReactions) {
					map[row.sender_id] = reactions.concat(map[row.sender_id].filter(r -> r.uri != null));
				} else if (row.kind == CompleteReactions) {
					map[row.sender_id] = reactions;
				}
			}
			final result: Map<String, Map<String, Array<Reaction>>> = [];
			for (id => reactions in agg) {
				final map: Map<String, Array<Reaction>> = [];
				for (reactionsBySender in reactions) {
					for (reactionD in reactionsBySender) {
						final reaction = if (reactionD.uri == null) {
							new Reaction(reactionD.senderId, reactionD.timestamp, reactionD.text, reactionD.envelopeId, reactionD.key);
						} else {
							new CustomEmojiReaction(reactionD.senderId, reactionD.timestamp, reactionD.text, reactionD.uri, reactionD.envelopeId);
						}

						if (!map.exists(reaction.key)) map[reaction.key] = [];
						map[reaction.key].push(reaction);
					}
				}
				result[id] = map;
			}
			return result;
		});
	}

	private function hydrateReplyTo(accountId: String, messages: Array<ChatMessage>, replyTos: Array<{ chatId: String, serverId: Null<String>, localId: Null<String> }>) {
		return (if (replyTos.length < 1) {
			Promise.resolve(null);
		} else {
			final params = [accountId];
			final q = new StringBuf();
			q.add("SELECT chat_id, stanza_id, stanza, direction, type, strftime('%FT%H:%M:%fZ', created_at / 1000.0, 'unixepoch') AS timestamp, sender_id, mam_id, mam_by, sync_point FROM messages WHERE account_id=? AND (");
			q.add(replyTos.map(parent ->
				if (parent.serverId != null) {
					params.push(parent.chatId);
					params.push(parent.serverId);
					" (chat_id=? AND mam_id=?)";
				} else {
					params.push(parent.chatId);
					params.push(parent.localId);
					" (chat_id=? AND stanza_id=?)";
				}
			).join(" OR "));
			q.add(")");
			db.exec(q.toString(), params);
		}).then(iter -> {
			if (iter != null) {
				final parents = { iterator: () -> iter }.array();
				for (message in messages) {
					if (message.replyToMessage != null) {
						final found: Dynamic = parents.find(p -> p.chat_id == message.chatId() && (message.replyToMessage.serverId == null || p.mam_id == message.replyToMessage.serverId) && (message.replyToMessage.localId == null || p.stanza_id == message.replyToMessage.localId));
						if (found != null) message.set_replyToMessage(hydrateMessages(accountId, [found].iterator())[0]);
					}
				}
			}
			return messages;
		});
	}

	private function hydrateMessages(accountId: String, rows: Iterator<{ stanza: String, timestamp: String, direction: MessageDirection, type: MessageType, mam_id: String, mam_by: String, sync_point: Int, sender_id: String, ?stanza_id: String, ?versions: String, ?version_times: String }>): Array<ChatMessage> {
		// TODO: Calls can "edit" from multiple senders, but the original direction and sender holds
		final accountJid = JID.parse(accountId);
		return { iterator: () -> rows }.map(row -> ChatMessage.fromStanza(Stanza.parse(row.stanza), accountJid, (builder, _) -> {
			builder.syncPoint = row.sync_point != 0;
			builder.timestamp = row.timestamp;
			builder.type = row.type;
			builder.senderId = row.sender_id;
			builder.serverId = row.mam_id == "" ? null : row.mam_id;
			builder.serverIdBy = row.mam_by;
			if (builder.direction != row.direction) {
				builder.direction = row.direction;
				final replyTo = builder.replyTo;
				builder.replyTo = builder.recipients;
				builder.recipients = replyTo;
			}
			if (row.stanza_id != null && row.stanza_id != "") builder.localId = row.stanza_id;
			if (row.versions != null) {
				final versionTimes: DynamicAccess<String> = Json.parse(row.version_times);
				final versions: DynamicAccess<String> =  Json.parse(row.versions);
				if (versions.keys().length > 1) {
					for (versionId => version in versions) {
						final versionM = ChatMessage.fromStanza(Stanza.parse(version), accountJid, (toPushB, _) -> {
							if (toPushB.serverId == null && versionId != toPushB.localId)toPushB.serverId = versionId;
							toPushB.timestamp = versionTimes[versionId];
							return toPushB;
						});
						final toPush = versionM == null || versionM.versions.length < 1 ? versionM : versionM.versions[0];
						if (toPush != null) {
							builder.versions.push(toPush);
						}
					}
					builder.versions.sort((a, b) -> Reflect.compare(b.timestamp, a.timestamp));
				}
			}
			return builder;
		}));
	}
}
