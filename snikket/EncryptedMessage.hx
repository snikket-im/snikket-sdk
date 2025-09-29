package snikket;

import thenshim.Promise;

abstract class EncryptedMessage {
    abstract public function decrypt(client: Client):Promise<Message>;
}
