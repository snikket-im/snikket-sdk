package snikket;

using StringTools;

#if cpp
import HaxeCBridge;
#end

@:nullSafety(Strict)
@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class Reaction {
	public final senderId: String;
	public final timestamp: String;
	public final text: String;
	public final key: String;
	public final envelopeId: Null<String>;

	@:allow(snikket)
	private function new(senderId: String, timestamp: String, text: String, envelopeId: Null<String> = null, key: Null<String> = null) {
		this.senderId = senderId;
		this.timestamp = timestamp;
		this.text = text.replace("\u{fe0f}", "");
		this.envelopeId = envelopeId;
		this.key = key ?? this.text;
	}

	/**
		Create a new Unicode reaction to send

		@param unicode emoji of the reaction
	**/
	public static function unicode(unicode: String) {
		return new Reaction("", "", unicode);
	}

	@:allow(snikket)
	private function render<T>(forText: (String) -> T, forImage: (String, String) -> T) {
		return forText(text + "\u{fe0f}");
	}
}

@:expose
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class CustomEmojiReaction extends Reaction {
	public final uri: String;

	@:allow(snikket)
	private function new(senderId: String, timestamp: String, text: String, uri: String, envelopeId: Null<String> = null) {
		super(senderId, timestamp, text, envelopeId, uri);
		this.uri = uri;
	}

	/**
		Create a new custom emoji reaction to send

		@param text name of custom emoji
		@param uri URI for media of custom emoji
	**/
	public static function custom(text: String, uri: String) {
		return new CustomEmojiReaction("", "", text, uri);
	}

	@:allow(snikket)
	override public function render<T>(forText: (String) -> T, forImage: (String, String) -> T) {
		final hash = Hash.fromUri(uri);
		return forImage(text, hash?.toUri() ?? uri);
	}
}
