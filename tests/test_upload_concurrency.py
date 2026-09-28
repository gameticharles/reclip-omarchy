"""Concurrency and security regression tests for the ReClip LAN file server.

The two headline cases are the races reported in review:

  * concurrent uploads each passing the same session-quota check, so their sum
    exceeds the cap and the host filesystem is exhausted;
  * concurrent uploads of an identical filename selecting the same destination
    and silently overwriting one another via os.replace().

Both are asserted against a real threaded server over real sockets, not a mock,
because the failure mode only exists when handler threads actually overlap.

Run:  python3 -m unittest discover -s tests -v
"""

import html
import http.client
import os
import re
import shutil
import sys
import tempfile
import threading
import time
import unittest
import zipfile
from html.parser import HTMLParser

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))

import qr_file_server as qfs  # noqa: E402


def free_bytes(path):
    try:
        return shutil.disk_usage(path).free
    except OSError:
        return 0


class ServerHarness:
    """Boots a real ThreadedFileShareServer on an ephemeral port."""

    def __init__(self, save_dir, files_meta=None, **kwargs):
        self.server = qfs.ThreadedFileShareServer(
            ("127.0.0.1", 0),
            qfs.FileShareHandler,
            files_meta or [],
            lan_ip="127.0.0.1",
            save_dir=save_dir,
            **kwargs,
        )
        self.port = self.server.server_address[1]
        self.token = self.server.token
        self.csrf = self.server.csrf_token()
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def client(self):
        return http.client.HTTPConnection("127.0.0.1", self.port, timeout=60)

    def stop(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=5)


class UploadTestBase(unittest.TestCase):
    def setUp(self):
        self.save_dir = tempfile.mkdtemp(prefix="reclip-test-")
        # The upload path demands a 256 MB OS margin on top of the payload, so
        # skip rather than report a spurious 507 on a nearly-full filesystem.
        if free_bytes(self.save_dir) < 2 * 1024 * 1024 * 1024:
            self.skipTest("needs >= 2 GB free to satisfy the disk-space margin")

    def tearDown(self):
        shutil.rmtree(self.save_dir, ignore_errors=True)

    def upload(self, harness, filename, payload, timeout=60):
        """POST /upload as an authenticated, CSRF-bearing client."""
        import urllib.parse
        conn = harness.client()
        try:
            conn.request(
                "POST",
                "/upload",
                body=payload,
                headers={
                    "Content-Type": "application/octet-stream",
                    "Content-Length": str(len(payload)),
                    "Cookie": f"reclip_auth={harness.token}",
                    "X-CSRF-Token": harness.csrf,
                    "X-Filename": urllib.parse.quote(filename),
                },
            )
            resp = conn.getresponse()
            body = resp.read()
            return resp.status, body
        finally:
            conn.close()


