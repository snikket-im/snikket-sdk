package borogove;

import haxe.io.BytesData;

using thenshim.Promise;

// A description for of the types and methods used and provided by libsignal

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

typedef SignedPublicPreKey = {
	var keyId: Int;
	var publicKey: BytesData;
	var signature: BytesData;
}

typedef SignalCipherText = {
	// '1' for session key, '3' for prekey
	var type: Int;
	var body: String;
}

@:structInit
class SignalPublicPreKeyInfo {
	final keyId: Int;
	final publicKey: BytesData;
}

@:structInit
class SignalDeviceInfo {
	final registrationId: Int;
	final identityKey: IdentityPublicKey;
	final signedPreKey: SignedPublicPreKey;
	final preKey: SignalPublicPreKeyInfo;
}

@:native("libsignal.SignalProtocolAddress")
extern class SignalProtocolAddress {
	public function new(name:String, deviceId:Int);
	public function getName():String;
	public function getDeviceId():Int;
	public function toString():String;
	public function equals():Bool;
	static public function fromString(str:String):SignalProtocolAddress;
}

@:native("libsignal.SessionBuilder")
extern class SessionBuilder {
	public function new(store:SignalProtocolStore, address:SignalProtocolAddress);
	public function processPreKey(device:SignalDeviceInfo):Promise<Any>;
}

@:native("libsignal.SessionCipher")
extern class SessionCipher {
	public function new(store:SignalProtocolStore, address:SignalProtocolAddress);
	public function decryptPreKeyWhisperMessage(ciphertext:BytesData):Promise<BytesData>;
	public function decryptWhisperMessage(ciphertext:BytesData):Promise<BytesData>;
	public function encrypt(plaintext:BytesData):Promise<SignalCipherText>;
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
	public final Direction = {
		SENDING: 1,
		RECEIVING: 2,
	};
	// Return our identity keypair
	// Note: There is no corresponding function in this interface to
	// store our identity keypair (this is out of scope for libsignal,
	// the application will store it directly with the persistence API)
	abstract public function getIdentityKeyPair():Promise<IdentityKeyPair>;

	// Return our "device id"
	abstract public function getLocalRegistrationId():Promise<Int>;

	// Return a boolean indicating whether we trust this identity
	abstract public function isTrustedIdentity(identifier: String, identityKey: IdentityPublicKey, _direction: Int):Promise<Bool>;

	abstract public function loadIdentityKey(identifier: SignalProtocolAddress):Promise<IdentityPublicKey>;

	abstract public function saveIdentity(identifier: SignalProtocolAddress, identityKey:IdentityPublicKey):Promise<Bool>;

	abstract public function loadPreKey(keyId:Int):Promise<PreKeyPair>;

	abstract public function storePreKey(keyId:Int, keyPair:PreKeyPair):Promise<Bool>;

	abstract public function removePreKey(keyId:Int):Promise<Bool>;

	abstract public function loadSignedPreKey(keyId:Int):Promise<PreKeyPair>;

	abstract public function storeSignedPreKey(keyId:Int, keyPair:SignedPreKey):Promise<Bool>;

	abstract public function removeSignedPreKey(keyId:Int):Promise<Bool>;

	abstract public function loadSession(identifier:SignalProtocolAddress):Promise<SignalSession>;

	abstract public function storeSession(identifier:SignalProtocolAddress, session:SignalSession):Promise<Bool>;

	abstract public function removeSession(identifier:SignalProtocolAddress):Promise<Bool>;

	abstract public function removeAllSessions(identifier:SignalProtocolAddress):Promise<Bool>;
}
