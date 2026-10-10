"""Exercise pinned parsers without attaching a scheduler or connecting to a desktop."""

import configparser
import ctypes
import json
import os
from pathlib import Path
import re
import resource
import subprocess
import sys
import tarfile
import tempfile
import tomllib


resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
manifest = json.loads(Path(sys.argv[1]).read_text())
output = Path(sys.argv[2])


def run(args, environment, log, success=True):
    result = subprocess.run(
        list(map(str, args)), env=environment, stdin=subprocess.DEVNULL,
        capture_output=True, text=True, timeout=20,
    )
    text = result.stdout + result.stderr
    log.write_text(text)
    if success:
        assert result.returncode == 0, f"{log.name}: {text}"
    return result, text


def bluez_schema(source):
    with tarfile.open(source) as archive:
        member = min(
            (p for p in archive.getnames() if p.endswith("/src/main.c")), key=len
        )
        text = archive.extractfile(member).read().decode()
    arrays = {
        name: set(re.findall(r'"([^"\n]+)"', body))
        for name, body in re.findall(
            r"static const char \*(?:const )?(\w+)\[\]\s*=\s*\{(.*?)\};", text, re.S
        )
    }
    table = re.search(r"\}\s*valid_groups\[\]\s*=\s*\{(.*?)\};", text, re.S)
    assert table, "BlueZ group schema changed; update the schema extractor"
    return {group: arrays[name] for group, name in re.findall(
        r'\{\s*"([^"\n]+)"\s*,\s*(\w+)\s*\}', table[1]
    )}


def check_bluez(text, schema):
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    parser.read_string(text)
    for group in parser.sections():
        assert group in schema, f"Unknown BlueZ group: {group}"
        assert set(parser[group]) <= schema[group], f"Unknown BlueZ option in {group}"
    if parser.has_option("Policy", "ReconnectIntervals"):
        assert all(int(v) > 0 for v in parser["Policy"]["ReconnectIntervals"].split(","))


def subset(expected, actual):
    if isinstance(expected, dict):
        return all(k in actual and subset(v, actual[k]) for k, v in expected.items())
    if isinstance(expected, list):
        return len(expected) == len(actual) and all(map(subset, expected, actual))
    return expected == actual


def check_wireplumber(config):
    source = Path(config["source"])
    docs = (source / "doc/dox/config/pipewire-props.7.md").read_text()
    monitor = set(re.findall(r"@PAR@\s+monitor-prop\s+(bluez5\.[\w-]+)", docs))
    device = set(re.findall(r"@PAR@\s+device-prop\s+(bluez5\.[\w-]+)", docs))
    assert monitor and device, "PipeWire property documentation changed"
    schema = Path(config["schema"]).read_text()
    codecs = set()
    for file in (source / "spa/plugins/bluez5").glob("a2dp-codec-*.c"):
        codecs.update(re.findall(r'\.name\s*=\s*"([\w-]+)"', file.read_text()))
    for section in config["config"].values():
        props = section.get("monitor.bluez.properties", {})
        assert {key for key in props if key.startswith("bluez5.")} <= monitor
        assert set(props.get("bluez5.codecs", [])) <= codecs
        for rule in section.get("monitor.bluez.rules", []):
            props = rule.get("actions", {}).get("update-props", {})
            assert {key for key in props if key.startswith("bluez5.")} <= device
        for key, value in section.get("wireplumber.settings", {}).items():
            field = re.search(r"^\s*" + re.escape(key) + r"\s*=\s*\{(.*?)\}", schema, re.M | re.S)
            assert field, f"Unknown WirePlumber setting: {key}"
            if re.search(r'type\s*=\s*"bool"', field[1]):
                assert isinstance(value, bool), f"Expected a boolean for {key}"