class TestSessionQuotaUnderConcurrency(UploadTestBase):
    """The reviewer's first race: N uploads must not collectively exceed quota."""

    PAYLOAD_SIZE = 256 * 1024
    QUOTA = 1024 * 1024
    THREADS = 12

    def test_total_accepted_never_exceeds_quota(self):
        harness = ServerHarness(self.save_dir, max_session_quota=self.QUOTA)
        try:
            payload = os.urandom(self.PAYLOAD_SIZE)
            barrier = threading.Barrier(self.THREADS)
            results = [None] * self.THREADS
            # Sample the reservation counter throughout: a leaked or
            # non-atomic reservation shows up as a transient overshoot even
            # when the number of accepted uploads happens to come out right.
            observed = []
            sampling = threading.Event()

            def sampler():
                while not sampling.is_set():
                    observed.append(harness.server.session_uploaded_bytes)
                    time.sleep(0.001)

            def worker(idx):
                barrier.wait()
                try:
                    results[idx] = self.upload(
                        harness, f"quota_{idx}.bin", payload
                    )
                except Exception as exc:  # pragma: no cover - diagnostics
                    results[idx] = (0, str(exc).encode())

            mon = threading.Thread(target=sampler, daemon=True)
            mon.start()
            workers = [
                threading.Thread(target=worker, args=(i,))
                for i in range(self.THREADS)
            ]
            for t in workers:
                t.start()
            for t in workers:
                t.join(timeout=120)
            sampling.set()
            mon.join(timeout=5)

            statuses = [r[0] for r in results if r]
            accepted = [s for s in statuses if s == 200]
            rejected = [s for s in statuses if s == 413]

            # Every thread must have been answered one way or the other.
            self.assertEqual(
                len(statuses), self.THREADS, f"threads hung or failed: {results}"
            )
            # The core assertion: bytes actually on disk are within the quota.
            on_disk = sum(
                os.path.getsize(os.path.join(self.save_dir, f))
                for f in os.listdir(self.save_dir)
                if os.path.isfile(os.path.join(self.save_dir, f))
                and not f.endswith((".reserve", ".part"))
            )
            self.assertLessEqual(
                on_disk,
                self.QUOTA,
                f"accepted {on_disk} bytes with a {self.QUOTA} byte quota",
            )
            # The reservation counter must never have overshot either, which is
            # what keeps the disk-space check honest for in-flight uploads.
            self.assertLessEqual(
                max(observed) if observed else 0,
                self.QUOTA,
                "session_uploaded_bytes overshot the quota mid-flight",
            )
            # Sanity: the limiter is actually engaged, not passing everything.
            self.assertTrue(rejected, "no upload was quota-rejected; test is vacuous")
            self.assertLessEqual(
                len(accepted) * self.PAYLOAD_SIZE,
                self.QUOTA,
                "more uploads accepted than the quota permits",
            )
            # No partial or reservation debris may survive a clean run.
            leftovers = [
                f for f in os.listdir(self.save_dir)
                if f.endswith((".part", ".reserve"))
            ]
            self.assertEqual(leftovers, [], f"temp files leaked: {leftovers}")
        finally:
            harness.stop()


class TestIdenticalFilenameCollision(UploadTestBase):
    """The reviewer's second race: same name must never clobber an earlier upload."""

    THREADS = 12
    ROUNDS = 4

    def _one_round(self, harness, round_idx):
        size = 32 * 1024
        payloads = [os.urandom(size) for _ in range(self.THREADS)]
        barrier = threading.Barrier(self.THREADS)
        results = [None] * self.THREADS

        def worker(idx):
            barrier.wait()
            try:
                # Same filename for every thread -- this is the collision.
                results[idx] = self.upload(harness, "photo.jpg", payloads[idx])
            except Exception as exc:  # pragma: no cover - diagnostics
                results[idx] = (0, str(exc).encode())

        workers = [
            threading.Thread(target=worker, args=(i,))
            for i in range(self.THREADS)
        ]
        for t in workers:
            t.start()
        for t in workers:
            t.join(timeout=120)

        statuses = [r[0] for r in results if r]
        self.assertEqual(
            len(statuses), self.THREADS,
            f"round {round_idx}: threads hung or failed: {results}",
        )
        self.assertTrue(
            all(s == 200 for s in statuses),
            f"round {round_idx}: quota is ample here, expected all 200: {statuses}",
        )

        files = sorted(
            f for f in os.listdir(self.save_dir)
            if os.path.isfile(os.path.join(self.save_dir, f))
        )
        # Every upload must have landed at its own distinct destination.
        self.assertEqual(
            len(files), self.THREADS,
            f"round {round_idx}: expected {self.THREADS} distinct files, got {files}",
        )

        # Independent signal: no upload's bytes were lost. An overwrite shows up
        # here even if the file count happened to look right.
        stored = set()
        for f in files:
            with open(os.path.join(self.save_dir, f), "rb") as fh:
                stored.add(fh.read())
        self.assertEqual(
            len(stored), self.THREADS,
            f"round {round_idx}: duplicate content on disk -- an upload overwrote another",
        )
        self.assertEqual(
            stored, set(payloads),
            f"round {round_idx}: stored bytes do not match what was uploaded",
        )

        for f in files:
            os.unlink(os.path.join(self.save_dir, f))

    def test_identical_names_do_not_overwrite(self):
        harness = ServerHarness(self.save_dir, max_session_quota=64 * 1024 * 1024)
        try:
            for round_idx in range(self.ROUNDS):
                self._one_round(harness, round_idx)
        finally:
            harness.stop()


