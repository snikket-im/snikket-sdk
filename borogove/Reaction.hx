package borogove;

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
	/**
		ID of who sent this Reaction
	**/
	public final senderId: String;
	/**
		Date and time when this Reaction was sent,
		in format YYYY-MM-DDThh:mm:ss[.sss]+00:00
	**/
	public final timestamp: String;
	@:allow(borogove)
	private final text: String;
	/**
		Key for grouping reactions
	**/
	public final key: String;
	@:allow(borogove)
	private final envelopeId: Null<String>;

	@:allow(borogove)
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
		@returns Reaction
	**/
	public static function unicode(unicode: String) {
		return new Reaction("", "", unicode);
	}

	/**
		Create a new Unicode reaction to send

		@param forText Callback called if this is a textual reaction.
		               Called with the unicode String.
		@param forImage Callback called if this is a custom/image reaction.
		               Called with the name and the URI to the image.
		@returns the return value of the callback
	**/
	#if cpp
	@:allow(borogove)
	private function render(forText: (String) -> String, forImage: (String, String) -> String) {
	#else
	public function render<T>(forText: (String) -> T, forImage: (String, String) -> T) {
	#end
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

	@:allow(borogove)
	private function new(senderId: String, timestamp: String, text: String, uri: String, envelopeId: Null<String> = null) {
		super(senderId, timestamp, text, envelopeId, uri);
		this.uri = uri;
	}

	/**
		Create a new custom emoji reaction to send

		@param text name of custom emoji
		@param uri URI for media of custom emoji
		@returns Reaction
	**/
	public static function custom(text: String, uri: String) {
		return new CustomEmojiReaction("", "", text, uri);
	}

	#if cpp
	@:allow(borogove)
	override private function render(forText: (String) -> String, forImage: (String, String) -> String) {
	#else
	override public function render<T>(forText: (String) -> T, forImage: (String, String) -> T) {
	#end
		final hash = Hash.fromUri(uri);
		return forImage(text, hash?.toUri() ?? uri);
	}
}
