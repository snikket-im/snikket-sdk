package test;

import utest.Assert;
import utest.Async;
import borogove.Stanza;
import borogove.calls.SessionDescription;

class TestSessionDescription extends utest.Test {
	final stanzaSource = '<iq type="set"><jingle sid="kxcebFwaWUQTQQO5sUoJJA" action="session-initiate" xmlns="urn:xmpp:jingle:1"><group semantics="BUNDLE" xmlns="urn:xmpp:jingle:apps:grouping:0"><content name="0"/></group><content name="0" creator="initiator" xmlns="urn:xmpp:jingle:1"><description media="audio" xmlns="urn:xmpp:jingle:apps:rtp:1"><payload-type channels="2" name="opus" clockrate="48000" id="111" xmlns="urn:xmpp:jingle:apps:rtp:1"><parameter name="minptime" value="10" xmlns="urn:xmpp:jingle:apps:rtp:1"/><parameter name="useinbandfec" value="1" xmlns="urn:xmpp:jingle:apps:rtp:1"/><rtcp-fb type="transport-cc" xmlns="urn:xmpp:jingle:apps:rtp:rtcp-fb:0"/></payload-type><payload-type channels="2" name="red" clockrate="48000" id="63" xmlns="urn:xmpp:jingle:apps:rtp:1"/><payload-type name="ISAC" clockrate="16000" id="103" xmlns="urn:xmpp:jingle:apps:rtp:1"/><payload-type name="ISAC" clockrate="32000" id="104" xmlns="urn:xmpp:jingle:apps:rtp:1"/><payload-type name="G722" clockrate="8000" id="9" xmlns="urn:xmpp:jingle:apps:rtp:1"/><payload-type name="ILBC" clockrate="8000" id="102" xmlns="urn:xmpp:jingle:apps:rtp:1"/><payload-type name="PCMU" clockrate="8000" id="0" xmlns="urn:xmpp:jingle:apps:rtp:1"/><payload-type name="PCMA" clockrate="8000" id="8" xmlns="urn:xmpp:jingle:apps:rtp:1"/><payload-type name="CN" clockrate="32000" id="106" xmlns="urn:xmpp:jingle:apps:rtp:1"/><payload-type name="CN" clockrate="16000" id="105" xmlns="urn:xmpp:jingle:apps:rtp:1"/><payload-type name="CN" clockrate="8000" id="13" xmlns="urn:xmpp:jingle:apps:rtp:1"/><payload-type name="telephone-event" clockrate="48000" id="110" xmlns="urn:xmpp:jingle:apps:rtp:1"/><payload-type name="telephone-event" clockrate="32000" id="112" xmlns="urn:xmpp:jingle:apps:rtp:1"/><payload-type name="telephone-event" clockrate="16000" id="113" xmlns="urn:xmpp:jingle:apps:rtp:1"/><payload-type name="telephone-event" clockrate="8000" id="126" xmlns="urn:xmpp:jingle:apps:rtp:1"/><rtp-hdrext uri="urn:ietf:params:rtp-hdrext:ssrc-audio-level" id="1" xmlns="urn:xmpp:jingle:apps:rtp:rtp-hdrext:0"/><rtp-hdrext uri="http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time" id="2" xmlns="urn:xmpp:jingle:apps:rtp:rtp-hdrext:0"/><rtp-hdrext uri="http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01" id="3" xmlns="urn:xmpp:jingle:apps:rtp:rtp-hdrext:0"/><rtp-hdrext uri="urn:ietf:params:rtp-hdrext:sdes:mid" id="4" xmlns="urn:xmpp:jingle:apps:rtp:rtp-hdrext:0"/><extmap-allow-mixed xmlns="urn:xmpp:jingle:apps:rtp:rtp-hdrext:0"/><source ssrc="3713170236" xmlns="urn:xmpp:jingle:apps:rtp:ssma:0"><parameter name="cname" value="KP3+b0QvXtga40Uo"/><parameter name="msid" value="- audio-track-76673976-daf1-4afa-bed8-1277ddc1c7f7"/></source><rtcp-mux/></description><transport pwd="88yXZajgGS00ziBDQ0yLtr9t" ufrag="r8tL" xmlns="urn:xmpp:jingle:transports:ice-udp:1"><fingerprint setup="actpass" hash="sha-256" xmlns="urn:xmpp:jingle:apps:dtls:0">26:58:C5:C5:68:7A:BA:C9:11:2D:6D:A3:C5:57:16:4C:E0:A0:46:06:FA:49:62:1B:54:E4:A5:F1:CB:89:18:43</fingerprint></transport></content></jingle></iq>';
	final sdpExample =
		"v=0\r\n" +
		"o=- 8770656990916039506 2 IN IP4 127.0.0.1\r\n" +
		"s=-\r\n" +
		"t=0 0\r\n" +
		"a=group:BUNDLE 0\r\n" +
		"a=msid-semantic:WMS my-media-stream\r\n" +
		"m=audio 9 UDP/TLS/RTP/SAVPF 111 63 103 104 9 102 0 8 106 105 13 110 112 113 126\r\n"+
		"c=IN IP4 0.0.0.0\r\n" +
		"a=ice-ufrag:r8tL\r\n" +
		"a=ice-pwd:88yXZajgGS00ziBDQ0yLtr9t\r\n" +
		"a=ice-options:trickle\r\n" +
		"a=fingerprint:sha-256 26:58:C5:C5:68:7A:BA:C9:11:2D:6D:A3:C5:57:16:4C:E0:A0:46:06:FA:49:62:1B:54:E4:A5:F1:CB:89:18:43\r\n" +
		"a=setup:actpass\r\n" +
		"a=rtpmap:111 opus/48000/2\r\n" +
		"a=fmtp:111 minptime=10;useinbandfec=1\r\n" +
		"a=rtcp-fb:111 transport-cc\r\n" +
		"a=rtpmap:63 red/48000/2\r\n" +
		"a=rtpmap:103 ISAC/16000\r\n" +
		"a=rtpmap:104 ISAC/32000\r\n" +
		"a=rtpmap:9 G722/8000\r\n" +
		"a=rtpmap:102 ILBC/8000\r\n" +
		"a=rtpmap:0 PCMU/8000\r\n" +
		"a=rtpmap:8 PCMA/8000\r\n" +
		"a=rtpmap:106 CN/32000\r\n" +
		"a=rtpmap:105 CN/16000\r\n" +
		"a=rtpmap:13 CN/8000\r\n" +
		"a=rtpmap:110 telephone-event/48000\r\n" +
		"a=rtpmap:112 telephone-event/32000\r\n" +
		"a=rtpmap:113 telephone-event/16000\r\n" +
		"a=rtpmap:126 telephone-event/8000\r\n" +
		"a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level\r\n" +
		"a=extmap:2 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time\r\n" +
		"a=extmap:3 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01\r\n" +
		"a=extmap:4 urn:ietf:params:rtp-hdrext:sdes:mid\r\n" +
		"a=extmap-allow-mixed\r\n" +
		"a=ssrc:3713170236 cname:KP3+b0QvXtga40Uo\r\n" +
		"a=ssrc:3713170236 msid:- audio-track-76673976-daf1-4afa-bed8-1277ddc1c7f7\r\n" +
		"a=mid:0\r\n" +
		"a=sendrecv\r\n" +
		"a=rtcp-mux\r\n" +
		"a=rtcp:9 IN IP4 0.0.0.0\r\n";

