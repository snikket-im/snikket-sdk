import xmpp.Client;
import xmpp.EventHandler;

class Main {
	static public function main():Void {
		var client = new Client("user@example.com");

		client.on("status/online", function (data) {
			trace("CONNECTED CLIENT!");

			var chat = client.getDirectChat("user2@example.com");
			chat.getMessages(function (result) {
				trace('${result.messages.length} messages received:');
				for (message in result.messages) {
					trace('[${message.isIncoming()?"incoming":"outgoing"}]: ${message.text}');
				}
				trace("complete: " + !result.sync.hasMore());
			});
			chat.onMessage((msg) -> {
				trace("live message: ", msg);
			});

			return EventHandled;
		});

		client.on("auth/password-needed", function (data) {
			client.usePassword("secret-password");
			return EventHandled;
		});

		client.start();
	}
}
