package borogove;

#if cpp
import HaxeCBridge;
#end

@:expose
@:nullSafety(StrictThreaded)
#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class Status {
	public final emoji: String;
	public final text: String;

	public function new(emoji: String, text: String) {
		this.emoji = emoji;
		this.text = text;
	}

	public function toString() {
		return emoji + (emoji == "" || text == "" ? "" : " ") + text;
	}

	public function toStanza() {
		final s = new Stanza("activity", { xmlns: "http://jabber.org/protocol/activity" });
		if (text != "") s.textTag("text", text);
		if (emoji == "") {
			s.tag("undefined").tag("other").up().up();
		} else {
			s.tag("undefined").textTag("emoji", emoji, { xmlns: "https://ns.borogove.dev/" }).up();
		}
		return s;
	}
}
