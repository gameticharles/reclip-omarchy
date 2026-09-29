// Behavioural test harness for lib/FileShareArgs.js.
//
// The Wi-Fi share server is spawned as a subprocess, so the Settings UI can
// only reach lib/qr_file_server.py's tunables through the argv this module
// builds. That makes the argv the contract: a renamed flag or a dropped
// override reverts to a compiled-in default at runtime with no error anywhere.
// So the only honest way to test it is to build the argv and assert on it.
//
// The companion check that these flags actually exist in argparse lives in
// tests/test_upload_concurrency.py (TestShareServerArgv), so the two sides
// cannot drift apart.
//
// Run directly for a human-readable report:
//     node tests/fileshare_args_harness.js lib/FileShareArgs.js
// Exits non-zero if any assertion fails.

'use strict';

const fs = require('fs');
const vm = require('vm');

const JS_PATH = process.argv[2] || 'lib/FileShareArgs.js';
if (!fs.existsSync(JS_PATH)) {
    console.error(`fileshare_args_harness: ${JS_PATH} not found`);
    process.exit(2);
}

// The .pragma library line is QML syntax, not JS; strip it before evaluating.
const source = fs.readFileSync(JS_PATH, 'utf8').replace(/^\.pragma library$/m, '');
const sandbox = { isFinite: isFinite, Math: Math, Number: Number, String: String };
vm.createContext(sandbox);
vm.runInContext(source, sandbox, { filename: JS_PATH });
const FSA = sandbox.buildArgs ? sandbox : Object.assign(sandbox, vm.runInContext(
    '({ buildArgs: buildArgs, defaults: defaults })', sandbox));

let passed = 0;
let failed = 0;

function check(name, fn) {
    try {
        fn();
        passed++;
    } catch (e) {
        failed++;
        console.log(`  FAIL ${name}\n       ${e.message}`);
    }
}

function eq(actual, expected, what) {
    const a = JSON.stringify(actual);
    const b = JSON.stringify(expected);
    if (a !== b) throw new Error(`${what}\n       expected ${b}\n       actual   ${a}`);
}

// Position of a flag in argv, or -1.
function idxOf(args, flag) {
    return args.indexOf(flag);
}

function valueOf(args, flag) {
    const i = args.indexOf(flag);
    return i === -1 ? undefined : args[i + 1];
}

const SCRIPT = '/plug/lib/qr_file_server.py';

// ---------------------------------------------------------------------------
console.log('\nargv construction:');

check('always starts with the interpreter and script', () => {
    const args = FSA.buildArgs(SCRIPT, {}, []);
    eq(args.slice(0, 2), ['python3', SCRIPT], 'argv head');
});

check('an empty options object produces only the negative booleans', () => {
    // singleShot/allowUpload/allowBeam all default false, so all three
    // negative flags are expected. This is the shape every QML call produces
    // when the user has touched nothing.
    const args = FSA.buildArgs(SCRIPT, {}, []);
    const withoutPaths = args.slice(0, 2);
    eq(withoutPaths, ['python3', SCRIPT], 'head only');
    for (const f of ['--timeout', '--ports', '--pin-lockout', '--max-upload-size']) {
        if (args.includes(f)) throw new Error(`${f} was emitted with no setting set`);
    }
});

check('paths are appended last, after every flag', () => {
    const args = FSA.buildArgs(SCRIPT, { timeout: 600 }, ['/a/one.txt', '/b/two']);
    eq(args.slice(-2), ['/a/one.txt', '/b/two'], 'trailing paths');
    // argparse has nargs="+" for files, so a flag after a path would be
    // swallowed as another filename.
    const lastFlag = args.map((a, i) => (a.startsWith('--') ? i : -1)).filter(i => i >= 0).pop();
    if (lastFlag > args.length - 3) throw new Error('a flag appears after the file list');
});

