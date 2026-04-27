# AffineCam (Prototype)

A small prototype for real-time camera processing.

The app captures camera frames, renders a live preview using Metal, and performs OCR (digit recognition) in parallel using Apple Vision.

---

## Architecture

The pipeline is split into independent parts:

CameraEngine → FrameInbox →  
- Metal-based preview renderer  
- OCR processor (Vision)

The camera writes frames into a thread-safe buffer (`FrameInbox`).  
Rendering and OCR read from it independently, so UI updates do not block background processing.

---

## Key points

- GPU-based preview rendering (Metal)
- Thread-safe frame handoff (single-slot buffer)
- OCR processing on a background actor
- Minimal coupling between capture, rendering, and processing

---

## Notes

This is a prototype built for learning purposes.  
Some parts (like orientation handling and OCR preprocessing) are simplified.