class TestFailedUploadReleasesQuota(UploadTestBase):
    """A reservation must not leak when the transfer dies mid-body."""

    def test_truncated_upload_releases_reservation(self):
        harness = ServerHarness(self.save_dir, max_session_quota=1024 * 1024)
        try:
            import urllib.parse
            conn = harness.client()
            # Promise 512 KB, send far less, then hang up.
            conn.putrequest("POST", "/upload")
            conn.putheader("Content-Type", "application/octet-stream")
            conn.putheader("Content-Length", str(512 * 1024))
            conn.putheader("Cookie", f"reclip_auth={harness.token}")
            conn.putheader("X-CSRF-Token", harness.csrf)
            conn.putheader("X-Filename", urllib.parse.quote("partial.bin"))
            conn.endheaders()
            conn.send(b"x" * 1024)
            time.sleep(0.2)
            conn.close()

            deadline = time.time() + 15
            while time.time() < deadline:
                if harness.server.session_uploaded_bytes == 0:
                    break
                time.sleep(0.05)

            self.assertEqual(
                harness.server.session_uploaded_bytes,
                0,
                "quota reservation leaked after a failed upload",
            )
            debris = [
                f for f in os.listdir(self.save_dir)
                if f.endswith((".part", ".reserve"))
            ]
            self.assertEqual(debris, [], f"partial files leaked: {debris}")
        finally:
            harness.stop()


class TestCSRF(UploadTestBase):
    def setUp(self):
        super().setUp()
        self.harness = ServerHarness(self.save_dir)
        self.addCleanup(self.harness.stop)

    def test_cookie_post_without_csrf_header_is_rejected(self):
        conn = self.harness.client()
        body = b'{"text":"clipboard overwrite attempt"}'
        conn.request(
            "POST",
            "/api/beam-text",
            body=body,
            headers={
                "Content-Type": "application/json",
                "Content-Length": str(len(body)),
                "Cookie": f"reclip_auth={self.harness.token}",
            },
        )
        resp = conn.getresponse()
        resp.read()
        conn.close()
        self.assertEqual(resp.status, 403, "CSRF-less cookie POST was accepted")

    def test_query_token_post_needs_no_csrf(self):
        """Non-browser clients using ?token= stay exempt from CSRF."""
        conn = self.harness.client()
        body = b'{"text":"legit"}'
        conn.request(
            "POST",
            f"/api/beam-text?token={self.harness.token}",
            body=body,
            headers={
                "Content-Type": "application/json",
                "Content-Length": str(len(body)),
            },
        )
        resp = conn.getresponse()
        resp.read()
        conn.close()
        self.assertEqual(resp.status, 200, "token-auth POST should bypass CSRF")

    def test_verify_pin_stays_reachable(self):
        """The pre-auth PIN check must not require a CSRF token."""
        conn = self.harness.client()
        body = b'{"pin":"000000"}'
        conn.request(
            "POST",
            "/api/verify-pin",
            body=body,
            headers={
                "Content-Type": "application/json",
                "Content-Length": str(len(body)),
            },
        )
        resp = conn.getresponse()
        resp.read()
        conn.close()
        self.assertNotEqual(resp.status, 403, "verify-pin must not demand CSRF")


class TestBeamRateLimit(UploadTestBase):
    def test_beam_is_rate_limited(self):
        harness = ServerHarness(self.save_dir)
        self.addCleanup(harness.stop)
        statuses = []
        for i in range(qfs.BEAM_MAX_PER_WINDOW + 4):
            conn = harness.client()
            body = f'{{"text":"spam {i}"}}'.encode()
            conn.request(
                "POST",
                f"/api/beam-text?token={harness.token}",
                body=body,
                headers={
                    "Content-Type": "application/json",
                    "Content-Length": str(len(body)),
                },
            )
            resp = conn.getresponse()
            resp.read()
            conn.close()
            statuses.append(resp.status)
        self.assertIn(
            429, statuses, f"beam never rate limited (statuses {statuses})"
        )
        self.assertLessEqual(
            sum(1 for s in statuses if s == 200),
            qfs.BEAM_MAX_PER_WINDOW,
            "more beams accepted than the limit allows",
        )


