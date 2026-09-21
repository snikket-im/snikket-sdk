package test;

import haxe.io.Bytes;
import haxe.io.BytesData;
import haxe.crypto.random.SecureRandom;
import thenshim.Promise;
import thenshim.PromiseTools;
import utest.Assert;
import utest.Async;

import borogove.persistence.Sqlite;
import borogove.persistence.MediaStore;
import borogove.persistence.KeyValueStore;
import borogove.ChatMessageBuilder;
import borogove.ChatMessage;
import borogove.EncryptionInfo;
import borogove.JID;
import borogove.ID;
import borogove.Message;
import borogove.Chat;
import borogove.Chat.AvailableChat;
import borogove.Status;
import borogove.Reaction;
import borogove.ReactionUpdate;
import borogove.Html;
import borogove.Hash;
import borogove.Member;
import borogove.MemberUpdate;
import borogove.Role;
import borogove.Stanza;
import borogove.Source;
#if !NO_OMEMO
import borogove.SignalProtocol.PreKeyPair;
import borogove.SignalProtocol.SignalSession;
import borogove.OMEMO.OMEMOSessionMetadata;
#end

using Lambda;
using thenshim.PromiseTools;

@:access(borogove)
class MockMediaStore implements MediaStore {
	private var kv: Null<KeyValueStore> = null;

	public function new() { }

	@:allow(borogove)
	private function setKV(kv: KeyValueStore) {
		this.kv = kv;
	}

	public function getMediaPath(uri: String): Promise<Null<String>> {
		final hash = Hash.fromUri(uri);
		if (hash.algorithm == "sha-256") {
			return kv.get(hash.serializeUri()).then(v ->
				Promise.resolve(v == null ? null : hash.serializeUri())
			);
		} else {
			return kv.get(hash.serializeUri()).then(sha256uri -> {
				final sha256 = sha256uri == null ? null : Hash.fromUri(sha256uri);
				if (sha256 == null) {
					return Promise.resolve(null);
				} else {
					return getMediaPath(sha256.toUri());
				}
			});
		}
	}

	public function hasMedia(hash: Hash): Promise<Null<String>> {
		return getMediaPath(hash.toUri());
	}

	public function removeMedia(hashAlgorithm: String, hash: BytesData) {
		final hash = new Hash(hashAlgorithm, hash);
		return getMediaPath(hash.toUri()).then(p -> kv.set(p, null)).then(_ -> true);
	}

	public function storeMedia(mime: String, source: Source): Promise<Null<String>> {
		return new Promise((resolve, reject) -> {
			tink.io.Source.RealSourceTools.all(source).handle(o -> switch o {
				case Success(bytes): resolve((bytes : Bytes));
				case Failure(e): reject(e);
			});
		}).then(bytes -> {
			final sha1 = Hash.sha1(bytes);
			final sha256 = Hash.sha256(bytes);
			return thenshim.PromiseTools.all([
				kv.set(sha1.serializeUri(), sha256.serializeUri()),
				kv.set(sha256.serializeUri(), mime)
			]).then(_ -> "/path");
		});
	}
}

@:access(borogove)
@:timeout(5000)
class TestSqlite extends utest.Test {
	var persistence: Sqlite;
	var mediaStore: MockMediaStore;

	public function setup() {
		mediaStore = new MockMediaStore();
		persistence = new Sqlite("file:" + ID.unique() + "?mode=memory&cache=shared", mediaStore);
	}

