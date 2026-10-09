//
//  MirrorViewerPage.swift
//  remote + MirrorBroadcast
//
//  The web page the phone serves in "Web Browser" mode: any browser on the same Wi-Fi opens
//  `http://<phone>:<port>/<code>` and watches the live screen. It has no library and needs no internet.
//
//  Safari plays the HLS playlist itself. Other browsers get a small Media Source player: it reads
//  `live.m3u8`, appends `init.mp4` and each new segment to one source buffer, stays close to the live edge
//  and trims what it has already played.
//
//  UNVERIFIED on real TV browsers and older desktop browsers: Media Source support and which H.264 level
//  string each one accepts (the player tries several).
//

import Foundation

nonisolated enum MirrorViewerPage {
    static let html = #"""
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>iPhone Screen</title>
    <style>
      html, body { margin: 0; height: 100%; background: #000; color: #fff; font-family: -apple-system, Helvetica, Arial, sans-serif; }
      video { width: 100%; height: 100%; object-fit: contain; background: #000; }
      #note { position: fixed; left: 0; right: 0; top: 40%; text-align: center; font-size: 20px; padding: 0 24px; }
      #sound { position: fixed; right: 16px; bottom: 16px; border: 0; border-radius: 22px; padding: 12px 20px;
               font-size: 16px; background: #004bf9; color: #fff; display: none; }
    </style>
    </head>
    <body>
    <video id="v" autoplay muted playsinline controls></video>
    <div id="note">Connecting to the iPhone screen…</div>
    <button id="sound">Tap for sound</button>
    <script>
    (function () {
      var video = document.getElementById('v');
      var note = document.getElementById('note');
      var sound = document.getElementById('sound');
      var base = location.pathname.replace(/\/+$/, '');

      function say(text) { note.textContent = text; note.style.display = text ? 'block' : 'none'; }
      video.addEventListener('playing', function () { say(''); sound.style.display = video.muted ? 'block' : 'none'; });
      sound.addEventListener('click', function () { video.muted = false; sound.style.display = 'none'; video.play(); });

      if (video.canPlayType('application/vnd.apple.mpegurl')) {
        video.src = base + '/live.m3u8';
        video.play().catch(function () {});
        return;
      }
      if (!window.MediaSource) {
        say('This browser cannot play the live screen. Try Chrome, Edge, Firefox or Safari.');
        return;
      }

      var candidates = [
        'video/mp4; codecs="avc1.64002a,mp4a.40.2"',
        'video/mp4; codecs="avc1.640028,mp4a.40.2"',
        'video/mp4; codecs="avc1.64001f,mp4a.40.2"',
        'video/mp4; codecs="avc1.64001e,mp4a.40.2"'
      ];
      var mime = null;
      for (var i = 0; i < candidates.length; i++) {
        if (MediaSource.isTypeSupported(candidates[i])) { mime = candidates[i]; break; }
      }
      if (!mime) { say('This browser cannot play this video format.'); return; }

      var source = new MediaSource();
      video.src = URL.createObjectURL(source);
      source.addEventListener('sourceopen', function () {
        var buffer = source.addSourceBuffer(mime);
        buffer.mode = 'sequence';
        var queue = [];
        var nextSequence = null;
        var failures = 0;
        var running = false;

        function get(path, type) {
          return fetch(base + '/' + path, { cache: 'no-store' }).then(function (r) {
            if (!r.ok) { throw new Error(r.status); }
            return type === 'text' ? r.text() : r.arrayBuffer();
          });
        }

        function pump() {
          if (buffer.updating || source.readyState !== 'open') { return; }
          if (queue.length) {
            try { buffer.appendBuffer(queue.shift()); } catch (e) { queue = []; }
            return;
          }
          var ranges = buffer.buffered;
          if (!ranges.length) { return; }
          var start = ranges.start(0), end = ranges.end(ranges.length - 1);
          if (video.currentTime < start || end - video.currentTime > 4) {
            video.currentTime = Math.max(start, end - 1.5);
          }
          if (video.paused) { video.play().catch(function () {}); }
          if (video.currentTime - start > 12) {
            try { buffer.remove(start, video.currentTime - 6); } catch (e) {}
          }
        }
        buffer.addEventListener('updateend', pump);

        function poll() {
          if (running) { return; }
          running = true;
          get('live.m3u8', 'text').then(function (text) {
            failures = 0;
            var lines = text.split('\n');
            var first = 0, names = [];
            lines.forEach(function (line) {
              if (line.indexOf('#EXT-X-MEDIA-SEQUENCE:') === 0) { first = parseInt(line.split(':')[1], 10); }
              else if (line && line.charAt(0) !== '#') { names.push(line.trim()); }
            });
            if (!names.length) { return; }
            var last = first + names.length - 1;
            var fresh = nextSequence === null;
            if (fresh) { nextSequence = Math.max(first, last - 1); }
            if (nextSequence < first) { nextSequence = first; }
            var jobs = Promise.resolve();
            if (fresh) {
              jobs = get('init.mp4', 'buffer').then(function (data) { queue.push(data); pump(); });
            }
            while (nextSequence <= last) {
              (function (sequence) {
                jobs = jobs.then(function () { return get('seg' + sequence + '.m4s', 'buffer'); })
                           .then(function (data) { queue.push(data); pump(); });
              })(nextSequence);
              nextSequence += 1;
            }
            return jobs;
          }).catch(function () {
            failures += 1;
            if (failures > 5) { say('Waiting for the iPhone to broadcast…'); nextSequence = null; }
          }).then(function () { running = false; });
        }
        poll();
        setInterval(poll, 1000);
        setInterval(pump, 500);
      }, { once: true });
    })();
    </script>
    </body>
    </html>
    """#
}
