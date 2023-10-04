package xmpp.jingle;

import xmpp.ID;
import xmpp.jingle.PeerConnection;
import xmpp.jingle.SessionDescription;
using Lambda;

interface Session {
	public var sid (get, null): String;
	public function initiate(stanza: Stanza): InitiatedSession;
	public function accept(): Void;
	public function hangup(): Void;
	public function retract(): Void;
	public function terminate(): Void;
	public function transportInfo(stanza: Stanza): Promise<Void>;
	public function callStatus():String;
	public function videoTracks():Array<MediaStreamTrack>;
}

class IncomingProposedSession implements Session {
	public var sid (get, null): String;
	private final client: Client;
	private final from: JID;
	private final _sid: String;
	private var accepted: Bool = false;

	public function new(client: Client, from: JID, sid: String) {
		this.client = client;
		this.from = from;
		this._sid = sid;
	}

	public function ring() {
		// XEP-0353 says to send <ringing/> but that leaks presence if not careful
		client.trigger("call/ring", { chatId: from.asBare().asString(), session: this });
	}

	public function hangup() {
		// XEP-0353 says to send <reject/> but that leaks presence if not careful
		// It also tells all other devices to stop ringing, which you may or may not want
		client.getDirectChat(from.asBare().asString(), false).jingleSessions.remove(sid);
	}

	public function retract() {
		// Other side retracted, stop ringing
		client.trigger("call/retract", { chatId: from.asBare().asString() });
	}

	public function terminate() {
		trace("Tried to terminate before session-initiate: " + sid, this);
	}

	public function transportInfo(_) {
		trace("Got transport-info before session-initiate: " + sid, this);
		return Promise.resolve(null);
	}

	public function accept() {
		if (accepted) return;
		accepted = true;
		client.sendPresence(from.asString());
		client.sendStanza(
			new Stanza("message", { to: from.asString(), type: "chat" })
				.tag("proceed", { xmlns: "urn:xmpp:jingle-message:0", id: sid }).up()
				.tag("store", { xmlns: "urn:xmpp:hints" })
		);
	}

	public function initiate(stanza: Stanza) {
		// TODO: check if new session has corrent media
		final session = InitiatedSession.fromSessionInitiate(client, stanza);
		if (session.sid != sid) throw "id mismatch";
		if (!accepted) throw "trying to initiate unaccepted session";
		session.accept();
		return session;
	}

	public function callStatus() {
		return "incoming";
	}

	public function videoTracks() {
		return [];
	}

	private function get_sid() {
		return this._sid;
	}
}

class OutgoingProposedSession implements Session {
	public var sid (get, null): String;
	private final client: Client;
	private final to: JID;
	private final _sid: String;
	private var audio = false;
	private var video = false;

	public function new(client: Client, to: JID) {
		this.client = client;
		this.to = to;
		this._sid = ID.long();
	}

	public function propose(audio: Bool, video: Bool) {
		this.audio = audio;
		this.video = video;
		final stanza = new Stanza("message", { to: to.asString(), type: "chat" })
			.tag("propose", { xmlns: "urn:xmpp:jingle-message:0", id: sid });
		if (audio) {
			stanza.tag("description", { xmlns: "urn:xmpp:jingle:apps:rtp:1", media: "audio" }).up();
		}
		if (video) {
			stanza.tag("description", { xmlns: "urn:xmpp:jingle:apps:rtp:1", media: "video" }).up();
		}
		stanza.up().tag("store", { xmlns: "urn:xmpp:hints" });
		client.sendStanza(stanza);
	}

	public function ring() {
		trace("Tried to accept before initiate: " + sid, this);
	}

	public function hangup() {
		client.sendStanza(
			new Stanza("message", { to: to.asString(), type: "chat" })
				.tag("retract", { xmlns: "urn:xmpp:jingle-message:0", id: sid }).up()
				.tag("store", { xmlns: "urn:xmpp:hints" })
		);
		client.getDirectChat(to.asBare().asString(), false).jingleSessions.remove(sid);
	}

