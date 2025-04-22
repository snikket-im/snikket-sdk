# OMEMO support

Implementation of XEP-0384 v0.3.

Depends on libsignal-protocol-js at runtime.

To disable OMEMO at build time (and thus remove the libsignal dependency)
compile with the NO_OMEMO flag.

## TODO / known issues

- No caching of remote contact devices
- No API to control encryption of outgoing messages
- No API to determine cryptographic identity of message sender
- Persistence: only IndexedDB backend is currently implemented
- Encryption status reported by the API can be forged by sender
- Consumed prekeys are not removed and replaced
- Outgoing messages are not encrypted to the sending account's other devices
- No support for group chats
