import { sqlite3Worker1Promiser as borogove_persistence_Worker1 } from "@sqlite.org/sqlite-wasm";
import * as borogove from "./borogove-browser.js"
var $global = globalThis;
class borogove_persistence_Sqlite {
    constructor(dbfile, media) {
        this.smStoreNext = null;
        this.smStoreInProgress = false;
        this.storeChatTimer = null;
        this.storeChatBuffer = new Map([]);
        this.storeMessagesSerialized = new borogove.borogove_AsyncLock();
        this.media = media;
        media.setKV(this);
        this.db = new borogove_persistence_SqliteDriver(dbfile, function (exec) {
            return borogove.thenshim_Promise.then(exec(["PRAGMA user_version"]), function (iter) {
                let version;
                let tmp = iter.array[iter.current++];
                let tmp1 = borogove.Std.parseInt(tmp != null ? tmp.user_version : null);
                version = tmp1 != null ? tmp1 : 0;
                return borogove.thenshim_Promise.then(borogove.thenshim_Promise.then(borogove.thenshim_Promise.then(borogove.thenshim_Promise.then(borogove.thenshim_Promise.then(borogove.thenshim_Promise.then(borogove.thenshim_Promise.then(borogove.thenshim_Promise.then(borogove.thenshim_Promise.then(borogove.thenshim_Promise.resolve(null), function (_) {
                    if (version < 1) {
                        return exec(["CREATE TABLE messages (\n\t\t\t\t\t\t\taccount_id TEXT NOT NULL,\n\t\t\t\t\t\t\tmam_id TEXT NOT NULL,\n\t\t\t\t\t\t\tmam_by TEXT NOT NULL,\n\t\t\t\t\t\t\tstanza_id TEXT NOT NULL,\n\t\t\t\t\t\t\tcorrection_id TEXT NOT NULL,\n\t\t\t\t\t\t\tsync_point INTEGER NOT NULL,\n\t\t\t\t\t\t\tchat_id TEXT NOT NULL,\n\t\t\t\t\t\t\tsender_id TEXT NOT NULL,\n\t\t\t\t\t\t\tcreated_at INTEGER NOT NULL,\n\t\t\t\t\t\t\tstatus INTEGER NOT NULL,\n\t\t\t\t\t\t\tdirection INTEGER NOT NULL,\n\t\t\t\t\t\t\ttype INTEGER NOT NULL,\n\t\t\t\t\t\t\tstanza TEXT NOT NULL,\n\t\t\t\t\t\t\tPRIMARY KEY (account_id, mam_id, mam_by, stanza_id)\n\t\t\t\t\t\t) STRICT", "CREATE INDEX messages_created_at ON messages (account_id, chat_id, created_at)", "CREATE INDEX messages_correction_id ON messages (correction_id)", "CREATE TABLE chats (\n\t\t\t\t\t\t\taccount_id TEXT NOT NULL,\n\t\t\t\t\t\t\tchat_id TEXT NOT NULL,\n\t\t\t\t\t\t\ttrusted INTEGER NOT NULL,\n\t\t\t\t\t\t\tavatar_sha1 BLOB,\n\t\t\t\t\t\t\tfn TEXT,\n\t\t\t\t\t\t\tui_state INTEGER NOT NULL,\n\t\t\t\t\t\t\tblocked INTEGER NOT NULL,\n\t\t\t\t\t\t\textensions TEXT,\n\t\t\t\t\t\t\tread_up_to_id TEXT,\n\t\t\t\t\t\t\tread_up_to_by TEXT,\n\t\t\t\t\t\t\tcaps_ver BLOB,\n\t\t\t\t\t\t\tpresence BLOB NOT NULL,\n\t\t\t\t\t\t\tclass TEXT NOT NULL,\n\t\t\t\t\t\t\tPRIMARY KEY (account_id, chat_id)\n\t\t\t\t\t\t) STRICT", "CREATE TABLE keyvaluepairs (\n\t\t\t\t\t\t\tk TEXT NOT NULL PRIMARY KEY,\n\t\t\t\t\t\t\tv TEXT NOT NULL\n\t\t\t\t\t\t) STRICT", "CREATE TABLE caps (\n\t\t\t\t\t\t\tsha1 BLOB NOT NULL PRIMARY KEY,\n\t\t\t\t\t\t\tcaps BLOB NOT NULL\n\t\t\t\t\t\t) STRICT", "CREATE TABLE services (\n\t\t\t\t\t\t\taccount_id TEXT NOT NULL,\n\t\t\t\t\t\t\tservice_id TEXT NOT NULL,\n\t\t\t\t\t\t\tname TEXT,\n\t\t\t\t\t\t\tnode TEXT,\n\t\t\t\t\t\t\tcaps BLOB NOT NULL,\n\t\t\t\t\t\t\tPRIMARY KEY (account_id, service_id)\n\t\t\t\t\t\t) STRICT", "CREATE TABLE accounts (\n\t\t\t\t\t\t\taccount_id TEXT NOT NULL,\n\t\t\t\t\t\t\tclient_id TEXT NOT NULL,\n\t\t\t\t\t\t\tdisplay_name TEXT,\n\t\t\t\t\t\t\ttoken TEXT,\n\t\t\t\t\t\t\tfast_count INTEGER NOT NULL DEFAULT 0,\n\t\t\t\t\t\t\tsm_state BLOB,\n\t\t\t\t\t\t\tPRIMARY KEY (account_id)\n\t\t\t\t\t\t) STRICT", "CREATE TABLE reactions (\n\t\t\t\t\t\t\taccount_id TEXT NOT NULL,\n\t\t\t\t\t\t\tupdate_id TEXT NOT NULL,\n\t\t\t\t\t\t\tmam_id TEXT,\n\t\t\t\t\t\t\tmam_by TEXT,\n\t\t\t\t\t\t\tstanza_id TEXT,\n\t\t\t\t\t\t\tchat_id TEXT NOT NULL,\n\t\t\t\t\t\t\tsender_id TEXT NOT NULL,\n\t\t\t\t\t\t\tcreated_at INTEGER NOT NULL,\n\t\t\t\t\t\t\treactions BLOB NOT NULL,\n\t\t\t\t\t\t\tkind INTEGER NOT NULL,\n\t\t\t\t\t\t\tPRIMARY KEY (account_id, chat_id, sender_id, update_id)\n\t\t\t\t\t\t) STRICT", "PRAGMA user_version = 1"]);
                    }
                    return borogove.thenshim_Promise.resolve(null);
                }), function (_) {
                    if (version < 2) {
                        return exec(["ALTER TABLE chats ADD COLUMN notifications_filtered INTEGER", "ALTER TABLE chats ADD COLUMN notify_mention INTEGER NOT NULL DEFAULT 0", "ALTER TABLE chats ADD COLUMN notify_reply INTEGER NOT NULL DEFAULT 0", "PRAGMA user_version = 2"]);
                    }
                    return borogove.thenshim_Promise.resolve(null);
                }), function (_) {
                    if (version < 3) {
                        return exec(["ALTER TABLE messages ADD COLUMN status_text TEXT", "PRAGMA user_version = 3"]);
                    }
                    return borogove.thenshim_Promise.resolve(null);
                }), function (_) {
                    if (version < 4) {
                        return exec(["CREATE INDEX messages_stanza_id on messages (account_id, stanza_id)", "PRAGMA user_version = 4"]);
                    }
                    return borogove.thenshim_Promise.resolve(null);
                }), function (_) {
                    if (version < 5) {
                        return exec(["CREATE INDEX messages_mam_id on messages (account_id, chat_id, mam_id)", "PRAGMA user_version = 5"]);
                    }
                    return borogove.thenshim_Promise.resolve(null);
                }), function (_) {
                    if (version < 6) {
                        return exec(["ALTER TABLE chats ADD COLUMN bookmarked INTEGER NOT NULL DEFAULT 0", "PRAGMA user_version = 6"]);
                    }
                    return borogove.thenshim_Promise.resolve(null);
                }), function (_) {
                    if (version < 7) {
                        return exec(["DELETE FROM messages WHERE rowid IN (SELECT rowid FROM (select rowid, ROW_NUMBER() OVER (PARTITION BY account_id, stanza_id ORDER BY (mam_id <> '') DESC, rowid DESC) AS rn FROM messages WHERE direction=1 AND stanza_id<>'') WHERE rn<>1)", "CREATE UNIQUE INDEX messages_stanza_id_sent_unique ON messages (account_id, stanza_id) WHERE stanza_id<>'' AND direction=" + "1", "PRAGMA user_version = 7"]);
                    }
                    return borogove.thenshim_Promise.resolve(null);
                }), function (_) {
                    if (version < 8) {
                        return borogove.thenshim_Promise.then(borogove.thenshim_Promise.then(borogove.thenshim_Promise.then(exec(["ALTER TABLE messages ADD COLUMN sort_id TEXT NOT NULL DEFAULT 'a '", "CREATE INDEX messages_sort_id ON messages (account_id, chat_id, sort_id)"]), function (_) {
                            return exec(["SELECT ROWID FROM messages ORDER BY created_at"]);
                        }), function (rows) {
                            let promise = borogove.thenshim_Promise.resolve(null);
                            let toInsert = [];
                            let sortId = "a ";
                            while (rows.current < rows.array.length) {
                                let row = rows.array[rows.current++];
                                sortId = FractionalIndexing_between(sortId, null, " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~");
                                toInsert.push("UPDATE messages SET sort_id='" + StringTools.replace(sortId, "'", "''") + "' WHERE ROWID=" + row.rowid);
                                if (toInsert.length >= 10000) {
                                    promise = borogove.thenshim_Promise.then(promise, function (_) {
                                        return exec(toInsert);
                                    });
                                    toInsert = [];
                                }
                            }
                            return borogove.thenshim_Promise.then(promise, function (_) {
                                if (toInsert.length < 1) {
                                    return null;
                                }
                                else {
                                    return exec(toInsert);
                                }
                            });
                        }), function (_) {
                            return exec(["PRAGMA user_version = 8"]);
                        });
                    }
                    return borogove.thenshim_Promise.resolve(null);
                }), function (_) {
                    if (version < 9) {
                        return exec(["ALTER TABLE chats ADD COLUMN meta BLOB NOT NULL DEFAULT X'0C'", "PRAGMA user_version = 9"]);
                    }
                    return borogove.thenshim_Promise.resolve(null);
                });
            });
        });
    }
    get(k) {
        return borogove.thenshim_Promise.then(this.db.exec("SELECT v FROM keyvaluepairs WHERE k=? LIMIT 1", [k]), function (iter) {
            while (iter.current < iter.array.length)
                return iter.array[iter.current++].v;
            return null;
        });
    }
    set(k, v) {
        if (v == null) {
            return borogove.thenshim_Promise.then(this.db.exec("DELETE FROM keyvaluepairs WHERE k=?", [k]), function (_) {
                return true;
            });
        }
        else {
            return borogove.thenshim_Promise.then(this.db.exec("INSERT OR REPLACE INTO keyvaluepairs VALUES (?,?)", [k, v]), function (_) {
                return true;
            });
        }
    }
    syncPoint(accountId, chatId) {
        let params = [accountId];
        let q = "SELECT stanza, direction, type, status, status_text, strftime('%FT%H:%M:%fZ', created_at / 1000.0, 'unixepoch') AS timestamp, sender_id, mam_id, mam_by, sync_point, sort_id FROM messages WHERE mam_id IS NOT NULL AND mam_id<>'' AND sync_point AND account_id=?";
        if (chatId == null) {
            q = "SELECT stanza, direction, type, status, status_text, strftime('%FT%H:%M:%fZ', created_at / 1000.0, 'unixepoch') AS timestamp, sender_id, mam_id, mam_by, sync_point, sort_id FROM messages WHERE mam_id IS NOT NULL AND mam_id<>'' AND sync_point AND account_id=?" + " AND mam_by=?";
            params.push(accountId);
        }
        else {
            q = "SELECT stanza, direction, type, status, status_text, strftime('%FT%H:%M:%fZ', created_at / 1000.0, 'unixepoch') AS timestamp, sender_id, mam_id, mam_by, sync_point, sort_id FROM messages WHERE mam_id IS NOT NULL AND mam_id<>'' AND sync_point AND account_id=?" + " AND mam_by=?";
            params.push(chatId);
        }
        q += " ORDER BY sort_id DESC LIMIT 1";
        let _gthis = this;
        return borogove.thenshim_Promise.then(this.db.exec(q, params), function (result) {
            return _gthis.hydrateMessages(accountId, result)[0];
        });
    }
    storeChats(accountId, chats) {
        if (this.storeChatTimer != null) {
            this.storeChatTimer.stop();
        }
        let _g = 0;
        while (_g < chats.length) {
            let chat = chats[_g];
            ++_g;
            this.storeChatBuffer.set(accountId + "\n" + chat.chatId, chat);
        }
        let _gthis = this;
        this.storeChatTimer = borogove.haxe_Timer.delay(function () {
            let mapPresence = function (chat) {
                let storePresence = {};
                let jsIterator = chat.presence.entries();
                let _g_jsIterator = jsIterator;
                let _g_lastStep = jsIterator.next();
                while (!_g_lastStep.done) {
                    let v = _g_lastStep.value;
                    _g_lastStep = _g_jsIterator.next();
                    let resource = v[0];
                    let tmp = resource;
                    if (storePresence[tmp != null ? tmp : ""] == null) {
                        let value = v[1].toString();
                        let tmp = resource;
                        storePresence[tmp != null ? tmp : ""] = value;
                    }
                }
                return storePresence;
            };
            let q_b = "";
            q_b += "INSERT OR REPLACE INTO chats VALUES ";
            let first = true;
            let jsIterator = _gthis.storeChatBuffer.values();
            let __jsIterator = jsIterator;
            let __lastStep = jsIterator.next();
            while (!__lastStep.done) {
                __lastStep = __jsIterator.next();
                if (!first) {
                    q_b += ",";
                }
                first = false;
                q_b += "(?,?,?,?,?,?,?,?,?,?,?,jsonb(?),?,?,?,?,?,jsonb(?))";
            }
            let _gthis1 = _gthis.db;
            let this1 = _gthis.storeChatBuffer;
            let _g = [];
            let x = borogove.$getIterator({ iterator: function () {
                    return new borogove.js_lib_HaxeIterator(this1.values());
                } });
            while (x.hasNext()) {
                let x1 = x.next();
                let channel = ((x1) instanceof borogove.borogove_Channel) ? x1 : null;
                if (channel != null) {
                    _gthis.storeCaps(channel.disco);
                }
                let accountId1 = accountId;
                let x2 = x1.chatId;
                let row = x1.isTrusted();
                let x3 = x1.avatarSha1;
                let row1 = x1.getDisplayName();
                let x4 = x1.uiState;
                let x5 = x1.isBlocked;
                let row2 = x1.extensions.toString();
                let x6 = x1.readUpToId;
                let x7 = x1.readUpToBy;
                let tmp = channel != null ? channel.disco : null;
                let row3 = tmp != null ? tmp.verRaw().hash : null;
                let row4 = JSON.stringify(mapPresence(x1));
                let c = borogove.js_Boot.getClass(x1);
                let row5 = c.__name__.split(".").pop();
                let row6 = x1.notificationsFiltered();
                let row7 = x1.notifyMention();
                let row8 = x1.notifyReply();
                let x8 = x1.isBookmarked;
                let row9 = { emoji: x1.status.emoji, text: x1.status.text };
                let t = {};
                let jsIterator = x1.threads.entries();
                let _g_jsIterator = jsIterator;
                let _g_lastStep = jsIterator.next();
                while (!_g_lastStep.done) {
                    let v = _g_lastStep.value;
                    _g_lastStep = _g_jsIterator.next();
                    let tmp = v[0];
                    t[tmp != null ? tmp : ""] = v[1];
                }
                _g.push([accountId1, x2, row, x3, row1, x4, x5, row2, x6, x7, row3, row4, row5, row6, row7, row8, x8, borogove.borogove_JsonPrinter.print({ status: row9, threads: t })]);
            }
            let _g1 = [];
            let e = borogove.$getIterator(_g);
            while (e.hasNext()) {
                let x = borogove.$getIterator(e.next());
                while (x.hasNext())
                    _g1.push(x.next());
            }
            _gthis1.exec(q_b, _g1);
            _gthis.storeChatTimer = null;
            _gthis.storeChatBuffer.clear();
        }, 100);
    }
    searchMessages(accountId, chatId, q) {
        let sql = "SELECT stanza, direction, type, status, status_text, strftime('%FT%H:%M:%fZ', created_at / 1000.0, 'unixepoch') AS timestamp, sender_id, mam_id, mam_by, sort_id, sync_point FROM messages WHERE account_id=? AND stanza LIKE ?";
        let params = [accountId, "%" + q + "%"];
        if (chatId != null) {
            sql = "SELECT stanza, direction, type, status, status_text, strftime('%FT%H:%M:%fZ', created_at / 1000.0, 'unixepoch') AS timestamp, sender_id, mam_id, mam_by, sort_id, sync_point FROM messages WHERE account_id=? AND stanza LIKE ?" + " AND chat_id=?";
            params.push(chatId);
        }
        let _gthis = this;
        return borogove.thenshim_Promise.then(this.db.exec(sql, params), function (result) {
            return _gthis.hydrateMessages(accountId, result);
        });
    }
    getChats(accountId) {
        let _gthis = this;
        return borogove.thenshim_Promise.then(this.db.exec("SELECT chat_id, trusted, bookmarked, avatar_sha1, fn, ui_state, blocked, extensions, read_up_to_id, read_up_to_by, notifications_filtered, notify_mention, notify_reply, json(caps) AS caps, caps_ver, json(presence) AS presence, json(meta) AS meta, class FROM chats LEFT JOIN caps ON chats.caps_ver=caps.sha1 WHERE account_id=?", [accountId]), function (result) {
            let chats = [];
            while (result.current < result.array.length) {
                let row = result.array[result.current++];
                let capsJson = row.caps == null ? null : JSON.parse(row.caps);
                row.capsObj = capsJson == null ? null : _gthis.hydrateCaps(capsJson, row.caps_ver);
                let presenceJson = JSON.parse(row.presence);
                let presenceMap = new Map([]);
                let _g_keys = borogove.Reflect.fields(presenceJson);
                let _g_index = 0;
                while (_g_index < _g_keys.length) {
                    let key = _g_keys[_g_index++];
                    let _g_value = presenceJson[key];
                    if (typeof (_g_value) == "string") {
                        presenceMap.set(key, borogove.borogove_Stanza.parse(_g_value));
                    }
                    else {
                        presenceMap.set(key, borogove.borogove_Presence._new(_g_value.caps == null ? null : new borogove.borogove_Caps("", [], [], [], borogove.haxe_crypto_Base64.decode(_g_value.caps).b.bufferValue), _g_value.mucUser == null ? null : borogove.borogove_Stanza.parse(_g_value.mucUser), _g_value.avatarHash == null ? null : borogove.borogove_Hash.fromUri(_g_value.avatarHash)));
                    }
                }
                let metaJson = JSON.parse(row.meta);
                let threadsMap = new Map();
                let tmp = metaJson.threads;
                let access = tmp != null ? tmp : {};
                let _g_keys1 = borogove.Reflect.fields(access);
                let _g_index1 = 0;
                while (_g_index1 < _g_keys1.length) {
                    let key = _g_keys1[_g_index1++];
                    threadsMap.set(key == "" ? null : key, access[key]);
                }
                let tmp1 = metaJson.status;
                let tmp2 = tmp1 != null ? tmp1.emoji : null;
                let tmp3 = metaJson.status;
                let tmp4 = tmp3 != null ? tmp3.text : null;
                chats.push(new borogove.borogove_SerializedChat(row.chat_id, row.trusted != 0, row.bookmarked != 0, row.avatar_sha1, presenceMap, row.fn, row.ui_state, row.blocked != 0, new borogove.borogove_Status(tmp2 != null ? tmp2 : "", tmp4 != null ? tmp4 : ""), row.extensions, row.read_up_to_id, row.read_up_to_by, row.notifications_filtered == null ? null : row.notifications_filtered != 0, row.notify_mention != 0, row.notify_reply != 0, threadsMap, row.capsObj, [], borogove.Reflect.field(row, "class")));
            }
            return chats;
        });
    }
    storeMessages(accountId, messages) {
        if (messages.length < 1) {
            return borogove.thenshim_Promise.resolve(messages);
        }
        let chatIds = [];
        let localIds = [];
        let replyTos = [];
        let _g = 0;
        while (_g < messages.length) {
            let message = messages[_g];
            ++_g;
            if (message.sortId == null) {
                throw borogove.haxe_Exception.thrown("Cannot store a message with no sortId");
            }
            if (message.serverId == null && message.localId == null) {
                throw borogove.haxe_Exception.thrown("Cannot store a message with no id");
            }
            if (message.serverId == null && message.isIncoming()) {
                throw borogove.haxe_Exception.thrown("Cannot store an incoming message with no server id");
            }
            if (message.serverId != null && message.serverIdBy == null) {
                throw borogove.haxe_Exception.thrown("Cannot store a message with a server id and no by");
            }
            if (!message.isIncoming() && message.versions.length < 1) {
                chatIds.push(message.chatId());
                localIds.push(message.localId);
            }
            if (message.replyToMessage != null) {
                replyTos.push({ chatId: message.chatId(), serverId: message.replyToMessage.serverId, localId: message.replyToMessage.localId });
            }
        }
        let _gthis = this;
        return this.storeMessagesSerialized.run(function () {
            let _gthis1 = _gthis.db;
            let result = new Array(messages.length);
            let _g = 0;
            let _g1 = messages.length;
            while (_g < _g1)
                result[_g++] = "(?,?,?,?,?,?,?,?,CAST(unixepoch(?, 'subsec') * 1000 AS INTEGER),?,?,?,?,?,?)";
            let tmp = "INSERT OR REPLACE INTO messages VALUES " + result.join(",");
            let _g2 = [];
            let _g_current = 0;
            let _g_array = messages;
            while (_g_current < _g_array.length) {
                let x = _g_array[_g_current++];
                let message = x.versions.length == 1 ? x.versions[0] : x;
                let accountId1 = accountId;
                let tmp = message.serverId;
                let tmp1 = message.serverIdBy;
                let tmp2 = message.localId;
                let tmp3 = x.callSid();
                let tmp4 = tmp3 != null ? tmp3 : x.localId;
                let tmp5 = tmp4 != null ? tmp4 : x.serverId;
                let correctable = x.syncPoint;
                let tmp6 = x.chatId();
                _g2.push([accountId1, tmp != null ? tmp : "", tmp1 != null ? tmp1 : "", tmp2 != null ? tmp2 : "", tmp5, correctable, tmp6, x.senderId, message.timestamp, message.status, message.direction, message.type, message.asStanza().toString(), message.statusText, message.sortId]);
            }
            let _g3 = [];
            let e = borogove.$getIterator(_g2);
            while (e.hasNext()) {
                let x = borogove.$getIterator(e.next());
                while (x.hasNext())
                    _g3.push(x.next());
            }
            return borogove.thenshim_Promise.then(borogove.thenshim_Promise.then(_gthis1.exec(tmp, _g3), function (_) {
                return _gthis.hydrateReplyTo(accountId, messages, replyTos);
            }), function (ms) {
                return _gthis.hydrateReactions(accountId, ms);
            });
        });
    }
    updateMessage(accountId, message) {
        this.storeMessages(accountId, [message]);
    }
    getMessage(accountId, chatId, serverId, localId) {
        let q = "SELECT stanza, direction, type, status, status_text, strftime('%FT%H:%M:%fZ', created_at / 1000.0, 'unixepoch') AS timestamp, sender_id, mam_id, mam_by, sort_id, sync_point FROM messages WHERE account_id=? AND chat_id=?";
        let params = [accountId, chatId];
        if (serverId != null) {
            q = "SELECT stanza, direction, type, status, status_text, strftime('%FT%H:%M:%fZ', created_at / 1000.0, 'unixepoch') AS timestamp, sender_id, mam_id, mam_by, sort_id, sync_point FROM messages WHERE account_id=? AND chat_id=?" + " AND mam_id=?";
            params.push(serverId);
        }
        else if (localId != null) {
            q = "SELECT stanza, direction, type, status, status_text, strftime('%FT%H:%M:%fZ', created_at / 1000.0, 'unixepoch') AS timestamp, sender_id, mam_id, mam_by, sort_id, sync_point FROM messages WHERE account_id=? AND chat_id=?" + " AND stanza_id=?";
            params.push(localId);
        }
        q += "LIMIT 1";
        let _gthis = this;
        return borogove.thenshim_Promise.then(borogove.thenshim_Promise.then(this.db.exec(q, params), function (result) {
            return _gthis.hydrateMessages(accountId, result);
        }), function (messages) {
            let result = new Array(messages.length);
            let _g = 0;
            let _g1 = messages.length;
            while (_g < _g1) {
                let i = _g++;
                let message = messages[i];
                result[i] = borogove.thenshim_Promise.then(message.replyToMessage != null ? _gthis.hydrateReplyTo(accountId, [message], [{ chatId: chatId, serverId: message.replyToMessage.serverId, localId: message.replyToMessage.localId }]) : borogove.thenshim_Promise.resolve([message]), function (messages) {
                    return _gthis.hydrateReactions(accountId, messages);
                });
            }
            return borogove.thenshim_Promise.then(borogove.thenshim_Promise.then(borogove.thenshim_PromiseTools.all(result), function (items) {
                let _g = [];
                let _g_current = 0;
                while (_g_current < items.length) {
                    let x = borogove.$getIterator(items[_g_current++]);
                    while (x.hasNext())
                        _g.push(x.next());
                }
                return _g;
            }), function (items) {
                if (items.length > 0) {
                    return items[0];
                }
                else {
                    return null;
                }
            });
        });
    }
    getMessages(accountId, chatId, sortId, op, useTimestamp, timestamp) {
        if (useTimestamp == null) {
            useTimestamp = false;
        }
        if (useTimestamp && timestamp == null) {
            throw borogove.haxe_Exception.thrown("Cannot use timestamp without specifying one");
        }
        let q = "WITH page AS (SELECT stanza_id, mam_id FROM messages where account_id=? AND chat_id=? AND (stanza_id IS NULL OR stanza_id='' OR stanza_id=correction_id) AND type<>?";
        let params = [accountId, chatId, 3];
        if (useTimestamp) {
            q += " AND messages.created_at " + op + " unixepoch(?, 'subsec') * 1000";
            params.push(timestamp);
            q += " ORDER BY messages.created_at";
        }
        else if (sortId != null) {
            q += " AND messages.sort_id " + op + " ?";
            params.push(sortId);
            q += " ORDER BY messages.sort_id";
        }
        else {
            q += " ORDER BY messages.sort_id";
        }
        if (op == "<" || op == "<=") {
            q += " DESC";
        }
        q += " LIMIT 50) ";
        q += "SELECT\n\t\t\tcorrection_id AS stanza_id,\n\t\t\tversions.stanza,\n\t\t\tjson_group_object(CASE WHEN versions.mam_id IS NULL OR versions.mam_id='' THEN versions.stanza_id ELSE versions.mam_id END, strftime('%FT%H:%M:%fZ', versions.created_at / 1000.0, 'unixepoch')) AS version_times,\n\t\t\tjson_group_object(CASE WHEN versions.mam_id IS NULL OR versions.mam_id='' THEN versions.stanza_id ELSE versions.mam_id END, versions.stanza) AS versions,\n\t\t\tmessages.direction,\n\t\t\tmessages.type,\n\t\t\tmessages.status,\n\t\t\tmessages.status_text,\n\t\t\tstrftime('%FT%H:%M:%fZ', messages.created_at / 1000.0, 'unixepoch') AS timestamp,\n\t\t\tmessages.sender_id,\n\t\t\tmessages.mam_id,\n\t\t\tmessages.mam_by,\n\t\t\tmessages.sort_id,\n\t\t\tmessages.sync_point,\n\t\t\tMAX(versions.created_at)\n\t\t\tFROM messages INNER JOIN messages versions USING (correction_id, sender_id) WHERE (messages.stanza_id, messages.mam_id) IN (SELECT * FROM page) AND messages.account_id=? AND messages.chat_id=? GROUP BY correction_id, CASE WHEN messages.type=? THEN 'call' ELSE messages.sender_id END";
        q += " ORDER BY messages.sort_id";
        if (op == "<" || op == "<=") {
            q += " DESC";
        }
        q += ", messages.created_at";
        if (op == "<" || op == "<=") {
            q += " DESC";
        }
        params.push(accountId);
        params.push(chatId);
        params.push(1);
        let _gthis = this;
        return borogove.thenshim_Promise.then(borogove.thenshim_Promise.then(borogove.thenshim_Promise.then(this.db.exec(q, params), function (result) {
            let messages = _gthis.hydrateMessages(accountId, result);
            if (messages.length > 0 && messages[0].serverIdBy == chatId) {
                let boundary = messages[messages.length - 1].timestamp;
                let pmQ = "SELECT stanza, direction, type, status, status_text, strftime('%FT%H:%M:%fZ', created_at / 1000.0, 'unixepoch') AS timestamp, sender_id, mam_id, mam_by, sort_id, sync_point FROM messages WHERE account_id=? AND chat_id=? AND type=?";
                let pmParams = [accountId, chatId, 3];
                if (timestamp != null) {
                    pmQ = "SELECT stanza, direction, type, status, status_text, strftime('%FT%H:%M:%fZ', created_at / 1000.0, 'unixepoch') AS timestamp, sender_id, mam_id, mam_by, sort_id, sync_point FROM messages WHERE account_id=? AND chat_id=? AND type=?" + (" AND messages.created_at " + op + " unixepoch(?, 'subsec') * 1000");
                    pmParams.push(timestamp);
                }
                if (op == "<" || op == "<=") {
                    pmQ += " AND messages.created_at > unixepoch(?, 'subsec') * 1000";
                    pmParams.push(boundary);
                }
                pmQ += " ORDER BY messages.created_at";
                if (op == "<" || op == "<=") {
                    q += " DESC";
                }
                pmQ += " LIMIT 50";
                return borogove.thenshim_Promise.then(_gthis.db.exec(pmQ, pmParams), function (pmResult) {
                    let pms = _gthis.hydrateMessages(accountId, pmResult);
                    let _g = 0;
                    while (_g < pms.length) {
                        let pm = pms[_g];
                        ++_g;
                        if (op == "<" || op == "<=") {
                            let idx = borogove.Lambda.findIndex(messages, function (m) {
                                return m.timestamp <= pm.timestamp;
                            });
                            if (idx >= 0) {
                                messages.splice(idx, 0, pm);
                            }
                        }
                        else {
                            let idx = messages.length - 1;
                            while (idx >= 0) {
                                if (messages[idx].timestamp < pm.timestamp) {
                                    break;
                                }
                                --idx;
                            }
                            if (idx >= 0) {
                                messages.splice(idx + 1, 0, pm);
                            }
                            if (pm.timestamp > boundary) {
                                break;
                            }
                        }
                    }
                    return messages;
                });
            }
            return borogove.thenshim_Promise.resolve(messages);
        }), function (messages) {
            if (op == "<" || op == "<=") {
                messages.reverse();
            }
            let replyTos = [];
            let _g = 0;
            while (_g < messages.length) {
                let message = messages[_g];
                ++_g;
                if (message.replyToMessage != null && message.replyToMessage.serverIdBy == null) {
                    replyTos.push({ chatId: message.chatId(), serverId: message.replyToMessage.serverId, localId: message.replyToMessage.localId });
                }
            }
            return _gthis.hydrateReplyTo(accountId, messages, replyTos);
        }), function (messages) {
            return _gthis.hydrateReactions(accountId, messages);
        });
    }
    getMessagesBefore(accountId, chatId, before) {
        return this.getMessages(accountId, chatId, before != null ? before.sortId : null, "<", (before != null ? before.type : null) == 3, before != null ? before.timestamp : null);
    }
    getMessagesAfter(accountId, chatId, after) {
        return this.getMessages(accountId, chatId, after != null ? after.sortId : null, ">", (after != null ? after.type : null) == 3, after != null ? after.timestamp : null);
    }
    getMessagesAround(accountId, around) {
        let chatId = around.chatId();
        return borogove.thenshim_Promise.then(borogove.thenshim_PromiseTools.all([this.getMessages(accountId, chatId, around.sortId, "<", (around != null ? around.type : null) == 3, around != null ? around.timestamp : null), this.getMessages(accountId, chatId, around.sortId, ">=", (around != null ? around.type : null) == 3, around != null ? around.timestamp : null)]), function (results) {
            let _g = [];
            let _g_current = 0;
            while (_g_current < results.length) {
                let x = borogove.$getIterator(results[_g_current++]);
                while (x.hasNext())
                    _g.push(x.next());
            }
            return _g;
        });
    }
    getChatUnreadDetails(accountId, chat) {
        let _gthis = this;
        return borogove.thenshim_Promise.then(this.db.exec("WITH subq AS (SELECT ROWID AS row, COALESCE(MAX(sort_id), 'a ') AS sort_id FROM messages where account_id=? AND chat_id=? AND (mam_id=? OR direction=?)) SELECT chat_id AS chatId, stanza, direction, type, status, status_text, sender_id, mam_id, mam_by, MAX(sort_id), sync_point, CASE WHEN (SELECT row FROM subq) IS NULL THEN COUNT(*) ELSE COUNT(*) - 1 END AS unreadCount, strftime('%FT%H:%M:%fZ', messages.created_at / 1000.0, 'unixepoch') AS timestamp FROM messages WHERE account_id=? AND chat_id=? AND (stanza_id IS NULL OR stanza_id='' OR stanza_id=correction_id) AND (messages.sort_id >= (SELECT sort_id FROM subq) AND (messages.sort_id <> (SELECT sort_id FROM subq) OR messages.ROWID = (SELECT row FROM subq)))", [accountId, chat.chatId, chat.readUpToId, 1, accountId, chat.chatId]), function (result) {
            let row = result.array[result.current++];
            let lastMessage = row.stanza == null ? [] : _gthis.hydrateMessages(accountId, new borogove.haxe_iterators_ArrayIterator([row]));
            return { unreadCount: row.unreadCount, chatId: chat.chatId, message: lastMessage[0] };
        });
    }
    getChatsUnreadDetails(accountId, chats) {
        if (chats == null || chats.length < 1) {
            return borogove.thenshim_Promise.resolve([]);
        }
        let result = new Array(chats.length);
        let _g = 0;
        let _g1 = chats.length;
        while (_g < _g1) {
            let i = _g++;
            result[i] = this.getChatUnreadDetails(accountId, chats[i]);
        }
        return borogove.thenshim_PromiseTools.all(result);
    }
    storeReaction(accountId, update) {
        let _gthis = this;
        return borogove.thenshim_Promise.then(this.db.exec("INSERT OR REPLACE INTO reactions VALUES (?,?,?,?,?,?,?,CAST(unixepoch(?, 'subsec') * 1000 AS INTEGER),jsonb(?),?)", [accountId, update.updateId, update.serverId, update.serverIdBy, update.localId, update.chatId, update.senderId, update.timestamp, borogove.borogove_JsonPrinter.print(update.reactions), update.kind]), function (_) {
            return _gthis.getMessage(accountId, update.chatId, update.serverId, update.localId);
        });
    }
    updateMessageStatus(accountId, localId, status, statusText) {
        let _gthis = this;
        return this.storeMessagesSerialized.run(function () {
            return borogove.thenshim_Promise.then(borogove.thenshim_Promise.then(_gthis.db.exec("UPDATE messages SET status=?, status_text=? WHERE account_id=? AND stanza_id=? AND direction=? AND status <> ? AND status <> ? RETURNING stanza, direction, type, status, status_text, strftime('%FT%H:%M:%fZ', created_at / 1000.0, 'unixepoch') AS timestamp, sender_id, correction_id AS stanza_id, sort_id, mam_id, mam_by, sync_point", [status, statusText, accountId, localId, 1, 2, 3]), function (result) {
                let _this = _gthis.hydrateMessages(accountId, result);
                let result1 = new Array(_this.length);
                let _g = 0;
                let _g1 = _this.length;
                while (_g < _g1) {
                    let i = _g++;
                    let message = _this[i];
                    result1[i] = borogove.thenshim_Promise.then(message.replyToMessage != null ? _gthis.hydrateReplyTo(accountId, [message], [{ chatId: message.chatId(), serverId: message.replyToMessage.serverId, localId: message.replyToMessage.localId }]) : borogove.thenshim_Promise.resolve([message]), function (messages) {
                        return _gthis.hydrateReactions(accountId, messages);
                    });
                }
                return borogove.thenshim_PromiseTools.all(result1);
            }), function (hydrated) {
                let _g = [];
                let _g_current = 0;
                while (_g_current < hydrated.length) {
                    let x = borogove.$getIterator(hydrated[_g_current++]);
                    while (x.hasNext())
                        _g.push(x.next());
                }
                if (_g.length > 0) {
                    return borogove.thenshim_Promise.resolve(_g[0]);
                }
                else {
                    return borogove.thenshim_Promise.reject("Message not found: " + localId);
                }
            });
        });
    }
    hasMedia(hashAlgorithm, hash) {
        return this.media.hasMedia(hashAlgorithm, hash);
    }
    removeMedia(hashAlgorithm, hash) {
        return this.media.removeMedia(hashAlgorithm, hash);
    }
    storeMedia(mime, bd) {
        return this.media.storeMedia(mime, bd);
    }
    storeCaps(caps) {
        let map = new Map([]);
        map.set(caps.verRaw().hash, caps);
        this.storeCapsSet(map);
    }
    storeCapsSet(capsSet) {
        let params = [];
        let q_b = "";
        q_b = "INSERT OR IGNORE INTO caps VALUES ";
        let first = true;
        let jsIterator = capsSet.entries();
        let _g_lastStep = jsIterator.next();
        while (!_g_lastStep.done) {
            let v = _g_lastStep.value;
            _g_lastStep = jsIterator.next();
            let _g_value = v[1];
            if (!first) {
                q_b += ",";
            }
            q_b += "(?,jsonb(?))";
            params.push(v[0]);
            let caps = _g_value.node;
            let caps1 = _g_value.identities;
            let caps2 = _g_value.features;
            let _this = _g_value.data;
            let result = new Array(_this.length);
            let _g = 0;
            let _g1 = _this.length;
            while (_g < _g1) {
                let i = _g++;
                result[i] = _this[i].toString();
            }
            params.push(JSON.stringify({ node: caps, identities: caps1, features: caps2, data: result }));
            first = false;
        }
        if (params.length < 1) {
            return;
        }
        this.db.exec(q_b, params);
    }
    getCaps(ver) {
        let verData;
        try {
            verData = borogove.haxe_crypto_Base64.decode(ver).b.bufferValue;
        }
        catch (_g) {
            return borogove.thenshim_Promise.resolve(null);
        }
        let _gthis = this;
        return borogove.thenshim_Promise.then(this.db.exec("SELECT json(caps) AS caps FROM caps WHERE sha1=? LIMIT 1", [verData]), function (result) {
            while (result.current < result.array.length) {
                let json = JSON.parse(result.array[result.current++].caps);
                return _gthis.hydrateCaps(json, verData);
            }
            return null;
        });
    }
    storeLogin(accountId, clientId, displayName, token) {
        let params = [accountId, clientId, displayName];
        let q_b = "";
        q_b = "INSERT INTO accounts (account_id, client_id, display_name";
        if (token != null) {
            q_b = "INSERT INTO accounts (account_id, client_id, display_name" + ", token, fast_count";
        }
        q_b += ") VALUES (?,?,?";
        if (token != null) {
            q_b += ",?";
            params.push(token);
            q_b += ",0";
        }
        q_b += ") ON CONFLICT DO UPDATE SET client_id=?";
        params.push(clientId);
        q_b += ", display_name=?";
        params.push(displayName);
        if (token != null) {
            q_b += ", token=?";
            params.push(token);
            q_b += ", fast_count=0";
        }
        this.db.exec(q_b, params);
    }
    getLogin(accountId) {
        let _gthis = this;
        return borogove.thenshim_Promise.then(this.db.exec("SELECT client_id AS clientId, display_name AS displayName, token, COALESCE(fast_count, 0) AS fastCount FROM accounts WHERE account_id=? LIMIT 1", [accountId]), function (result) {
            while (result.current < result.array.length) {
                let row = result.array[result.current++];
                if (row.token != null) {
                    _gthis.db.exec("UPDATE accounts SET fast_count=fast_count+1 WHERE account_id=?", [accountId]);
                }
                return row;
            }
            return { clientId: null, token: null, fastCount: 0, displayName: null };
        });
    }
    removeAccount(accountId, completely) {
        let _gthis = this;
        return borogove.thenshim_Promise.then(borogove.thenshim_Promise.then(this.db.exec("DELETE FROM accounts WHERE account_id=?", [accountId]), function (_) {
            if (!completely) {
                return borogove.thenshim_Promise.resolve(null);
            }
            return _gthis.db.execMany([{ sql: "DELETE FROM messages WHERE account_id=?", params: [accountId] }, { sql: "DELETE FROM chats WHERE account_id=?", params: [accountId] }, { sql: "DELETE FROM services WHERE account_id=?", params: [accountId] }]);
        }), function (_) {
            return true;
        });
    }
    listAccounts() {
        return borogove.thenshim_Promise.then(this.db.exec("SELECT account_id FROM accounts"), function (result) {
            if (result == null) {
                return [];
            }
            else {
                let _g = [];
                let x = borogove.$getIterator({ iterator: function () {
                        return result;
                    } });
                while (x.hasNext())
                    _g.push(x.next().account_id);
                return _g;
            }
        });
    }
    storeStreamManagement(accountId, sm) {
        this.smStoreNext = sm;
        let _gthis = this;
        if (!this.smStoreInProgress) {
            this.smStoreInProgress = true;
            borogove.thenshim_Promise.then(this.db.exec("UPDATE accounts SET sm_state=? WHERE account_id=?", [sm, accountId]), function (_) {
                _gthis.smStoreInProgress = false;
                if (_gthis.smStoreNext != sm) {
                    _gthis.storeStreamManagement(accountId, sm);
                }
            });
        }
    }
    getStreamManagement(accountId) {
        return borogove.thenshim_Promise.then(this.db.exec("SELECT sm_state FROM accounts  WHERE account_id=?", [accountId]), function (result) {
            while (result.current < result.array.length)
                return result.array[result.current++].sm_state;
            return null;
        });
    }
    storeService(accountId, serviceId, name, node, caps) {
        this.storeCaps(caps);
        this.db.exec("INSERT OR REPLACE INTO services VALUES (?,?,?,?,?)", [accountId, serviceId, name, node, caps.verRaw().hash]);
    }
    findServicesWithFeature(accountId, feature) {
        let _gthis = this;
        return borogove.thenshim_Promise.then(this.db.exec("SELECT service_id, name, node, json(caps.caps) AS caps FROM services INNER JOIN caps ON services.caps=caps.sha1 WHERE account_id=?", [accountId]), function (result) {
            let services = [];
            while (result.current < result.array.length) {
                let row = result.array[result.current++];
                let json = JSON.parse(row.caps);
                let tmp = json != null ? json.features : null;
                if ((tmp != null ? tmp : []).includes(feature)) {
                    services.push({ serviceId: row.service_id, name: row.name, node: row.node, caps: _gthis.hydrateCaps(json) });
                }
            }
            return services;
        });
    }
    hydrateReactions(accountId, messages) {
        let result = new Array(messages.length);
        let _g = 0;
        let _g1 = messages.length;
        while (_g < _g1) {
            let i = _g++;
            let m = messages[i];
            result[i] = { chatId: m.chatId(), serverId: m.serverId, serverIdBy: m.serverIdBy, localId: m.localId };
        }
        return borogove.thenshim_Promise.then(this.fetchReactions(accountId, result), function (result) {
            let jsIterator = result.entries();
            let _g_lastStep = jsIterator.next();
            while (!_g_lastStep.done) {
                let v = _g_lastStep.value;
                _g_lastStep = jsIterator.next();
                let _g_key = v[0];
                let _g_value = v[1];
                let result = null;
                let _g = 0;
                while (_g < messages.length) {
                    let v = messages[_g];
                    ++_g;
                    if ((v.serverId == null ? v.localId : v.serverId + "\n" + v.serverIdBy) + "\n" + v.chatId() == _g_key || (v.localId == null ? v.serverId + "\n" + v.serverIdBy : v.localId) + "\n" + v.chatId() == _g_key) {
                        result = v;
                        break;
                    }
                }
                let m = result;
                if (m != null) {
                    m.set_reactions(_g_value);
                }
            }
            return messages;
        });
    }
    fetchReactions(accountId, ids) {
        let q_b = "";
        q_b = "SELECT kind, chat_id, mam_id, mam_by, stanza_id, sender_id, json(reactions) AS reactions FROM reactions WHERE 1=0";
        let params = [];
        let _g = 0;
        while (_g < ids.length) {
            let item = ids[_g];
            ++_g;
            if (item.serverId != null) {
                q_b += " OR (mam_id=? AND mam_by=?)";
                params.push(item.serverId);
                params.push(item.serverIdBy);
            }
            if (item.localId != null) {
                q_b += " OR stanza_id=?";
                params.push(item.localId);
            }
        }
        q_b += " ORDER BY created_at, ROWID";
        return borogove.thenshim_Promise.then(this.db.exec(q_b, params), function (rows) {
            let agg = new Map([]);
            while (rows.current < rows.array.length) {
                let row = rows.array[rows.current++];
                let reactions = JSON.parse(row.reactions);
                let mapId = (row.mam_id == null || row.mam_id == "" ? row.stanza_id : row.mam_id + "\n" + row.mam_by) + "\n" + row.chat_id;
                if (!agg.has(mapId)) {
                    agg.set(mapId, new Map([]));
                }
                let map = agg.get(mapId);
                if (!map.has(row.sender_id)) {
                    map.set(row.sender_id, []);
                }
                if (row.kind == 1) {
                    let _g = 0;
                    while (_g < reactions.length)
                        map.get(row.sender_id).push(reactions[_g++]);
                }
                else if (row.kind == 0) {
                    let k = row.sender_id;
                    let _this = map.get(row.sender_id);
                    let _g = [];
                    let _g1 = 0;
                    while (_g1 < _this.length) {
                        let v = _this[_g1];
                        ++_g1;
                        if (v.uri != null) {
                            _g.push(v);
                        }
                    }
                    map.set(k, reactions.concat(_g));
                }
                else if (row.kind == 2) {
                    map.set(row.sender_id, reactions);
                }
            }
            let result = new Map([]);
            let jsIterator = agg.entries();
            let _g_lastStep = jsIterator.next();
            while (!_g_lastStep.done) {
                let v = _g_lastStep.value;
                _g_lastStep = jsIterator.next();
                let _g_key = v[0];
                let map = new Map([]);
                let jsIterator1 = v[1].values();
                let _g_lastStep1 = jsIterator1.next();
                while (!_g_lastStep1.done) {
                    let v = _g_lastStep1.value;
                    _g_lastStep1 = jsIterator1.next();
                    let _g = 0;
                    while (_g < v.length) {
                        let reactionD = v[_g];
                        ++_g;
                        let reaction = reactionD.uri == null ? new borogove.borogove_Reaction(reactionD.senderId, reactionD.timestamp, reactionD.text, reactionD.envelopeId, reactionD.key) : new borogove.borogove_CustomEmojiReaction(reactionD.senderId, reactionD.timestamp, reactionD.text, reactionD.uri, reactionD.envelopeId);
                        if (!map.has(reaction.key)) {
                            map.set(reaction.key, []);
                        }
                        map.get(reaction.key).push(reaction);
                    }
                }
                result.set(_g_key, map);
            }
            return result;
        });
    }
    hydrateReplyTo(accountId, messages, replyTos) {
        let _gthis = this;
        let tmp;
        if (replyTos.length < 1) {
            tmp = borogove.thenshim_Promise.resolve(null);
        }
        else {
            let mamIds = [];
            let mamIdsS = [];
            let stanzaIds = [];
            let stanzaIdsS = [];
            let params = [accountId];
            let _g = 0;
            while (_g < replyTos.length) {
                let parent = replyTos[_g];
                ++_g;
                if (parent.serverId != null) {
                    mamIds.push(parent.chatId);
                    mamIds.push(parent.serverId);
                    mamIdsS.push("(?,?)");
                }
                else {
                    stanzaIds.push(parent.chatId);
                    stanzaIds.push(parent.localId);
                    stanzaIdsS.push("(?,?)");
                }
            }
            let q = [];
            if (mamIds.length > 0) {
                q.push("SELECT chat_id, stanza_id, stanza, direction, type, status, status_text, strftime('%FT%H:%M:%fZ', created_at / 1000.0, 'unixepoch') AS timestamp, sender_id, mam_id, mam_by, sort_id, sync_point FROM messages WHERE account_id=?" + " AND (chat_id, mam_id) IN (" + mamIdsS.join(",") + ")");
                params = params.concat(mamIds);
            }
            if (stanzaIds.length > 0) {
                q.push("SELECT chat_id, stanza_id, stanza, direction, type, status, status_text, strftime('%FT%H:%M:%fZ', created_at / 1000.0, 'unixepoch') AS timestamp, sender_id, mam_id, mam_by, sort_id, sync_point FROM messages WHERE account_id=?" + " AND (chat_id, stanza_id) IN (" + stanzaIdsS.join(",") + ")");
                params = params.concat(stanzaIds);
            }
            tmp = this.db.exec(q.join(" UNION ALL "), params);
        }
        return borogove.thenshim_Promise.then(tmp, function (iter) {
            if (iter != null) {
                let parents = borogove.Lambda.array({ iterator: function () {
                        return iter;
                    } });
                let _g = 0;
                while (_g < messages.length) {
                    let message = messages[_g];
                    ++_g;
                    if (message.replyToMessage != null) {
                        let result = null;
                        let _g = 0;
                        while (_g < parents.length) {
                            let v = parents[_g];
                            ++_g;
                            if (v.chat_id == message.chatId() && (message.replyToMessage.serverId == null || v.mam_id == message.replyToMessage.serverId) && (message.replyToMessage.localId == null || v.stanza_id == message.replyToMessage.localId)) {
                                result = v;
                                break;
                            }
                        }
                        let found = result;
                        if (found != null) {
                            message.set_replyToMessage(_gthis.hydrateMessages(accountId, new borogove.haxe_iterators_ArrayIterator([found]))[0]);
                        }
                    }
                }
            }
            return messages;
        });
    }
    hydrateMessages(accountId, rows) {
        let accountJid = borogove.borogove_JID.parse(accountId);
        let _g = [];
        let x = (function () {
            return rows;
        })();
        while (x.hasNext()) {
            let row = x.next();
            _g.push(borogove.borogove_ChatMessage.fromStanza(borogove.borogove_Stanza.parse(row.stanza), accountJid, function (builder, _) {
                builder.syncPoint = row.sync_point != 0;
                builder.timestamp = row.timestamp;
                builder.type = row.type;
                builder.status = row.status;
                builder.statusText = row.status_text;
                builder.senderId = row.sender_id;
                builder.serverId = row.mam_id == "" ? null : row.mam_id;
                builder.serverIdBy = row.mam_by == "" ? null : row.mam_by;
                builder.sortId = row.sort_id;
                if (builder.direction != row.direction) {
                    builder.direction = row.direction;
                    let replyTo = builder.replyTo;
                    builder.replyTo = builder.recipients;
                    builder.recipients = replyTo;
                }
                if (row.stanza_id != null && row.stanza_id != "") {
                    builder.localId = row.stanza_id;
                }
                if (row.versions != null) {
                    let versionTimes = JSON.parse(row.version_times);
                    let versions = JSON.parse(row.versions);
                    if (borogove.Reflect.fields(versions).length > 1) {
                        let _g_keys = borogove.Reflect.fields(versions);
                        let _g_index = 0;
                        while (_g_index < _g_keys.length) {
                            let key = _g_keys[_g_index++];
                            let versionId = key;
                            let versionM = borogove.borogove_ChatMessage.fromStanza(borogove.borogove_Stanza.parse(versions[key]), accountJid, function (toPushB, _) {
                                if (toPushB.serverId == null && versionId != toPushB.localId) {
                                    toPushB.serverId = versionId;
                                }
                                toPushB.timestamp = versionTimes[versionId];
                                return toPushB;
                            });
                            let toPush = versionM == null || versionM.versions.length < 1 ? versionM : versionM.versions[0];
                            if (toPush != null) {
                                builder.versions.push(toPush);
                            }
                        }
                        builder.versions.sort(function (a, b) {
                            return borogove.Reflect.compare(b.timestamp, a.timestamp);
                        });
                    }
                }
                return builder;
            }));
        }
        return _g;
    }
    hydrateCaps(o, ver) {
        let o1 = o.node;
        let tmp = o.identities;
        let _this = tmp != null ? tmp : [];
        let result = new Array(_this.length);
        let _g = 0;
        let _g1 = _this.length;
        while (_g < _g1) {
            let i = _g++;
            let i1 = _this[i];
            result[i] = new borogove.borogove_Identity(i1.category, i1.type, i1.name);
        }
        let tmp1 = o.features;
        let tmp2 = tmp1 != null ? tmp1 : [];
        let tmp3 = o.data;
        let _this1 = tmp3 != null ? tmp3 : [];
        let result1 = new Array(_this1.length);
        let _g2 = 0;
        let _g3 = _this1.length;
        while (_g2 < _g3) {
            let i = _g2++;
            result1[i] = borogove.borogove_Stanza.parse(_this1[i]);
        }
        return new borogove.borogove_Caps(o1, result, tmp2, result1, ver);
    }
    static prepare(q) {
        return new borogove.EReg("\\?", "gm").map(q.sql, function (f) {
            let tmp = q.params;
            let p = (tmp != null ? tmp : []).shift();
            let _g = borogove.Type.typeof(p);
            switch (_g._hx_index) {
                case 0:
                    return "NULL";
                case 1:
                    return borogove.Std.string(p);
                case 2:
                    return borogove.Std.string(p);
                case 3:
                    if (p == true) {
                        return "1";
                    }
                    else {
                        return "0";
                    }
                    break;
                case 6:
                    switch (_g.c) {
                        case Array:
                            return "X'" + borogove.haxe_io_Bytes.ofData(p).toHex() + "'";
                        case String:
                            if (p.indexOf("\x00") >= 0) {
                                let hexChars = [];
                                let _g = 0;
                                let _g1 = p.length;
                                while (_g < _g1)
                                    hexChars.push(StringTools.hex(p.charCodeAt(_g++), 2));
                                return "x'" + hexChars.join("") + "'";
                            }
                            else {
                                return "'" + borogove.Std.string(p.split("'").join("''")) + "'";
                            }
                            break;
                        case borogove.haxe_io_Bytes:
                            return "X'" + p.toHex() + "'";
                        default:
                            throw borogove.haxe_Exception.thrown("UKNONWN: " + borogove.Std.string(borogove.Type.typeof(p)));
                    }
                    break;
                default:
                    throw borogove.haxe_Exception.thrown("UKNONWN: " + borogove.Std.string(borogove.Type.typeof(p)));
            }
        });
    }
}
borogove_persistence_Sqlite.__name__ = "borogove.persistence.Sqlite";
borogove_persistence_Sqlite.__interfaces__ = [borogove.borogove_persistence_KeyValueStore, borogove.borogove_Persistence];
Object.assign(borogove_persistence_Sqlite.prototype, {
    __class__: borogove_persistence_Sqlite,
    db: null,
    media: null,
    storeMessagesSerialized: null,
    storeChatBuffer: null,
    storeChatTimer: null,
    smStoreInProgress: null,
    smStoreNext: null
});
class borogove_persistence_SqliteDriver {
    constructor(dbfile, migrate) {
        let _gthis = this;
        this.ready = borogove.thenshim_Promise._new(function (resolve, reject) {
            _gthis.setReady = resolve;
        });
        borogove.thenshim_Promise.then(borogove.thenshim_Promise.then(borogove.thenshim_Promise.then(borogove_persistence_Worker1({ worker: function () {
                return new Worker(new URL("sqlite-worker1.mjs", import.meta.url), { type: "module" });
            } }), function (promiser) {
            _gthis.sqlite = promiser;
            return _gthis.sqlite("open", { filename: dbfile, vfs: "opfs-sahpool" });
        }), function (openResult) {
            _gthis.dbId = openResult.dbId;
            return migrate(function (sql) {
                let _gthis1 = _gthis;
                let result = new Array(sql.length);
                let _g = 0;
                let _g1 = sql.length;
                while (_g < _g1) {
                    let i = _g++;
                    result[i] = { sql: sql[i], params: [] };
                }
                return _gthis1.execute(result);
            });
        }), function (_) {
            _gthis.setReady(true);
        });
    }
    execute(qs) {
        let first = qs.shift();
        let result = new Array(qs.length);
        let _g = 0;
        let _g1 = qs.length;
        while (_g < _g1) {
            let i = _g++;
            result[i] = borogove_persistence_Sqlite.prepare(qs[i]) + ";";
        }
        let items = [];
        let signalAllDone;
        let allDone = borogove.thenshim_Promise._new(function (resolve, reject) {
            signalAllDone = resolve;
        });
        let tmp = this.sqlite;
        let tmp1 = this.dbId;
        let tmp2 = [first.sql + ";"].concat(result);
        let tmp3 = first.params;
        let _this = tmp3 != null ? tmp3 : [];
        let f = borogove.$bind(this, this.formatParam);
        let result1 = new Array(_this.length);
        let _g2 = 0;
        let _g3 = _this.length;
        while (_g2 < _g3) {
            let i = _g2++;
            result1[i] = f(_this[i]);
        }
        return borogove.thenshim_Promise.then(borogove.thenshim_Promise.then(tmp("exec", { dbId: tmp1, sql: tmp2, bind: result1, rowMode: "object", callback: function (r) {
                if (r.rowNumber == null) {
                    signalAllDone(null);
                }
                else {
                    items.push(r.row);
                }
                return null;
            } }), function (_) {
            return allDone;
        }), function (_) {
            return new borogove.haxe_iterators_ArrayIterator(items);
        });
    }
    execMany(qs) {
        let _gthis = this;
        return borogove.thenshim_Promise.then(this.ready, function (_) {
            return _gthis.execute(qs);
        });
    }
    exec(sql, params) {
        return this.execMany([{ sql: sql, params: params }]);
    }
    formatParam(p) {
        let _g = borogove.Type.typeof(p);
        if (_g._hx_index == 6) {
            if (_g.c == borogove.haxe_io_Bytes) {
                return p.b.bufferValue;
            }
            else {
                return p;
            }
        }
        else {
            return p;
        }
    }
}
borogove_persistence_SqliteDriver.__name__ = "borogove.persistence.SqliteDriver";
Object.assign(borogove_persistence_SqliteDriver.prototype, {
    __class__: borogove_persistence_SqliteDriver,
    sqlite: null,
    dbId: null,
    ready: null,
    setReady: null
});
borogove_persistence_Sqlite.__meta__ = { fields: { get: { 'HaxeCBridge.noemit': null }, set: { 'HaxeCBridge.noemit': null }, syncPoint: { 'HaxeCBridge.noemit': null }, storeChats: { 'HaxeCBridge.noemit': null }, searchMessages: { 'HaxeCBridge.noemit': null }, getChats: { 'HaxeCBridge.noemit': null }, storeMessages: { 'HaxeCBridge.noemit': null }, updateMessage: { 'HaxeCBridge.noemit': null }, getMessagesBefore: { 'HaxeCBridge.noemit': null }, getMessagesAfter: { 'HaxeCBridge.noemit': null }, getMessagesAround: { 'HaxeCBridge.noemit': null }, getChatsUnreadDetails: { 'HaxeCBridge.noemit': null }, storeReaction: { 'HaxeCBridge.noemit': null }, updateMessageStatus: { 'HaxeCBridge.noemit': null }, hasMedia: { 'HaxeCBridge.noemit': null }, removeMedia: { 'HaxeCBridge.noemit': null }, storeMedia: { 'HaxeCBridge.noemit': null }, storeCaps: { 'HaxeCBridge.noemit': null }, getCaps: { 'HaxeCBridge.noemit': null }, storeLogin: { 'HaxeCBridge.noemit': null }, getLogin: { 'HaxeCBridge.noemit': null }, storeStreamManagement: { 'HaxeCBridge.noemit': null }, getStreamManagement: { 'HaxeCBridge.noemit': null }, storeService: { 'HaxeCBridge.noemit': null }, findServicesWithFeature: { 'HaxeCBridge.noemit': null } } };
export { borogove_persistence_Sqlite };
