package snikket.jingle;

import js.html.rtc.PeerConnection;

@:native("RTCPeerConnection")
extern class PeerConnection extends js.html.rtc.PeerConnection {
	final connectionState: String;
}

typedef SdpType = js.html.rtc.SdpType;
typedef MediaStream = js.html.MediaStream;
typedef MediaStreamTrack = js.html.MediaStreamTrack;
typedef DTMFSender = js.html.rtc.DTMFSender;
