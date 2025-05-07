package snikket;

@:structInit
class EncryptionPolicy {
    // These allow blocking all incoming/outgoing
    // chat messages which are not using E2EE
	public final allowUnencryptedIncoming:Bool;
	public final allowUnencryptedOutgoing:Bool;

    // Outgoing encryption will be preferred,
    // but may not be used if a recipient lacks
    // support (and of course if the above
    // policies permit unencrypted)
    public final preferEncryptedOutgoing:Bool;
}
