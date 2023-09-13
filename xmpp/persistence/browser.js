// This example persistence driver is written in JavaScript
// so that SDK users can easily see how to write their own

exports.xmpp.persistence = {
  browser: (dbname) => {
    var db = null;
    var dbOpenReq = indexedDB.open(dbname, 1);
    dbOpenReq.onerror = console.error;
    dbOpenReq.onupgradeneeded = (event) => {
      const upgradeDb = event.target.result;
      const store = upgradeDb.createObjectStore("messages", { keyPath: "serverId" });
      store.createIndex("account", ["timestamp", "account"]);
      store.createIndex("conversation", ["timestamp", "account", "conversation"]);
    };
    dbOpenReq.onsuccess = (event) => {
      db = event.target.result;
    };

    return {
	   lastId: function(account, jid, callback) {
		  const tx = db.transaction(["messages"], "readonly");
		  const store = tx.objectStore("messages");
		  var cursor = null;
		  if (jid === null) {
		    cursor = store.index("account").openCursor(
			   IDBKeyRange.bound([new Date(0), account], [new Date("9999-01-01"), account]),
			   "prev"
		    );
		  } else {
		    cursor = store.index("conversation").openCursor(
			   IDBKeyRange.bound([new Date(0), account, jid], [new Date("9999-01-01"), account, jid]),
			   "prev"
		    );
		  }
		  cursor.onsuccess = (event) => {
		    callback(event.target.result ? event.target.result.value.serverId : null);
		  }
		  cursor.onerror = (event) => {
		    console.error(event);
		    callback(null);
		  }
	   },

	   storeMessage: function(account, message) {
		  const tx = db.transaction(["messages"], "readwrite");
		  const store = tx.objectStore("messages");
		  store.put({
		    ...message,
		    account: account,
		    conversation: message.conversation(),
		    timestamp: new Date(message.timestamp),
		    direction: message.direction.toString()
		  });
      }
	 }
  }
};
