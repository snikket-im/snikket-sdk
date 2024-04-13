package snikket.jingle;

import haxe.DynamicAccess;
using Lambda;

class SessionDescription {
	public var version (default, null): Int;
	public var name (default, null): String;
	public var media (default, null): Array<Media>;
	public var attributes (default, null): Array<Attribute>;
	public var identificationTags (default, null): Array<String>;

	public function new(version: Int, name: String, media: Array<Media>, attributes: Array<Attribute>, identificationTags: Array<String>) {
		this.version = version;
		this.name = name;
		this.media = media;
		this.attributes = attributes;
		this.identificationTags = identificationTags;
	}

	public static function parse(input: String) {
		var version = 0;
		var name = "-";
		var attributes = [];
		final media: Array<Media> = [];
		var currentAttributes: Array<Attribute> = [];
		var currentMedia: Null<Dynamic> = null;

		for (line in input.split("\r\n")) {
			if (line.indexOf("=") != 1) {
				continue; // skip unknown format line
			}
			final value = line.substr(2);
			switch(line.charAt(0)) {
			case "v":
				version = Std.parseInt(value);
			case "s":
				name = value;
			case "a":
				currentAttributes.push(Attribute.parse(value));
			case "m":
				if (currentMedia == null) {
					attributes = currentAttributes;
				} else {
					final mid = currentAttributes.find((attr) -> attr.key == "mid");
					media.push(new Media(
						mid == null ? null : mid.value,
						currentMedia.media,
						currentMedia.connectionData,
						currentMedia.port,
						currentMedia.protocol,
						currentAttributes,
						currentMedia.formats
					));
				}
				currentAttributes = [];
				final segments = value.split(" ");
				if (segments.length >= 3) {
					currentMedia = {
						media: segments[0],
						port: segments[1],
						protocol: segments[2],
						formats: segments.slice(3).map((format) -> Std.parseInt(format))
					}
				} else {
					currentMedia = {};
				}
			case "c":
				if (currentMedia != null) currentMedia.connectionData = value;
			}
		}

		if (currentMedia != null) {
			final mid = currentAttributes.find((attr) -> attr.key == "mid");
			media.push(new Media(
				mid == null ? null : mid.value,
				currentMedia.media,
				currentMedia.connectionData,
				currentMedia.port,
				currentMedia.protocol,
				currentAttributes,
				currentMedia.formats
			));
		} else {
			attributes = currentAttributes;
		}

		var tags: Array<String>;
		final group = attributes.find((attr) -> attr.key == "group");
		if (group != null) {
			tags = Group.parse(group.value).identificationTags;
		} else {
			tags = media.map((m) -> m.mid);
		}

		return new SessionDescription(version, name, media, attributes, tags);
	}

	public static function fromStanza(iq: Stanza, initiator: Bool, ?existingDescription: SessionDescription) {
		final attributes: Array<Attribute> = [];
		final jingle = iq.getChild("jingle", "urn:xmpp:jingle:1");
		final group = jingle.getChild("group", "urn:xmpp:jingle:apps:grouping:0");
		final media = jingle.allTags("content").map((el) -> Media.fromElement(el, initiator, group != null, existingDescription));

		var tags: Array<String>;
		if (group != null) {
			final group = Group.fromElement(group);
			attributes.push(new Attribute("group", group.toSdp()));
			tags = group.identificationTags;
		} else {
			tags = media.map((m) -> m.mid);
		}
		attributes.push(new Attribute("msid-semantic", "WMS my-media-stream"));

		return new SessionDescription(0, "-", media, attributes, tags);
	}

	public function getUfragPwd() {
		var ufragPwd = null;
		for (m in media) {
			final mUfragPwd = m.getUfragPwd();
			if (ufragPwd != null && mUfragPwd.ufrag != ufragPwd.ufrag) throw "ufrag not unique";
			if (ufragPwd != null && mUfragPwd.pwd != ufragPwd.pwd) throw "pwd not unique";
			ufragPwd = mUfragPwd;
		}

		if (ufragPwd == null) throw "no ufrag or pwd found";
		return ufragPwd;
	}