	public function testOrder(async: Async) {
		final account = "alice@example.com";
		final builder = new ChatMessageBuilder();
		builder.serverId = "1";
		builder.serverIdBy = "alice@example.com";
		builder.senderId = "hatter@example.com";
		builder.direction = MessageReceived;
		builder.sortId = "a0";
		builder.to = JID.parse("alice@example.com");
		builder.from = JID.parse("hatter@example.com");
		builder.recipients = [builder.to];
		builder.replyTo = [builder.from];

		final builder2 = new ChatMessageBuilder();
		builder2.serverId = "2";
		builder2.serverIdBy = "alice@example.com";
		builder2.senderId = "hatter@example.com";
		builder2.direction = MessageReceived;
		builder2.sortId = "b0";
		builder2.to = JID.parse("alice@example.com");
		builder2.from = JID.parse("hatter@example.com");
		builder2.recipients = [builder2.to];
		builder2.replyTo = [builder2.from];

		persistence.storeMessages(account, [
			builder2.build(),
			builder.build(),
		]).then(_ -> {
			return persistence.getMessagesBefore(account, "hatter@example.com", null);
		}).then(result -> {
			Assert.equals(2, result.length);
			Assert.equals("1", result[0].serverId);
			Assert.equals("2", result[1].serverId);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testMessagesBefore(async: Async) {
		final account = "alice@example.com";
		final builder = new ChatMessageBuilder();
		builder.serverId = "1";
		builder.serverIdBy = "teaparty@example.com";
		builder.senderId = "teaparty@example.com/hatter";
		builder.direction = MessageReceived;
		builder.type = MessageChannel;
		builder.timestamp = "2020-01-01T00:00:01Z";
		builder.sortId = "a0";
		builder.to = JID.parse("alice@example.com");
		builder.from = JID.parse("teaparty@example.com/hatter");
		builder.replyTo = [builder.from.asBare()];

		final builder2 = new ChatMessageBuilder();
		builder2.serverId = "2";
		builder2.serverIdBy = "teaparty@example.com";
		builder2.senderId = "teaparty@example.com/hatter";
		builder2.direction = MessageReceived;
		builder2.type = MessageChannel;
		builder2.timestamp = "2020-01-01T00:00:00Z";
		builder2.sortId = "b0";
		builder2.to = JID.parse("alice@example.com");
		builder2.from = JID.parse("teaparty@example.com/hatter");
		builder2.replyTo = [builder2.from.asBare()];

		final builder3 = new ChatMessageBuilder();
		builder3.serverId = "3";
		builder3.serverIdBy = "alice@example.com";
		builder3.senderId = "teaparty@example.com/hatter";
		builder3.direction = MessageReceived;
		builder3.type = MessageChannelPrivate;
		builder3.timestamp = "2020-01-01T00:00:03Z";
		builder3.sortId = "a0";
		builder3.to = JID.parse("alice@example.com");
		builder3.from = JID.parse("teaparty@example.com/hatter");
		builder3.replyTo = [builder3.from.asBare()];

		persistence.storeMessages(account, [
			builder2.build(),
			builder3.build(),
			builder.build(),
		]).then(_ -> {
			return persistence.getMessagesBefore(account, "teaparty@example.com", null);
		}).then(result -> {
			Assert.equals(3, result.length);
			Assert.equals("1", result[0].serverId);
			Assert.equals("2", result[1].serverId);
			Assert.equals("3", result[2].serverId);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testMessagesBeforePoint(async: Async) {
		final account = "alice@example.com";
		final builder = new ChatMessageBuilder();
		builder.serverId = "1";
		builder.serverIdBy = "teaparty@example.com";
		builder.senderId = "teaparty@example.com/hatter";
		builder.direction = MessageReceived;
		builder.type = MessageChannel;
		builder.timestamp = "2020-01-01T00:00:01Z";
		builder.sortId = "a0";
		builder.to = JID.parse("alice@example.com");
		builder.from = JID.parse("teaparty@example.com/hatter");
		builder.replyTo = [builder.from.asBare()];

		final builder2 = new ChatMessageBuilder();
		builder2.serverId = "2";
		builder2.serverIdBy = "teaparty@example.com";
		builder2.senderId = "teaparty@example.com/hatter";
		builder2.direction = MessageReceived;
		builder2.type = MessageChannel;
		builder2.timestamp = "2020-01-01T00:00:00Z";
		builder2.sortId = "b0";
		builder2.to = JID.parse("alice@example.com");
		builder2.from = JID.parse("teaparty@example.com/hatter");
		builder2.replyTo = [builder2.from.asBare()];

		final builder3 = new ChatMessageBuilder();
		builder3.serverId = "3";
		builder3.serverIdBy = "alice@example.com";
		builder3.senderId = "teaparty@example.com/hatter";
		builder3.direction = MessageReceived;
		builder3.type = MessageChannelPrivate;
		builder3.timestamp = "2020-01-01T00:00:03Z";
		builder3.sortId = "Z~";
		builder3.to = JID.parse("alice@example.com");
		builder3.from = JID.parse("teaparty@example.com/hatter");
		builder3.replyTo = [builder3.from.asBare()];

		final builder4 = new ChatMessageBuilder();
		builder4.serverId = "4";
		builder4.serverIdBy = "teaparty@example.com";
		builder4.senderId = "teaparty@example.com/hatter";
		builder4.direction = MessageReceived;
		builder4.type = MessageChannel;
		builder4.timestamp = "2020-01-01T00:00:04Z";
		builder4.sortId = "c0";
		builder4.to = JID.parse("alice@example.com");
		builder4.from = JID.parse("teaparty@example.com/hatter");
		builder4.replyTo = [builder4.from.asBare()];

		persistence.storeMessages(account, [
			builder2.build(),
			builder4.build(),
			builder3.build(),
			builder.build(),
		]).then(_ -> {
			return persistence.getMessagesBefore(account, "teaparty@example.com", builder4.build());
		}).then(result -> {
			Assert.equals(3, result.length);
			Assert.equals("1", result[0].serverId);
			Assert.equals("2", result[1].serverId);
			Assert.equals("3", result[2].serverId);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testMessagesBeforePM(async: Async) {
		final account = "alice@example.com";
		final builder = new ChatMessageBuilder();
		builder.serverId = "1";
		builder.serverIdBy = "teaparty@example.com";
		builder.senderId = "teaparty@example.com/hatter";
		builder.direction = MessageReceived;
		builder.type = MessageChannel;
		builder.timestamp = "2020-01-01T00:00:00Z";
		builder.sortId = "a0";
		builder.to = JID.parse("alice@example.com");
		builder.from = JID.parse("teaparty@example.com/hatter");
		builder.replyTo = [builder.from.asBare()];

		final builder2 = new ChatMessageBuilder();
		builder2.serverId = "2";
		builder2.serverIdBy = "teaparty@example.com";
		builder2.senderId = "teaparty@example.com/hatter";
		builder2.direction = MessageReceived;
		builder2.type = MessageChannel;
		builder2.timestamp = "2020-01-01T00:00:01Z";
		builder2.sortId = "b0";
		builder2.to = JID.parse("alice@example.com");
		builder2.from = JID.parse("teaparty@example.com/hatter");
		builder2.replyTo = [builder2.from.asBare()];

		final builder3 = new ChatMessageBuilder();
		builder3.serverId = "3";
		builder3.serverIdBy = "alice@example.com";
		builder3.senderId = "teaparty@example.com/hatter";
		builder3.direction = MessageReceived;
		builder3.type = MessageChannelPrivate;
		builder3.timestamp = "2020-01-01T00:00:03Z";
		builder3.sortId = "Z~";
		builder3.to = JID.parse("alice@example.com");
		builder3.from = JID.parse("teaparty@example.com/hatter");
		builder3.replyTo = [builder3.from.asBare()];

		final builder4 = new ChatMessageBuilder();
		builder4.serverId = "4";
		builder4.serverIdBy = "teaparty@example.com";
		builder4.senderId = "teaparty@example.com/hatter";
		builder4.direction = MessageReceived;
		builder4.type = MessageChannel;
		builder4.timestamp = "2020-01-01T00:00:04Z";
		builder4.sortId = "c0";
		builder4.to = JID.parse("alice@example.com");
		builder4.from = JID.parse("teaparty@example.com/hatter");
		builder4.replyTo = [builder4.from.asBare()];

		persistence.storeMessages(account, [
			builder2.build(),
			builder4.build(),
			builder3.build(),
			builder.build(),
		]).then(_ -> {
			return persistence.getMessagesBefore(account, "teaparty@example.com", builder3.build());
		}).then(result -> {
			Assert.equals(2, result.length);
			Assert.equals("1", result[0].serverId);
			Assert.equals("2", result[1].serverId);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testMessagesAfter(async: Async) {
		final account = "alice@example.com";
		final builder = new ChatMessageBuilder();
		builder.serverId = "1";
		builder.serverIdBy = "teaparty@example.com";
		builder.senderId = "teaparty@example.com/hatter";
		builder.direction = MessageReceived;
		builder.type = MessageChannel;
		builder.timestamp = "2020-01-01T00:00:00Z";
		builder.sortId = "a0";
		builder.to = JID.parse("alice@example.com");
		builder.from = JID.parse("teaparty@example.com/hatter");
		builder.replyTo = [builder.from.asBare()];

		final builder2 = new ChatMessageBuilder();
		builder2.serverId = "2";
		builder2.serverIdBy = "teaparty@example.com";
		builder2.senderId = "teaparty@example.com/hatter";
		builder2.direction = MessageReceived;
		builder2.type = MessageChannel;
		builder2.timestamp = "2020-01-01T00:00:01Z";
		builder2.sortId = "b0";
		builder2.to = JID.parse("alice@example.com");
		builder2.from = JID.parse("teaparty@example.com/hatter");
		builder2.replyTo = [builder2.from.asBare()];

		final builder3 = new ChatMessageBuilder();
		builder3.serverId = "3";
		builder3.serverIdBy = "alice@example.com";
		builder3.senderId = "teaparty@example.com/hatter";
		builder3.direction = MessageReceived;
		builder3.type = MessageChannelPrivate;
		builder3.timestamp = "2020-01-01T00:00:03Z";
		builder3.sortId = "a1";
		builder3.to = JID.parse("alice@example.com");
		builder3.from = JID.parse("teaparty@example.com/hatter");
		builder3.replyTo = [builder3.from.asBare()];

		persistence.storeMessages(account, [
			builder2.build(),
			builder3.build(),
			builder.build(),
		]).then(_ -> {
			return persistence.getMessagesAfter(account, "teaparty@example.com", null);
		}).then(result -> {
			Assert.equals(3, result.length);
			Assert.equals("1", result[0].serverId);
			Assert.equals("2", result[1].serverId);
			Assert.equals("3", result[2].serverId);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testMessagesAfterPoint(async: Async) {
		final account = "alice@example.com";
		final builder = new ChatMessageBuilder();
		builder.serverId = "1";
		builder.serverIdBy = "teaparty@example.com";
		builder.senderId = "teaparty@example.com/hatter";
		builder.direction = MessageReceived;
		builder.type = MessageChannel;
		builder.timestamp = "2020-01-01T00:00:01Z";
		builder.sortId = "a0";
		builder.to = JID.parse("alice@example.com");
		builder.from = JID.parse("teaparty@example.com/hatter");
		builder.replyTo = [builder.from.asBare()];

		final builder2 = new ChatMessageBuilder();
		builder2.serverId = "2";
		builder2.serverIdBy = "teaparty@example.com";
		builder2.senderId = "teaparty@example.com/hatter";
		builder2.direction = MessageReceived;
		builder2.type = MessageChannel;
		builder2.timestamp = "2020-01-01T00:00:00Z";
		builder2.sortId = "b0";
		builder2.to = JID.parse("alice@example.com");
		builder2.from = JID.parse("teaparty@example.com/hatter");
		builder2.replyTo = [builder2.from.asBare()];

		final builder3 = new ChatMessageBuilder();
		builder3.serverId = "3";
		builder3.serverIdBy = "alice@example.com";
		builder3.senderId = "teaparty@example.com/hatter";
		builder3.direction = MessageReceived;
		builder3.type = MessageChannelPrivate;
		builder3.timestamp = "2020-01-01T00:00:03Z";
		builder3.sortId = "Z~";
		builder3.to = JID.parse("alice@example.com");
		builder3.from = JID.parse("teaparty@example.com/hatter");
		builder3.replyTo = [builder3.from.asBare()];

		final builder4 = new ChatMessageBuilder();
		builder4.serverId = "4";
		builder4.serverIdBy = "teaparty@example.com";
		builder4.senderId = "teaparty@example.com/hatter";
		builder4.direction = MessageReceived;
		builder4.type = MessageChannel;
		builder4.timestamp = "2020-01-01T00:00:04Z";
		builder4.sortId = "c0";
		builder4.to = JID.parse("alice@example.com");
		builder4.from = JID.parse("teaparty@example.com/hatter");
		builder4.replyTo = [builder4.from.asBare()];

		persistence.storeMessages(account, [
			builder2.build(),
			builder4.build(),
			builder3.build(),
			builder.build(),
		]).then(_ -> {
			return persistence.getMessagesAfter(account, "teaparty@example.com", builder.build());
		}).then(result -> {
			Assert.equals(3, result.length);
			Assert.equals("2", result[0].serverId);
			Assert.equals("3", result[1].serverId);
			Assert.equals("4", result[2].serverId);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testMessagesAfterPM(async: Async) {
		final account = "alice@example.com";
		final builder = new ChatMessageBuilder();
		builder.serverId = "1";
		builder.serverIdBy = "teaparty@example.com";
		builder.senderId = "teaparty@example.com/hatter";
		builder.direction = MessageReceived;
		builder.type = MessageChannel;
		builder.timestamp = "2020-01-01T00:00:00Z";
		builder.sortId = "a0";
		builder.to = JID.parse("alice@example.com");
		builder.from = JID.parse("teaparty@example.com/hatter");
		builder.replyTo = [builder.from.asBare()];

		final builder2 = new ChatMessageBuilder();
		builder2.serverId = "2";
		builder2.serverIdBy = "teaparty@example.com";
		builder2.senderId = "teaparty@example.com/hatter";
		builder2.direction = MessageReceived;
		builder2.type = MessageChannel;
		builder2.timestamp = "2020-01-01T00:00:01Z";
		builder2.sortId = "b0";
		builder2.to = JID.parse("alice@example.com");
		builder2.from = JID.parse("teaparty@example.com/hatter");
		builder2.replyTo = [builder2.from.asBare()];

		final builder3 = new ChatMessageBuilder();
		builder3.serverId = "3";
		builder3.serverIdBy = "alice@example.com";
		builder3.senderId = "teaparty@example.com/hatter";
		builder3.direction = MessageReceived;
		builder3.type = MessageChannelPrivate;
		builder3.timestamp = "2020-01-01T00:00:03Z";
		builder3.sortId = "Z~";
		builder3.to = JID.parse("alice@example.com");
		builder3.from = JID.parse("teaparty@example.com/hatter");
		builder3.replyTo = [builder3.from.asBare()];

		final builder4 = new ChatMessageBuilder();
		builder4.serverId = "4";
		builder4.serverIdBy = "teaparty@example.com";
		builder4.senderId = "teaparty@example.com/hatter";
		builder4.direction = MessageReceived;
		builder4.type = MessageChannel;
		builder4.timestamp = "2020-01-01T00:00:04Z";
		builder4.sortId = "c0";
		builder4.to = JID.parse("alice@example.com");
		builder4.from = JID.parse("teaparty@example.com/hatter");
		builder4.replyTo = [builder4.from.asBare()];

		persistence.storeMessages(account, [
			builder2.build(),
			builder4.build(),
			builder3.build(),
			builder.build(),
		]).then(_ -> {
			return persistence.getMessagesAfter(account, "teaparty@example.com", builder3.build());
		}).then(result -> {
			Assert.equals(1, result.length);
			Assert.equals("4", result[0].serverId);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testStoreChats(async: Async) {
		final account = "alice@example.com";
		final chat = new DirectChat(cast null, cast null, persistence, "hatter@example.com");
		chat.displayName = "The Mad Hatter";
		chat.trusted = true;
		chat.threads.set(null, "Tea Time");
		chat.threads.set("thread-1", "Introductions");

		persistence.storeChats(account, [chat]);
		haxe.Timer.delay(() -> {
			persistence.getChats(account).then(chats -> {
				Assert.equals(1, chats.length);
				Assert.equals("hatter@example.com", chats[0].chatId);
				Assert.equals("The Mad Hatter", chats[0].displayName);
				Assert.isTrue(chats[0].trusted);
				Assert.equals("DirectChat", chats[0].klass);
				Assert.equals("Tea Time", chats[0].threads.get(null));
				Assert.equals("Introductions", chats[0].threads.get("thread-1"));
				async.done();
			}).catchError(e -> {
				Assert.fail(Std.string(e));
				async.done();
			});
		}, 200);
	}

	public function testGetMessage(async: Async) {
		final account = "alice@example.com";
		final builder = new ChatMessageBuilder();
		builder.serverId = "srv1";
		builder.serverIdBy = "hatter@example.com";
		builder.localId = "loc1";
		builder.senderId = "hatter@example.com";
		builder.direction = MessageReceived;
		builder.sortId = "a0";
		builder.to = JID.parse("alice@example.com");
		builder.from = JID.parse("hatter@example.com");
		builder.recipients = [builder.to];
		builder.replyTo = [builder.from];

		persistence.storeMessages(account, [builder.build()]).then(_ -> {
			return persistence.getMessage(account, "hatter@example.com", "srv1", null);
		}).then(byServerId -> {
			Assert.notNull(byServerId);
			Assert.equals("srv1", byServerId.serverId);
			return persistence.getMessage(account, "hatter@example.com", null, "loc1");
		}).then(byLocalId -> {
			Assert.notNull(byLocalId);
			Assert.equals("loc1", byLocalId.localId);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testCorrectableMessageStorageUsesCallSidForCorrectionId(async: Async) {
		final account = "alice@example.com";
		final version = makeMessage({
			timestamp: "2020-01-01T00:00:00Z",
			localId: "version-call-local",
			serverId: "version-call-server"
		});
		final correctable = makeMessage({
			timestamp: "2020-01-01T00:00:01Z",
			localId: "correctable-call-local",
			serverId: "correctable-call-server",
			versions: [version],
			callSid: "call-sid",
			syncPoint: true,
			senderId: "correctable@example.com",
			chatId: "correctable-chat@example.com"
		});

		persistence.storeMessages(account, [correctable]).then(_ -> {
			return persistence.db.exec("SELECT correction_id FROM messages WHERE mam_id=?", [version.serverId]);
		}).then(rows -> {
			final row = rows.next();
			Assert.equals("call-sid", row.correction_id);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testCorrectableMessageStorageUsesCorrectableFields(async: Async) {
		final account = "alice@example.com";
		final version = makeMessage({
			timestamp: "2020-01-01T00:00:00Z",
			localId: "version-local",
			serverId: "version-server",
			senderId: "version@example.com",
			chatId: "version-chat@example.com"
		});
		final correctable = makeMessage({
			timestamp: "2020-01-01T00:00:01Z",
			localId: "correctable-local",
			serverId: "correctable-server",
			versions: [version],
			syncPoint: true,
			senderId: "correctable@example.com",
			chatId: "correctable-chat@example.com"
		});

		persistence.storeMessages(account, [correctable]).then(_ -> {
			return persistence.db.exec("SELECT sync_point, chat_id, sender_id FROM messages WHERE mam_id=?", [version.serverId]);
		}).then(rows -> {
			final row = rows.next();
			Assert.equals(1, row.sync_point);
			Assert.equals("correctable-chat@example.com", row.chat_id);
			Assert.equals("correctable@example.com", row.sender_id);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testCorrectableMessageStorageFallsBackToLocalIdForCorrectionId(async: Async) {
		final account = "alice@example.com";
		final version = makeMessage({
			timestamp: "2020-01-01T00:00:00Z",
			localId: "version-local-local",
			serverId: "version-local-server"
		});
		final correctable = makeMessage({
			timestamp: "2020-01-01T00:00:01Z",
			localId: "correctable-local-local",
			serverId: "correctable-local-server",
			versions: [version]
		});

		persistence.storeMessages(account, [correctable]).then(_ -> {
			return persistence.db.exec("SELECT correction_id FROM messages WHERE mam_id=?", [version.serverId]);
		}).then(rows -> {
			Assert.equals("correctable-local-local", rows.next().correction_id);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testCorrectableMessageStorageFallsBackToServerIdForCorrectionId(async: Async) {
		final account = "alice@example.com";
		final version = makeMessage({
			timestamp: "2020-01-01T00:00:00Z",
			localId: "version-server-local",
			serverId: "version-server-server"
		});
		final correctable = makeMessage({
			timestamp: "2020-01-01T00:00:01Z",
			serverId: "correctable-server-server",
			versions: [version]
		});

		persistence.storeMessages(account, [correctable]).then(_ -> {
			return persistence.db.exec("SELECT correction_id FROM messages WHERE mam_id=?", [version.serverId]);
		}).then(rows -> {
			Assert.equals("correctable-server-server", rows.next().correction_id);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testMessageTimestampFormatting(async: Async) {
		final account = "alice@example.com";
		final message = makeMessage({
			timestamp: "2020-01-01T00:00:00.123Z",
			localId: "timestamp-local",
			serverId: "timestamp-server"
		});

		persistence.storeMessages(account, [message]).then(_ -> {
			return persistence.db.exec("SELECT strftime('%FT%H:%M:%fZ', created_at / 1000.0, 'unixepoch') AS timestamp FROM messages WHERE mam_id=?", [message.serverId]);
		}).then(rows -> {
			Assert.equals("2020-01-01T00:00:00.123Z", rows.next().timestamp);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testGetMessagesByStatus(async: Async) {
		final account = "alice@example.com";
		final pendingOld = makeMessage({
			timestamp: "2020-01-01T00:00:00Z",
			localId: "pending-old",
			status: MessagePending
		});
		final delivered = makeMessage({
			timestamp: "2020-01-01T00:00:01Z",
			localId: "delivered",
			status: MessageDeliveredToServer
		});
		final pendingNew = makeMessage({
			timestamp: "2020-01-01T00:00:02Z",
			localId: "pending-new",
			status: MessagePending
		});
		final otherAccountPending = makeMessage({
			timestamp: "2020-01-01T00:00:03Z",
			localId: "other-account-pending",
			status: MessagePending
		});

		persistence.storeMessages(account, [pendingNew, delivered, pendingOld]).then(_ -> {
			return persistence.storeMessages("other@example.com", [otherAccountPending]);
		}).then(_ -> {
			return persistence.getMessagesByStatus(account, MessagePending);
		}).then(messages -> {
			Assert.equals(2, messages.length);
			Assert.equals("pending-old", messages[0].localId);
			Assert.equals("pending-new", messages[1].localId);
			Assert.equals(MessagePending, messages[0].status);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	private function makeMessage(params: {
		timestamp: String,
		?localId: String,
		?serverId: String,
		?serverIdBy: String,
		?senderId: String,
		?chatId: String,
		?versions: Array<ChatMessage>,
		?callSid: String,
		?syncPoint: Bool,
		?sortId: String,
		?encryption: EncryptionInfo,
		?source: String,
		?body: String,
		?received: Bool,
		?status: MessageStatus
	}):ChatMessage {
		final senderId = params.senderId ?? "version@example.com";
		final chatId = params.chatId ?? "chat@example.com";
		final builder = new ChatMessageBuilder();
		builder.localId = params.localId;
		builder.serverId = params.serverId;
		builder.serverIdBy = params.serverId == null ? null : params.serverIdBy ?? "server.example.com";
		builder.senderId = senderId;
		builder.direction = params.received ?? false ? MessageReceived : MessageSent;
		builder.sortId = params.sortId ?? params.localId ?? params.serverId ?? "message";
		builder.timestamp = params.timestamp;
		builder.syncPoint = params.syncPoint ?? false;
		builder.status = params.status ?? MessagePending;
		builder.versions = params.versions ?? [];
		builder.encryption = params.encryption;
		if (params.source != null) builder.debug = { source: params.source };
		if (params.body != null) builder.setBody(Html.text(params.body));
		builder.to = JID.parse(chatId);
		builder.from = JID.parse(senderId);
		builder.recipients = [builder.to];
		builder.replyTo = [builder.from];
		if (params.callSid != null) {
			builder.payloads = [new Stanza("propose", { xmlns: "urn:xmpp:jingle-message:0", id: params.callSid })];
		}
		return builder.build();
	}

	public function testMessageEncryption(async: Async) {
		final account = "encryption-alice@example.com";
		final chatId = "encryption-hatter@example.com";
		final expectedEncryption = new EncryptionInfo(
			DecryptionFailure,
			"urn:xmpp:omemo:2",
			"invalid-key",
			"The sender key was invalid",
			"OMEMO 2"
		);
		final message = makeMessage({
			timestamp: "2026-08-26T12:00:00Z",
			serverId: "encrypted-message",
			serverIdBy: account,
			senderId: chatId,
			chatId: account,
			received: true,
			sortId: "encrypted-a0",
			syncPoint: true,
			body: "Encrypted persistence marker",
			encryption: expectedEncryption
		});

		persistence.storeMessages(account, [message]).then(stored -> {
			assertEncryption(stored[0], expectedEncryption);
			return persistence.getMessage(account, chatId, "encrypted-message", null);
		}).then(fetched -> {
			assertEncryption(fetched, expectedEncryption);
			return persistence.searchMessages(account, chatId, "persistence marker");
		}).then(searched -> {
			Assert.equals(1, searched.length);
			assertEncryption(searched[0], expectedEncryption);
			return persistence.getMessagesBefore(account, chatId, null);
		}).then(paged -> {
			Assert.equals(1, paged.length);
			assertEncryption(paged[0], expectedEncryption);
			return persistence.syncPoint(account, null);
		}).then(syncPoint -> {
			assertEncryption(syncPoint, expectedEncryption);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testCorrectedMessageEncryption(async: Async) {
		final account = "encryption-correction-alice@example.com";
		final chatId = "encryption-correction-hatter@example.com";
		final originalExpected = {
			text: "Original encrypted text",
			encryption: new EncryptionInfo(DecryptionSuccess, "urn:xmpp:omemo:1", null, null, "OMEMO 1")
		};
		final original = makeMessage({
			timestamp: "2026-08-26T12:00:00Z",
			localId: "encrypted-original",
			senderId: account,
			chatId: chatId,
			sortId: "encrypted-c0",
			body: originalExpected.text,
			source: "outgoing",
			encryption: originalExpected.encryption
		});
		final correctionExpected = {
			text: "Corrected encrypted text",
			encryption: new EncryptionInfo(
				DecryptionFailure,
				"urn:xmpp:omemo:2",
				"invalid-key",
				"Correction could not be decrypted",
				"OMEMO 2"
			)
		};
		final correctionVersion = makeMessage({
			timestamp: "2026-08-26T12:01:00Z",
			localId: "encrypted-correction",
			senderId: account,
			chatId: chatId,
			sortId: "encrypted-c0",
			body: correctionExpected.text,
			source: "mam",
			encryption: correctionExpected.encryption
		});
		final correctable = makeMessage({
			timestamp: "2026-08-26T12:01:00Z",
			localId: original.localId,
			senderId: account,
			chatId: chatId,
			sortId: "encrypted-c0",
			versions: [correctionVersion]
		});

		persistence.storeMessages(account, [original]).then(_ -> {
			return persistence.storeMessages(account, [correctable]);
		}).then(stored -> {
			final corrected = stored[0];
			Assert.equals(correctionExpected.text, corrected.text);
			Assert.equals("mam", corrected.debug.source);
			assertEncryption(corrected, correctionExpected.encryption);

			final storedCorrection = corrected.versions.find(version -> version.localId == correctionVersion.localId);
			Assert.notNull(storedCorrection);
			Assert.equals(correctionExpected.text, storedCorrection.text);
			Assert.equals("mam", storedCorrection.debug.source);
			assertEncryption(storedCorrection, correctionExpected.encryption);

			final storedOriginal = corrected.versions.find(version -> version.localId == original.localId);
			Assert.notNull(storedOriginal);
			Assert.equals(originalExpected.text, storedOriginal.text);
			Assert.equals("outgoing", storedOriginal.debug.source);
			assertEncryption(storedOriginal, originalExpected.encryption);

			return persistence.getMessagesBefore(account, chatId, null);
		}).then(fetched -> {
			Assert.equals(1, fetched.length);
			final corrected = fetched[0];
			Assert.equals(correctionExpected.text, corrected.text);
			Assert.equals("mam", corrected.debug.source);
			assertEncryption(corrected, correctionExpected.encryption);

			final fetchedCorrection = corrected.versions.find(version -> version.localId == correctionVersion.localId);
			Assert.notNull(fetchedCorrection);
			Assert.equals(correctionExpected.text, fetchedCorrection.text);
			Assert.equals("mam", fetchedCorrection.debug.source);
			assertEncryption(fetchedCorrection, correctionExpected.encryption);

			final fetchedOriginal = corrected.versions.find(version -> version.localId == original.localId);
			Assert.notNull(fetchedOriginal);
			Assert.equals(originalExpected.text, fetchedOriginal.text);
			Assert.equals("outgoing", fetchedOriginal.debug.source);
			assertEncryption(fetchedOriginal, originalExpected.encryption);

			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testStoreReaction(async: Async) {
		final account = "alice@example.com";
		final builder = new ChatMessageBuilder();
		builder.serverId = "srv1";
		builder.serverIdBy = "hatter@example.com";
		builder.senderId = "hatter@example.com";
		builder.direction = MessageReceived;
		builder.sortId = "a0";
		builder.to = JID.parse("alice@example.com");
		builder.from = JID.parse("hatter@example.com");
		builder.recipients = [builder.to];
		builder.replyTo = [builder.from];

		// Workaround for https://github.com/HaxeFoundation/haxe/issues/12914
		final key = haxe.io.Bytes.ofString("👍").toString();
		persistence.storeMessages(account, [builder.build()]).then(_ -> {
			final reaction = new Reaction("alice@example.com", "2020-01-01T00:00:01Z", key);
			final update = new ReactionUpdate(
				"up1",
				"srv1",
				"hatter@example.com",
				null,
				"hatter@example.com",
				"alice@example.com",
				"2020-01-01T00:00:01Z",
				[reaction],
				EmojiReactions
			);
			return persistence.storeReaction(account, update);
		}).then(msg -> {
			Assert.notNull(msg);
			final reactions = msg.reactions;
			Assert.equals(1, Lambda.count({ iterator: () -> reactions.iterator() }));
			Assert.isTrue(reactions.exists(key));
			Assert.equals(1, reactions.get(key).length);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testUpdateMessageStatus(async: Async) {
		final account = "alice@example.com";
		final expectedEncryption = new EncryptionInfo(DecryptionSuccess, "eu.siacs.conversations.axolotl", null, null, "OMEMO");
		final builder = new ChatMessageBuilder();
		builder.localId = "loc1";
		builder.senderId = "alice@example.com";
		builder.direction = MessageSent;
		builder.sortId = "a0";
		builder.to = JID.parse("hatter@example.com");
		builder.from = JID.parse("alice@example.com");
		builder.recipients = [builder.to];
		builder.replyTo = [builder.from];
		builder.encryption = expectedEncryption;

		persistence.storeMessages(account, [builder.build()]).then(_ -> {
			return persistence.updateMessageStatus(account, "loc1", MessageDeliveredToServer, "Delivered");
		}).then(updated -> {
			Assert.equals(MessageDeliveredToServer, updated.status);
			Assert.equals("Delivered", updated.statusText);
			assertEncryption(updated, expectedEncryption);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	private function assertEncryption(message: Null<ChatMessage>, expected: EncryptionInfo) {
		Assert.notNull(message);
		Assert.notNull(message.encryption);
		Assert.equals(expected.status, message.encryption.status);
		Assert.equals(expected.method, message.encryption.method);
		Assert.equals(expected.methodName, message.encryption.methodName);
		Assert.equals(expected.reason, message.encryption.reason);
		Assert.equals(expected.reasonText, message.encryption.reasonText);
	}

	public function testSearchMessages(async: Async) {
		final account = "alice@example.com";
		final builder = new ChatMessageBuilder();
		builder.serverId = "srv1";
		builder.serverIdBy = "hatter@example.com";
		builder.senderId = "hatter@example.com";
		builder.direction = MessageReceived;
		builder.sortId = "a0";
		builder.setBody(Html.text("Hello world"));
		builder.to = JID.parse("alice@example.com");
		builder.from = JID.parse("hatter@example.com");
		builder.recipients = [builder.to];
		builder.replyTo = [builder.from];

		final builder2 = new ChatMessageBuilder();
		builder2.serverId = "srv2";
		builder2.serverIdBy = "hatter@example.com";
		builder2.senderId = "hatter@example.com";
		builder2.direction = MessageReceived;
		builder2.sortId = "a1";
		builder2.setBody(Html.text("Goodbye world"));
		builder2.to = JID.parse("alice@example.com");
		builder2.from = JID.parse("hatter@example.com");
		builder2.recipients = [builder2.to];
		builder2.replyTo = [builder2.from];

		persistence.storeMessages(account, [builder.build(), builder2.build()]).then(_ -> {
			return persistence.searchMessages(account, "hatter@example.com", "hello");
		}).then(results -> {
			Assert.equals(1, results.length);
			Assert.equals("Hello world", results[0].text);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testRemoveAccount(async: Async) {
		final account1 = "alice@example.com";
		final account2 = "bob@example.com";

		persistence.storeLogin(account1, "client1", "Alice", null, null);
		persistence.storeLogin(account2, "client2", "Bob", null, null);

		persistence.listAccounts().then(accountsBefore -> {
			Assert.contains(account1, accountsBefore);
			Assert.contains(account2, accountsBefore);
			persistence.removeAccount(account1, true);
		}).then(_ -> {
			return persistence.listAccounts();
		}).then(accountsAfter -> {
			Assert.notContains(account1, accountsAfter);
			Assert.contains(account2, accountsAfter);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testGetChatUnreadDetails(async: Async) {
		final account = "alice@example.com";
		final chat = new DirectChat(cast null, cast null, persistence, "hatter@example.com");
		chat.displayName = "A Chat";
		chat.readUpToId = "srv1";

		final builder = new ChatMessageBuilder();
		builder.serverId = "srv1";
		builder.serverIdBy = "hatter@example.com";
		builder.senderId = "hatter@example.com";
		builder.direction = MessageReceived;
		builder.sortId = "a0";
		builder.to = JID.parse("alice@example.com");
		builder.from = JID.parse("hatter@example.com");
		builder.recipients = [builder.to];
		builder.replyTo = [builder.from];

		final builder2 = new ChatMessageBuilder();
		builder2.serverId = "srv2";
		builder2.serverIdBy = "hatter@example.com";
		builder2.senderId = "hatter@example.com";
		builder2.direction = MessageReceived;
		builder2.sortId = "a1";
		builder2.to = JID.parse("alice@example.com");
		builder2.from = JID.parse("hatter@example.com");
		builder2.recipients = [builder2.to];
		builder2.replyTo = [builder2.from];

		persistence.storeMessages(account, [builder.build(), builder2.build()]).then(_ -> {
			return persistence.getChatUnreadDetails(account, chat);
		}).then(result -> {
			Assert.equals(1, result.unreadCount);
			Assert.equals("srv2", result.message.serverId);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testMedia(async: Async) {
		final bytes = haxe.io.Bytes.ofString("hello");
		persistence.storeMedia("image/png", bytes).then(_ -> {
			return persistence.hasMedia(Hash.sha256(bytes));
		}).then(hasBefore -> {
			Assert.equals("ni:///sha-256;LPJNul-wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ", hasBefore);
			persistence.removeMedia("sha-256", Hash.sha256(bytes).hash);
		}).then(_ -> {
			return persistence.hasMedia(Hash.sha256(bytes));
		}).then(hasAfter -> {
			Assert.isNull(hasAfter);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testHydrateReplyTo(async: Async) {
		final account = "alice@example.com";
		final builder = new ChatMessageBuilder();
		builder.serverId = "parent";
		builder.serverIdBy = "hatter@example.com";
		builder.localId = "loc1";
		builder.senderId = "hatter@example.com";
		builder.direction = MessageReceived;
		builder.sortId = "a0";
		builder.to = JID.parse("alice@example.com");
		builder.from = JID.parse("hatter@example.com");
		builder.recipients = [builder.to];
		builder.replyTo = [builder.from];
		builder.type = MessageChannel;
		final parentStub = builder.build();

		builder.setBody(Html.text("Hello"));
		final parentMsg = builder.build();

		final builder2 = new ChatMessageBuilder();
		builder2.serverId = "child";
		builder2.serverIdBy = "hatter@example.com";
		builder2.localId = "loc2";
		builder2.senderId = "hatter@example.com";
		builder2.direction = MessageReceived;
		builder2.sortId = "a1";
		builder2.to = JID.parse("alice@example.com");
		builder2.from = JID.parse("hatter@example.com");
		builder2.recipients = [builder2.to];
		builder2.replyTo = [builder2.from];
		builder2.replyToMessage = parentStub;
		builder2.type = MessageChannel;
		final childMsg = builder2.build();

		persistence.storeMessages(account, [parentMsg]).then(_ -> {
			return persistence.storeMessages(account, [childMsg]);
		}).then(msgs -> {
			final childStored = msgs[0];
			Assert.notNull(childStored.replyToMessage);
			Assert.equals("Hello", childStored.replyToMessage.text);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testStoreChatsWithStatus(async: Async) {
		final account = "alice@example.com";
		final chat = new DirectChat(cast null, cast null, persistence, "hatter@example.com");
		chat.displayName = "The Mad Hatter";
		chat.trusted = true;
		chat.status = new Status("🎩", "Time for tea!");

		persistence.storeChats(account, [chat]);
		haxe.Timer.delay(() -> {
			persistence.getChats(account).then(chats -> {
				Assert.equals(1, chats.length);
				Assert.equals("hatter@example.com", chats[0].chatId);
				Assert.equals("🎩", chats[0].status.emoji);
				Assert.equals("Time for tea!", chats[0].status.text);
				async.done();
			}).catchError(e -> {
				Assert.fail(Std.string(e));
				async.done();
			});
		}, 200);
	}

	public function testGetChatsUsesMemberPresenceForDirectChats(async: Async) {
		final account = "alice@example.com";
		final chat = new DirectChat(cast null, cast null, persistence, "hatter@example.com");
		chat.displayName = "The Mad Hatter";
		chat.trusted = true;
		chat.setPresence("desk", Stanza.parse("<presence />"), true);

		persistence.storeChats(account, [chat]);
		persistence.storeMembers(account, chat.chatId, [
			new Member(
				"hatter@example.com",
				"The Mad Hatter",
				null,
				false,
				[],
				JID.parse("hatter@example.com"),
				["phone" => Stanza.parse("<presence />")],
				null
			)
		]).then(_ -> {
			haxe.Timer.delay(() -> {
				persistence.getChats(account).then(chats -> {
					final stored = chats[0];
					Assert.equals(1, [for (_ in stored.presence.keys()) _].length);
					Assert.notNull(stored.presence["phone"]);
					Assert.isNull(stored.presence["desk"]);
					async.done();
				}).catchError(e -> {
					Assert.fail(Std.string(e));
					async.done();
				});
			}, 200);
			return null;
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testGetChatsHydratesMembersForNameAndMavUntil(async: Async) {
		final account = "alice@example.com";
		final chat = new Channel(cast null, cast null, persistence, "room-chat-hydrate@example.com");
		chat.displayName = "Tea Room";
		chat.mavUntil = "2024-05-01T12:00:00Z";

		persistence.storeChats(account, [chat]);
		persistence.storeMembers(account, chat.chatId, [
			new Member(
				chat.chatId,
				"Tea Room",
				null,
				false,
				[],
				JID.parse(chat.chatId),
				new Map(),
				null
			),
			new Member(
				chat.chatId + "/self",
				"Myself",
				null,
				true,
				[new Role("owner", "Owner")],
				JID.parse("alice@example.com"),
				["desk" => Stanza.parse("<presence />")],
				null
			),
			new Member(
				chat.chatId + "/zulu",
				"Zulu",
				null,
				false,
				[new Role("admin", "Admin")],
				JID.parse("zulu@example.com"),
				["desk" => Stanza.parse("<presence />")],
				new AvailableChat("zulu@example.com", "Zulu", "", new borogove.Caps("", [], [], []))
			),
			new Member(
				chat.chatId + "/alpha",
				"Alpha",
				null,
				false,
				[],
				JID.parse("alpha@example.com"),
				["desk" => Stanza.parse("<presence />")],
				new AvailableChat("alpha@example.com", "Alpha", "", new borogove.Caps("", [], [], []))
			),
			new Member(
				chat.chatId + "/hidden",
				"Hidden",
				null,
				false,
				[new Role("none", "Guest")],
				JID.parse("hidden@example.com"),
				["desk" => Stanza.parse("<presence />")],
				new AvailableChat("hidden@example.com", "Hidden", "", new borogove.Caps("", [], [], []))
			)
		]).then(_ -> {
			haxe.Timer.delay(() -> {
				persistence.getChats(account).then(chats -> {
					final stored = chats[0];
					Assert.notNull(stored.membersForName);
					Assert.equals("2024-05-01T12:00:00Z", stored.mavUntil);
					Assert.equals(2, stored.membersForName.length);
					Assert.equals("Alpha", stored.membersForName[0].displayName);
					Assert.equals("Zulu", stored.membersForName[1].displayName);
					Assert.equals(1, [for (_ in stored.presence.keys()) _].length);
					Assert.notNull(stored.presence["desk"]);
					async.done();
				}).catchError(e -> {
					Assert.fail(Std.string(e));
					async.done();
				});
			}, 200);
			return null;
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testStoreStreamManamagementAndGetStreamManagement(async: Async) {
		persistence.storeLogin("alice@example.com", "", "", null, null).then(_ ->
			persistence.storeStreamManagement("alice@example.com", Bytes.ofHex("01020004").getData(), "ZZ")
		).then(_ ->
			persistence.getStreamManagement("alice@example.com")
		).then(result -> {
			Assert.equals(Bytes.ofData(result.sm).toHex(), "01020004");
			Assert.isTrue(Std.isOfType(result.sm, BytesData), "Should be BytesData");
			Assert.equals(result.sortId, "ZZ");
			async.done();
		});
	}

	public function testGetMembersHydratesPersistedMemberData(async: Async) {
		final account = "alice@example.com";
		final chat = new Channel(cast null, cast null, persistence, "room-members-1@example.com");
		chat.displayName = "A Chat";
		chat.trusted = true;
		final member = new Member(
			"room-members-1@example.com/occ-1",
			"Alice",
			"photo:alice",
			false,
			[new Role("admin", "Admin")],
			JID.parse("alice@example.com"),
			["laptop" => Stanza.parse('<presence><show>away</show></presence>')],
			new AvailableChat("alice@example.com", "Alice", "", new borogove.Caps("", [], [], []))
		);

		persistence.storeMembers(account, chat.chatId, [member]).then(_ ->
			persistence.getMembers(account, chat, false)
		).then(result -> {
			Assert.equals(1, result.length);
			Assert.equals(member.id, result[0].id);
			Assert.equals("Alice", result[0].displayName);
			Assert.equals("alice@example.com", result[0].chat.chatId);
			Assert.equals("admin", result[0].roles[0].id);
			Assert.notNull(result[0].presence.get("laptop"));
			Assert.equals(1, cast(result[0].showPresence, Int));
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testStoreMemberUpdatesMergesExistingMemberData(async: Async) {
		final account = "alice@example.com";
		final chat = new Channel(cast null, cast null, persistence, "room-members-2@example.com");
		chat.displayName = "A Chat";

		persistence.storeMembers(account, chat.chatId, [
			new Member(
				"room-members-2@example.com/occ-1",
				"Alice",
				null,
				false,
				[new Role("admin", "Admin"), new Role("urn:xmpp:hats:test", "Tea Host")],
				JID.parse("alice@example.com"),
				["desk" => Stanza.parse("<presence />")],
				new AvailableChat("alice@example.com", "Alice", "", new borogove.Caps("", [], [], []))
			)
		]).then(_ ->
			persistence.storeMemberUpdates(account, chat, [
				new MemberUpdate(
					"room-members-2@example.com/occ-1",
					JID.parse("alice@example.com"),
					"Alice Cooper",
					false,
					null,
					["mobile" => Stanza.parse("<presence />")]
				)
			], false)
		).then(result -> {
			Assert.equals(1, result.length);
			Assert.equals("Alice Cooper", result[0].displayName);
			Assert.equals(1, result[0].roles.length);
			Assert.equals("urn:xmpp:hats:test", result[0].roles[0].id);
			Assert.notNull(result[0].presence.get("desk"));
			Assert.notNull(result[0].presence.get("mobile"));
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testStoreMemberUpdatesClearsOmittedFullListAffiliations(async: Async) {
		final account = "alice@example.com";
		final chat = new Channel(cast null, cast null, persistence, "room-members-2b@example.com");
		chat.displayName = "A Chat";

		persistence.storeMembers(account, chat.chatId, [
			new Member(
				"room-members-2b@example.com/occ-1",
				"Alice",
				null,
				false,
				[new Role("admin", "Admin")],
				JID.parse("alice@example.com"),
				new Map(),
				new AvailableChat("alice@example.com", "Alice", "", new borogove.Caps("", [], [], []))
			),
			new Member(
				"room-members-2b@example.com/occ-2",
				"Bob",
				null,
				false,
				[new Role("owner", "Owner")],
				JID.parse("bob@example.com"),
				new Map(),
				new AvailableChat("bob@example.com", "Bob", "", new borogove.Caps("", [], [], []))
			)
		]).then(_ ->
			persistence.storeMemberUpdates(account, chat, [
				new MemberUpdate(
					"room-members-2b@example.com/occ-1",
					JID.parse("alice@example.com"),
					"Alice",
					false,
					null,
					new Map()
				)
			], true)
			).then(_ ->
				persistence.getMembers(account, chat, true)
			).then(result -> {
				var bob: Null<Member> = null;
				for (member in result) {
					if (member.id == "room-members-2b@example.com/occ-2") {
						bob = member;
						break;
					}
				}
				Assert.notNull(bob);
				if (bob != null) Assert.equals(0, bob.roles.length);
				async.done();
			}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testStoreMemberUpdatesMatchesExistingMemberByTrueJid(async: Async) {
		final account = "alice@example.com";
		final chat = new Channel(cast null, cast null, persistence, "room-members-3@example.com");
		chat.displayName = "A Chat";

		persistence.storeMembers(account, chat.chatId, [
			new Member(
				"room-members-3@example.com/occ-1",
				"Alice",
				null,
				false,
				[new Role("admin", "Admin")],
				JID.parse("alice@example.com"),
				new Map(),
				new AvailableChat("alice@example.com", "Alice", "", new borogove.Caps("", [], [], []))
			)
		]).then(_ ->
			persistence.storeMemberUpdates(account, chat, [
				new MemberUpdate(
					null,
					JID.parse("alice@example.com"),
					"Alice Renamed",
					false,
					null,
					new Map()
				)
			], false)
		).then(_ ->
			persistence.getMemberDetails(account, chat, ["room-members-3@example.com/occ-1"])
		).then(result -> {
			Assert.notNull(result[0]);
			Assert.equals("Alice Renamed", result[0].displayName);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testClearMemberPresenceOnlyClearsTargetedChat(async: Async) {
		final account = "alice@example.com";
		final chat1 = new Channel(cast null, cast null, persistence, "room-members-4a@example.com");
		chat1.displayName = "A Chat";
		final chat2 = new Channel(cast null, cast null, persistence, "room-members-4b@example.com");
		chat2.displayName = "A Chat";

		persistence.storeMembers(account, chat1.chatId, [
			new Member(
				"room-members-4a@example.com/occ-1",
				"Alice",
				null,
				false,
				[new Role("admin", "Admin")],
				JID.parse("alice@example.com"),
				["desk" => Stanza.parse("<presence />")],
				new AvailableChat("alice@example.com", "Alice", "", new borogove.Caps("", [], [], []))
			)
		]).then(_ ->
			persistence.storeMembers(account, chat2.chatId, [
				new Member(
					"room-members-4b@example.com/occ-1",
					"Bob",
					null,
					false,
					[new Role("admin", "Admin")],
					JID.parse("bob@example.com"),
					["phone" => Stanza.parse("<presence />")],
					new AvailableChat("bob@example.com", "Bob", "", new borogove.Caps("", [], [], []))
				)
			])
		).then(_ ->
			persistence.clearMemberPresence(account, chat1.chatId)
		).then(_ ->
			persistence.getMemberDetails(account, chat1, ["room-members-4a@example.com/occ-1"]).then(result1 ->
				persistence.getMemberDetails(account, chat2, ["room-members-4b@example.com/occ-1"]).then(result2 ->
					Promise.resolve([result1[0], result2[0]])
				)
			)
		).then(result -> {
			Assert.notNull(result[0]);
			Assert.notNull(result[1]);
			Assert.equals(0, result[0].presence.keys().hasNext() ? 1 : 0);
			Assert.notNull(result[1].presence.get("phone"));
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testGetMembersFiltersHiddenRowsForNonModerators(async: Async) {
		final account = "alice@example.com";
		final chat = new Channel(cast null, cast null, persistence, "room-members-5@example.com");
		chat.displayName = "A Chat";

		persistence.storeMembers(account, chat.chatId, [
			new Member("room-members-5@example.com/owner", "Zulu", null, false, [new Role("owner", "Owner")], JID.parse("zulu@example.com"), ["desk" => Stanza.parse("<presence />")], new AvailableChat("zulu@example.com", "Zulu", "", new borogove.Caps("", [], [], []))),
			new Member("room-members-5@example.com/outcast", "Banned", null, false, [new Role("outcast", "Banned")], JID.parse("banned@example.com"), ["desk" => Stanza.parse("<presence />")], new AvailableChat("banned@example.com", "Banned", "", new borogove.Caps("", [], [], []))),
			new Member("room-members-5@example.com/guest-offline", "Guest", null, false, [new Role("none", "Guest")], JID.parse("guest@example.com"), ["desk" => Stanza.parse('<presence type="unavailable" />')], new AvailableChat("guest@example.com", "Guest", "", new borogove.Caps("", [], [], []))),
			new Member("room-members-5@example.com/admin", "Alpha", null, false, [new Role("admin", "Admin")], JID.parse("alpha@example.com"), ["desk" => Stanza.parse("<presence />")], new AvailableChat("alpha@example.com", "Alpha", "", new borogove.Caps("", [], [], [])))
		]).then(_ ->
			persistence.getMembers(account, chat, false)
		).then(result -> {
			Assert.same(["Zulu", "Alpha"], result.map(m -> m.displayName));
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testGetMembersTreatsEmptyPresenceAsOffline(async: Async) {
		final account = "alice@example.com";
		final chat = new Channel(cast null, cast null, persistence, "room-members-empty-presence@example.com");
		chat.displayName = "A Chat";

		persistence.storeMembers(account, chat.chatId, [
			new Member(
				"room-members-empty-presence@example.com/guest",
				"Guest",
				null,
				false,
				[new Role("none", "Guest")],
				JID.parse("guest@example.com"),
				new Map(),
				new AvailableChat("guest@example.com", "Guest", "", new borogove.Caps("", [], [], []))
			)
		]).then(_ ->
			persistence.getMembers(account, chat, false)
		).then(result -> {
			Assert.equals(0, result.length);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testGetMembersIncludesModeratorVisibleRows(async: Async) {
		final account = "alice@example.com";
		final chat = new Channel(cast null, cast null, persistence, "room-members-6@example.com");
		chat.displayName = "A Chat";

		persistence.storeMembers(account, chat.chatId, [
			new Member("room-members-6@example.com/owner", "Zulu", null, false, [new Role("owner", "Owner")], JID.parse("zulu@example.com"), ["desk" => Stanza.parse("<presence />")], new AvailableChat("zulu@example.com", "Zulu", "", new borogove.Caps("", [], [], []))),
			new Member("room-members-6@example.com/outcast", "Banned", null, false, [new Role("outcast", "Banned")], JID.parse("banned@example.com"), ["desk" => Stanza.parse("<presence />")], new AvailableChat("banned@example.com", "Banned", "", new borogove.Caps("", [], [], []))),
			new Member("room-members-6@example.com/guest-offline", "Guest", null, false, [new Role("none", "Guest")], JID.parse("guest@example.com"), ["desk" => Stanza.parse('<presence type="unavailable" />')], new AvailableChat("guest@example.com", "Guest", "", new borogove.Caps("", [], [], []))),
			new Member("room-members-6@example.com/admin", "Alpha", null, false, [new Role("admin", "Admin")], JID.parse("alpha@example.com"), ["desk" => Stanza.parse("<presence />")], new AvailableChat("alpha@example.com", "Alpha", "", new borogove.Caps("", [], [], [])))
		]).then(_ ->
			persistence.getMembers(account, chat, true)
		).then(result -> {
			Assert.same(["Zulu", "Alpha", "Banned"], result.map(m -> m.displayName));
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testGetMemberDetailsReturnsNullForIncompleteRows(async: Async) {
		final account = "alice@example.com";
		final chat = new Channel(cast null, cast null, persistence, "room-members-7@example.com");
		chat.displayName = "A Chat";

		persistence.storeMembers(account, chat.chatId, [
			new Member(
				"room-members-7@example.com/admin",
				"Alpha",
				null,
				false,
				[new Role("admin", "Admin")],
				JID.parse("alpha@example.com"),
				["desk" => Stanza.parse("<presence />")],
				new AvailableChat("alpha@example.com", "Alpha", "", new borogove.Caps("", [], [], []))
			)
		]).then(_ -> {
			return untyped persistence.db.exec('INSERT INTO members(account_id, chat_id, member_id, display_name, photo_uri, is_self, chat, roles, presence, jid) VALUES(?, ?, ?, ?, ?, ?, ?, jsonb(?), jsonb(?), ?)', [
				account,
				chat.chatId,
				"room-members-7@example.com/incomplete",
				"",
				null,
				0,
				"{}",
				"[]",
				"{}",
				""
			]);
		}).then(_ ->
			persistence.getMemberDetails(account, chat, [
				"room-members-7@example.com/admin",
				"room-members-7@example.com/incomplete"
			])
		).then(result -> {
			Assert.equals("Alpha", result[0]?.displayName);
			Assert.isNull(result[1]);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

	public function testVoiceRequests(async: Async) {
		final account = "alice@example.com";
		final chat = new Channel(cast null, cast null, persistence, "room-voice-requests@example.com");
		chat.displayName = "A Chat";

		persistence.storeMembers(account, chat.chatId, [
			new Member("room-voice-requests@example.com/bob", "Bob", null, false, [new Role("none", "Participant")], JID.parse("bob@example.com"), ["desk" => Stanza.parse("<presence />")], new AvailableChat("bob@example.com", "Bob", "", new borogove.Caps("", [], [], []))),
			new Member("room-voice-requests@example.com/charlie", "Charlie", null, false, [new Role("none", "Participant")], JID.parse("charlie@example.com"), ["desk" => Stanza.parse("<presence />")], new AvailableChat("charlie@example.com", "Charlie", "", new borogove.Caps("", [], [], [])))
		]).then(_ ->
			persistence.storeVoiceRequest(account, chat, "bob@example.com", true)
		).then(_ ->
			persistence.storeVoiceRequest(account, chat, "charlie@example.com", true)
		).then(_ ->
			persistence.listVoiceRequests(account, chat)
		).then(reqs1 -> {
			final reqsNames = reqs1.map(m -> m.displayName);
			reqsNames.sort((a, b) -> Reflect.compare(a, b));
			Assert.same(["Bob", "Charlie"], reqsNames);
			return persistence.storeVoiceRequest(account, chat, "bob@example.com", false);
		}).then(_ ->
			persistence.listVoiceRequests(account, chat)
		).then(reqs2 -> {
			final reqsNames2 = reqs2.map(m -> m.displayName);
			Assert.same(["Charlie"], reqsNames2);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}

#if !NO_OMEMO
	public function testGetOmemoIdNotFound(async: Async) {
		persistence
			.getOmemoId('notfound@example.com')
			.then(result -> {
				Assert.equals(null, result);
				async.done();
			})
			.catchError(e -> {
				Assert.fail(Std.string(e));
				async.done();
			});
	}

	public function testGetOmemoIdExisting(async: Async) {
		final login = "existing@example.com";
		final omemoId = 12345;

		persistence
			.storeOmemoId(login, omemoId)
			.then(_ -> persistence.getOmemoId(login))
			.then(result -> {
				Assert.equals(omemoId, result);
				async.done();
			})
			.catchError(e -> {
				Assert.fail(Std.string(e));
				async.done();
			});
	}

	public function testGetOmemoIdentityKeyNotFound(async: Async) {
		persistence
			.getOmemoIdentityKey("identity-notfound@example.com")
			.then(result -> {
				Assert.equals(null, result);
				async.done();
			})
			.catchError(e -> {
				Assert.fail(Std.string(e));
				async.done();
			});
	}

	public function testOmemoIdentityKey(async: Async) {
		final login = "identity-existing@example.com";
		final keyPair = makeKeyPair();

		persistence
			.storeOmemoIdentityKey(login, keyPair)
			.then(_ -> persistence.getOmemoIdentityKey(login))
			.then(result -> {
				assertKeyPairMatches(keyPair, result);
				async.done();
			})
			.catchError(e -> {
				Assert.fail(Std.string(e));
				async.done();
			});
	}

	public function testGetOmemoDeviceListNotFound(async: Async) {
		persistence
			.getOmemoDeviceList("devices-notfound@example.com")
			.then(result -> {
				Assert.same([], result);
				async.done();
			})
			.catchError(e -> {
				Assert.fail(Std.string(e));
				async.done();
			});
	}

	public function testOmemoDeviceList(async: Async) {
		final identifier = "devices-existing@example.com";
		persistence
			.storeOmemoDeviceList(identifier, [1, 2, 3])
			.then(_ -> persistence.getOmemoDeviceList(identifier))
			.then(initial -> {
				Assert.same([1, 2, 3], initial);
				return persistence.storeOmemoDeviceList(identifier, [4, 5]);
			})
			.then(_ -> persistence.getOmemoDeviceList(identifier))
			.then(replaced -> {
				Assert.same([4, 5], replaced);
				return persistence.storeOmemoDeviceList(identifier, []);
			})
			.then(_ -> persistence.getOmemoDeviceList(identifier))
			.then(cleared -> {
				Assert.same([], cleared);
				async.done();
			})
			.catchError(e -> {
				Assert.fail(Std.string(e));
				async.done();
			});
	}

	public function testGetOmemoPreKeyNotFound(async: Async) {
		persistence
			.getOmemoPreKey("prekey-notfound@example.com", 1)
			.then(result -> {
				Assert.equals(null, result);
				async.done();
			})
			.catchError(e -> {
				Assert.fail(Std.string(e));
				async.done();
			});
	}

	public function testOmemoPreKey(async: Async) {
		final login = "prekey-existing@example.com";
		final keyId = 42;
		final keyPair = makeKeyPair();

		persistence
			.storeOmemoPreKey(login, keyId, keyPair)
			.then(_ -> persistence.getOmemoPreKey(login, keyId))
			.then(result -> {
				assertKeyPairMatches(keyPair, result);
				return persistence.removeOmemoPreKey(login, keyId);
			})
			.then(_ -> persistence.getOmemoPreKey(login, keyId))
			.then(result -> {
				Assert.equals(null, result);
				async.done();
			})
			.catchError(e -> {
				Assert.fail(Std.string(e));
				async.done();
			});
	}

	public function testOmemoPreKeys(async: Async) {
		final login = "prekeys-existing@example.com";
		final preKeys = [
			{
				login: login,
				keyId: 2,
				keyPair: makeKeyPair(),
			},
			{
				login: login,
				keyId: 3,
				keyPair: makeKeyPair(),
			},
		];

		PromiseTools.all(preKeys.map(preKey ->
			persistence.storeOmemoPreKey(
				preKey.login,
				preKey.keyId,
				preKey.keyPair,
			)
		))
			.then(_ -> persistence.getOmemoPreKeys(login))
			.then(result -> {
				Assert.equals(preKeys.length, result.length);
				for (expected in preKeys) {
					final actual = result.find(preKey -> preKey.keyId == expected.keyId);
					Assert.notNull(actual, "Can't find preKey with id "+expected.keyId);
					if (actual != null) {
						assertKeyPairMatches(expected.keyPair, actual.keyPair);
					}
				}
				async.done();
			})
			.catchError(e -> {
				Assert.fail(Std.string(e));
				async.done();
			});
	}

	public function testGetOmemoContactIdentityKeyNotFound(async: Async) {
		persistence
			.getOmemoContactIdentityKey(
				"contact-notfound@example.com",
				"contact@example.com/1",
			)
			.then(result -> {
				Assert.equals(null, result);
				async.done();
			})
			.catchError(e -> {
				Assert.fail(Std.string(e));
				async.done();
			});
	}

	public function testOmemoContactIdentityKey(async: Async) {
		final account = "contact-existing@example.com";
		final address = "contact@example.com/1";
		final identityKey = makeKey();

		persistence
			.storeOmemoContactIdentityKey(account, address, identityKey)
			.then(_ -> persistence.getOmemoContactIdentityKey(account, address))
			.then(result -> {
				assertKeyMatches(identityKey, result);
				async.done();
			})
			.catchError(e -> {
				Assert.fail(Std.string(e));
				async.done();
			});
	}

	public function testGetOmemoSessionNotFound(async: Async) {
		persistence
			.getOmemoSession("session-notfound@example.com", "contact@example.com/1")
			.then(result -> {
				Assert.equals(null, result);
				async.done();
			})
			.catchError(e -> {
				Assert.fail(Std.string(e));
				async.done();
			});
	}

	public function testGetOmemoMetadataNotFound(async: Async) {
		persistence
			.getOmemoMetadata("metadata-notfound@example.com", "contact@example.com/1")
			.then(result -> {
				Assert.equals(null, result);
				async.done();
			})
			.catchError(e -> {
				Assert.fail(Std.string(e));
				async.done();
			});
	}

	public function testOmemoMetadata(async: Async) {
		final account = "metadata-existing@example.com";
		final address = "contact@example.com/1";
		final metadata = new OMEMOSessionMetadata(true, false, true);

		persistence
			.storeOmemoMetadata(account, address, metadata)
			.then(_ -> persistence.getOmemoMetadata(account, address))
			.then(result -> {
				Assert.equals(metadata.receivedSessionMessageOk, result.receivedSessionMessageOk);
				Assert.equals(metadata.lastMessageDecryptedOk, result.lastMessageDecryptedOk);
				Assert.equals(metadata.sentKeyExchange, result.sentKeyExchange);
				async.done();
			})
			.catchError(e -> {
				Assert.fail(Std.string(e));
				async.done();
			});
	}

	public function testOmemoSession(async: Async) {
		final account = "session-existing@example.com";
		final address = "contact@example.com/1";
		final session = new SignalSession('{"sessions":{},"version":"v1"}');

		persistence
			.storeOmemoSession(account, address, session)
			.then(_ -> persistence.getOmemoSession(account, address))
			.then(result -> {
				Assert.equals(session, result);
				return persistence.removeOmemoSession(account, address);
			})
			.then(_ -> persistence.getOmemoSession(account, address))
			.then(result -> {
				Assert.equals(null, result);
				async.done();
			})
			.catchError(e -> {
				Assert.fail(Std.string(e));
				async.done();
			});
	}

	public function testOmemoSignedPreKey(async: Async) {
		final login = "signed-prekey@example.com";
		final signedPreKey = {
			keyId: 42,
			keyPair: makeKeyPair(),
			signature: makeKey(),
		};

		persistence
			.storeOmemoSignedPreKey(login, signedPreKey)
			.then(_ -> persistence.getOmemoSignedPreKey(login, signedPreKey.keyId))
			.then(result -> {
				Assert.equals(signedPreKey.keyId, result.keyId);
				assertKeyPairMatches(signedPreKey.keyPair, result.keyPair);
				assertKeyMatches(signedPreKey.signature, result.signature);
				async.done();
			})
			.catchError(e -> {
				Assert.fail(Std.string(e));
				async.done();
			});
	}

	public function testGetOmemoSignedPreKeyNotFound(async: Async) {
		persistence
			.getOmemoSignedPreKey("signed-prekey-notfound@example.com", 1)
			.then(result -> {
				Assert.equals(null, result);
				async.done();
			})
			.catchError(e -> {
				Assert.fail(Std.string(e));
				async.done();
			});
	}

	private function makeKey():BytesData {
		return SecureRandom.bytes(32).getData();
	}

	private function makeKeyPair():PreKeyPair {
		return {
			privKey: makeKey(),
			pubKey: makeKey(),
		};
	}

	private function assertKeyPairMatches(expected:PreKeyPair, actual:PreKeyPair):Void {
		assertKeyMatches(expected.privKey, actual.privKey);
		assertKeyMatches(expected.pubKey, actual.pubKey);
	}

	private function assertKeyMatches(expected:BytesData, actual:BytesData):Void {
		Assert.same(Bytes.ofData(expected), Bytes.ofData(actual));
	}

#end

	public function testColDefaultstoNameForSql() {
		Assert.same(
			{
				name: "stanza_id",
				sql: "stanza_id",
			},
			Sqlite.col("stanza_id"),
		);
	}

	public function testColAllowsSpecifyingSql() {
		Assert.same(
			{
				name: "sort_id",
				sql: "MAX(sort_id) AS sort_id",
			},
			Sqlite.col("sort_id", "MAX(sort_id) AS sort_id"),
		);
	}

	public function testMessageColumnsDefaults() {
		final expected = [
			"stanza",
			"direction",
			"type",
			"status",
			"status_text",
			"strftime('%FT%H:%M:%fZ', created_at / 1000.0, 'unixepoch') AS timestamp",
			"sender_id",
			"mam_id",
			"mam_by",
			"sort_id",
			"sync_point",
			"json(encryption) AS encryption",
			"json(debug) AS debug"
		];
		expected.sort(Reflect.compare);

		final actual = Sqlite.messageColumns();
		actual.sort(Reflect.compare);

		Assert.same(expected, actual);
	}

	public function testMessageColumnsAllowsAddingColumns() {
		final defaultColumns = [
			"stanza",
			"direction",
			"type",
			"status",
			"status_text",
			"strftime('%FT%H:%M:%fZ', created_at / 1000.0, 'unixepoch') AS timestamp",
			"sender_id",
			"mam_id",
			"mam_by",
			"sort_id",
			"sync_point",
			"json(encryption) AS encryption",
			"json(debug) AS debug"
		];

		final expected = defaultColumns.concat(["stanza_id"]);
		expected.sort(Reflect.compare);

		final actual = Sqlite.messageColumns([Sqlite.col("stanza_id")]);
		actual.sort(Reflect.compare);

		Assert.same(expected, actual);
	}

	public function testMessageColumnsAllowsOverridingColumns() {
		final columnToReplace = "sort_id";
		final replacementSql = "MAX(sort_id) AS sort_id";
		final defaultColumns = [
			"stanza",
			"direction",
			"type",
			"status",
			"status_text",
			"strftime('%FT%H:%M:%fZ', created_at / 1000.0, 'unixepoch') AS timestamp",
			"sender_id",
			"mam_id",
			"mam_by",
			"sort_id",
			"sync_point",
			"json(encryption) AS encryption",
			"json(debug) AS debug"
		];
		final expected = defaultColumns.copy();
		expected[defaultColumns.indexOf(columnToReplace)] = replacementSql;
		expected.sort(Reflect.compare);

		final actual = Sqlite.messageColumns([Sqlite.col(columnToReplace, replacementSql)]);
		actual.sort(Reflect.compare);

		Assert.same(expected, actual);
	}
}
