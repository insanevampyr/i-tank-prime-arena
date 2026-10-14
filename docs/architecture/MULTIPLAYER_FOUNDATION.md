# Host Authoritative Multiplayer Foundation

## Current boundary

Task 2 is an in-process synchronization harness. `AuthoritativeCombatSession` is the only component allowed to schedule combat events. It delegates ordering and seeded randomness to `CombatSimulation`, drains the authoritative queue, and publishes immutable event envelopes with monotonically increasing protocol sequence numbers.

`ObservedCombatClient` is passive. It may buffer out-of-order envelopes, ignore identical duplicate delivery, and record the authoritative transcript in sequence order. It cannot schedule events, roll randomness, or change combat state. `SynchronizationReport` compares canonical client digests and produces an explicit mismatch report.

No socket, HTTP, WebSocket, WebRTC, RPC, lobby, matchmaking, prediction, rollback, reconnect, or persistence behavior exists in this harness.

## Future transport path

1. Keep the current combat event dictionary as the versioned protocol payload, adding an explicit protocol version before external transport is introduced.
2. Serialize authoritative envelopes at the host boundary. Validate sequence, identity, schema, size, and permitted fields before a client accepts them.
3. Deliver envelopes over a transport adapter. Desktop hosts may support transports unavailable to browsers; browser clients should use a supported client transport such as secure WebSocket or WebRTC.
4. Retain client buffering and idempotent duplicate handling. Add bounded buffer limits, acknowledgements, retransmission, reconnect snapshots, and replay-window rules before real networking.
5. Compare periodic authoritative state digests. On mismatch, stop client-side progression, record the sequence boundary, and request an authoritative snapshot rather than repairing state locally.
6. Test two real clients against one host before adding more combat content, as required by the roadmap.

## Cross-platform protocol constraints

- Keep protocol timestamps and sequence numbers as integers. Avoid platform-dependent wall-clock time.
- Canonicalize dictionary keys before hashing. Do not rely on dictionary insertion order, locale, object identity, or runtime hash values.
- Keep random decisions on the authority and include their resolved values in authoritative events. Clients must not reproduce outcomes by rolling independently.
- Define explicit numeric ranges before transport. JavaScript numbers cannot precisely represent every signed 64-bit integer, so a future JavaScript-facing serializer must encode large integers safely or constrain protocol ranges.
- Avoid native-only GDExtensions and platform-specific binary serialization if Windows and Web clients must share the protocol.
- Browser tabs pause background processing. Reconnect and authoritative catch-up are required before browser multiplayer can be considered reliable.
- Godot Web clients do not have low-level networking. Future browser transport choices are limited to supported HTTP, WebSocket client, or WebRTC paths.

## Synchronization failure behavior

A local observer reports malformed or conflicting duplicate envelopes immediately. Cross-client comparison reports the reference client, its digest and event count, each mismatching client, its digest and event count, and any local observer failure. The harness never silently accepts disagreement.
