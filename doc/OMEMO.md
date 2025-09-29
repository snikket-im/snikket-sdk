# OMEMO support

Implementation of XEP-0384 v0.3.

Depends on libsignal-protocol-js at runtime.

To disable OMEMO at build time (and thus remove the libsignal dependency)
compile with the NO_OMEMO flag.

## TODO / known issues

- [x] One-to-one bidirectional OMEMO
- [x] Healing of broken sessions
- [x] Remove and replace consumed prekeys
- [x] Allow non-OMEMO messages to recipients with no published keys when policy allows
- [x] Encrypt outgoing messages to the sending account's other devices
- [x] OMEMO carbons working
- [x] Persistence: IndexedDB (for web)
- [x] Use cache for remote contact devices
- [x] Fix that encryption status reported by the API can be forged by sender
- [ ] Persistence: SQLite backend (for native)
- [ ] API to control encryption of outgoing messages
- [ ] API to determine cryptographic identity of message sender
- [ ] Group chat support

