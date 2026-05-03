# Getting Started

This guide quickly brings you up to speed on Borogove's Swift API. The API is flexible and allows you to build any type of chat or messaging app.

Add the Swift package in Xcode with **Add Package Dependencies** or in `Package.swift`:

```swift
dependencies: [
	.package(url: "https://borogove.dev/src/r/swiftpm")
]
```

Then import the library:

```swift
import Borogove
```

## Chat Client

Let's get started by initializing the SDK, creating a persistence layer, and creating a client for the current account:

```swift
import Borogove

setup { message in
	if let message {
		print(String(cString: message))
	}
}

let mediaStore = MediaStoreFS(path: "media")
let persistence = Sqlite(dbfile: "borogove.db", media: mediaStore)
let client = Client(accountId: "alice@example.com", persistence: persistence)
```

Now connect to the server and authenticate the user:

```swift
client.addPasswordNeededListener { client in
	client.usePassword(password: "mycoolpassword")
}

client.start()
```

In a real app you will usually prompt the user when this event fires. You should not store the password yourself, as Borogove persists the user's session token until an explicit logout.

## Chats

Let's continue by starting your first chat. A chat contains messages and a list of people participating in it. The example below starts a chat with a new contact:

```swift
func findOneChat(client: Client) async -> Chat? {
	for await availableChat in client.findAvailableChats(q: "hatter@example.com") {
		return client.startChat(availableChat: availableChat)
	}

	return nil
}
```

[`findAvailableChats`](./borogove/client/findavailablechats(q:).md) returns an async sequence of search results. Here we return the first result that is found.

You can always search by the full ID or URI of any chat on the network. Locally known chats will also be returned, as well as any chats from other services configured on the account.

If you have already used a chat before, you can always get it from [`getChat`](./borogove/client/getchat(chatid:).md) or list all known chats with [`getChats`](./borogove/client/getchats().md).

## Messages

Now that we have the chat set up, let's send our first message:

```swift
let outgoing = ChatMessageBuilder()
outgoing.setBody(html: Html.text(text: "I would like some tea."))
chat.sendMessage(message: outgoing)
```

You can also load the most recent messages from a chat's history:

```swift
let messages = await chat.getMessagesBefore(before: nil)
```

and send a reply to one of those:

```swift
let reply = messages[0].reply()
reply.setBody(html: Html.text(text: "Is that so?"))
chat.sendMessage(message: reply)
```

and mark off that you've read all of these:

```swift
if let last = messages.last {
	chat.markReadUpTo(message: last)
}
```

## Events

This is how you can listen to events:

```swift
let onlineEventToken = client.addStatusOnlineListener {
	print("\(client.accountId()) is online and in sync")
}

let messageEventToken = client.addChatMessageListener { message, eventType in
	print("Message \(message.body().toPlainText()) received or updated: \(eventType)")
}
```

Listeners return a token that can later be removed:

```swift
client.removeEventListener(token: onlineEventToken)
client.removeEventListener(token: messageEventToken)
```