	public function getFingerprint() {
		var fingerprint = attributes.find((attr) -> attr.key == "fingerprint");
		if (fingerprint != null) return fingerprint;

		for (m in media) {
			final mFingerprint = m.attributes.find((attr) -> attr.key == "fingerprint");
			if (fingerprint != null && mFingerprint != null && fingerprint.value != mFingerprint.value) throw "fingerprint not unique";
			fingerprint = mFingerprint;
		}

		if (fingerprint == null) throw "no fingerprint found";
		return fingerprint;
	}

	public function getDtlsSetup() {
		var setup = attributes.find((attr) -> attr.key == "setup");
		if (setup != null) return setup.value;

		for (m in media) {
			final mSetup = m.attributes.find((attr) -> attr.key == "setup");
			if (setup != null && mSetup != null && setup.value != mSetup.value) throw "setup not unique";
			setup = mSetup;
		}

		if (setup == null) throw "no setup found";
		return setup.value;
	}

	public function addContent(newDescription: SessionDescription) {
		for (newM in newDescription.media) {
			if (media.find((m) -> m.mid == newM.mid) != null) {
				throw "Media with id " + newM.mid + " already exists!";
			}
		}
		return new SessionDescription(
			version,
			name,
			media.concat(newDescription.media),
			attributes.filter((attr) -> attr.key != "group").concat(newDescription.attributes.filter((attr) -> attr.key == "group")),
			newDescription.identificationTags
		);
	}

	public function toSdp() {
		return
			"v=" + version + "\r\n" +
			"o=- 8770656990916039506 2 IN IP4 127.0.0.1\r\n" +
			"s=" + name + "\r\n" +
			"t=0 0\r\n" +
			attributes.map((attr) -> attr.toSdp()).join("") +
			media.map((media) -> media.toSdp()).join("");
	}

	public function toStanza(action: String, sid: String, initiator: Bool) {
		final iq = new Stanza("iq", { type: "set" });
		final jingle = iq.tag("jingle", { xmlns: "urn:xmpp:jingle:1", action: action, sid: sid });
		final group = attributes.find((attr) -> attr.key == "group");
		if (group != null) {
			jingle.addChild(Group.parse(group.value).toElement());
		}
		for (m in media) {
			jingle.addChild(m.toElement(attributes, initiator));
		}
		jingle.up();
		return iq;
	}
}

class TransportInfo {
	private final media: Media;
	private final sid: String;

	public function new(media: Media, sid: String) {
		this.media = media;
		this.sid = sid;
	}

	public function toStanza(initiator: Bool) {
		final iq = new Stanza("iq", { type: "set" });
		final jingle = iq.tag("jingle", { xmlns: "urn:xmpp:jingle:1", action: "transport-info", sid: sid });
		jingle.addChild(media.contentElement(initiator).addChild(media.toTransportElement([])).up());
		jingle.up();
		return iq;
	}
}

class Media {
	public var mid (default, null): String;
	public var media (default, null): String;
	public var connectionData (default, null): String;
	public var port (default, null): String;
	public var protocol (default, null): String;
	public var attributes (default, null): Array<Attribute>;
	public var formats (default, null): Array<Int>;

	public function new(mid: String, media: String, connectionData: String, port: String, protocol: String, attributes: Array<Attribute>, formats: Array<Int>) {
		this.mid = mid;
		this.media = media;
		this.connectionData = connectionData;
		this.port = port;
		this.protocol = protocol;
		this.attributes = attributes;
		this.formats = formats;
	}

