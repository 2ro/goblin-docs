# Run a name authority

> **Summary.** `goblin-nip05d` is a small, self-hostable Axum + SQLite service that issues `name@yourdomain` identities and resolves them via NIP-05, with NIP-98-authenticated self-service registration. Running your own makes you an independent issuer; `goblin.st` is just one operator.

## What it is

A single binary that:

- answers `GET /.well-known/nostr.json?name=<name>` with the pubkey + advertised relays ([NIP-05](https://nips.nostr.com/5));
- authorizes every write (register, release, transfer) with a signed Nostr event in the `Authorization: Nostr …` header ([NIP-98](https://nips.nostr.com/98)): **the key is the account**, no passwords;
- stores only **names and pubkeys**, no avatars, no PII (clients render avatars from the pubkey).

It pairs with a [relay](relay.md) (which the bundled Docker Compose can run for you) but only *advertises* the relay; it isn't one.

## Security model (built in)

- **Cryptographic ownership, no recovery**: lose the key, lose the name; the operator cannot reassign it.
- **Anti-squatting**: a reserved list (`admin`, `support`, …), your own domain label reserved automatically, and look-alike/homograph folding; extend via `GOBLIN_RESERVED_FILE`.
- **One active name per key**: enforced by a partial unique index at the DB layer.
- **Rate limiting keys off `X-Real-IP`**: your reverse proxy **must** set it from the real client address, or the limiter is defeated. The provided proxy configs do this.

## Deploying

The repo ships ready-to-adapt configs in `goblin-nip05d/deploy/`:

- `goblin-nip05d.service`: a hardened systemd unit (`DynamicUser`, `ProtectSystem=strict`, `StateDirectory`, etc.). Set `NIP05_DB` to your state path.
- `nginx.conf.example` / `Caddyfile`: TLS termination that proxies `/.well-known/nostr.json` and `/api/` to the service (on its loopback port) **with `X-Real-IP` set**, and the relay websocket to `strfry`.
- `strfry/`: the bundled relay write-policy (see [Run a relay](relay.md)).
- A Docker Compose option runs the service + relay + auto-HTTPS together.

Rough shape:

```sh
# build
cd goblin-nip05d && cargo build --release
# run (bare-metal): install the binary, set env, enable the unit
sudo install -m755 target/release/goblin-nip05d /usr/local/bin/
sudo systemctl enable --now goblin-nip05d
# front it with TLS + X-Real-IP per deploy/nginx.conf.example
```

Then point a wallet at it: **Settings → Identity → Name authority → `yourdomain`**.

**Optional: name sales.** The [name marketplace](../features/name-marketplace.md) is **off by default** and per-authority: enable it with `GOBLIN_ALLOW_TRANSFERS=true` plus `GOBLIN_GRIN_NODE_URL` pointing at a Grin node's foreign API (read-only chain access, used only to confirm payment kernels; the authority never runs a wallet and never holds funds).

## Reference

- Crate: `goblin-nip05d/` (Axum + SQLite). README documents endpoints, env, and the security model in full.
- Endpoints: `GET /.well-known/nostr.json`, `GET /api/v1/name/{name}` (availability), `POST /api/v1/register`, `DELETE` release, transfer, and `by-pubkey` reverse lookup.
- Deploy templates: `goblin-nip05d/deploy/{goblin-nip05d.service,nginx.conf.example,Caddyfile,strfry}`.
- Client side: [The NIP-05 name authority](../features/name-authority.md).

## References

- NIP-05: <https://nips.nostr.com/5>; NIP-98: <https://nips.nostr.com/98>.
