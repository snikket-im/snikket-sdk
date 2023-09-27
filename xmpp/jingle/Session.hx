package xmpp.jingle;

import xmpp.jingle.PeerConnection;
import xmpp.jingle.SessionDescription;
using Lambda;

class Session {
	public var sid (get, null): String;
	private final client: Client;
	private final sessionInitiate: Stanza;
	private final session: SessionDescription;
	private var answer: Null<SessionDescription> = null;
	private var pc: PeerConnection = null;
	private final queuedInboundTransportInfo: Array<Stanza> = [];
	private final queuedOutboundCandidate: Array<{ candidate: String, sdpMid: String, usernameFragment: String }> = [];

	public function new(client: Client, sessionInitiate: Stanza) {
		this.client = client;
		this.sessionInitiate = sessionInitiate;
		this.session = SessionDescription.fromStanza(sessionInitiate, false);
	}

	public function get_sid() {
		final jingle = sessionInitiate.getChild("jingle", "urn:xmpp:jingle:1");
		return jingle.attr.get("sid");
	}

	public function accept() {
		client.trigger("call/media", { session: this });
	}

	public function terminate() {
		if (pc == null) return;
		pc.close();
		for (tranceiver in pc.getTransceivers()) {
			if (tranceiver.sender != null && tranceiver.sender.track != null) {
				tranceiver.sender.track.stop();
			}
		}
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
