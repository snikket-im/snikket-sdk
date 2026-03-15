# Getting Started

This guide quickly brings you up to speed on Borogove's JavaScript API. The API is flexible and allows you to build any type of chat or messaging.

```console
npm i https://gitpkg-singpolyma.vercel.app/snikket-im/snikket-sdk/npm?compiled
```

There is a known bug in one of our JavaScript dependencies for browser builds, if xmpp.js is <= 0.14.0 then you may need something like this vite.config.js example

```js
resolve: {
	alias: {
		// https://github.com/xmppjs/xmpp.js/issues/1093
		"node:dns": "./src/dns-stub.js",
	},
},
```

And then the stub:

```js
export default {
	lookup: (x, y, cb) => cb(null, []),
	resolveSrv: (x, cb) => cb(null, []),
};
```

## Chat Client

Let's get started by  initializing the client and setting the current user and persistence layer:

```typescript
import * as borogove from "borogove";

// Cache avatars and other media in browser cache
const mediaStore = borogove.persistence.MediaStoreCache("myapp");

// Store chats and history in IndexedDB
const persist = await borogove.persistence.IDB("snikket", mediaStore);

// Create client
const client = new borogove.Client("alice@example.com", persist);
```

This example is for in the browser, but for other context only the persistence choices will need to change.

Now we need to connect to the server, which must be a [Snikket](https://snikket.org)-compatible instance living at `example.com`, and authenticate the user:

```typescript
client.addPasswordNeededListener() => {
	client.usePassword("mycoolpassword");
});

client.start();
```

In real life you probably want to prompt the user when receiving the event. You should not store the password anywhere, as Borogove will handle keeping the user's session token persisted until an explicit logout.

## Chats

Let’s continue by starting your first chat. A chat contains messages, a list of people that are participating, and optionally a list of members. The example below shows how to start a chat with a new contact:

```typescript
async function findOneChat(client: borogove.Client): borogove.Chat {
	const iterator = client.findAvailableChats("hatter@example.com");
	for await (const availableChat of iterator) {
		return client.startChat(availableChat);
	}

	return null;
}
```

[`findAvailableChats`](./borogove.client.findavailablechats.md) return an async iterator over all the search results. Here we return the first one that is found.

You can always search by the full ID or URI of any chat on the network. Locally known chats will also be returned, as well as any chats from other services configured on the account.

If you have already used a chat before, you can always get it from [`getChat`](./borogove.client.getchat.md) or list all known chats with [`getChats`](./borogove.client.getchats.md).

## Messages

Now that we have the chat set up, let's send our first message.

```typescript
chat.sendMessage(new borogove.ChatMessageBuilder({
	localId: crypto.randomUUID(),
	text: "I would like some tea."
}));
```

We can also load the most recent messages from a chat's history:

```typescript
const messages = await chat.getMessagesBefore(null, null);
```

and send a reply to one of those:

```typescript
const reply = messages[0].reply();
reply.localId = crypto.randomUUID();
reply.text = "Is that so?";
chat.sendMessage(reply);
```

and mark off that we've read all these:

```typescript
chat.markReadUpTo(messages[messages.length - 1]);
```

## Events

This is how you can listen to events:

```typescript
const onlineEventToken = client.addStatusOnlineListener(() => {
	console.log(`${client.accountId()} is online and in sync`)
});

const messageEventToken = client.addMessageListener((message, eventType) => {
	console.log(`Message ${mesage.text} received or updated`, eventType);
});

```