	public static function fromElement(content: Stanza, initiator: Bool, hasGroup: Bool, ?existingDescription: SessionDescription) {
		final mediaAttributes: Array<Attribute> = [];
		final mediaFormats: Array<Int> = [];
		final mid = content.attr.get("name");
		final transport = content.getChild("transport", "urn:xmpp:jingle:transports:ice-udp:1");
		if (transport == null) throw "ice-udp transport is missing";

		var ufrag = transport.attr.get("ufrag");
		var pwd = transport.attr.get("pwd");
		if ((ufrag == null || pwd == null) && existingDescription != null) {
			final ufragPwd = existingDescription.getUfragPwd();
			ufrag = ufragPwd.ufrag;
			pwd = ufragPwd.pwd;
		}
		if (ufrag == null) throw "transport is missing ufrag";
		mediaAttributes.push(new Attribute("ice-ufrag", ufrag));

		if (pwd == null) throw "transport is missing pwd";
		mediaAttributes.push(new Attribute("ice-pwd", pwd));
		mediaAttributes.push(new Attribute("ice-options", "trickle"));

		final fingerprint = transport.getChild("fingerprint", "urn:xmpp:jingle:apps:dtls:0");
		if (fingerprint == null) {
			if (existingDescription != null) {
				mediaAttributes.push(existingDescription.getFingerprint());
			}
		} else {
			mediaAttributes.push(new Attribute("fingerprint", fingerprint.attr.get("hash") + " " + fingerprint.getText()));
			if (fingerprint.attr.get("setup") != null) {
				mediaAttributes.push(new Attribute("setup", fingerprint.attr.get("setup")));
			}
		}

		final description = content.getChild("description", "urn:xmpp:jingle:apps:rtp:1");
		for (payloadType in description.allTags("payload-type")) {
			final id = Std.parseInt(payloadType.attr.get("id"));
			if (payloadType.attr.get("id") == null) throw "payload-type missing or invalid id";
			mediaFormats.push(id);
			final clockRate = Std.parseInt(payloadType.attr.get("clockrate"));
			final channels = Std.parseInt(payloadType.attr.get("channels"));
			mediaAttributes.push(new Attribute("rtpmap", id + " " + payloadType.attr.get("name") + "/" + (clockRate == null ? 0 : clockRate) + (channels == null || channels == 1 ? "" : "/" + channels)));

			final parameters = payloadType.allTags("parameter").map((el) -> (el.attr.get("name") == null ? "" : el.attr.get("name") + "=") + el.attr.get("value"));
			if (parameters.length > 0) {
				mediaAttributes.push(new Attribute("fmtp", id + " " + parameters.join(";")));
			}

			for (feedbackNegotiation in payloadType.allTags("rtcp-fb", "urn:xmpp:jingle:apps:rtp:rtcp-fb:0")) {
				final subtype = feedbackNegotiation.attr.get("subtype");
				mediaAttributes.push(new Attribute("rtcp-fb", id + " " + feedbackNegotiation.attr.get("type") + (subtype == null || subtype == "" ? "" : " " + subtype)));
			}

			for (trrInt in payloadType.allTags("rtcp-fb-trr-int", "urn:xmpp:jingle:apps:rtp:rtcp-fb:0")) {
				mediaAttributes.push(new Attribute("rtcp-fb", id + " trr-int " + trrInt.attr.get("value")));
			}
		}

		for (feedbackNegotiation in description.allTags("rtcp-fb", "urn:xmpp:jingle:apps:rtp:rtcp-fb:0")) {
			final subtype = feedbackNegotiation.attr.get("subtype");
			mediaAttributes.push(new Attribute("rtcp-fb", "* " + feedbackNegotiation.attr.get("type") + (subtype == null || subtype == "" ? "" : " " + subtype)));
		}

		for (trrInt in description.allTags("rtcp-fb-trr-int", "urn:xmpp:jingle:apps:rtp:rtcp-fb:0")) {
			mediaAttributes.push(new Attribute("rtcp-fb", "* trr-int " + trrInt.attr.get("value")));
		}

		for (headerExtension in description.allTags("rtp-hdrext", "urn:xmpp:jingle:apps:rtp:rtp-hdrext:0")) {
			mediaAttributes.push(new Attribute("extmap", headerExtension.attr.get("id") + " " + headerExtension.attr.get("uri")));
		}

		if (description.getChild("extmap-allow-mixed", "urn:xmpp:jingle:apps:rtp:rtp-hdrext:0") != null) {
			mediaAttributes.push(new Attribute("extmap-allow-mixed", ""));
		}

		for (sourceGroup in description.allTags("ssrc-group", "urn:xmpp:jingle:apps:rtp:ssma:0")) {
			mediaAttributes.push(new Attribute("ssrc-group", sourceGroup.attr.get("semantics") + " " + sourceGroup.allTags("source").map((el) -> el.attr.get("ssrc")).join(" ")));
		}

		for (source in description.allTags("source", "urn:xmpp:jingle:apps:rtp:ssma:0")) {
			for (parameter in source.allTags("parameter")) {
				mediaAttributes.push(new Attribute("ssrc", source.attr.get("ssrc") + " " + parameter.attr.get("name") + ":" + parameter.attr.get("value")));
			}
		}

		mediaAttributes.push(new Attribute("mid", mid));

		switch(content.attr.get("senders")) {
		case "none":
			mediaAttributes.push(new Attribute("inactive", ""));
		case "initiator":
			if (initiator) {
				mediaAttributes.push(new Attribute("sendonly", ""));
			} else {
				mediaAttributes.push(new Attribute("recvonly", ""));
			}
		case "responder":
			if (initiator) {
				mediaAttributes.push(new Attribute("recvonly", ""));
			} else {
				mediaAttributes.push(new Attribute("sendonly", ""));
			}
		default:
			mediaAttributes.push(new Attribute("sendrecv", ""));
		}
		if (hasGroup || description.getChild("rtcp-mux") != null) {
			mediaAttributes.push(new Attribute("rtcp-mux", ""));
		}

		if (description.getChild("ice-lite") != null) {
			mediaAttributes.push(new Attribute("ice-lite", ""));
		}

		mediaAttributes.push(new Attribute("rtcp", "9 IN IP4 0.0.0.0"));
		return new Media(
			mid,
			description == null ? "" : description.attr.get("media"),
			"IN IP4 0.0.0.0",
			"9",
			"UDP/TLS/RTP/SAVPF",
			mediaAttributes,
			mediaFormats
		);
	}