class TestSymlinkContainment(unittest.TestCase):
    """#2: a symlink in a shared folder must not exfiltrate host files."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="reclip-symlink-")
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.secret = os.path.join(self.tmp, "secret.txt")
        with open(self.secret, "w") as fh:
            fh.write("TOP-SECRET-HOST-DATA")
        self.share = os.path.join(self.tmp, "share")
        os.makedirs(self.share)
        self.public = os.path.join(self.share, "public.txt")
        with open(self.public, "w") as fh:
            fh.write("public")
        # A symlinked *file* pointing at a host file outside the share.
        os.symlink(self.secret, os.path.join(self.share, "leak.txt"))
        # A symlinked *directory* pointing outside the share.
        os.symlink(self.tmp, os.path.join(self.share, "escape"))

    def test_walk_yields_only_contained_regular_files(self):
        found = {os.path.basename(fp) for fp, _ in qfs.iter_share_files(self.share)}
        self.assertIn("public.txt", found)
        self.assertNotIn("leak.txt", found, "symlinked file was exposed")
        self.assertNotIn("secret.txt", found, "symlinked dir let a host file in")

    def test_zip_bundle_excludes_symlinks(self):
        out = os.path.join(self.tmp, "out.zip")
        parent = os.path.dirname(os.path.abspath(self.share))
        with zipfile.ZipFile(out, "w") as zf:
            for fp, _ in qfs.iter_share_files(self.share):
                zf.write(fp, arcname=os.path.relpath(fp, parent))
        with zipfile.ZipFile(out) as zf:
            names = zf.namelist()
            blob = b"".join(zf.read(n) for n in names)
        self.assertNotIn(b"TOP-SECRET-HOST-DATA", blob, "host file leaked into ZIP")


class TestContentDispositionEscaping(unittest.TestCase):
    """#1: a crafted filename must not break out of the header value."""

    def test_quote_and_crlf_are_neutralized(self):
        evil = 'ev"il\r\nX-Injected: yes\r\n\r\nbody.jpg'
        value = qfs.content_disposition_value("attachment", evil)
        # Nothing may break out of the header line.
        self.assertNotIn("\r", value)
        self.assertNotIn("\n", value)
        # The quoted filename= parameter must be exactly one balanced token:
        # extract it and prove it holds no quote, CR or LF of its own.
        quoted = value.split('filename="', 1)[1].split('"; filename*=', 1)[0]
        self.assertNotIn('"', quoted)
        self.assertNotIn("\r", quoted)
        self.assertNotIn("\n", quoted)
        self.assertEqual(value.count('"'), 2, "unbalanced quotes in header value")
        # The attacker-controlled CRLF payload must not survive as a header.
        self.assertNotIn("X-Injected: yes\r\n", value)

    def test_unicode_name_survives_via_rfc5987(self):
        value = qfs.content_disposition_value("attachment", "réunion notes.pdf")
        self.assertIn("filename*=UTF-8''", value)
        self.assertIn("r%C3%A9union", value)

    def test_empty_name_gets_placeholder(self):
        self.assertIn('filename="download"', qfs.content_disposition_value("attachment", ""))


