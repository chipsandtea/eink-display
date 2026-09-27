# DIY E-Ink Photo Album

This project is a small homebrew prototype inspired by the feel of Picpak-style e-ink photo albums: slow, calm, battery-friendly, and built around a few cherished photos rather than a flashy color screen.

The goal here is not a production product; it is a practical starting point you can run on a Raspberry Pi or a desktop during development.

## What this prototype does

- Builds an e-ink-style album page from a set of local photos
- Applies a grayscale, paper-like aesthetic to mimic e-paper
- Supports a simple slideshow / refresh flow for a home display
- Gives you a foundation for a Raspberry Pi + e-ink device at home

## Recommended hardware

For a real device, the simplest DIY stack is:

- Raspberry Pi Zero 2 W or Pi 4
- 7.5-inch or 13.3-inch e-ink panel
- MicroSD card with Raspberry Pi OS
- USB power bank or battery with power management
- Small wall mount or stand
- Optional Wi-Fi sync from a phone or laptop

A good target build is:

- Display: 7.5" monochrome e-paper
- Controller: Raspberry Pi Zero 2 W
- Storage: local USB stick with a photo library
- Update cadence: one page every 10-30 minutes or a manual button-triggered refresh

## Software layout

- `src/album_generator.py` generates a static album page with a paper-like e-ink look
- `output/` contains generated album previews

## Quick start

1. Install Python dependencies
2. Run the generator
3. Review the generated album image

```bash
pip install -r requirements.txt
python src/album_generator.py --out output/album_preview.png --title "Home Memories"
```

## Design notes

This concept intentionally avoids trying to recreate a full color, high-refresh digital photo frame. The charm of the e-ink photo album is the slow interaction:

- fewer photos per page
- matte paper background
- reduced power draw
- grayscale tone with soft contrast
- a more contemplative, framed experience

## Next upgrades

- Add a slideshow loop for multiple pages
- Add automatic refresh on a timer
- Build a small local web UI to select albums and rotate photos
- Add a power-saving sleep mode for the Pi
- Use a driver library for a specific e-ink panel model

## Notes

This is intentionally a modest prototype. It is designed to be easy to adjust, easy to run locally, and easy to expand into a real home display project.