	public function toSdp() {
		return
			"m=" + media + " " + port + " " + protocol + " " + formats.join(" ") + "\r\n" +
			"c=" + connectionData + "\r\n" +
			attributes.map((attr) -> attr.toSdp()).join("");
	}

	public function contentElement(initiator: Bool) {
		final attrs: DynamicAccess<String> = { xmlns: "urn:xmpp:jingle:1", creator: "initiator", name: mid };
		if (attributes.exists((attr) -> attr.key == "inactive")) {
			attrs.set("senders", "none");
		} else if (attributes.exists((attr) -> attr.key == "sendonly")) {
			attrs.set("senders", initiator ? "initiator" : "responder");
		} else if (attributes.exists((attr) -> attr.key == "recvonly")) {
			attrs.set("senders", initiator ? "responder" : "initiator");
		}
		return new Stanza("content", attrs);
	}

	public function toElement(sessionAttributes: Array<Attribute>, initiator: Bool) {
		final content = contentElement(initiator);
		final description = content.tag("description", { xmlns: "urn:xmpp:jingle:apps:rtp:1", media: media });
		final fbs = attributes.filter((attr) -> attr.key == "rtcp-fb").map((fb) -> {
			final segments = fb.value.split(" ");
			return { id: segments[0], el: if (segments[1] == "trr-int") {
				new Stanza("rtcp-fb-trr-int", { xmlns: "urn:xmpp:jingle:apps:rtp:rtcp-fb:0", value: segments[2] });
			} else {
				var fbattrs: DynamicAccess<String> = { xmlns: "urn:xmpp:jingle:apps:rtp:rtcp-fb:0", type: segments[1] };
				if (segments.length >= 3) fbattrs.set("subtype", segments[2]);
				new Stanza("rtcp-fb", fbattrs);
			} };
		});
		final ssrc: Map<String, Array<Stanza>> = [];
		final fmtp: Map<String, Array<Stanza>> = [];
		for (attr in attributes) {
			if (attr.key == "fmtp") {
				final pos = attr.value.indexOf(" ");
				if (pos < 0) continue;
				fmtp.set(attr.value.substr(0, pos), attr.value.substr(pos+1).split(";").map((param) -> {
					final eqPos = param.indexOf("=");
					final attrs: DynamicAccess<String> = { value: eqPos > 0 ? param.substr(eqPos + 1) : param };
					if (eqPos > 0) attrs.set("name", param.substr(0, eqPos));
					return new Stanza("parameter", attrs);
				}));
			} else if (attr.key == "ssrc") {
				final pos = attr.value.indexOf(" ");
				if (pos < 0) continue;
				final id = attr.value.substr(0, pos);
				if (ssrc.get(id) == null) ssrc.set(id, []);
				final param = attr.value.substr(pos + 1);
				final colonPos = param.indexOf(":");
				final attrs: DynamicAccess<String> = { name: colonPos > 0 ? param.substr(0, colonPos) : param };
				if (colonPos > 0) attrs.set("value", param.substr(colonPos + 1));
				ssrc.get(id).push(new Stanza("parameter", attrs));
			} else if (attr.key == "extmap") {
				final pos = attr.value.indexOf(" ");
				if (pos < 0) continue;
				description.tag("rtp-hdrext", { xmlns: "urn:xmpp:jingle:apps:rtp:rtp-hdrext:0", id: attr.value.substr(0, pos), uri: attr.value.substr(pos + 1)}).up();
			} else if (attr.key == "ssrc-group") {
				final segments = attr.value.split(" ");
				if (segments.length < 2) continue;
				final group = description.tag("ssrc-group", { xmlns: "urn:xmpp:jingle:apps:rtp:ssma:0", semantics: segments[0] });
				for (seg in segments.slice(1)) {
					group.tag("source", { ssrc: seg }).up();
				}
				group.up();
			}
		}
		description.addChildren(fbs.filter((fb) -> fb.id == "*").map((fb) -> fb.el));
		description.addChildren(attributes.filter((attr) -> attr.key == "rtpmap").map((rtpmap) -> {
			final pos = rtpmap.value.indexOf(" ");
			if (pos < 0) throw "invalid rtpmap";
			final id = rtpmap.value.substr(0, pos);
			final segments = rtpmap.value.substr(pos+1).split("/");
			final attrs: DynamicAccess<String> = { id: id };
			if (segments.length > 0) attrs.set("name", segments[0]);
			if (segments.length > 1) attrs.set("clockrate", segments[1]);
			if (segments.length > 2 && segments[2] != "" && segments[2] != "1") attrs.set("channels", segments[2]);
			return new Stanza("payload-type", attrs)
				.addChildren(fbs.filter((fb) -> fb.id == id).map((fb) -> fb.el))
				.addChildren(fmtp.get(id) == null ? [] : fmtp.get(id));
		}));
		if (attributes.exists((attr) -> attr.key == "extmap-allow-mixed") || sessionAttributes.exists((attr) -> attr.key == "extmap-allow-mixed")) {
			description.tag("extmap-allow-mixed", { xmlns: "urn:xmpp:jingle:apps:rtp:rtp-hdrext:0" }).up();
		}
		for (entry in ssrc.keyValueIterator()) {
			final msid = attributes.find((attr) -> attr.key == "msid");
			// We have nowhere in jingle to put a media-level msid
			// Chrome and libwebrtc require a media-level or a ssrc level one if rtx is in use
			// Firefox generates only a media level one
			// So copy to ssrc level if it is present to make Chrome happy
			if (msid != null && !entry.value.exists((param) -> param.attr.get("name") == "msid")) {
				entry.value.push(new Stanza("parameter", { name: "msid", value: msid.value }));
			}
			description.tag("source", { xmlns: "urn:xmpp:jingle:apps:rtp:ssma:0", ssrc: entry.key })
				.addChildren(entry.value).up();
		}
		if (attributes.exists((attr) -> attr.key == "rtcp-mux")) {
			description.tag("rtcp-mux").up();
		}
		if (attributes.exists((attr) -> attr.key == "ice-lite")) {
			description.tag("ice-lite").up();
		}
		description.up();
		content.addChild(toTransportElement(sessionAttributes)).up();
		return content;
	}