class TestPortalHtmlEscaping(unittest.TestCase):
    """The portal renders user-controlled filenames into HTML.

    A filename is attacker-controlled data, so it must never land in a place
    the browser parses as script. The image-preview button is the sharp edge:
    it used to be wired with an inline onclick built from the filename, where a
    single double quote terminated the attribute and left a syntax error (or,
    with a weaker escaper, a live handler).
    """

    HOSTILE = '"><img src=x onerror=alert(1)>.png'

    def _render(self, names):
        save_dir = tempfile.mkdtemp(prefix="reclip-html-")
        self.addCleanup(shutil.rmtree, save_dir, True)
        files_meta = []
        for name in names:
            path = os.path.join(save_dir, "f%d.bin" % len(files_meta))
            with open(path, "wb") as fh:
                fh.write(b"\x89PNG\r\n\x1a\n")
            files_meta.append({
                "name": name, "path": path, "size": 8, "size_str": "8 B",
                "is_dir": False, "file_count": 0,
            })
        harness = ServerHarness(save_dir, files_meta)
        self.addCleanup(harness.stop)
        conn = harness.client()
        conn.request("GET", f"/?token={harness.token}")
        resp = conn.getresponse()
        body = resp.read().decode("utf-8", "replace")
        conn.close()
        self.assertEqual(resp.status, 200)
        return body

    def test_filename_never_becomes_live_markup(self):
        """The payload may appear as *text* (that is the point), but never as a
        parsed element and never as an event-handler attribute."""
        page = self._render([self.HOSTILE])

        class Collector(HTMLParser):
            def __init__(self):
                super().__init__()
                self.imgs = []
                self.attr_values = []

            def handle_starttag(self, tag, attrs):
                if tag == "img":
                    self.imgs.append(dict(attrs))
                for key, value in attrs:
                    self.attr_values.append((tag, key, value))

        collector = Collector()
        collector.feed(page)

        # The attacker asked for an <img onerror=...>. Every <img> on the page
        # is one ReClip authored (the lightbox); none may carry the payload.
        self.assertTrue(collector.imgs, "expected the lightbox <img> to exist")
        for attrs in collector.imgs:
            self.assertNotIn("onerror", attrs, "payload landed on an <img> handler")
            self.assertNotEqual(attrs.get("src"), "x", "payload landed on an <img> src")
        # The page has legitimate static handlers (toggleTheme, closeLightbox),
        # so the check is that the payload never rides along inside one.
        for tag, key, value in collector.attr_values:
            if key.startswith("on"):
                self.assertNotIn("alert", value,
                                 f"payload reached the {tag} {key} handler")
        # And it is still visible to the user, escaped, as the filename.
        self.assertIn("&lt;img src=x onerror=alert(1)&gt;", page)

    def test_no_inline_js_built_from_filename(self):
        """Every onclick must be a static handler, never one containing the name."""
        page = self._render([self.HOSTILE, "it's a photo.png"])
        for match in re.finditer(r'onclick="([^"]*)"', page):
            handler = match.group(1)
            self.assertNotIn("openLightbox", handler,
                             "lightbox wired via inline JS built from a filename")
            self.assertNotIn("alert", handler)
            self.assertNotIn("img src=x", handler)

    def test_hostile_name_round_trips_through_data_attribute(self):
        """data-name is escaped for the attribute, so getAttribute() returns the
        exact original name and the lightbox caption is correct."""
        page = self._render([self.HOSTILE])
        values = re.findall(r'data-name="([^"]*)"', page)
        self.assertIn(self.HOSTILE, [html.unescape(v) for v in values])

    def test_page_html_is_well_formed(self):
        """A truncated attribute shows up as a parser error, which is how the
        inline-onclick bug presented itself."""
        page = self._render([self.HOSTILE])

        class Checker(HTMLParser):
            VOID = {"meta", "link", "br", "hr", "img", "input"}

            def __init__(self):
                super().__init__()
                self.stack = []
                self.errors = []

            def handle_starttag(self, tag, attrs):
                if tag not in self.VOID:
                    self.stack.append(tag)

            def handle_endtag(self, tag):
                if tag in self.VOID:
                    return
                if self.stack and self.stack[-1] == tag:
                    self.stack.pop()
                else:
                    self.errors.append(tag)

        checker = Checker()
        checker.feed(page)
        self.assertEqual(checker.errors, [], "mismatched closing tags")
        self.assertEqual(checker.stack, [], "unclosed tags")


