//
//  MirrorViewerPage.swift
//  remote + MirrorBroadcast
//
//  The web page the phone serves in "Web Browser" mode: any browser on the same Wi-Fi opens
//  `http://<phone>:<port>/<code>` and watches the live screen. It has no library and needs no internet.
//
//  Browsers with Media Source (Chrome, Edge, Firefox, desktop Safari, most TV browsers) get a small player: it
//  reads `live.m3u8` every quarter of a second, appends `init.mp4` and each new segment to one source buffer
//  and stays close to the live edge with an adaptive reserve: very little picture in reserve while the network
//  is calm, more after a freeze, less again after a calm spell. It speeds up a little when behind, jumps
//  forward when far behind and trims what it has already played. A browser without Media Source (iPhone Safari) plays the HLS playlist
//  itself, which holds back about three seconds.
//
//  Address options, for measuring: `?debug=1` shows how far behind the newest picture it is, `?native=1`
//  forces the browser's own HLS player.
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
      #dbg { position: fixed; left: 8px; top: 8px; display: none; padding: 4px 8px; border-radius: 6px;
             font: 12px/1.4 Menlo, Consolas, monospace; background: rgba(0, 0, 0, 0.6); }
      #sound { position: fixed; right: 16px; bottom: 16px; border: 0; border-radius: 22px; padding: 12px 20px;
               font-size: 16px; background: #004bf9; color: #fff; display: none; }
    </style>
    </head>
    <body>
    <video id="v" autoplay muted playsinline controls></video>
    <div id="note">Connecting to the iPhone screen…</div>
    <div id="dbg"></div>
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

      var debug = location.search.indexOf('debug=1') >= 0;
      var hasNative = !!video.canPlayType('application/vnd.apple.mpegurl');
      if (location.search.indexOf('native=1') >= 0 || (hasNative && !window.MediaSource)) {
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
        // Live edge with an adaptive buffer. `margin` is the picture kept in reserve just before the next segment
        // arrives: small while the network is calm, larger after every freeze, smaller again after a calm spell.
        // Beyond the buffer's normal swing (`margin` to `margin + segment`) it plays a little faster, and it
        // jumps forward when far behind; just before running dry it plays a little slower.
        var segment = 0.5;                       // seconds per segment, read from the playlist
        var MIN_MARGIN = 0.15, MAX_MARGIN = 2.0, GROW = 0.35, DECAY = 0.1, CALM_MS = 8000;
        var FAST_EXTRA = 0.5, JUMP_EXTRA = 1.5, FAST_RATE = 1.08, SLOW_RATE = 0.92;
        var margin = MIN_MARGIN;
        var lastTrouble = Date.now(), started = false;
        video.addEventListener('playing', function () { started = true; });
        video.addEventListener('waiting', function () {
          if (!started) { return; }
          margin = Math.min(MAX_MARGIN, margin + GROW);
          lastTrouble = Date.now();
        });
        setInterval(function () {
          if (margin > MIN_MARGIN && Date.now() - lastTrouble > CALM_MS) {
            margin = Math.max(MIN_MARGIN, margin - DECAY);
            lastTrouble = Date.now();
          }
        }, 1000);
        var lastKB = 0, lastMs = 0;

        function get(path, type) {
          var started = Date.now();
          return fetch(base + '/' + path, { cache: 'no-store' }).then(function (r) {
            if (!r.ok) { throw new Error(r.status); }
            return type === 'text' ? r.text() : r.arrayBuffer();
          }).then(function (data) {
            if (type === 'buffer' && path.indexOf('seg') === 0) {
              lastMs = Date.now() - started;
              lastKB = Math.round(data.byteLength / 1024);
            }
            return data;
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
          var lag = end - video.currentTime;
          // The buffer swings between `margin` and `margin + segment` as segments arrive.
          if (video.currentTime < start || lag > margin + segment + JUMP_EXTRA) {
            video.currentTime = Math.max(start, end - (margin + segment));
            lag = end - video.currentTime;
          }
          var rate = 1;
          if (lag > margin + segment + FAST_EXTRA) { rate = FAST_RATE; }
          else if (lag < margin * 0.5) { rate = SLOW_RATE; }
          if (video.playbackRate !== rate) { video.playbackRate = rate; }
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
              else if (line.indexOf('#EXTINF:') === 0) { segment = parseFloat(line.substring(8)) || segment; }
              else if (line && line.charAt(0) !== '#') { names.push(line.trim()); }
            });
            if (!names.length) { return; }
            var last = first + names.length - 1;
            var fresh = nextSequence === null;
            if (fresh) { nextSequence = Math.max(first, last); }
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
        setInterval(poll, 250);
        setInterval(pump, 200);
        if (debug) {
          var label = document.getElementById('dbg');
          label.style.display = 'block';
          setInterval(function () {
            var shown = buffer.buffered;
            var behind = shown.length ? shown.end(shown.length - 1) - video.currentTime : 0;
            label.textContent = 'behind newest picture ' + behind.toFixed(2) + ' s | speed ' + video.playbackRate.toFixed(2) + ' | reserve ' + margin.toFixed(2) + ' s' +
              ' | last segment ' + lastKB + ' KB in ' + lastMs + ' ms';
          }, 200);
        }
      }, { once: true });
    })();
    </script>
    </body>
    </html>
    """#
}
