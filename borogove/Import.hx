package borogove;

import ltx.Sax;
using StringTools;

import borogove.Chat;

@:expose
@:access(Xml)
class Import {
	private final p: Sax;
	private final targetAccount: Null<String>;
	private var sortA: String;
	private final sortAinit: String;
	private final sortB: String;
	private var counterSameTime = 0;
	private var previousMessageTime = "";
	private var ignoredSources = new Map();

	public var onAccount: String->Void;
	public var onChannel: String->Void;
	public var onChat: (String, AvailableChat)->Void;
	public var onMessage: (String, Message)->Void;

	public function new(targetAccount: Null<String>, sortA: String = "Wt@|q", sortB: String = "a ") {
		this.targetAccount = targetAccount;
		this.sortAinit = this.sortA = sortA;
		this.sortB = sortB;
		p = new Sax();

		var ns = new NsContext(null, new Map());
		var host = null;
		var item = null;
		var mucComponent = false;
		var inArchive = false;
		var inRoster = false;
		var resultStanza: Null<Stanza> = null;
		p.onStartElement = (tag: Xml) -> {
			ns = NsContext.from(ns, tag);

			if (resultStanza != null) {
				resultStanza.tag(tag.nodeName, tag.attributeMap);
				return;
			}

			switch (ns.expandName(tag.nodeName)) {
			case "{urn:xmpp:pie:0}host":
				host = tag.get("jid");
			case "{urn:xmpp:pie:0}user":
				sortA = sortAinit;
				item = tag.get("name");
				if (onAccount != null) onAccount(item + "@" + host);
			case "{urn:xmpp:pie:0#component}component":
				host = tag.get("jid");
				mucComponent = tag.get("type") == "muc";
			case "{urn:xmpp:pie:0#component}item":
				sortA = sortAinit;
				item = tag.get("name");
				if (mucComponent && onChannel != null) onChannel(item + "@" + host);
			case "{jabber:iq:roster}query":
				if (inArchive) throw "Roster inside an archive?";
				inRoster = true;
			case "{jabber:iq:roster}item":
				if (inRoster && onChat != null && !ignoredSources[item + "@" + host]) {
					resultStanza = new Stanza("item", tag.attributeMap);
				}
			case "{urn:xmpp:pie:0#mam}archive":
				if (inRoster) throw "Archive inside a roster?";
				if (item != null && host != null) inArchive = true;
			case "{urn:xmpp:mam:2}result":
				if (inArchive && onMessage != null && !ignoredSources[item + "@" + host]) {
					resultStanza = new Stanza("result", tag.attributeMap);
				}
			}
		};
		p.onEndElement = (tagName: String) -> {
			if (resultStanza != null) {
				resultStanza.up();
				if (resultStanza.atTop()) {
					if (inRoster) {
						if (onChat != null) onChat(item + "@" + host, new AvailableChat(resultStanza.attr.get("jid"), resultStanza.attr.get("name"), "Import", CapsRepo.empty, resultStanza));
					} else if (inArchive) {
						if (onMessage != null) processResultStanza(resultStanza, item, host);
					}
					resultStanza = null;
				}
				return;
			}

			switch (ns.expandName(tagName)) {
			case "{urn:xmpp:pie:0}host":
				host = null;
			case "{urn:xmpp:pie:0#component}component":
				host = null;
				mucComponent = false;
			case "{urn:xmpp:pie:0#component}item", "{urn:xmpp:pie:0}user":
				item = null;
			case "{jabber:iq:roster}query":
				inRoster = false;
			case "{urn:xmpp:pie:0#mam}archive":
				inArchive = false;
			case "{urn:xmpp:mam:2}result":
				resultStanza = null;
			}

			ns = ns.parent;
		};

		p.onText = (txt: String) -> {
			if (resultStanza != null) resultStanza.text(txt);
		};
	}

	public function ignoreSource(source: String) {
		ignoredSources.set(source, true);
	}

	public function write(chunk: String) {
		p.write(chunk);
	}

	inline private function processResultStanza(resultStanza: Stanza, item: String, host: String) {
		final originalMessage = resultStanza.findChild("{urn:xmpp:forward:0}forwarded/{jabber:client}message");
		if (originalMessage == null) return;

		final source = item + "@" + host;
		if (ignoredSources.get(source)) return;

		if (targetAccount != null) {
			// TODO: setup senderId and direction on MUC messages based on targetAccount?
			// What if we don't even know target occupant id at this time? Just direction?
			// Worst case if we don't is sent messages show as received from a different account...
			// which is honestly kinda right so may don't do this?

			final from = originalMessage.attr.get("from");
			if (from != null && from.startsWith(source)) {
				originalMessage.attr.set("from", targetAccount);
			}

			final to = originalMessage.attr.get("to");
			if (to != null && to.startsWith(source)) {
				originalMessage.attr.set("to", targetAccount);
			}
		}

		sortA = FractionalIndexing.between(sortA, sortB, FractionalIndexing.BASE_95_DIGITS);
		var timestamp = resultStanza.findText("{urn:xmpp:forward:0}forwarded/{urn:xmpp:delay}delay@stamp");
		if (timestamp != null) {
			// If no subseconds, fix them to at least sort right
			timestamp = ~/([0-9][0-9]:[0-9][0-9]:[0-9][0-9])(\.[0-9][0-9][0-9])?/.map(timestamp, (ereg) -> {
				if (ereg.matched(2) == null || ereg.matched(2) == ".000") {
					if (ereg.matched(1) == previousMessageTime) {
						counterSameTime++;
					} else {
						previousMessageTime = ereg.matched(1);
						counterSameTime = 1;
					}

					return ereg.matched(1) + "." + Std.string(counterSameTime).lpad("0", 3);
				}

				return ereg.matched(0);
			});
		}

		if (resultStanza.attr.get("id") == null && originalMessage.attr.get("id") == null) {
			// Skip messages in the export with no id of any kind
			return;
		}

		final msg = Message.fromStanza(originalMessage, targetAccount == null ? new JID(item, host) : JID.parse(targetAccount), (builder, stanza) -> {
			builder.sortId = sortA;
			builder.serverId = resultStanza.attr.get("id");
			builder.serverIdBy = source;
			if (timestamp != null && builder.timestamp == null) builder.timestamp = timestamp;
			return builder;
		});

		onMessage(source, msg);
	}
}

class NsContext {
	public final parent: Null<NsContext>;
	private final ns: Map<String, String>;

	public function new(parent: Null<NsContext>, ns: Map<String, String>) {
		this.parent = parent;
		this.ns = ns;
	}

	static public function from(parent: Null<NsContext>, tag: Xml) {
		final ns = new Map();
		for (att in tag.attributes()) {
			if (att == "xmlns") {
				ns.set("", tag.get(att));
			} else if(att.startsWith("xmlns:")) {
				ns.set(att.substr(6), tag.get(att));
			}
		}

		return new NsContext(parent, ns);
	}

	public function get(prefix: String) {
		final uri = ns.get(prefix);
		if (uri != null) return uri;

		return parent?.get(prefix);
	}

	public function expandName(name: String) {
		var parts = name.split(":");
		if (parts[0] == "xml") return name;

		if (parts.length < 2) parts = ["", name];

		final ns = get(parts[0]);
		if (ns == null) throw "Undefined prefix";

		return '{$ns}${parts[1]}';
	}
}