	public function getUfragPwd(sessionAttributes: Null<Array<Attribute>> = null) {
		final allAttributes = attributes.concat(sessionAttributes ?? []);
		final ufrag = allAttributes.find((attr) -> attr.key == "ice-ufrag");
		final pwd = allAttributes.find((attr) -> attr.key == "ice-pwd");
		if (ufrag == null || pwd == null) throw "transport is missing ufrag or pwd";
		return { ufrag: ufrag.value, pwd: pwd.value };
	}

	public function toTransportElement(sessionAttributes: Array<Attribute>) {
		final transportAttr: DynamicAccess<String> = { xmlns: "urn:xmpp:jingle:transports:ice-udp:1" };
		final ufragPwd = getUfragPwd(sessionAttributes);
		transportAttr.set("ufrag", ufragPwd.ufrag);
		transportAttr.set("pwd", ufragPwd.pwd);
		final transport = new Stanza("transport", transportAttr);
		final fingerprint = (attributes.concat(sessionAttributes)).find((attr) -> attr.key == "fingerprint");
		final setup = (attributes.concat(sessionAttributes)).find((attr) -> attr.key == "setup");
		if (fingerprint != null && setup != null && fingerprint.value.indexOf(" ") > 0) {
			final pos = fingerprint.value.indexOf(" ");
			transport.textTag("fingerprint", fingerprint.value.substr(pos + 1), { xmlns: "urn:xmpp:jingle:apps:dtls:0", hash: fingerprint.value.substr(0, pos), setup: setup.value });
		}
		transport.addChildren(attributes.filter((attr) -> attr.key == "candidate").map((attr) -> IceCandidate.parse(attr.value, mid, ufragPwd.ufrag).toElement()));
		transport.up();
		return transport;
	}
}

