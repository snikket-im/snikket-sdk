package borogove;

import haxe.crypto.Base64;
import haxe.ds.ReadOnlyArray;
import haxe.io.Bytes;
import haxe.io.BytesData;
using Lambda;
using borogove.Util;

import borogove.DataForm;
import borogove.Hash;
import borogove.Util;

class Caps {
	public final node: String;
	public final identities: ReadOnlyArray<Identity>;
	public final features : ReadOnlyArray<String>;
	public final data: ReadOnlyArray<DataForm>;
	private var _ver : Null<Hash> = null;

	@:allow(borogove)
	private static function withIdentity(caps:KeyValueIterator<String, Null<Caps>>, category:Null<String>, type:Null<String>):Array<String> {
		final result = [];
		for (cap in caps) {
			if (cap.value != null) {
				for (identity in cap.value.identities) {
					if ((category == null || category == identity.category) && (type == null || type == identity.type)) {
						result.push(cap.key);
					}
				}
			}
		}
		return result;
	}

	@:allow(borogove)
	private static function withFeature(caps:KeyValueIterator<String, Null<Caps>>, feature:String):Array<String> {
		final result = [];
		for (cap in caps) {
			if (cap.value != null) {
				for (feat in cap.value.features) {
					if (feature == feat) {
						result.push(cap.key);
					}
				}
			}
		}
		return result;
	}

	public function new(node: String, identities: Array<Identity>, features: Array<String>, data: Array<DataForm>, ?ver: BytesData) {
		if (ver == null) {
			// If we won't need to generate ver we don't actually need to sort
			features.sort((x, y) -> x == y ? 0 : (x < y ? -1 : 1));
			identities.sort((x, y) -> x.ver() == y.ver() ? 0 : (x.ver() < y.ver() ? -1 : 1));
			data.sort((x, y) -> Reflect.compare(x.field("FORM_TYPE")?.value, y.field("FORM_TYPE")?.value));
		}

		this.node = node;
		this.identities = identities;
		this.features = features;
		this.data = data;
		if (ver != null) {
			_ver = new Hash("sha-1", ver);
		}
	}

	public function isChannel(chatId: String) {
		if (chatId.indexOf("@") < 0) return false; // MUC must have a localpart
		return features.contains("http://jabber.org/protocol/muc") && identities.find((identity) -> identity.category == "conference") != null;
	}

	public function discoReply():Stanza {
		final query = new Stanza("query", { xmlns: "http://jabber.org/protocol/disco#info" });
		for (identity in identities) {
			identity.addToDisco(query);
		}
		for (feature in features) {
			query.tag("feature", { "var": feature }).up();
		}
		query.addChildren(data);
		return query;
	}

	public function addC(stanza: Stanza): Stanza {
		stanza.tag("c", {
			xmlns: "http://jabber.org/protocol/caps",
			hash: "sha-1",
			node: node,
			ver: ver()
		}).up();
		stanza.tag("c", {
			xmlns: "urn:xmpp:caps",
		}).textTag(
			"hash",
			Hash.sha256(hashInput()).toBase64(),
			{ xmlns: "urn:xmpp:hashes:2", algo: "sha-256" }
		).up();
		return stanza;
	}

	private function hashInput(): Bytes {
		var s = new haxe.io.BytesOutput();
		for (feature in features) {
			s.writeS(feature);
			s.writeByte(0x1f);
		}
		s.writeByte(0x1c);
		for (identity in identities) {
			identity.writeTo(s);
		}
		s.writeByte(0x1c);
		for (form in data) {
			final fields = form.fields();
			fields.sort((x, y) -> Reflect.compare([x.name].concat(x.value).join("\x1f"), [y.name].concat(y.value).join("\x1f")));
			for (field in fields) {
				final values = field.value;
				values.sort(Reflect.compare);
				s.writeS(field.name);
				s.writeByte(0x1f);
				for (value in values) {
					s.writeS(value);
					s.writeByte(0x1f);
				}
				s.writeByte(0x1e);
			}
			s.writeByte(0x1d);
		}
		s.writeByte(0x1c);
		return s.getBytes();
	}

	private function computeVer(): Hash {
		var s = "";
		for (identity in identities) {
			s += identity.ver() + "<";
		}
		for (feature in features) {
			s += feature + "<";
		}
		for (form in data) {
			s += form.field("FORM_TYPE").value[0] + "<";
			final fields = form.fields();
			fields.sort((x, y) -> Reflect.compare(x.name, y.name));
			for (field in fields) {
				if (field.name != "FORM_TYPE") {
					s += field.name + "<";
					final values = field.value;
					values.sort(Reflect.compare);
					for (value in values) {
						s += value + "<";
					}
				}
			}
		}
		return Hash.sha1(bytesOfString(s));
	}

	public function verRaw(): Hash {
		if (_ver == null) _ver = computeVer();
		return _ver;
	}

	public function ver(): String {
		return verRaw().toBase64();
	}
}

class Identity {
	public final category:String;
	public final type:String;
	public final name:String;
	public final lang:String;

	public function new(category:String, type: String, name: String, lang: Null<String> = null) {
		this.category = category;
		this.type = type;
		this.name = name;
		this.lang = lang ?? "";
	}

	public function addToDisco(stanza: Stanza) {
		var attrs: haxe.DynamicAccess<String> = { category: category, type: type, name: name };
		if (lang != null && lang != "") attrs.set("xml:lang", lang);
		stanza.tag("identity", attrs).up();
	}

	public function ver(): String {
		return category + "/" + type + "/" + (lang ?? "") + "/" + name;
	}

	public function writeTo(out: haxe.io.Output) {
		out.writeS(category);
		out.writeByte(0x1f);
		out.writeS(type);
		out.writeByte(0x1f);
		out.writeS(lang ?? "");
		out.writeByte(0x1f);
		out.writeS(name);
		out.writeByte(0x1f);
		out.writeByte(0x1e);
	}
}
