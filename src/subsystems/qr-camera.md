# QR & camera

> **Summary.** Goblin reads and writes QR codes for the things you hand to another person face-to-face: your payment code (`nprofile`), and your recovery phrase (SeedQR). The camera path decodes standard and animated (multi-frame) QR codes across platforms.

## Motivation

In person, a QR is the fastest "address exchange" there is, and for a recovery phrase, scanning beats re-typing 24 words. Goblin uses QR in two directions: **show** your code so someone can scan-to-pay you, and **scan** a code to fill a recipient or import a seed. The scanner deliberately refuses to echo sensitive scans (seeds, raw slatepacks) into the UI.

## How it works

- **Showing.** The Receive screen and "My Code" tab render your `nprofile` (npub + relay hints) as a QR so a payer can scan it and reach you with no lookup. Long payloads use animated **Uniform Resources (UR)**: a sequence of frames.
- **Scanning.** The camera feed is decoded with `rqrr`; the recipient row and home header offer a scanner for scan-to-pay, and onboarding offers a **SeedQR** scan to import a phrase. Only text QR results are accepted into the recipient field. A plain `nostr:<nprofile>` code fills only the recipient; a **pay-URI** code (for example a GoblinPay checkout QR, `nostr:<nprofile>?amount=…&memo=…`) also fills the **amount** and **note**, so scanning a checkout needs no retyping. Prefilling is all scanning does: the amount and review screens still confirm the send.
- **Cross-platform camera.** Backed by `nokhwa` (V4L on Linux, MSMF on Windows, AVFoundation on macOS). Frames that arrive as raw YUYV are decoded before QR scanning; a "No camera found" state appears if nothing opens.

<div class="shot-todo"><strong>Screenshot:</strong> the in-app "Scan to pay" camera panel and the Receive "My Code" QR, dark, 390×844.</div>

## Reference

- `goblin/src/gui/views/camera.rs`: `CameraContent`, the `nokhwa` capture + `rqrr` decode, UR reassembly, the unavailable-camera timeout.
- `goblin/src/gui/views/qr.rs`: `QrCodeContent` generation (`qrcodegen`), animated UR output.
- Scan entry points + accepted payloads: `goblin/src/gui/views/goblin/send.rs` (`scan`, `ScanTab`).

## References

- The codes it shows: [Send & request](../features/send-request.md), [Identity](../pillars/nostr-identity.md) (`nprofile`).
