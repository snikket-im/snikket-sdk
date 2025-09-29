package borogove;

enum abstract EncryptionStatus(Int) {
	var DecryptionSuccess; // Message was encrypted, and we decrypted it
	var DecryptionFailure; // Message is encrypted, and we failed to decrypt it
}

@:nullSafety(Strict)
class EncryptionInfo {
    public final status:EncryptionStatus;
    public final method:String;
    public final methodName:Null<String>;
    public final reason:Null<String>;
    public final reasonText:Null<String>;

	// List from XEP-0380
	private static final knownEncryptionSchemes:Map<String,String> = [
		"urn:xmpp:otr:0" => "OTR",
		"jabber:x:encrypted" => "Legacy OpenPGP",
		"urn:xmpp:openpgp:0" => "OpenPGP",
		"eu.siacs.conversations.axolotl" => "OMEMO",
		"urn:xmpp:omemo:1" => "OMEMO 1",
		"urn:xmpp:omemo:2" => "OMEMO 2",
    ];

    public function new(status:EncryptionStatus, method:String, ?methodName:String, ?reason:String, ?reasonText:String) {
        this.status = status;
        this.method = method;
        this.methodName = methodName;
        this.reason = reason;
        this.reasonText = reasonText;
    }

    public function toXml():Stanza {
        final el = new Stanza("decryption-status", {
            xmlns: "https://borogove.dev/protocol/sdk",
            encryption: this.method,
            result: status == DecryptionSuccess?"success":"failure",
        });
        if(reason != null) {
            el.textTag("reason", reason);
        }
        if(reasonText != null) {
            el.textTag("text", reasonText);
        }
        return el;
    }

    // Typically used to deduce an EncryptionInfo when none has been provided
    // May return null if the stanza is not recognizably encrypted.
    static public function fromStanza(stanza:Stanza):Null<EncryptionInfo> {
		final emeElement = stanza.getChild("encryption", "urn:xmpp:eme:0");
        // We did not decrypt this stanza, so check for any signs
        // that it was encrypted in the first place...
        var ns = null, name = null;
        if(emeElement != null) {
            ns = emeElement.attr.get("namespace");
            name = emeElement.attr.get("name");
        } else if(stanza.getChild("encrypted", "eu.siacs.conversations.axolotl") != null) {
            // Special handling for OMEMO without EME, just because it is
            // so widely used.
            ns = "eu.siacs.conversations.axolotl";
        }
        if(ns != null) {
            return new EncryptionInfo(
                DecryptionFailure,
                ns??"unknown",
                knownEncryptionSchemes.get(ns)??name??"Unknown encryption",
                "unsupported-encryption",
                "Unsupported encryption method: "+(name??ns)
            );
        }
        return null; // Probably not encrypted
    }
}