class TestRangeRequests(unittest.TestCase):
    """#10: invalid ranges must be 416, not a silently clamped 206."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="reclip-range-")
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.payload = bytes(range(256)) * 4  # 1024 bytes
        self.fpath = os.path.join(self.tmp, "r.bin")
        with open(self.fpath, "wb") as fh:
            fh.write(self.payload)
        harness = ServerHarness(self.tmp, files_meta=[
            {"index": 0, "name": "r.bin", "path": self.fpath, "size": len(self.payload),
             "size_str": "1 KB", "is_dir": False, "category": "file"}
        ])
        self.addCleanup(harness.stop)
        self.harness = harness

    def _get(self, range_value):
        conn = self.harness.client()
        conn.request("GET", "/r.bin", headers={
            "Cookie": f"reclip_auth={self.harness.token}",
            "Range": range_value,
        })
        resp = conn.getresponse()
        body = resp.read()
        conn.close()
        return resp.status, dict(resp.getheaders()), body

    def test_valid_range_serves_partial(self):
        status, headers, body = self._get("bytes=0-9")
        self.assertEqual(status, 206)
        self.assertEqual(body, self.payload[:10])
        self.assertEqual(headers.get("Content-Range"), f"bytes 0-9/{len(self.payload)}")

    def test_suffix_range(self):
        status, _, body = self._get("bytes=-10")
        self.assertEqual(status, 206)
        self.assertEqual(body, self.payload[-10:])

    def test_inverted_range_is_416(self):
        status, headers, _ = self._get("bytes=500-100")
        self.assertEqual(status, 416)
        self.assertEqual(headers.get("Content-Range"), f"bytes */{len(self.payload)}")

    def test_out_of_bounds_start_is_416(self):
        status, _, _ = self._get("bytes=99999-")
        self.assertEqual(status, 416)

    def test_garbage_range_is_416(self):
        status, _, _ = self._get("bytes=abc-def")
        self.assertEqual(status, 416)

    def test_multirange_falls_back_to_full_entity(self):
        status, _, body = self._get("bytes=0-9,20-29")
        self.assertEqual(status, 200)
        self.assertEqual(body, self.payload)


class TestStatusJsonHidesPaths(unittest.TestCase):
    """#18: status.json must not disclose the host directory layout."""

    def test_path_field_is_stripped(self):
        tmp = tempfile.mkdtemp(prefix="reclip-status-")
        self.addCleanup(shutil.rmtree, tmp, ignore_errors=True)
        fpath = os.path.join(tmp, "doc.txt")
        with open(fpath, "w") as fh:
            fh.write("hi")
        harness = ServerHarness(tmp, files_meta=[
            {"index": 0, "name": "doc.txt", "path": fpath, "size": 2,
             "size_str": "2 B", "is_dir": False, "category": "file"}
        ])
        self.addCleanup(harness.stop)
        conn = harness.client()
        conn.request("GET", "/status.json", headers={
            "Cookie": f"reclip_auth={harness.token}"})
        resp = conn.getresponse()
        body = resp.read().decode()
        conn.close()
        self.assertNotIn(tmp, body, "status.json leaked the host path")
        self.assertIn("doc.txt", body)


class TestZipCacheEviction(unittest.TestCase):
    """#13: the folder ZIP cache must be bounded."""

    def test_cache_is_capped(self):
        tmp = tempfile.mkdtemp(prefix="reclip-zipcache-")
        self.addCleanup(shutil.rmtree, tmp, ignore_errors=True)
        harness = ServerHarness(tmp)
        self.addCleanup(harness.stop)
        made = []
        for i in range(qfs.FOLDER_ZIP_CACHE_MAX + 5):
            p = os.path.join(tmp, f"f{i}.zip")
            with open(p, "w") as fh:
                fh.write("x")
            made.append(p)
            harness.server.cache_folder_zip(f"folder{i}", p)
        self.assertLessEqual(
            len(harness.server.folder_zip_cache), qfs.FOLDER_ZIP_CACHE_MAX
        )
        # Evicted entries must be unlinked, not merely dropped from the dict.
        for p in made[:5]:
            self.assertFalse(os.path.exists(p), f"evicted ZIP {p} was left on disk")


if __name__ == "__main__":
    unittest.main(verbosity=2)