	final sdpExampleAnswer =
		"v=0\r\n" +
		"o=mozilla...THIS_IS_SDPARTA-99.0 4223511214128453424 0 IN IP4 0.0.0.0\r\n" +
		"s=-\r\n" +
		"t=0 0\r\n" +
		"a=sendrecv\r\n" +
		"a=fingerprint:sha-256 64:09:24:0A:A4:75:84:7D:61:6F:78:13:83:AB:8B:57:6E:E9:EF:39:FC:3A:92:17:AA:8C:0C:C1:9D:74:61:DF\r\n" +
		"a=group:BUNDLE 0\r\n" +
		"a=ice-options:trickle\r\n" +
		"a=msid-semantic:WMS *\r\n" +
		"m=audio 52831 UDP/TLS/RTP/SAVPF 111 9 0 8 126\r\n" +
		"c=IN IP4 127.0.0.1\r\n" +
		"a=candidate:0 1 UDP 2122252543 78677bb1-7843-4445-b8e7-44449283c4e1.local 38038 typ host\r\n" +
		"a=candidate:3 1 TCP 2105524479 78677bb1-7843-4445-b8e7-44449283c4e1.local 9 typ host tcptype active\r\n" +
		"a=candidate:1 1 UDP 1686052863 127.0.0.1 38038 typ srflx raddr 0.0.0.0 rport 0\r\n" +
		"a=candidate:2 1 UDP 92216319 127.0.0.1 52831 typ relay raddr 127.0.0.1 rport 52831\r\n" +
		"a=candidate:4 1 UDP 8331263 127.0.0.1 55366 typ relay raddr 127.0.0.1 rport 55366\r\n" +
		"a=recvonly\r\n" +
		"a=end-of-candidates\r\n" +
		"a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level\r\n" +
		"a=extmap:4 urn:ietf:params:rtp-hdrext:sdes:mid\r\n" +
		"a=fmtp:111 maxplaybackrate=48000;stereo=1;useinbandfec=1\r\n" +
		"a=fmtp:126 0-15\r\n" +
		"a=ice-pwd:4e45923f3734c434427d7bd002c79fd4\r\n" +
		"a=ice-ufrag:fe3fcb84\r\n" +
		"a=mid:0\r\n" +
		"a=rtcp-mux\r\n" +
		"a=rtpmap:111 opus/48000/2\r\n" +
		"a=rtpmap:9 G722/8000/1\r\n" +
		"a=rtpmap:0 PCMU/8000\r\n" +
		"a=rtpmap:8 PCMA/8000\r\n" +
		"a=rtpmap:126 telephone-event/8000\r\n" +
		"a=setup:active\r\n" +
		"a=ssrc:691851057 cname:{df71a836-615d-4bab-bf3e-7f2ee9d2f0a1}\r\n";

	public function testConvertStanzaToSDP() {
		final session = SessionDescription.fromStanza(Stanza.fromXml(Xml.parse(stanzaSource)), false);
		Assert.equals(sdpExample, session.toSdp());
	}

	public function testConvertSDPToSDP() {
		final session = SessionDescription.parse(sdpExample);
		Assert.equals(sdpExample, session.toSdp());
	}

	public function testConvertSDPToStanzaAndBack() {
		final session = SessionDescription.parse(sdpExample);
		Assert.equals(
			sdpExample,
			SessionDescription.fromStanza(session.toStanza("session-initiate", "kxcebFwaWUQTQQO5sUoJJA", false), false).toSdp()
		);
	}

	public function testConvertSDPAnswerToStanza() {
		final stanza = SessionDescription.parse(sdpExampleAnswer).toStanza("session-accept", "sid", false);
		Assert.notNull(stanza.getChild("jingle", "urn:xmpp:jingle:1").getChild("content").getChild("transport", "urn:xmpp:jingle:transports:ice-udp:1").getChild("candidate"));
	}
}