class IceCandidate {
	public var sdpMid (default, null): String;
	public var ufrag (default, null): Null<String>;
	public var foundation (default, null): String;
	public var component (default, null): String;
	public var transport (default, null): String;
	public var priority (default, null): String;
	public var connectionAddress (default, null): String;
	public var port (default, null): String;
	public var parameters (default, null): Map<String, String>;

	public function new(sdpMid: String, ufrag: Null<String>, foundation: String, component: String, transport: String, priority: String, connectionAddress: String, port: String, parameters: Map<String, String>) {
		this.sdpMid = sdpMid;
		this.ufrag = ufrag;
		this.foundation = foundation;
		this.component = component;
		this.transport = transport;
		this.priority = priority;
		this.connectionAddress = connectionAddress;
		this.port = port;
		this.parameters = parameters;
	}

	public static function fromElement(candidate: Stanza, sdpMid: String, ufrag: Null<String>) {
		final parameters: Map<String, String> = [];
		if (candidate.attr.get("type") != null) parameters.set("typ", candidate.attr.get("type"));
		if (candidate.attr.get("rel-addr") != null) parameters.set("raddr", candidate.attr.get("rel-addr"));
		if (candidate.attr.get("rel-port") != null) parameters.set("rport", candidate.attr.get("rel-port"));
		if (candidate.attr.get("generation") != null) parameters.set("generation", candidate.attr.get("generation"));
		if (candidate.attr.get("tcptype") != null) parameters.set("tcptype", candidate.attr.get("tcptype"));
		if (ufrag != null) parameters.set("ufrag", ufrag);
		return new IceCandidate(
			sdpMid,
			ufrag,
			candidate.attr.get("foundation"),
			candidate.attr.get("component"),
			candidate.attr.get("protocol").toLowerCase(),
			candidate.attr.get("priority"),
			candidate.attr.get("ip"),
			candidate.attr.get("port"),
			parameters
		);
	}

