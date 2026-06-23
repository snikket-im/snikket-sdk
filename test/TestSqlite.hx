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

	@:timeout(3000)
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

	@:timeout(3000)
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

	@:timeout(3000)
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

	@:timeout(3000)
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

	@:timeout(3000)
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

	@:timeout(3000)
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

	@:timeout(3000)
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

	@:timeout(3000)
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

	@:timeout(3000)
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

	@:timeout(3000)
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

	@:timeout(3000)
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

	@:timeout(3000)
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

	@:timeout(3000)
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

	@:timeout(3000)
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

	@:timeout(3000)
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

	@:timeout(3000)
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

	@:timeout(3000)
	public function testStoreStreamManamagementAndGetStreamManagement(async: Async) {
		persistence.storeLogin("alice@example.com", "", "", null).then(_ ->
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

	@:timeout(3000)
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

	@:timeout(3000)
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

	@:timeout(3000)
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

	@:timeout(3000)
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

	@:timeout(3000)
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

	@:timeout(3000)
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

	@:timeout(3000)
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

	@:timeout(3000)
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

	@:timeout(3000)
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
}