check('booleans use the negative form', () => {
    const all = FSA.buildArgs(SCRIPT, { singleShot: true, allowUpload: true, allowBeam: true }, []);
    for (const f of ['--no-single-shot', '--no-upload', '--no-beam']) {
        if (all.includes(f)) throw new Error(`${f} present when the feature is enabled`);
    }
    const none = FSA.buildArgs(SCRIPT, { singleShot: false, allowUpload: false, allowBeam: false }, []);
    for (const f of ['--no-single-shot', '--no-upload', '--no-beam']) {
        if (!none.includes(f)) throw new Error(`${f} missing when the feature is disabled`);
    }
});

check('every tunable maps to its flag with the value attached', () => {
    const opts = {
        ports: '1234,0',
        ip: '10.0.0.5',
        saveDir: '/tmp/drop',
        timeout: 600,
        uploadDeadlineMax: 900,
        maxUploadSizeMB: 100,
        maxSessionQuotaMB: 250,
        diskSpaceMarginMB: 12,
        folderZipCacheMax: 3,
        uploadNameMaxBytes: 120,
        beamMaxPerWindow: 9,
        beamWindow: 30,
        pinMaxAttempts: 4,
        pinLockout: 60,
        pinGlobalMaxAttempts: 8,
        pinGlobalLockout: 120,
        pinRecordTtl: 300
    };
    const args = FSA.buildArgs(SCRIPT, opts, []);
    const expect = {
        '--ports': '1234,0',
        '--ip': '10.0.0.5',
        '--save-dir': '/tmp/drop',
        '--timeout': '600',
        '--upload-deadline-max': '900',
        '--max-upload-size': String(100 * 1024 * 1024),
        '--max-session-quota': String(250 * 1024 * 1024),
        '--disk-space-margin-mb': '12',
        '--folder-zip-cache-max': '3',
        '--upload-name-max-bytes': '120',
        '--beam-max-per-window': '9',
        '--beam-window': '30',
        '--pin-max-attempts': '4',
        '--pin-lockout': '60',
        '--pin-global-max-attempts': '8',
        '--pin-global-lockout': '120',
        '--pin-record-ttl': '300'
    };
    for (const [flag, want] of Object.entries(expect)) {
        eq(valueOf(args, flag), want, `value of ${flag}`);
    }
});

check('MB values are converted to bytes for the byte-denominated flags', () => {
    // The server parses --max-upload-size in bytes; passing MB straight through
    // would silently cap uploads at 1 KB.
    const args = FSA.buildArgs(SCRIPT, { maxUploadSizeMB: 1, maxSessionQuotaMB: 2 }, []);
    eq(valueOf(args, '--max-upload-size'), '1048576', '1 MB in bytes');
    eq(valueOf(args, '--max-session-quota'), String(2 * 1024 * 1024), '2 MB in bytes');
});

check('MB conversion rounds to whole bytes', () => {
    const args = FSA.buildArgs(SCRIPT, { maxUploadSizeMB: 1.5 }, []);
    eq(valueOf(args, '--max-upload-size'), '1572864', '1.5 MB');
});

check('zero is a real value and is not dropped', () => {
    // 0 means "no disk headroom" / "no cache"; dropping it would silently
    // substitute the server default of 256 MB or 10 entries.
    const args = FSA.buildArgs(SCRIPT, { diskSpaceMarginMB: 0, folderZipCacheMax: 0 }, []);
    eq(valueOf(args, '--disk-space-margin-mb'), '0', 'zero headroom kept');
    eq(valueOf(args, '--folder-zip-cache-max'), '0', 'zero cache kept');
});

check('out-of-range integers are clamped to the server bounds', () => {
    const args = FSA.buildArgs(SCRIPT, {
        uploadNameMaxBytes: 9999,   // server caps at 200
        beamMaxPerWindow: 0,       // server floor is 1
        folderZipCacheMax: 5000,   // server caps at 100
        pinMaxAttempts: 0          // server floor is 1
    }, []);
    eq(valueOf(args, '--upload-name-max-bytes'), '200', 'name cap clamped high');
    eq(valueOf(args, '--beam-max-per-window'), '1', 'beam floor');
    eq(valueOf(args, '--folder-zip-cache-max'), '100', 'zip cache cap');
    eq(valueOf(args, '--pin-max-attempts'), '1', 'pin attempt floor');
});

