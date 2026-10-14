# Screen mirroring receiver (Google Cast)

`index.html` is the page the TV opens when the app mirrors the iPhone screen. It shows only the video (no title, no
"LIVE" label, no progress bar) and stays close to the live edge, so the delay is lower than with Google's
Default Media Receiver (about 3 s, which cannot be tuned from the phone).

## Set up (once)
1. Host `index.html` on any HTTPS static host (Firebase Hosting, GitHub Pages, Netlify, ...). Note its URL.
2. Open the [Google Cast SDK Developer Console](https://cast.google.com/publish) (one-time registration fee),
   **Add new application > Custom Receiver**, and enter the URL from step 1.
3. Copy the **Application ID** it gives you into `GoogleCastMessages.mirrorReceiver`
   (`remote/remote/Features/Core/Controllers/GoogleCastMessages.swift`).
4. While the application is unpublished, only TVs registered as test devices (Developer Console > Devices, serial
   number) can launch it. Publish it before release.

## Behaviour
- With `mirrorReceiver` empty, or when the TV cannot start the receiver, the app falls back to the Default Media
  Receiver, so mirroring still works (with the overlay and the longer delay).
- Photos, videos and music casting keep using the Default Media Receiver.

## Tuning
The constants at the top of the script set the target lag (`TARGET_LAG`), when it jumps forward (`JUMP_LAG`) and how
much it speeds up to catch up (`CATCH_UP_RATE`). Not verified on a TV yet: test on a Google TV and adjust.
