package snikket.persistence;

#if cpp
import HaxeCBridge;
#end
import datetime.DateTime;
import haxe.Json;
import haxe.crypto.Base64;
import haxe.crypto.Sha1;
import haxe.crypto.Sha256;
import haxe.io.Bytes;
import haxe.io.BytesData;
import sys.FileSystem;
import sys.db.Connection;
import sys.io.File;
import snikket.Caps;
import snikket.Chat;
import snikket.Message;

// TODO: consider doing background threads for operations

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class Sqlite implements Persistence {
	final db: Connection;
	final blobpath: String;

	/**
		Create a basic persistence layer based on sqlite

		@param dbfile path to sqlite database
		@params blobpath path to directory for blob storage
		@returns new persistence layer
	**/
	public function new(dbfile: String, blobpath: String) {
		this.blobpath = blobpath;
		db = sys.db.Sqlite.open(dbfile);
		final version = db.request("PRAGMA user_version;").getIntResult(0);
		if (version < 1) {
			db.request("CREATE TABLE messages (
				account_id TEXT NOT NULL,
				mam_id TEXT,
				mam_by TEXT,
				stanza_id TEXT NOT NULL,
				sync_point BOOLEAN NOT NULL,
				chat_id TEXT NOT NULL,
				created_at INTEGER NOT NULL,
				stanza TEXT NOT NULL,
				PRIMARY KEY (account_id, mam_id, mam_by)
			);");
			db.request("CREATE TABLE chats (
				account_id TEXT NOT NULL,
				chat_id TEXT NOT NULL,
				trusted BOOLEAN NOT NULL,
				avatar_sha1 BLOB,
				fn TEXT,
				ui_state TEXT NOT NULL,
				blocked BOOLEAN NOT NULL,
				extensions TEXT,
				read_up_to_id TEXT,
				read_up_to_by TEXT,
				class TEXT NOT NULL,
				PRIMARY KEY (account_id, chat_id)
			);");
			db.request("CREATE TABLE media (
				sha256 BLOB NOT NULL PRIMARY KEY,
				sha1 BLOB NOT NULL UNIQUE,
				mime TEXT NOT NULL
			);");
			db.request("CREATE TABLE caps (
				sha1 BLOB NOT NULL UNIQUE,
				caps JSONB NOT NULL
			);");
			db.request("CREATE TABLE services (
				account_id TEXT NOT NULL,
				service_id TEXT NOT NULL,
				name TEXT,
				node TEXT,
				caps BLOB NOT NULL,
				PRIMARY KEY (account_id, service_id)
			);");
			db.request("CREATE TABLE logins (
				login TEXT NOT NULL,
				client_id TEXT NOT NULL,
				display_name TEXT,
				token TEXT,
				fast_count INTEGER NOT NULL DEFAULT 0,
				PRIMARY KEY (login)
			);");
			db.request("PRAGMA user_version = 1;");
		}
	}

	@HaxeCBridge.noemit
	public function lastId(accountId: String, chatId: Null<String>, callback:(Null<String>)->Void):Void {
		final q = new StringBuf();
		q.add("SELECT mam_id FROM messages WHERE mam_id IS NOT NULL AND sync_point AND account_id=");
		db.addValue(q, accountId);
		if (chatId != null) {
			q.add(" AND chat_id=");
			db.addValue(q, chatId);
		}
		q.add(";");
		try {
			callback(db.request(q.toString()).getResult(0));
		} catch (e) {
			callback(null);
		}
	}

	@HaxeCBridge.noemit
	public function storeChat(accountId: String, chat: Chat) {
		// TODO: presence
		// TODO: disco
		trace("storeChat");
		final q = new StringBuf();
		q.add("INSERT OR REPLACE INTO chats VALUES (");
		db.addValue(q, accountId);
		q.add(",");
		db.addValue(q, chat.chatId);
		q.add(",");
		db.addValue(q, chat.isTrusted());
		if (chat.avatarSha1 == null) {
			q.add(",NULL");
		} else {
			q.add(",X");
			db.addValue(q, Bytes.ofData(chat.avatarSha1).toHex());
		}
		q.add(",");
		db.addValue(q, chat.getDisplayName());
		q.add(",");
		db.addValue(q, chat.uiState);
		q.add(",");
		db.addValue(q, chat.isBlocked);
		q.add(",");
		db.addValue(q, chat.extensions);
		q.add(",");
		db.addValue(q, chat.readUpTo());
		q.add(",");
		db.addValue(q, chat.readUpToBy);
		q.add(",");
		db.addValue(q, Type.getClassName(Type.getClass(chat)).split(".").pop());
		q.add(");");
		db.request(q.toString());
	}

	@HaxeCBridge.noemit
	public function getChats(accountId: String, callback: (Array<SerializedChat>)->Void) {
		// TODO: presence
		// TODO: disco
		final q = new StringBuf();
		q.add("SELECT chat_id, trusted, avatar_sha1, fn, ui_state, blocked, extensions, read_up_to_id, read_up_to_by, class FROM chats WHERE account_id=");
		db.addValue(q, accountId);
		final result = db.request(q.toString());
		final chats = [];
		for (row in result) {
			chats.push(new SerializedChat(row.chat_id, row.trusted, row.avatar_sha1, [], row.fn, row.ui_state, row.blocked, row.extensions, row.read_up_to_id, row.read_up_to_by, null, Reflect.field(row, "class")));
		}
		callback(chats);
	}

	@HaxeCBridge.noemit
	public function storeMessage(accountId: String, message: ChatMessage, callback: (ChatMessage)->Void) {
		final q = new StringBuf();
		q.add("INSERT OR REPLACE INTO messages VALUES (");
		db.addValue(q, accountId);
		q.add(",");
		db.addValue(q, message.serverId);
		q.add(",");
		db.addValue(q, message.serverIdBy);
		q.add(",");
		db.addValue(q, message.localId);
		q.add(",");
		db.addValue(q, message.syncPoint);
		q.add(",");
		db.addValue(q, message.chatId());
		q.add(",");
		db.addValue(q, DateTime.fromString(message.timestamp).getTime());
		q.add(",");
		db.addValue(q, message.asStanza().toString());
		q.add(");");
		db.request(q.toString());

		// TODO: hydrate reply to stubs?
		// TODO: corrections
		// TODO: fetch reactions?
		callback(message);
	}

	private function getMessages(accountId: String, chatId: String, time: String, op: String) {
		final q = new StringBuf();
		q.add("SELECT stanza FROM messages WHERE account_id=");
		db.addValue(q, accountId);
		q.add(" AND chat_id=");
		db.addValue(q, chatId);
		if (time != null) {
			q.add(" AND created_at " + op);
			db.addValue(q, DateTime.fromString(time).getTime());
		}
		q.add("LIMIT 50");
		final result = db.request(q.toString());
		final messages = [];
		for (row in result) {
			messages.push(ChatMessage.fromStanza(Stanza.parse(row.stanza), JID.parse(accountId))); // TODO
		}
		return messages;
	}

	@HaxeCBridge.noemit
	public function getMessagesBefore(accountId: String, chatId: String, beforeId: Null<String>, beforeTime: Null<String>, callback: (Array<ChatMessage>)->Void) {
		callback(getMessages(accountId, chatId, beforeTime, "<"));
	}

	@HaxeCBridge.noemit
	public function getMessagesAfter(accountId: String, chatId: String, afterId: Null<String>, afterTime: Null<String>, callback: (Array<ChatMessage>)->Void) {
		callback(getMessages(accountId, chatId, afterTime, ">"));
	}

	@HaxeCBridge.noemit
	public function getMessagesAround(accountId: String, chatId: String, aroundId: Null<String>, aroundTime: Null<String>, callback: (Array<ChatMessage>)->Void) {
		if (aroundTime == null) throw "Around what?";
		final before = getMessages(accountId, chatId, aroundTime, "<");
		final aroundAndAfter = getMessages(accountId, chatId, aroundTime, ">=");
		callback(before.concat(aroundAndAfter));
	}

	@HaxeCBridge.noemit
	public function getChatsUnreadDetails(accountId: String, chats: Array<Chat>, callback: (Array<{ chatId: String, message: ChatMessage, unreadCount: Int }>)->Void) {
		if (chats == null || chats.length < 1) {
			callback([]);
			return;
		}

		final subq = new StringBuf();
		subq.add("SELECT chat_id, MAX(ROWID) AS row FROM messages WHERE account_id=");
		db.addValue(subq, accountId);
		subq.add(" AND chat_id IN (");
		for (i => chat in chats) {
			if (i != 0) subq.add(",");
			db.addValue(subq, chat.chatId);
		}
		subq.add(") AND (mam_id IN (");
		var didOne = false;
		for (chat in chats) {
			if (chat.readUpTo() != null) {
				if (didOne) subq.add(",");
				db.addValue(subq, chat.readUpTo());
				didOne = true;
			}
		}
		subq.add(") OR stanza_id IN (");
		didOne = false;
		for (chat in chats) {
			if (chat.readUpTo() != null) {
				if (didOne) subq.add(",");
				db.addValue(subq, chat.readUpTo());
				didOne = true;
			}
		}
		subq.add(")) GROUP BY chat_id");

		final q = new StringBuf();
		q.add("SELECT chat_id as chatId, stanza, CASE WHEN subq.row IS NULL THEN COUNT(*) ELSE COUNT(*) - 1 END AS unreadCount, MAX(messages.created_at) ");
		q.add("FROM messages LEFT JOIN (");
		q.add(subq.toString());
		q.add(") subq USING (chat_id) WHERE account_id=");
		db.addValue(q, accountId);
		q.add(" AND chat_id IN (");
		for (i => chat in chats) {
			if (i != 0) q.add(",");
			db.addValue(q, chat.chatId);
		}
		q.add(") AND (subq.row IS NULL OR messages.ROWID >= subq.row) GROUP BY chat_id;");
		final result = db.request(q.toString());
		final details = [];
		for (row in result) {
			row.message = ChatMessage.fromStanza(Stanza.parse(row.stanza), JID.parse(accountId)); // TODO
			details.push(row);
		}
		callback(details);
	}

	@HaxeCBridge.noemit
	public function storeReaction(accountId: String, update: ReactionUpdate, callback: (Null<ChatMessage>)->Void) {
		callback(null); // TODO
	}

	@HaxeCBridge.noemit
	public function updateMessageStatus(accountId: String, localId: String, status:MessageStatus, callback: (ChatMessage)->Void) {
		callback(null); // TODO
	}

	@HaxeCBridge.noemit
	public function getMediaUri(hashAlgorithm:String, hash:BytesData, callback: (Null<String>)->Void) {
		if (hashAlgorithm == "sha-256") {
			final path = blobpath + "/f" + Bytes.ofData(hash).toHex();
			if (FileSystem.exists(path)) {
				callback("file://" + FileSystem.absolutePath(path));
			} else {
				callback(null);
			}
		} else if (hashAlgorithm == "sha-1") {
			final q = new StringBuf();
			q.add("SELECT sha256 FROM media WHERE sha1=X");
			db.addValue(q, Bytes.ofData(hash).toHex());
			q.add(" LIMIT 1");
			final result = db.request(q.toString());
			for (row in result) {
				getMediaUri("sha-256", row.sha256, callback);
				return;
			}
			callback(null);
		} else {
			throw "Unknown hash algorithm: " + hashAlgorithm;
		}
	}

	@HaxeCBridge.noemit
	public function hasMedia(hashAlgorithm:String, hash:BytesData, callback: (Bool)->Void) {
		getMediaUri(hashAlgorithm, hash, (uri) -> callback(uri != null));
	}

	@HaxeCBridge.noemit
	public function storeMedia(mime:String, bd:BytesData, callback: ()->Void) {
		final bytes = Bytes.ofData(bd);
		final sha256 = Sha256.make(bytes).toHex();
		final sha1 = Sha1.make(bytes).toHex();
		File.saveBytes(blobpath + "/f" + sha256, bytes);

		final q = new StringBuf();
		q.add("INSERT OR IGNORE INTO media VALUES (X");
		db.addValue(q, sha256);
		q.add(",X");
		db.addValue(q, sha1);
		q.add(",");
		db.addValue(q, mime);
		q.add(");");
		db.request(q.toString());

		callback();
	}

	@HaxeCBridge.noemit
	public function storeCaps(caps:Caps) {
		final q = new StringBuf();
		q.add("INSERT OR IGNORE INTO caps VALUES (X");
		db.addValue(q, caps.verRaw().toHex());
		q.add(",jsonb(");
		db.addValue(q, Json.stringify(caps));
		q.add("));");
		db.request(q.toString());
	}

	@HaxeCBridge.noemit
	public function getCaps(ver:String, callback: (Caps)->Void) {
		final q = new StringBuf();
		q.add("SELECT json(caps) AS caps FROM caps WHERE sha1=X");
		db.addValue(q, Base64.decode(ver).toHex());
		q.add(" LIMIT 1");
		final result = db.request(q.toString());
		for (row in result) {
			final json = Json.parse(row.caps);
			callback(new Caps(json.node, json.identities.map(i -> new Identity(i.category, i.type, i.name)), json.features));
			return;
		}
		callback(null);
	}

	@HaxeCBridge.noemit
	public function storeLogin(login:String, clientId:String, displayName:String, token:Null<String>) {
		final q = new StringBuf();
		q.add("INSERT INTO logins (login, client_id, display_name");
		if (token != null) {
			q.add(", token, fast_count");
		}
		q.add(") VALUES (");
		db.addValue(q, login);
		q.add(",");
		db.addValue(q, clientId);
		q.add(",");
		db.addValue(q, displayName);
		if (token != null) {
			q.add(",");
			db.addValue(q, token);
			q.add(",0"); // reset count to zero on new token
		}
		q.add(") ON CONFLICT DO UPDATE SET client_id=");
		db.addValue(q, clientId);
		q.add(", display_name=");
		db.addValue(q, displayName);
		if (token != null) {
			q.add(", token=");
			db.addValue(q, token);
			q.add(", fast_count=0"); // reset count to zero on new token
		}
		db.request(q.toString());
	}

	@HaxeCBridge.noemit
	public function getLogin(login:String, callback:(Null<String>, Null<String>, Int, Null<String>)->Void) {
		final q = new StringBuf();
		q.add("SELECT client_id, display_name, token, fast_count FROM logins WHERE login=");
		db.addValue(q, login);
		q.add(" LIMIT 1");
		final result = db.request(q.toString());
		for (row in result) {
			if (row.token != null) {
				final update = new StringBuf();
				update.add("UPDATE logins SET fast_count=fast_count+1 WHERE login=");
				db.addValue(update, login);
				db.request(update.toString());
			}
			callback(row.client_id, row.token, row.fast_count ?? 0, row.display_name);
			return;
		}

		callback(null, null, 0, null);
	}

	@HaxeCBridge.noemit
	public function removeAccount(accountId:String, completely:Bool) {
		var q = new StringBuf();
		q.add("DELETE FROM logins WHERE login=");
		db.addValue(q, accountId);
		db.request(q.toString());
		// TODO stream managemento

		if (!completely) return;

		var q = new StringBuf();
		q.add("DELETE FROM messages WHERE account_id=");
		db.addValue(q, accountId);
		db.request(q.toString());

		var q = new StringBuf();
		q.add("DELETE FROM chats WHERE account_id=");
		db.addValue(q, accountId);
		db.request(q.toString());

		var q = new StringBuf();
		q.add("DELETE FROM services WHERE account_id=");
		db.addValue(q, accountId);
		db.request(q.toString());
	}

	@HaxeCBridge.noemit
	public function storeStreamManagement(accountId:String, sm:Null<BytesData>) {
		// TODO
	}

	@HaxeCBridge.noemit
	public function getStreamManagement(accountId:String, callback: (Null<BytesData>)->Void) {
		callback(null); // TODO
	}

	@HaxeCBridge.noemit
	public function storeService(accountId:String, serviceId:String, name:Null<String>, node:Null<String>, caps:Caps) {
		storeCaps(caps);

		final q = new StringBuf();
		q.add("INSERT OR REPLACE INTO services VALUES (");
		db.addValue(q, accountId);
		q.add(",");
		db.addValue(q, serviceId);
		q.add(",");
		db.addValue(q, name);
		q.add(",");
		db.addValue(q, node);
		q.add(",X");
		db.addValue(q, caps.verRaw().toHex());
		q.add(");");
		db.request(q.toString());
	}

	@HaxeCBridge.noemit
	public function findServicesWithFeature(accountId:String, feature:String, callback:(Array<{serviceId:String, name:Null<String>, node:Null<String>, caps: Caps}>)->Void) {
		// Almost full scan shouldn't be too expensive, how many services are we aware of?
		final q = new StringBuf();
		q.add("SELECT service_id, name, node, json(caps.caps) AS caps FROM services INNER JOIN caps ON services.caps=caps.sha1 WHERE account_id=");
		db.addValue(q, accountId);
		final result = db.request(q.toString());
		final services = [];
		for (row in result) {
			final json = Json.parse(row.caps);
			if (json.features.contains(feature)) {
				row.set("caps", new Caps(json.node, json.identities.map(i -> new Identity(i.category, i.type, i.name)), json.features));
				services.push(row);
			}
		}
		callback(services);
	}
}
