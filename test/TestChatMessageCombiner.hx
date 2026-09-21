package test;

import utest.Assert;
import borogove.ChatMessage;
import borogove.ChatMessageCombiner;
import borogove.JID;
import borogove.Message;

@:access(borogove)
class TestChatMessageCombiner extends utest.Test {
	public function testCombineUniqueMessagesKeepsVersionsEmpty() {
		final input = [
			message({ localId: "first" }),
			message({ localId: "second" }),
			message({ localId: "third" })
		];
		for (m in input) Assert.equals(0, m.versions.length);

		final combined = ChatMessageCombiner.combine(input);

		final localIds = combined.map(m -> m.localId);
		localIds.sort(Reflect.compare);
		Assert.equals(3, combined.length);
		Assert.same(["first", "second", "third"], localIds);
		for (m in combined) Assert.equals(0, m.versions.length);
		for (m in input) Assert.equals(0, m.versions.length);
	}

	public function testCombineCorrections() {
		final original = message({ localId: "original", timestamp: "2024-01-01T00:00:00Z", sortId: "m", body: "old" });
		final correction = correction(original, "version", "2024-01-02T00:00:00Z", "new");
		final combined = ChatMessageCombiner.combine([original, correction]);

		Assert.equals(1, combined.length);
		Assert.equals("original", combined[0].localId);
		Assert.equals("m", combined[0].sortId);
		Assert.equals("new", combined[0].body().toPlainText());
		Assert.equals(2, combined[0].versions.length);
		Assert.equals("version", combined[0].versions[0].localId);
		Assert.equals("original", combined[0].versions[1].localId);
	}

	public function testCombineCorrectionsKeepsUnrelatedMessages() {
		final first = message({ localId: "first", timestamp: "2024-01-01T00:00:00Z" });
		final original = message({ localId: "original", timestamp: "2024-01-02T00:00:00Z" });
		final other = message({ localId: "other", chatId: "carol@example.com" });
		final correction = correction(original, "version", "2024-01-03T00:00:00Z", "new");
		final combined = ChatMessageCombiner.combine([first, correction, other, original]);

		final localIds = combined.map(m -> m.localId);
		localIds.sort(Reflect.compare);
		Assert.equals(3, combined.length);
		Assert.same(["first", "original", "other"], localIds);
	}

	public function testCombineCorrectionsSupportsVersionedHeadsAndDeduplicates() {
		final original = message({ localId: "original", timestamp: "2024-01-01T00:00:00Z" });
		final first = correction(original, "v1", "2024-01-02T00:00:00Z", "first");
		final second = correction(original, "v2", "2024-01-03T00:00:00Z", "second");
		final combined = ChatMessageCombiner.combine([first, original, second, second]);

		Assert.equals(1, combined.length);
		Assert.equals("second", combined[0].body().toPlainText());
		Assert.equals(3, combined[0].versions.length);
		Assert.equals("v2", combined[0].versions[0].localId);
		Assert.equals("v1", combined[0].versions[1].localId);
		Assert.equals("original", combined[0].versions[2].localId);
	}

	public function testCombineCorrectionsWithoutOriginal() {
		final original = message({ localId: "original", timestamp: "2024-01-01T00:00:00Z", sortId: "m" });
		final first = correction(original, "v1", "2024-01-02T00:00:00Z", "first");
		final second = correction(original, "v2", "2024-01-03T00:00:00Z", "second");
		final third = correction(original, "v3", "2024-01-04T00:00:00Z", "third");
		final combined = ChatMessageCombiner.combine([third, first, second]);

		Assert.equals(1, combined.length);
		Assert.equals("original", combined[0].localId);
		Assert.equals("third", combined[0].body().toPlainText());
		Assert.equals(3, combined[0].versions.length);
		Assert.equals("v3", combined[0].versions[0].localId);
		Assert.equals("v2", combined[0].versions[1].localId);
		Assert.equals("v1", combined[0].versions[2].localId);
	}

	public function testCombineCorrectionsCallSenderMismatch() {
		final original = message({ localId: "call", senderId: "alice@example.com", type: MessageCall });
		final callCorrection = correction(original, "call-version", "2024-01-02T00:00:00Z", "updated", "bob@example.com");
		final textOriginal = message({ localId: "text", senderId: "alice@example.com" });
		final textCorrection = correction(textOriginal, "text-version", "2024-01-02T00:00:00Z", "updated", "bob@example.com");

		Assert.equals(3, ChatMessageCombiner.combine([original, callCorrection, textOriginal, textCorrection]).length);
	}

	public function testCombineCorrectionsDoesNotMutateInputs() {
		final original = message({ localId: "original" });
		final correctionM = correction(original, "version", "2024-01-02T00:00:00Z", "new");
		final input = [original, correctionM];
		final originalVersions = original.versions.length;
		ChatMessageCombiner.combine(input);

		Assert.equals(2, input.length);
		Assert.equals(originalVersions, original.versions.length);
		Assert.equals(1, correctionM.versions.length);
	}

	private function message(params: {
		?localId: Null<String>, ?chatId: String, ?senderId: String, ?type: MessageType,
		?versions: Array<ChatMessage>, ?timestamp: String, ?body: String, ?sortId: String
	}): ChatMessage {
		final builder = new borogove.ChatMessageBuilder();
		builder.localId = params.localId;
		builder.from = JID.parse(params.senderId ?? "alice@example.com");
		builder.to = JID.parse(params.chatId ?? "bob@example.com");
		builder.recipients = [builder.to];
		builder.senderId = params.senderId ?? "alice@example.com";
		builder.type = params.type ?? MessageChat;
		builder.versions = params.versions ?? [];
		builder.timestamp = params.timestamp;
		builder.sortId = params.sortId;
		builder.setBody(borogove.Html.text(params.body ?? "message"));
		return builder.build();
	}

	private function correction(original: ChatMessage, versionId: String, timestamp: String, body: String, ?senderId: String): ChatMessage {
		final originalId = original.localId ?? throw "Correction requires an original local ID";
		final chatId = original.chatId();
		final correctionSenderId = senderId ?? original.senderId;
		return message({
			localId: originalId, chatId: chatId, senderId: correctionSenderId, type: original.type,
			timestamp: timestamp, body: body,
			versions: [message({ localId: versionId, chatId: chatId, senderId: correctionSenderId, type: original.type, timestamp: timestamp, body: body })]
		});
	}
}
