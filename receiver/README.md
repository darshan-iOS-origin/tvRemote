# Screen mirroring receiver (Google Cast)

`index.html` is the page the TV opens when the app mirrors the iPhone screen. It shows only the video (no title, no
"LIVE" label, no progress bar) and stays close to the live edge, so the delay is lower than with Google's
Default Media Receiver (about 3 s, which cannot be tuned from the phone).

## Set up (once)
1. Host `index.html` on any HTTPS static host (GitHub Pages, Netlify, ...), or with Firebase Hosting from the repo
   root (`firebase.json` is already set up: `npm i -g firebase-tools`, `firebase login`, `firebase use <project>`,
   `firebase deploy --only hosting`). Note its URL.
2. Open the [Google Cast SDK Developer Console](https://cast.google.com/publish) (one-time registration fee),
   **Add new application > Custom Receiver**, and enter the URL from step 1.
3. Copy the **Application ID** it gives you into `GoogleCastMessages.mirrorReceiver`
   (`smarttvremote2026/smarttvremote2026/Features/Core/Controllers/GoogleCastMessages.swift`).
4. While the application is unpublished, only TVs registered as test devices (Developer Console > Devices, serial
   number) can launch it. Publish it before release.

## Behaviour
- With `mirrorReceiver` empty, or when the TV cannot start the receiver, the app falls back to the Default Media
  Receiver, so mirroring still works (with the overlay and the longer delay).
- Photos, videos and music casting keep using the Default Media Receiver.

## Tuning
The player keeps an adaptive reserve of picture: small (`MIN_MARGIN`) while the network is calm, larger after every
freeze (`GROW`, up to `MAX_MARGIN`), smaller again after `CALM_MS` without one (`DECAY`). It speeds up slightly
(`FAST_RATE`) when behind, slows slightly (`SLOW_RATE`) just before running dry, and jumps forward when far behind
(`JUMP_EXTRA`). Add `?debug=1` to the receiver URL in the console to see the lag and reserve on the TV. Not verified
on a TV yet: test on a Google TV and adjust.