for hostname, host in manifest["hosts"].items():
    logs = output / hostname
    logs.mkdir()
    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        environment = os.environ | {
            "HOME": directory, "XDG_CONFIG_HOME": directory,
            "XDG_CACHE_HOME": directory, "XDG_RUNTIME_DIR": directory,
            "WAYLAND_DISPLAY": "audit-missing-display",
            "DISPLAY": "", "DBUS_SESSION_BUS_ADDRESS": "unix:path=/audit-missing-bus",
        }
        for name, args in {
            "ghostty": ["+validate-config", "--config-file=" + host["ghostty"]["config"]],
            "fuzzel": ["--check-config", "--config=" + host["fuzzel"]["config"]],
            "zellij": ["--config", host["zellij"]["config"], "setup", "--check"],
        }.items():
            run([host[name]["exe"], *args], environment, logs / (name + ".log"))

        (work / "config.kdl").write_text(Path(host["niri"]["config"]).read_text())
        (work / "host-settings.kdl").write_text(Path(host["niri"]["include"]).read_text())
        run([host["niri"]["exe"], "validate", "--config", work / "config.kdl"],
            environment, logs / "niri.log")

        # These applications parse before connecting to Wayland. Assert that they
        # reach that boundary and report no ignored/invalid configuration entries.
        _, text = run([host["ashell"]["exe"], "-c", host["ashell"]["config"]],
                      environment, logs / "ashell.log", success=False)
        assert "Config file loaded successfully" in text, text
        assert "Unknown configuration field" not in text, text
        assert "Failed to parse config" not in text, text
        assert "Connection(NoCompositor)" in text, text
        invalid = work / "invalid-ashell.toml"
        invalid.write_text(Path(host["ashell"]["config"]).read_text() + "\n[audit_invalid]\nfield = true\n")
        _, text = run([host["ashell"]["exe"], "-c", invalid], environment,
                      logs / "ashell-reject.log", success=False)
        assert "Unknown configuration field" in text, "Ashell parser was not exercised"
        _, text = run([host["hyprlock"]["exe"], "--config", host["hyprlock"]["config"],
                       "--grace", "5", "--display", "audit-missing-display"],
                      environment, logs / "hyprlock.log", success=False)
        assert "Couldn't connect to a wayland compositor" in text, text
        assert "Config has errors" not in text and "Config threw" not in text, text
        invalid = work / "invalid-hyprlock.conf"
        invalid.write_text(Path(host["hyprlock"]["config"]).read_text() + "\ngeneral {\n grace = 5\n}\n")
        _, text = run([host["hyprlock"]["exe"], "--config", invalid,
                       "--display", "audit-missing-display"],
                      environment, logs / "hyprlock-reject.log", success=False)
        assert "Config has errors" in text, "Hyprlock parser was not exercised"

        _, text = run([host["mpv"]["exe"], "--include=" + host["mpv"]["config"],
             "--load-scripts=no", "--vo=null", "--ao=null", "--keep-open=no",
             "--frames=1", "--msg-level=all=warn", "av://lavfi:testsrc=size=16x16:rate=1"],
            environment, logs / "mpv.log")
        assert "Error parsing" not in text, text

        for scheduler, modes in host["scx"]["settings"].get("scheds", {}).items():
            binary = next((Path(p) / "bin" / scheduler for p in host["scx"]["packages"]
                           if (Path(p) / "bin" / scheduler).exists()), None)
            assert binary, f"Missing scheduler binary: {scheduler}"
            for mode, args in modes.items():
                run([binary, *args, "--help"], environment, logs / f"{scheduler}-{mode}.log")
            result, _ = run([binary, "--audit-invalid-arg", "--help"], environment,
                            logs / f"{scheduler}-reject.log", success=False)
            assert result.returncode != 0, "Scheduler help bypassed argument parsing"

        if "bluez" in host:
            schema = bluez_schema(host["bluez"]["source"])
            check_bluez(Path(host["bluez"]["config"]).read_text(), schema)
            try:
                check_bluez("[Policy]\nReconnectInterval=2\n", schema)
            except AssertionError:
                pass
            else:
                raise AssertionError("BlueZ schema accepted an unknown option")
            (logs / "bluez.log").write_text("All configured keys are supported by the pinned BlueZ source.\n")
        if "rtkit" in host:
            run([host["rtkit"]["exe"], *host["rtkit"]["args"], "--help"],
                environment, logs / "rtkit.log")
            result, _ = run([host["rtkit"]["exe"], "--rttime-msec-max=200", "--help"],
                            environment, logs / "rtkit-reject.log", success=False)
            assert result.returncode != 0
        if "wireplumber" in host:
            check_wireplumber(host["wireplumber"])
            (logs / "wireplumber.log").write_text("Bluetooth property scopes, codecs and policy schema are valid.\n")
        if "tuigreet" in host:
            result, _ = run([host["tuigreet"]["exe"], "--config", host["tuigreet"]["config"],
                           "--dump-config"], environment, logs / "tuigreet.log")
            # The dump is stdout; a terminal helper may diagnose missing /dev/tty on stderr.
            dumped = tomllib.loads(result.stdout)
            expected = tomllib.loads(Path(host["tuigreet"]["config"]).read_text())
            assert subset(expected, dumped), "Tuigreet ignored a configured field"

        gtk = ctypes.CDLL(host["gtk2"]["library"])
        gtk.gtk_settings_get_type.restype = ctypes.c_size_t
        gtk.g_type_class_ref.argtypes = [ctypes.c_size_t]
        gtk.g_type_class_ref.restype = ctypes.c_void_p
        gtk.g_object_class_find_property.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
        gtk.g_object_class_find_property.restype = ctypes.c_void_p
        settings = gtk.g_type_class_ref(gtk.gtk_settings_get_type())
        for name in re.findall(r"^\s*(gtk-[\w-]+)\s*=", Path(host["gtk2"]["config"]).read_text(), re.M):
            assert gtk.g_object_class_find_property(settings, name.encode()), f"Unknown GTK2 setting: {name}"

        root = work / "root"
        (root / "etc").mkdir(parents=True)
        groups = {name: gid if gid is not None else i + 2000
                  for i, (name, gid) in enumerate(host["tmpfiles"]["groups"].items())}
        (root / "etc/group").write_text("".join(f"{name}:x:{gid}:\n" for name, gid in groups.items()))
        (root / "etc/passwd").write_text("".join(
            f"{name}:x:{u['uid'] if u['uid'] is not None else i + 2000}:{groups[u['group']]}::/nonexistent:/noshell\n"
            for i, (name, u) in enumerate(host["tmpfiles"]["users"].items())))
        run([manifest["tmpfiles"], "--create", "--dry-run", "--root=" + str(root),
             host["tmpfiles"]["rules"]], environment, logs / "tmpfiles.log")
    print(f"{hostname}: pass-through configuration checks passed", flush=True)
