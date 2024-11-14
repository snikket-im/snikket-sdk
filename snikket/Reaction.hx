package snikket;

using StringTools;

@:nullSafety(Strict)
@:expose
class Reaction {
	public final senderId: String;
	public final timestamp: String;
	public final text: String;
	public final key: String;
	public final envelopeId: Null<String>;

	public function new(senderId: String, timestamp: String, text: String, envelopeId: Null<String> = null, key: Null<String> = null) {
		this.senderId = senderId;
		this.timestamp = timestamp;
		this.text = text.replace("\u{fe0f}", "");
		this.envelopeId = envelopeId;
		this.key = key ?? this.text;
	}

	public function render<T>(forText: (String) -> T, forImage: (String, String) -> T) {
		return forText(text + "\u{fe0f}");
	}
}

@:expose
class CustomEmojiReaction extends Reaction {
	public final uri: String;

	public function new(senderId: String, timestamp: String, text: String, uri: String, envelopeId: Null<String> = null) {
		super(senderId, timestamp, text, envelopeId, uri);
		this.uri = uri;
	}

	override public function render<T>(forText: (String) -> T, forImage: (String, String) -> T) {
		final hash = Hash.fromUri(uri);
		return forImage(text, hash?.toUri() ?? uri);
	}
}
