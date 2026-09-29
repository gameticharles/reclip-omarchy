// FileShareArgs.js - argv construction for lib/qr_file_server.py
//
// The server is spawned as a subprocess, so the Settings UI can only reach
// its tunables through this argv. Keeping the construction in a pure
// .pragma library rather than inline in QRCodeModal.qml is what makes it
// testable: tests/fileshare_args_harness.js loads this file and asserts on
// the exact command line, so a flag rename or a dropped override fails a test
// instead of silently reverting to a compiled-in default at runtime.
.pragma library

// Defaults mirror the module-level constants in lib/qr_file_server.py. They
// are duplicated rather than shared because QML cannot import Python; the
// harness below and tests/test_upload_concurrency.py assert the two agree, so
// a one-sided change is caught.
function defaults() {
    return {
        ports: "53317,53318,8080,8000,8888,0",
        timeout: 1800,
        uploadDeadlineMax: 1800.0,
        maxUploadSizeMB: 1024,
        maxSessionQuotaMB: 5120,
        diskSpaceMarginMB: 256,
        folderZipCacheMax: 10,
        uploadNameMaxBytes: 180,
        beamMaxPerWindow: 5,
        beamWindow: 10.0,
        pinMaxAttempts: 5,
        pinLockout: 900.0,
        pinGlobalMaxAttempts: 20,
        pinGlobalLockout: 900.0,
        pinRecordTtl: 1800
    };
}

function isSet(v) {
    return v !== undefined && v !== null && v !== "";
}

// A finite number, or null. Guards against NaN from an emptied TextField and
// against Infinity, which would otherwise reach argparse as a valid float.
function num(v) {
    if (typeof v === "number") return isFinite(v) ? v : null;
    if (typeof v === "string" && v.trim() !== "") {
        var n = Number(v);
        return isFinite(n) ? n : null;
    }
    return null;
}

function pushNum(args, flag, value) {
    var n = num(value);
    if (n !== null) args.push(flag, String(n));
}

// Clamped client-side to the same bounds the server enforces in
// ThreadedFileShareServer.__init__. Duplicated on purpose: the server is the
// authority and will clamp again, but a slider that can reach 300 bytes would
// show a value that never takes effect.
function clampInt(v, low, high) {
    var n = num(v);
    if (n === null) return null;
    return Math.round(Math.max(low, Math.min(high, n)));
}

/**
 * buildArgs(scriptPath, opts, paths) -> string[]
 *
 * Returns the full argv for the server process. opts is the merged settings
 * object; any field that is absent or unusable is simply not passed, which
 * makes the server fall back to its own default. paths are appended last
 * because argparse has nargs="+" for the positional file list.
 */
function buildArgs(scriptPath, opts, paths) {
    var o = opts || {};
    var args = ["python3", scriptPath];

    // Booleans use the negative form, so "allowed" is the absence of a flag.
    if (!o.singleShot) args.push("--no-single-shot");
    if (!o.allowUpload) args.push("--no-upload");
    if (!o.allowBeam) args.push("--no-beam");

    if (isSet(o.saveDir)) args.push("--save-dir", String(o.saveDir));
    if (isSet(o.ip)) args.push("--ip", String(o.ip));
    if (isSet(o.ports)) args.push("--ports", String(o.ports));

    pushNum(args, "--timeout", o.timeout);
    pushNum(args, "--upload-deadline-max", o.uploadDeadlineMax);
    pushNum(args, "--max-upload-size", bytes(o.maxUploadSizeMB));
    pushNum(args, "--max-session-quota", bytes(o.maxSessionQuotaMB));
    pushNum(args, "--disk-space-margin-mb", o.diskSpaceMarginMB);
    pushNum(args, "--folder-zip-cache-max", clampInt(o.folderZipCacheMax, 0, 100));
    pushNum(args, "--upload-name-max-bytes", clampInt(o.uploadNameMaxBytes, 64, 200));
    pushNum(args, "--beam-max-per-window", clampInt(o.beamMaxPerWindow, 1, 1000));
    pushNum(args, "--beam-window", o.beamWindow);
    pushNum(args, "--pin-max-attempts", clampInt(o.pinMaxAttempts, 1, 100));
    pushNum(args, "--pin-lockout", o.pinLockout);
    pushNum(args, "--pin-global-max-attempts", clampInt(o.pinGlobalMaxAttempts, 1, 10000));
    pushNum(args, "--pin-global-lockout", o.pinGlobalLockout);
    pushNum(args, "--pin-record-ttl", o.pinRecordTtl);

    var list = paths || [];
    for (var i = 0; i < list.length; i++) args.push(String(list[i]));
    return args;
}

// The two size limits are stored in MB because that is what a person can
// reason about, and multiplied here so the settings never carry a byte count
// that has to be recomputed on every edit.
function bytes(mb) {
    var n = num(mb);
    if (n === null) return null;
    return Math.round(n * 1024 * 1024);
}