	public function retract() {
		// Other side rejected the call
		client.trigger("call/retract", { chatId: to.asBare().asString() });
	}

	public function terminate() {
		trace("Tried to terminate before session-initiate: " + sid, this);
	}

	public function transportInfo(_) {
		trace("Got transport-info before session-initiate: " + sid, this);
		return Promise.resolve(null);
	}

	public function accept() {
		trace("Tried to accept before initiate: " + sid, this);
	}

	public function initiate(stanza: Stanza) {
		final jmi = stanza.getChild("proceed", "urn:xmpp:jingle-message:0");
		if (jmi == null) throw "no jmi: " + stanza;
		if (jmi.attr.get("id") != sid) throw "sid doesn't match: " + jmi.attr.get("id") + " vs " + sid;
		client.sendPresence(to.asString());
		final session = new OutgoingSession(client, JID.parse(stanza.attr.get("from")), sid);
		client.trigger("call/media", { session: session, audio: audio, video: video });
		return session;
	}

	public function callStatus() {
		return "outgoing";
	}

	public function videoTracks() {
		return [];
	}

	private function get_sid() {
		return this._sid;
	}
}

class InitiatedSession implements Session {
	public var sid (get, null): String;
	private final client: Client;
	private final counterpart: JID;
	private final _sid: String;
	private var remoteDescription: Null<SessionDescription> = null;
	private var localDescription: Null<SessionDescription> = null;
	private var pc: PeerConnection = null;
	private final queuedInboundTransportInfo: Array<Stanza> = [];
	private final queuedOutboundCandidate: Array<{ candidate: String, sdpMid: String, usernameFragment: String }> = [];
	private var accepted: Bool = false;

	public function new(client: Client, counterpart: JID, sid: String, remoteDescription: Null<SessionDescription>) {
		this.client = client;
		this.counterpart = counterpart;
		this._sid = sid;
		this.remoteDescription = remoteDescription;
	}

	public static function fromSessionInitiate(client: Client, stanza: Stanza): InitiatedSession {
		final jingle = stanza.getChild("jingle", "urn:xmpp:jingle:1");
		final session = new InitiatedSession(
			client,
			JID.parse(stanza.attr.get("from")),
			jingle.attr.get("sid"),
			SessionDescription.fromStanza(stanza, false)
		);
		session.transportInfo(stanza); // Add any candidates from the initiate
		return session;
	}

	public function get_sid() {
		return _sid;
	}

	public function ring() {
		client.trigger("call/ring", { chatId: counterpart.asBare().asString(), session: this });
	}

	public function retract() {
		trace("Tried to retract session in wrong state: " + sid, this);
	}

	public function accept() {
		if (accepted || remoteDescription == null) return;
		accepted = true;
		final audio = remoteDescription.media.find((m) -> m.media == "audio") != null;
		final video = remoteDescription.media.find((m) -> m.media == "video") != null;
		client.trigger("call/media", { session: this, audio: audio, video: video });
	}

	public function hangup() {
		client.sendStanza(
			new Stanza("iq", { to: counterpart.asString(), type: "set", id: ID.medium() })
				.tag("jingle", { xmlns: "urn:xmpp:jingle:1", action: "session-terminate", sid: sid })
				.tag("reason").tag("success")
				.up().up().up()
		);
		terminate();
		client.trigger("call/retract", { chatId: counterpart.asBare().asString() });
	}

	public function initiate(stanza: Stanza) {
		trace("Trying to initiate already initiated session: " + sid);
		return throw "already initiated";
	}

	public function terminate() {
		if (pc == null) return;
		pc.close();
		for (tranceiver in pc.getTransceivers()) {
			if (tranceiver.sender != null && tranceiver.sender.track != null) {
				tranceiver.sender.track.stop();
			}
		}
		pc = null;
	}

