import importlib.util
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest
from urllib.parse import parse_qs, urlsplit

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts/add-vision-edge.py"
INSTALLER = ROOT / "scripts/install-ultraxray.sh"
spec = importlib.util.spec_from_file_location("edge", HELPER)
edge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(edge)
LINK = ("vless://00000000-0000-4000-8000-000000000001@example.com:8443?"
        "encryption=none&type=tcp&security=reality&sni=example.org&fp=chrome&"
        "pbk=TEST_KEY&sid=0123456789abcdef&flow=xtls-rprx-vision&spx=%2Fhello%3Fq%3D1#Original")


class EdgeProfiles(unittest.TestCase):
    def test_preserves_credentials_and_all_other_parameters(self):
        original, updated = urlsplit(LINK), urlsplit(edge.edge_uri(LINK))
        self.assertEqual(original.netloc, updated.netloc)
        before, after = parse_qs(original.query), parse_qs(updated.query)
        self.assertEqual(after.pop("fp"), ["edge"])
        before.pop("fp")
        self.assertEqual(before, after)
        self.assertEqual(edge.edge_uri(edge.edge_uri(LINK)), edge.edge_uri(LINK))

    def test_rejects_wrong_profile_and_ambiguous_input(self):
        for bad in (LINK.replace("type=tcp", "type=xhttp"), LINK.replace("vless://", "https://"),
                    LINK.replace("&sid=0123456789abcdef", ""), LINK + "\n" + LINK,
                    LINK.replace("&fp=chrome", "&fp=chrome&fp=edge")):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                edge.edge_uri(bad)

    def test_cli_is_repeatable_and_does_not_change_source(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            source = directory / "vision.txt"
            source.write_text(LINK)
            output = directory / "new"
            for _ in range(2):
                result = subprocess.run(["python3", str(HELPER), str(source), "--output-dir", str(output)],
                                        text=True, capture_output=True, check=True)
                self.assertEqual(result.stdout.strip(), edge.edge_uri(LINK))
            self.assertEqual(source.read_text(), LINK)
            saved = output / "ultraxray-vless-vision-edge-link.txt"
            self.assertEqual(saved.stat().st_mode & 0o777, 0o600)
            self.assertEqual(saved.read_text().strip(), edge.edge_uri(LINK))

    def test_invalid_input_creates_no_output(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "absent"
            result = subprocess.run(["python3", str(HELPER), "-", "--output-dir", str(output)],
                                    input="invalid", text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(output.exists())

    def test_old_env_can_display_edge_without_modification(self):
        with tempfile.TemporaryDirectory() as temp:
            env = Path(temp) / "old.env"
            content = "VLESS_LINK='example'\nHY2_LINK='example'\nVLESS_VISION_LINK=" + shlex.quote(LINK) + "\n"
            env.write_text(content)
            result = subprocess.run(["bash", str(ROOT / "scripts/generate-links.sh"), str(env)],
                                    capture_output=True, text=True, check=True)
            self.assertIn(edge.edge_uri(LINK), result.stdout)
            self.assertEqual(env.read_text(), content)


class InstallerSafety(unittest.TestCase):
    def shell(self, body):
        # No real root commands: every host inspection used here is overridden.
        setup = f"source {shlex.quote(str(INSTALLER))}\n"
        setup += "systemctl() { return 1; }; docker() { return 0; }; ss() { return 0; };\n"
        return subprocess.run(["bash", "-c", setup + body], capture_output=True, text=True)

    def test_existing_configuration_is_preserved(self):
        with tempfile.TemporaryDirectory() as temp:
            config = Path(temp) / "usr/local/etc/xray/config.json"
            config.parent.mkdir(parents=True)
            config.write_text("DO NOT CHANGE")
            result = self.shell(f"check_existing_installation {shlex.quote(temp)}")
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(config.read_text(), "DO NOT CHANGE")

    def test_existing_service_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            result = self.shell('systemctl() { [[ "$2" == hysteria-server.service ]]; };\n'
                                f"check_existing_installation {shlex.quote(temp)}")
            self.assertNotEqual(result.returncode, 0)

    def test_fresh_host_passes(self):
        with tempfile.TemporaryDirectory() as temp:
            result = self.shell(f"check_existing_installation {shlex.quote(temp)}; check_ports")
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_each_occupied_port_is_rejected(self):
        for port in (443, 8443, 20000):
            result = self.shell(f'ss() {{ if [[ "$*" == *":{port}" ]]; then echo occupied; fi; }}; check_ports')
            self.assertNotEqual(result.returncode, 0, port)

    def test_socket_inspection_error_is_not_treated_as_free_port(self):
        self.assertNotEqual(self.shell("ss() { return 1; }; check_ports").returncode, 0)

    def test_docker_publication_including_ranges_is_rejected(self):
        for published in ("0.0.0.0:443->443/tcp", "[::]:8443->8080/tcp",
                          "0.0.0.0:20000->9999/udp", "0.0.0.0:19000-21000->19000-21000/udp"):
            result = self.shell(f"docker() {{ echo {shlex.quote(published)}; }}; check_ports")
            self.assertNotEqual(result.returncode, 0, published)

    def test_amnezia_on_different_port_is_untouched(self):
        result = self.shell('docker() { [[ "$1" == ps ]] || return 99; echo "0.0.0.0:36157->36157/udp"; }; check_ports')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_active_firewall_gets_only_targeted_additions(self):
        result = self.shell('ufw() { if [[ "$1" == status ]]; then echo "Status: active"; '
                            'else echo "CALL:$*"; fi; }; configure_firewall')
        self.assertEqual(result.returncode, 0)
        calls = [line for line in result.stdout.splitlines() if line.startswith("CALL:")]
        self.assertEqual(calls, ["CALL:allow 443/tcp comment UltraXRay XHTTP",
                                 "CALL:allow 8443/tcp comment UltraXRay Vision and Edge",
                                 "CALL:allow 20000/udp comment UltraXRay Hysteria"])

    def test_inactive_firewall_is_not_enabled_or_modified(self):
        result = self.shell('ufw() { if [[ "$1" == status ]]; then echo "Status: inactive"; '
                            'else echo MUTATION; return 99; fi; }; configure_firewall')
        self.assertEqual(result.returncode, 0)
        self.assertNotIn("MUTATION", result.stdout)

    def test_main_stops_before_package_installation_on_conflict(self):
        result = self.shell('id() { echo 0; }; check_existing_installation() { return 0; }; '
                            'ss() { echo occupied; }; apt-get() { echo MUTATION; }; main')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("MUTATION", result.stdout)


if __name__ == "__main__":
    unittest.main()
