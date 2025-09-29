package borogove.calls;
// from js.html.rtc but cross platform

typedef IceServer = {
	var ?credential : String;
	// var ?credentialType : IceCredentialType;
	// var ?url : String;
	var ?urls : Array<String>;
	var ?username : String;
}