	public function transportInfo(stanza: Stanza) {
		if (pc == null) {
			queuedInboundTransportInfo.push(stanza);
			return Promise.resolve(null);
		}

		return Promise.all(IceCandidate.fromStanza(stanza).map((candidate) -> {
			final index = remoteDescription.identificationTags.indexOf(candidate.sdpMid);
			return pc.addIceCandidate(untyped {
				candidate: candidate.toSdp(),
				sdpMid: candidate.sdpMid,
				sdpMLineIndex: index < 0 ? null : index,
				usernameFragment: candidate.ufrag
			});
		})).then((_) -> {});
	}

	public function callStatus() {
		return "ongoing";
	}

	public function videoTracks() {
		if (pc == null) return [];
		return pc.getTransceivers()
			.filter((t) -> t.receiver != null && t.receiver.track != null && t.receiver.track.kind == "video" && !t.receiver.track.muted)
			.map((t) -> t.receiver.track);
	}

	private function sendIceCandidate(candidate: { candidate: String, sdpMid: String, usernameFragment: String }) {
		if (candidate == null) return; // All candidates received now
		if (candidate.candidate == "") return; // All candidates received now
		if (localDescription == null) {
			queuedOutboundCandidate.push(candidate);
			return;
		}
		final media = localDescription.media.find((media) -> media.mid == candidate.sdpMid);
		if (media == null) throw "Unknown media: " + candidate.sdpMid;
		final transportInfo = new TransportInfo(
			new Media(
				media.mid,
				media.media,
				media.connectionData,
				media.port,
				media.protocol,
				[
					Attribute.parse(candidate.candidate),
					new Attribute("ice-ufrag", candidate.usernameFragment),
					media.attributes.find((attr) -> attr.key == "ice-pwd")
				],
				media.formats
			),
			sid
		).toStanza(false);
		transportInfo.attr.set("to", counterpart.asString());
		transportInfo.attr.set("id", ID.medium());
		client.sendStanza(transportInfo);
	}

	public function supplyMedia(streams: Array<MediaStream>) {
		client.getIceServers((servers) -> {
			pc = new PeerConnection({ iceServers: servers });
			pc.addEventListener("track", (event) -> {
				client.trigger("call/track", { chatId: counterpart.asBare().asString(), track: event.track, streams: event.streams });
			});
			pc.addEventListener("negotiationneeded", (event) -> trace("renegotiate", event));
			pc.addEventListener("icecandidate", (event) -> {
				sendIceCandidate(event.candidate);
			});
			for (stream in streams) {
				for (track in stream.getTracks()) {
					pc.addTrack(track, stream);
				}
			}

			onPeerConnection().catchError((e) -> {
				trace("supplyMedia error", e);
				pc.close();
			});
		});
	}

	private function setupLocalDescription(type: String) {
		return pc.setLocalDescription(null).then((_) -> {
			localDescription = SessionDescription.parse(pc.localDescription.sdp);
			final sessionAccept = localDescription.toStanza(type, sid, false);
			sessionAccept.attr.set("to", counterpart.asString());
			sessionAccept.attr.set("id", ID.medium());
			client.sendStanza(sessionAccept);

			final outboundCandidate = queuedOutboundCandidate.copy();
			queuedOutboundCandidate.resize(0);
			for (candidate in outboundCandidate) {
				sendIceCandidate(candidate);
			}
		});
	}

	private function onPeerConnection() {
		return pc.setRemoteDescription({ type: SdpType.OFFER, sdp: remoteDescription.toSdp() })
		.then((_) -> {
			final inboundTransportInfo = queuedInboundTransportInfo.copy();
			queuedInboundTransportInfo.resize(0);
			return inboundTransportInfo.map(transportInfo);
		})
		.then((_) -> {
			setupLocalDescription("session-accept");
		});
	}
}

class OutgoingSession extends InitiatedSession {
	public function new(client: Client, counterpart: JID, sid: String) {
		super(client, counterpart, sid, null);
	}

	private override function onPeerConnection() {
		return setupLocalDescription("session-initiate");
	}

	public override function initiate(stanza: Stanza) {
		remoteDescription = SessionDescription.fromStanza(stanza, true);
		pc.setRemoteDescription({ type: SdpType.ANSWER, sdp: remoteDescription.toSdp() })
		  .then((_) -> transportInfo(stanza));
		return this;
	}
}