package xmpp.jingle;

import xmpp.ID;
import xmpp.jingle.PeerConnection;
import xmpp.jingle.SessionDescription;
using Lambda;

interface Session {
	public var sid (get, null): String;
	public function initiate(session: InitiatedSession): Null<InitiatedSession>;
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
		trace("Tried to terminate before session-inititate: " + sid, this);
	}

	public function transportInfo(_) {
		trace("Got transport-info before session-inititate: " + sid, this);
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

	public function initiate(session: InitiatedSession) {
		// TODO: check if new session has corrent media
		if (session.sid != sid) return null;
		if (!accepted) return null;
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

class InitiatedSession implements Session {
	public var sid (get, null): String;
	private final client: Client;
	private final sessionInitiate: Stanza;
	private final session: SessionDescription;
	private var answer: Null<SessionDescription> = null;
	private var pc: PeerConnection = null;
	private final queuedInboundTransportInfo: Array<Stanza> = [];
	private final queuedOutboundCandidate: Array<{ candidate: String, sdpMid: String, usernameFragment: String }> = [];
	private var accepted: Bool = false;

	public function new(client: Client, sessionInitiate: Stanza) {
		this.client = client;
		this.sessionInitiate = sessionInitiate;
		this.session = SessionDescription.fromStanza(sessionInitiate, false);
	}

	public function get_sid() {
		final jingle = sessionInitiate.getChild("jingle", "urn:xmpp:jingle:1");
		return jingle.attr.get("sid");
	}

	public function ring() {
		client.trigger("call/ring", { chatId: JID.parse(sessionInitiate.attr.get("from")).asBare().asString(), session: this });
	}

	public function retract() {
		trace("Tried to retract session in wrong state: " + sid, this);
	}

	public function accept() {
		if (accepted) return;
		accepted = true;
		client.trigger("call/media", { session: this });
	}

	public function hangup() {
		client.sendStanza(
			new Stanza("iq", { to: sessionInitiate.attr.get("from"), type: "set", id: ID.medium() })
				.tag("jingle", { xmlns: "urn:xmpp:jingle:1", action: "session-terminate", sid: sid })
				.tag("reason").tag("success")
				.up().up().up()
		);
		terminate();
		client.trigger("call/retract", { chatId: JID.parse(sessionInitiate.attr.get("from")).asBare().asString() });
	}

	public function initiate(session: InitiatedSession) {
		trace("Trying to inititate already initiated session: " + sid);
		return null;
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
			final index = session.identificationTags.indexOf(candidate.sdpMid);
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
		if (answer == null) {
			queuedOutboundCandidate.push(candidate);
			return;
		}
		final jingle = sessionInitiate.getChild("jingle", "urn:xmpp:jingle:1");
		final media = answer.media.find((media) -> media.mid == candidate.sdpMid);
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
			jingle.attr.get("sid")
		).toStanza(false);
		transportInfo.attr.set("to", sessionInitiate.attr.get("from"));
		transportInfo.attr.set("id", ID.medium());
		client.sendStanza(transportInfo);
	}

	public function supplyMedia(streams: Array<MediaStream>) {
		final jingle = sessionInitiate.getChild("jingle", "urn:xmpp:jingle:1");
		client.getIceServers((servers) -> {
			pc = new PeerConnection({ iceServers: servers });
			pc.addEventListener("track", (event) -> {
				client.trigger("call/track", { chatId: JID.parse(sessionInitiate.attr.get("from")).asBare().asString(), track: event.track, streams: event.streams });
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
			pc.setRemoteDescription({ type: SdpType.OFFER, sdp: session.toSdp() })
			.then((_) -> {
				final inboundTransportInfo = queuedInboundTransportInfo.copy();
				queuedInboundTransportInfo.resize(0);
				return Promise.all(IceCandidate.fromStanza(sessionInitiate).map((candidate) -> {
					final index = session.identificationTags.indexOf(candidate.sdpMid);
					return pc.addIceCandidate(untyped {
						candidate: candidate.toSdp(),
						sdpMid: candidate.sdpMid,
						sdpMLineIndex: index < 0 ? null : index,
						usernameFragment: candidate.ufrag
					});
				}).concat(inboundTransportInfo.map(transportInfo)));
			})
				.then((_) -> pc.setLocalDescription(null))
				.then((_) -> {
					answer = SessionDescription.parse(pc.localDescription.sdp);
					final sessionAccept = answer.toStanza("session-accept", jingle.attr.get("sid"), false);
					sessionAccept.attr.set("to", sessionInitiate.attr.get("from"));
					sessionAccept.attr.set("id", ID.medium());
					client.sendStanza(sessionAccept);

					final outboundCandidate = queuedOutboundCandidate.copy();
					queuedOutboundCandidate.resize(0);
					for (candidate in outboundCandidate) {
						sendIceCandidate(candidate);
					}
				})
				.catchError((e) -> {
					trace("acceptJingleRtp error", e);
					pc.close();
				});
		});
	}
}
