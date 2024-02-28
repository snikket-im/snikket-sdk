package xmpp.jingle;
// from js.html.rtc but cross platform

typedef IceServer = {
	var ?credential : String;
	// var ?credentialType : IceCredentialType;
	var ?url : String;
	var ?urls : haxe.extern.EitherType<String,Array<String>>;
	var ?username : String;
}
