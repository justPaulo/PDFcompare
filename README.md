# PDF Compare

A fast, native macOS app for spotting differences between PDF files without bouncing between browser tabs or paid desktop tools.

PDF Compare is built for the moments where you need to answer simple but critical questions quickly:

- Did this page change?
- Which text is different?
- Did a paragraph move, disappear, or get added?
- Is the visual layout still intact?

It compares two PDFs side by side, highlights changed pages, and gives you a few different views so you can inspect the diff from the angle that matters most.

## What it does

- Drag and drop PDFs into the app
- Compare page-by-page with visual overlays
- Switch between:
  - overlay mode
  - side-by-side mode
  - text-diff mode
- Navigate directly to the next or previous changed page
- Filter to only changed pages
- Zoom into page detail for closer inspection
- Works with native macOS PDF rendering via PDFKit

## Why this exists

A lot of PDF comparison tools are either web-based, locked behind pricey subscriptions, or built for Windows-only workflows. On macOS, the native options are surprisingly thin. This project fills that gap with a small, focused, unapologetically practical tool that does the job without the bloat.

## Features at a glance

- Native SwiftUI desktop interface
- No external dependencies for the core experience
- Fast visual comparison using rendered page thumbnails
- Text-level diffs for content changes
- Clear page status indicators for added/removed/mutated pages
- Works on Apple Silicon and Intel Macs

## Run it locally

Requirements:

- macOS
- Swift toolchain
- optional: Xcode if you want to open the project in the IDE

Build the app:

```bash
bash build.sh
```

This creates an app bundle at:

```bash
build/PDF Compare.app
```

Then open it with:

```bash
open "build/PDF Compare.app"
```

## Architecture

See the project overview in [ARCHITECTURE.md](ARCHITECTURE.md).

## Example workflow

1. Drop the original PDF in the A slot
2. Drop the modified PDF in the B slot
3. Let the app analyze each page
4. Use overlay or side-by-side view to inspect changes
5. Jump between modified pages with the navigation buttons
6. Export or review the exact differences before shipping

## Notes

This project is intentionally compact and laser-focused. It is not a full PDF editor or enterprise document review suite — it is a no-nonsense comparison tool for people who need to answer, "What changed?" with speed and clarity.

If you want to keep iterating, this is a great foundation for adding:

- PDF page export highlights
- OCR-based comparison for scanned documents
- text search and filtering
- folder-based batch comparison
- more advanced visual diff controls

## License

This project is provided as-is for local use and experimentation.
