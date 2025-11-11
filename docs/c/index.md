# Getting Started

This guide quickly brings you up to speed on Borogove's C API. The API is flexible and allows you to build any type of chat or messaging.

## Chat Client

Let's get started by  initializing the client and setting the current user and persistence layer:

```c
#include <borogove.h>

int main(void) {
	// Cache avatars and other media in a directory
	void *media_store = borogove_persistence_media_store_fs_new("./media");

	// Store chats and history in SQLite
	void *persist = borogove_persistence_sqlite_new("./db.sqlite3", media_store);

	// Create client
	void *client = borogove_client_new("alice@example.com", persist);
```

Now we need to connect to the server, which must be a [Snikket](https://snikket.org)-compatible instance living at `example.com`, and authenticate the user:

```c
// This will run on a background thread
void on_password_needed(void *client, void *password) {
	borogove_client_use_password(client, password);
	borogove_release(client);
}

// And in main...

borogove_client_add_password_needed_listener(client, on_password_needed, "mycoolpassword");

borogove_client_start(client);
```

In real life you probably want to prompt the user when receiving the event. You should not store the password anywhere, as Borogove will handle keeping the user's session token persisted until an explicit logout.

## Chats

Let’s continue by starting your first chat. A chat contains messages, a list of people that are participating, and optionally a list of members. The example below shows how to start a chat with a new contact:

```c
void *chat = NULL;

// This will run on a background thread
bool available_chats(const char *q, void **chats, size_t cchats, void *client) {
	// You can check if q is the search we expect
	// Allows running searches in parallel as a user types

	chat = borogove_client_start_chat(client, chats[0]);

	// Don't forget to release your memory
	for (size_t i = 0; i < cchats; i++) {
		borogove_release(chats[i]);
	}
	borogove_release(chats);
	borogove_release(q);

	// Stop searching
	return true;
}

// And in main...

borogove_client_find_available_chats(client, "hatter@example.com", available_chats, client);
```

`borogove_client_find_available_chats` will call the callback with all results found so far, and keep searching until either it has exhausted all options or the callback returns `true`. Here we just store in a global the first chat that was found, as simple example.

You can always search by the full ID or URI of any chat on the network. Locally known chats will also be returned, as well as any chats from other services configured on the account.

If you have already used a chat before, you can always get it from `borgove_client_get_chat` or list all known chats with `borogove_client_get_chats`.

## Messages

Now that we have the chat set up, let's send our first message.

```c
// Add to available_chats handler

coid *builder = borogove_chat_message_builder_new();
borogove_chat_message_builder_set_text(builder, "I would like some tea.");
borogove_chat_send_message(chat, builder);
borogove_release(builder);
```

## Events

This is how you can listen to events:

```c
int otoken = client_add_status_online_listener(client, &online_handler, context_or_null);
int mtoken = client_add_message_listener(client, &message_handler, context_or_null);
```

Handlers run in a background thread separate from your UI or event loop.
