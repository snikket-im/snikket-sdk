package xmpp.persistence;

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
import xmpp.Caps;
import xmpp.Chat;
import xmpp.Message;

// TODO: consider doing background threads for operations

@:expose
@:build(HaxeCBridge.expose())
class Sqlite extends Persistence {
	final db: Connection;
	final blobpath: String;

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
				ui_state TEXT,
				extensions TEXT,
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
			db.request("PRAGMA user_version = 1;");
		}
	}

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
		db.addValue(q, chat.extensions);
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
		q.add("SELECT chat_id, trusted, avatar_sha1, fn, ui_state, extensions, class FROM chats WHERE account_id=");
		db.addValue(q, accountId);
		final result = db.request(q.toString());
		final chats = [];
		for (row in result) {
			chats.push(new SerializedChat(row.chat_id, row.trusted, row.avatar_sha1, [], row.fn, row.ui_state, row.extensions, null, Reflect.field(row, "class")));
		}
		callback(chats);
	}

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

	@HaxeCBridge.noemit
	public function getMessages(accountId: String, chatId: String, beforeId: Null<String>, beforeTime: Null<String>, callback: (Array<ChatMessage>)->Void) {
		final q = new StringBuf();
		q.add("SELECT stanza FROM messages WHERE account_id=");
		db.addValue(q, accountId);
		q.add(" AND chat_id=");
		db.addValue(q, chatId);
		if (beforeTime != null) {
			q.add(" AND created_at <");
			db.addValue(q, DateTime.fromString(beforeTime).getTime());
		}
		final result = db.request(q.toString());
		final messages = [];
		for (row in result) {
			messages.push(ChatMessage.fromStanza(Stanza.parse(row.stanza), JID.parse(accountId))); // TODO
		}
		callback(messages);
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
				if (!didOne) subq.add(",");
				db.addValue(subq, chat.readUpTo());
				didOne = true;
			}
		}
		subq.add(") OR stanza_id IN (");
		didOne = false;
		for (chat in chats) {
			if (chat.readUpTo() != null) {
				if (!didOne) subq.add(",");
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

	public function storeCaps(caps:Caps) {
		final q = new StringBuf();
		q.add("INSERT OR IGNORE INTO caps VALUES (X");
		db.addValue(q, caps.verRaw().toHex());
		q.add(",jsonb(");
		db.addValue(q, Json.stringify(caps));
		q.add("));");
		db.request(q.toString());
	}

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

	public function storeLogin(login:String, clientId:String, displayName:String, token:Null<String>) {
		// TODO
	}

	public function getLogin(login:String, callback:(Null<String>, Null<String>, Int, Null<String>)->Void) {
		// TODO
		callback(null, null, 0, null);
	}

	@HaxeCBridge.noemit
	public function storeStreamManagement(accountId:String, smId:String, outboundCount:Int, inboundCount:Int, outboundQueue:Array<String>) {
		// TODO
	}

	@HaxeCBridge.noemit
	public function getStreamManagement(accountId:String, callback: (Null<String>, Int, Int, Array<String>)->Void) {
		callback(null, -1, -1, []); // TODO
	}

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
