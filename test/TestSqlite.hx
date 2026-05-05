package test;

import haxe.io.Bytes;
import haxe.io.BytesData;
import thenshim.Promise;
import thenshim.PromiseTools;
import utest.Assert;
import utest.Async;

import borogove.persistence.Sqlite;
import borogove.persistence.MediaStore;
import borogove.persistence.KeyValueStore;
import borogove.ChatMessageBuilder;
import borogove.JID;
import borogove.ID;
import borogove.Message;
import borogove.Chat;
import borogove.Status;
import borogove.Reaction;
import borogove.ReactionUpdate;
import borogove.Html;
import borogove.Hash;

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

	public function hasMedia(hashAlgorithm:String, hash:BytesData): Promise<Bool> {
		final hash = new Hash(hashAlgorithm, hash);
		return getMediaPath(hash.toUri()).then(path -> path != null);
	}

	public function removeMedia(hashAlgorithm: String, hash: BytesData) {
		final hash = new Hash(hashAlgorithm, hash);
		return getMediaPath(hash.toUri()).then(p -> kv.set(p, null)).then(_ -> true);
	}

	public function storeMedia(mime: String, bd: BytesData): Promise<Bool> {
		final bytes = Bytes.ofData(bd);
		final sha1 = Hash.sha1(bytes);
		final sha256 = Hash.sha256(bytes);
		return thenshim.PromiseTools.all([
			kv.set(sha1.serializeUri(), sha256.serializeUri()),
			kv.set(sha256.serializeUri(), mime)
		]).then(_ -> true);
	}
}

@:access(borogove)
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

	/* segfault ? public function testStoreReaction(async: Async) {
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

		persistence.storeMessages(account, [builder.build()]).then(_ -> {
			final reaction = new Reaction("alice@example.com", "2020-01-01T00:00:01Z", "👍");
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
			Assert.isTrue(reactions.exists("👍"));
			Assert.equals(1, reactions.get("👍").length);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
	}*/

	public function testUpdateMessageStatus(async: Async) {
		final account = "alice@example.com";
		final builder = new ChatMessageBuilder();
		builder.localId = "loc1";
		builder.senderId = "alice@example.com";
		builder.direction = MessageSent;
		builder.sortId = "a0";
		builder.to = JID.parse("hatter@example.com");
		builder.from = JID.parse("alice@example.com");
		builder.recipients = [builder.to];
		builder.replyTo = [builder.from];

		persistence.storeMessages(account, [builder.build()]).then(_ -> {
			return persistence.updateMessageStatus(account, "loc1", MessageDeliveredToServer, "Delivered");
		}).then(updated -> {
			Assert.equals(MessageDeliveredToServer, updated.status);
			Assert.equals("Delivered", updated.statusText);
			async.done();
		}).catchError(e -> {
			Assert.fail(Std.string(e));
			async.done();
		});
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

		persistence.storeLogin(account1, "client1", "Alice", null);
		persistence.storeLogin(account2, "client2", "Bob", null);

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
		final bytes = haxe.io.Bytes.ofString("hello").getData();
		persistence.storeMedia("image/png", bytes).then(_ -> {
			return persistence.hasMedia("sha-256", Hash.sha256(haxe.io.Bytes.ofData(bytes)).hash);
		}).then(hasBefore -> {
			Assert.isTrue(hasBefore);
			persistence.removeMedia("sha-256", Hash.sha256(haxe.io.Bytes.ofData(bytes)).hash);
		}).then(_ -> {
			return persistence.hasMedia("sha-256", Hash.sha256(haxe.io.Bytes.ofData(bytes)).hash);
		}).then(hasAfter -> {
			Assert.isFalse(hasAfter);
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
}
