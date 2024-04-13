package snikket.jingle;

import snikket.ID;
import snikket.jingle.PeerConnection;
import snikket.jingle.SessionDescription;
using Lambda;
using thenshim.PromiseTools;

#if cpp
import HaxeCBridge;
#end

#if cpp
@:build(HaxeSwiftBridge.expose())
#end
interface Session {
	public var sid (get, null): String;
	public function initiate(stanza: Stanza): InitiatedSession;
	public function accept(): Void;
	public function hangup(): Void;
	public function retract(): Void;
	public function terminate(): Void;
	public function contentAdd(stanza: Stanza): Void;
	public function contentAccept(stanza: Stanza): Void;
	public function transportInfo(stanza: Stanza): Promise<Any>;
	public function addMedia(streams: Array<MediaStream>): Void;
	public function callStatus():String;
	public function videoTracks():Array<MediaStreamTrack>;
	public function dtmf():Null<DTMFSender>;
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

	public function contentAdd(_) {
		trace("Got content-add before session-initiate: " + sid, this);
	}

	public function contentAccept(_) {
		trace("Got content-accept before session-initiate: " + sid, this);
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

	public function addMedia(_) {
		throw "Cannot add media before call starts";
	}

	public function callStatus() {
		return "incoming";
	}

	public function videoTracks() {
		return [];
	}

	public function dtmf() {
		return null;
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
		client.trigger("call/ringing", { chatId: to.asBare().asString() });
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

	public function contentAdd(_) {
		trace("Got content-add before session-initiate: " + sid, this);
	}

	public function contentAccept(_) {
		trace("Got content-accept before session-initiate: " + sid, this);
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

	public function addMedia(_) {
		throw "Cannot add media before call starts";
	}

	public function callStatus() {
		return "outgoing";
	}

	public function videoTracks() {
		return [];
	}

	public function dtmf() {
		return null;
	}

	private function get_sid() {
		return this._sid;
	}
}

#if cpp
@:build(HaxeCBridge.expose())
@:build(HaxeSwiftBridge.expose())
#end
class InitiatedSession implements Session {
	public var sid (get, null): String;
	private final client: Client;
	private final counterpart: JID;
	private final _sid: String;
	private var remoteDescription: Null<SessionDescription> = null;
	private var localDescription: Null<SessionDescription> = null;
	private var pc: PeerConnection = null;
	private var peerDtlsSetup: String = "actpass";
	private final queuedInboundTransportInfo: Array<Stanza> = [];
	private final queuedOutboundCandidate: Array<{ candidate: String, sdpMid: String, usernameFragment: String }> = [];
	private var accepted: Bool = false;
	private var afterMedia: Null<()->Void> = null;
	private final initiator: Bool;
	private var candidatesDone: Null<()->Void> = null;
	private final caps: Caps;

	public function new(client: Client, counterpart: JID, sid: String, remoteDescription: Null<SessionDescription>) {
		this.client = client;
		this.counterpart = counterpart;
		this._sid = sid;
		this.remoteDescription = remoteDescription;
		this.initiator = remoteDescription == null;
		this.caps = client.getDirectChat(counterpart.asBare().asString()).getResourceCaps(counterpart.resource);
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

	public function contentAdd(stanza: Stanza) {
		if (remoteDescription == null) throw "Got content-add before session-accept";

		final addThis = SessionDescription.fromStanza(stanza, initiator, remoteDescription);
		var video = false;
		var audio = false;
		for (m in addThis.media) {
			if (m.attributes.exists((attr) -> attr.key == "sendrecv" || attr.key == "sendonly")) {
				if (m.media == "video") video = true;
				if (m.media == "audio") audio = true;
			}
			m.attributes.push(new Attribute("setup", peerDtlsSetup));
		}
		remoteDescription = remoteDescription.addContent(addThis);
		// TODO: tie-break with any in-flight content-add we sent?
		pc.setRemoteDescription({ type: SdpType.OFFER, sdp: remoteDescription.toSdp() }).then((_) -> {
			afterMedia = () -> {
				setupLocalDescription(
					"content-accept",
					addThis.media.map((m) -> m.mid),
					false,
					(gonnaAccept) -> {
						if (gonnaAccept.media.find(
							(m) -> m.contentElement(false).attr.get("senders") != addThis.media.find((addM) -> addM.mid == m.mid).contentElement(false).attr.get("senders")
						) != null) {
							final modify = gonnaAccept.toStanza("content-modify", sid, initiator);
							modify.attr.set("to", counterpart.asString());
							modify.attr.set("id", ID.medium());
							client.sendStanza(modify);
						}
					}
				);
				afterMedia = null;
			};
			client.trigger("call/media", { session: this, audio: audio, video: video });
		});
	}

	public function contentAccept(stanza: Stanza) {
		if (remoteDescription == null) throw "Got content-accept before session-accept";
		// TODO: check if matches a content-add we sent?

		final addThis = SessionDescription.fromStanza(stanza, !initiator, remoteDescription);
		for (m in addThis.media) {
			m.attributes.push(new Attribute("setup", peerDtlsSetup));
		}
		remoteDescription = remoteDescription.addContent(addThis);
		pc.setRemoteDescription({ type: SdpType.ANSWER, sdp: remoteDescription.toSdp() });
	}

	public function transportInfo(stanza: Stanza) {
		if (pc == null || remoteDescription == null) {
			queuedInboundTransportInfo.push(stanza);
			return Promise.resolve(null);
		}

		return thenshim.PromiseTools.all(IceCandidate.fromStanza(stanza).map((candidate) -> {
			final index = remoteDescription.identificationTags.indexOf(candidate.sdpMid);
			return pc.addIceCandidate(untyped {
				candidate: candidate.toSdp(),
				sdpMid: candidate.sdpMid,
				sdpMLineIndex: index < 0 ? null : index,
				usernameFragment: candidate.ufrag
			});
		})).then((_) -> {});
	}

	public function addMedia(streams: Array<MediaStream>): Void {
		if (pc == null) throw "tried to add media before PeerConnection exists";

		final oldMids = localDescription.media.map((m) -> m.mid);
		for (stream in streams) {
			for (track in stream.getTracks()) {
				pc.addTrack(track, stream);
			}
		}

		setupLocalDescription("content-add", oldMids, true);
	}

	public function callStatus() {
		return "ongoing";
	}

	public function videoTracks(): Array<MediaStreamTrack> {
		if (pc == null) return [];
		return pc.getTransceivers()
			.filter((t) -> t.receiver != null && t.receiver.track != null && t.receiver.track.kind == "video" && !t.receiver.track.muted)
			.map((t) -> t.receiver.track);
	}

	public function dtmf() {
		if (pc == null) return null;
		final transceiver = pc.getTransceivers().find((t) -> t.sender != null && t.sender.track != null && t.sender.track.kind == "audio" && !t.sender.track.muted);
		if (transceiver == null) return null;
		return transceiver.sender.dtmf;
	}

	private function sendIceCandidate(candidate: { candidate: String, sdpMid: String, usernameFragment: String }) {
		if (candidate == null || candidate.candidate == "") { // All candidates received now
			if (candidatesDone != null) candidatesDone();
			return;
		}
		if (candidatesDone != null) return; // We're waiting for all done, not trickling
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
		).toStanza(initiator);
		transportInfo.attr.set("to", counterpart.asString());
		transportInfo.attr.set("id", ID.medium());
		client.sendStanza(transportInfo);
	}

	public function supplyMedia(streams: Array<MediaStream>): Void {
		setupPeerConnection(() -> {
			for (stream in streams) {
				for (track in stream.getTracks()) {
					pc.addTrack(track, stream);
				}
			}

			if (afterMedia == null) {
				onPeerConnection().catchError((e) -> {
					trace("supplyMedia error", e);
					pc.close();
				});
			} else {
				afterMedia();
			}
		});
	}

	private function setupPeerConnection(callback: ()->Void) {
		if (pc != null) {
			callback();
			return;
		}
		client.getIceServers((servers) -> {
			pc = new PeerConnection({ iceServers: servers });
			pc.addEventListener("track", (event) -> {
				client.trigger("call/track", { chatId: counterpart.asBare().asString(), track: event.track, streams: event.streams });
			});
			pc.addEventListener("negotiationneeded", (event) -> trace("renegotiate", event));
			pc.addEventListener("icecandidate", (event) -> {
				sendIceCandidate(event.candidate);
			});
			callback();
		});
	}

	private function setupLocalDescription(type: String, ?filterMedia: Array<String>, ?filterOut: Bool = false, ?beforeSend: (SessionDescription)->Void) {
		return pc.setLocalDescription(null).then((_) ->
			if ((type == "session-initiate" || type == "session-accept") && caps.features.contains("urn:ietf:rfc:3264")) {
				new Promise((resolve, reject) -> candidatesDone = () -> resolve(true));
			} else {
				null;
			}
		).then((_) -> {
			localDescription = SessionDescription.parse(pc.localDescription.sdp);
			var descriptionToSend = localDescription;
			if (filterMedia != null) {
				descriptionToSend = new SessionDescription(
					descriptionToSend.version,
					descriptionToSend.name,
					descriptionToSend.media.filter((m) -> filterOut ? !filterMedia.contains(m.mid) : filterMedia.contains(m.mid)),
					descriptionToSend.attributes,
					descriptionToSend.identificationTags
				);
			}
			if (beforeSend != null) beforeSend(descriptionToSend);
			final sessionAccept = descriptionToSend.toStanza(type, sid, initiator);
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
		}).then((x) -> {
			peerDtlsSetup = localDescription.getDtlsSetup() == "active" ? "passive" : "active";
			return;
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
		peerDtlsSetup = remoteDescription.getDtlsSetup();
		pc.setRemoteDescription({ type: SdpType.ANSWER, sdp: remoteDescription.toSdp() })
		  .then((_) -> transportInfo(stanza));
		return this;
	}
}