check('name-byte cap is clamped low as well as high', () => {
    const args = FSA.buildArgs(SCRIPT, { uploadNameMaxBytes: 1 }, []);
    eq(valueOf(args, '--upload-name-max-bytes'), '64', 'name cap clamped low');
});

check('float values that the field allows are not rounded away', () => {
    // beamWindow and the lockout durations are floats; Math.round on them
    // would turn 900.5 into 900 and make the UI lie about what it stores.
    const args = FSA.buildArgs(SCRIPT, { beamWindow: 2.5, pinLockout: 60.25 }, []);
    eq(valueOf(args, '--beam-window'), '2.5', 'float window preserved');
    eq(valueOf(args, '--pin-lockout'), '60.25', 'float lockout preserved');
});

check('NaN, Infinity and non-numeric strings are omitted, not forwarded', () => {
    // An emptied TextField yields "" and a corrupted settings.json can yield
    // NaN; argparse would accept "NaN" for a float and fail deep in the run.
    const args = FSA.buildArgs(SCRIPT, {
        timeout: NaN,
        beamWindow: Infinity,
        pinLockout: 'abc',
        maxUploadSizeMB: null
    }, []);
    for (const f of ['--timeout', '--beam-window', '--pin-lockout', '--max-upload-size']) {
        if (args.includes(f)) throw new Error(`${f} was emitted for an unusable value`);
    }
});

check('numeric strings are accepted', () => {
    // Settings round-trip through JSON, so a value can come back as "600"
    // rather than 600.
    const args = FSA.buildArgs(SCRIPT, { timeout: '600', beamMaxPerWindow: '7' }, []);
    eq(valueOf(args, '--timeout'), '600', 'string timeout coerced');
    eq(valueOf(args, '--beam-max-per-window'), '7', 'string beam count coerced');
});

check('empty-string text fields are omitted so the server default applies', () => {
    const args = FSA.buildArgs(SCRIPT, { ports: '', ip: '', saveDir: '' }, []);
    for (const f of ['--ports', '--ip', '--save-dir']) {
        if (args.includes(f)) throw new Error(`${f} emitted for an empty value`);
    }
});

check('a value of 0 in the ports list survives stringification', () => {
    // 0 means "OS-assigned" and is the fallback in the default port list, so a
    // falsy check on the number would be a bug; it arrives as a string here.
    const args = FSA.buildArgs(SCRIPT, { ports: '53317,0' }, []);
    eq(valueOf(args, '--ports'), '53317,0', 'ports list with 0');
});

check('a paths value that is not an array does not throw', () => {
    const args = FSA.buildArgs(SCRIPT, {}, undefined);
    if (args.some(a => a.startsWith('/') && a !== SCRIPT)) {
        throw new Error('a path appeared from an undefined list');
    }
    eq(args, ['python3', SCRIPT, '--no-single-shot', '--no-upload', '--no-beam'], 'no paths at all');
});

// ---------------------------------------------------------------------------
console.log('defaults agree with the server constants:');

check('defaults() reports the same numbers as qr_file_server.py', () => {
    // The Python side asserts the same table; this is the JS half of that pair.
    const d = FSA.defaults();
    const expect = {
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
        pinRecordTtl: 1800,
        ports: '53317,53318,8080,8000,8888,0'
    };
    for (const [k, v] of Object.entries(expect)) {
        if (d[k] !== v) throw new Error(`defaults().${k} is ${d[k]}, expected ${v}`);
    }
});

check('buildArgs with no options omits every flag, including the ports list', () => {
    // If buildArgs were ever changed to fill in defaults(), an untouched
    // install would start sending overrides and the server's own constants
    // would stop being the single source of truth.
    const args = FSA.buildArgs(SCRIPT, {}, []);
    const flags = args.filter(a => a.startsWith('--'));
    eq(flags, ['--no-single-shot', '--no-upload', '--no-beam'], 'only the three negative flags');
});

// ---------------------------------------------------------------------------
console.log(`\nfile share args: ${passed} assertions passed, ${failed} failed\n`);
process.exit(failed === 0 ? 0 : 1);
