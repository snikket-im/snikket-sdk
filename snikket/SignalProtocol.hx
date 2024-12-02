package snikket;

import haxe.io.BytesData;

using thenshim.Promise;

// Types and methods used/provided by libsignal

@:expose
typedef IdentityPublicKey = BytesData;

@:expose
typedef IdentityKeyPair = {
	var privKey: BytesData;
	var pubKey: BytesData;
}

@:expose
typedef PublicPreKey = {
	var keyId: Int;
	// Base64 representation of the public key
	var pubKey: String;
}

@:expose
typedef PreKeyPair = {
	var privKey: BytesData;
	var pubKey: BytesData;
}

@:expose
typedef PreKey = {
	var keyId: Int;
	var keyPair: PreKeyPair;
}

@:expose
typedef SignedPreKey = {
	var keyId: Int;
	var keyPair: PreKeyPair;
	var signature: BytesData;
}

// Not sure what the fields are for this one
typedef SignalSession = Dynamic;

@:native("libsignal.KeyHelper")
extern class KeyHelper {
	static function generateRegistrationId():Int;
	static function generatePreKey(keyId: Int):Promise<PreKey>;
	static function generateIdentityKeyPair():Promise<IdentityKeyPair>;
	static function generateSignedPreKey(identityKeyPair: IdentityKeyPair, keyId: Int):Promise<SignedPreKey>;
}

abstract class SignalProtocolStore {
	static final Direction = {
		SENDING: 1,
		RECEIVING: 2,
	};
	// Return our identity keypair
	abstract public function getIdentityKeyPair():IdentityKeyPair;

	// Return our "device id"
	abstract public function getLocalRegistrationId():Int;

	// Return a boolean indicating whether we trust this identity
	abstract public function isTrustedIdentity(identifier: String, identityKey: IdentityPublicKey, _direction: Int):Promise<Bool>;

	abstract public function loadIdentityKey(identifier: String):Promise<IdentityPublicKey>;

	abstract public function saveIdentity(identifier: String, identityKey:IdentityPublicKey):Promise<Bool>;

	abstract public function loadPreKey(keyId:Int):Promise<PreKeyPair>;

	abstract public function storePreKey(keyId:Int, keyPair:PreKeyPair):Promise<Bool>;

	abstract public function removePreKey(keyId:Int):Promise<Bool>;

	abstract public function loadSignedPreKey(keyId:Int):Promise<SignedPreKey>;

	abstract public function storeSignedPreKey(keyId:Int, keyPair:SignedPreKey):Promise<Bool>;

	abstract public function removeSignedPreKey(keyId:Int):Promise<Bool>;

	abstract public function loadSession(identifier:String):Promise<SignalSession>;

	abstract public function storeSession(identifier:String, session:SignalSession):Promise<Bool>;

	abstract public function removeSession(identifier:String):Promise<Bool>;

	abstract public function removeAllSessions(identifier:String):Promise<Bool>;
}