	public static function fromTransport(transport: Stanza, sdpMid: String) {
		return transport.allTags("candidate").map((el) -> fromElement(el, sdpMid, transport.attr.get("ufrag")));
	}

	public static function fromStanza(iq: Stanza) {
		final jingle = iq.getChild("jingle", "urn:xmpp:jingle:1");
		return jingle.allTags("content").flatMap((content) -> {
			final transport = content.getChild("transport", "urn:xmpp:jingle:transports:ice-udp:1");
			return fromTransport(transport, content.attr.get("name"));
		});
	}

	public static function parse(input: String, sdpMid: String, ufrag: Null<String>) {
		if (input.substr(0, 10) == "candidate:") {
			input = input.substr(11);
		}
		final segments = input.split(" ");
		final paramSegs = segments.slice(6);
		final paramLength = Std.int(paramSegs.length / 2);
		final parameters: Map<String, String> = [];
		for (i in 0...paramLength) {
			parameters.set(paramSegs[i*2], paramSegs[(i*2)+1]);
		}
		if (ufrag != null) parameters.set("ufrag", ufrag);
		return new IceCandidate(
			sdpMid,
			ufrag,
			segments[0],
			segments[1],
			segments[2],
			segments[3],
			segments[4],
			segments[5],
			parameters
		);
	}

	public function toElement() {
		final attrs: DynamicAccess<String> = {
			xmlns: parameters.get("tcptype") == null ? "urn:xmpp:jingle:transports:ice-udp:1" : "urn:xmpp:jingle:transports:ice:0",
			foundation: foundation,
			component: component,
			protocol: transport.toLowerCase(),
			priority: priority,
			ip: connectionAddress,
			port: port,
			generation: parameters.get("generation") ?? "0"
		};
		if (parameters.get("typ") != null) attrs.set("type", parameters.get("typ"));
		if (parameters.get("raddr") != null) attrs.set("rel-addr", parameters.get("raddr"));
		if (parameters.get("rport") != null) attrs.set("rel-port", parameters.get("rport"));
		if (parameters.get("tcptype") != null) attrs.set("tcptype", parameters.get("tcptype"));
		return new Stanza("candidate", attrs);
	}

	public function toSdp() {
		var result = "candidate:" +
			foundation + " " +
			component + " " +
			transport + " " +
			priority + " " +
			connectionAddress + " " +
			port;
		// https://github.com/paullouisageneau/libdatachannel/issues/1143
		if (parameters.exists("typ")) {
			result += " typ " + parameters["typ"];
		}
		if (parameters.exists("raddr")) {
			result += " raddr " + parameters["raddr"];
		}
		if (parameters.exists("rport")) {
			result += " rport " + parameters["rport"];
		}
		for (entry in parameters.keyValueIterator()) {
			if (entry.key != "typ" && entry.key != "raddr" && entry.key != "rport") {
				result += " " + entry.key + " " + entry.value;
			}
		}
		return result;
	}
}

class Attribute {
	public var key (default, null): String;
	public var value (default, null): String;

	public function new(key: String, value: String) {
		this.key = key;
		this.value = value;
	}

	public static function parse(input: String) {
		final pos = input.indexOf(":");
		if (pos < 0) {
			return new Attribute(input, "");
		} else {
			return new Attribute(input.substr(0, pos), input.substr(pos+1));
		}
	}

	public function toSdp() {
		return "a=" + key + (value == null || value == "" ? "" : ":" + value) + "\r\n";
	}

	public function toString() {
		return toSdp();
	}
}
