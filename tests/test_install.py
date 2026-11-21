"""Installer regressions (2026-09-11); all writes stay in temporary fixtures."""

import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import time
import unittest


REPO = Path(__file__).resolve().parents[1]
SKILLS = (
    "mx-doctrine", "mx-flow", "mx-brainstorm", "mx-team-review",
    "mx-review-triage", "mx-commit", "mx-pr",
)

# Stands in for GitHub: the ref list request gets $MX_REMOTE_REFS, any -o
# download gets $MX_REMOTE_ARCHIVE, and MX_CURL_OFFLINE fails every call.
CURL_STUB = r"""#!/bin/bash
echo "$*" >> "$MX_CURL_LOG"
[[ -z "${MX_CURL_OFFLINE:-}" ]] || exit 6
out="" url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) out=$2; shift ;;
    http*) url=$1 ;;
  esac
  shift
done
if [[ "$url" == *"/info/refs?"* ]]; then cat "$MX_REMOTE_REFS"; exit 0; fi
[[ -n "$out" ]] || exit 22
cp "$MX_REMOTE_ARCHIVE" "$out"
"""


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="mx-install-test-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.target = self.base / "target"
        self.source = self.base / "source"
        self.target.mkdir()
        self.source.mkdir()
        self.env = dict(os.environ, MX_INSTALL_TEST_ROOT=str(self.target))
        # Redirect only the copied installer's filesystem root, never HOME itself.
        script = (REPO / "install.sh").read_text().replace(
            "$HOME", "$MX_INSTALL_TEST_ROOT"
        )
        (self.source / "install.sh").write_text(script)
        for skill in SKILLS:
            self.write(self.source / skill / "SKILL.md", "new skill\n")
            self.write(self.source / skill / "README.md", "new readme\n")
            self.write(self.source / skill / "references/config.md", "upstream\n")

    def write(self, path, content):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def install(self, *args, success=True):
        result = subprocess.run(
            ["/bin/bash", str(self.source / "install.sh"), *args],
            env=self.env, text=True, capture_output=True,
        )
        output = result.stdout + result.stderr
        if success:
            self.assertEqual(result.returncode, 0, output)
        else:
            self.assertNotEqual(result.returncode, 0, output)
        return result

    def canonical(self, skill="mx-pr"):
        return self.target / ".agents/skills" / skill

    def agent(self, agent=".codex", skill="mx-pr"):
        return self.target / agent / "skills" / skill

    def record_legacy(self, root, reference="upstream\n", skill="mx-pr"):
        content = f"{skill}\troot\t{root}\n"
        content += f"{skill}\treferences/config.md\t{hashlib.sha256(reference.encode()).hexdigest()}\n"
        self.write(self.target / ".mx/.mx-harness.lock", content)

    def prepare_remote(self, top="mx-harness-main", skill_text="remote version\n",
                       installer=None, commit=None):
        """Serve the source tree as a GitHub archive; `commit` goes in its pax header."""
        remote = self.base / "remote" / top
        shutil.copytree(self.source, remote)
        self.write(remote / "mx-pr/SKILL.md", skill_text)
        if installer is not None:
            self.write(remote / "install.sh", installer)
        archive = self.base / f"{top}.tgz"
        pax = {"format": tarfile.PAX_FORMAT, "pax_headers": {"comment": commit}} if commit else {}
        with tarfile.open(archive, "w:gz", **pax) as tar:
            tar.add(remote, arcname=top)
        self.curl_log = self.base / "curl.log"
        stub = self.write(self.base / "bin/curl", CURL_STUB)
        stub.chmod(0o755)
        if str(stub.parent) not in self.env["PATH"].split(os.pathsep):
            self.env["PATH"] = str(stub.parent) + os.pathsep + self.env["PATH"]
        self.env["MX_REMOTE_ARCHIVE"] = str(archive)
        self.env["MX_CURL_LOG"] = str(self.curl_log)

    def lock_meta(self, key):
        for line in (self.target / ".mx/.mx-harness.lock").read_text().splitlines():
            parts = line.split("\t")
            if parts[:2] == ["_meta", key]:
                return parts[2]
        return None

    def git(self, *args):
        subprocess.run(
            ["git", "-C", str(self.source), "-c", "user.name=t", "-c", "user.email=t@t",
             "-c", "commit.gpgsign=false", "-c", "tag.gpgsign=false", *args],
            check=True, capture_output=True,
        )

    def test_ref_installs_tagged_archive_and_records_version(self):
        self.prepare_remote(top="mx-harness-1.2.3")
        self.install("--ref", "v1.2.3", "mx-pr")
        self.assertEqual((self.canonical() / "SKILL.md").read_text(), "remote version\n")
        self.assertIn("/archive/refs/tags/v1.2.3.tar.gz", self.curl_log.read_text())
        self.assertEqual(self.lock_meta("version"), "v1.2.3")

    def test_ref_accepts_equals_form(self):
        self.prepare_remote(top="mx-harness-1.2.3")
        self.install("--ref=v1.2.3", "mx-pr")
        self.assertEqual(self.lock_meta("version"), "v1.2.3")

    def test_ref_rejects_non_semver_value_before_fetching(self):
        self.prepare_remote()
        for ref in ("main", "v1.2", "v1.2.3;rm", ""):
            with self.subTest(ref=ref):
                result = self.install("--ref", ref, "mx-pr", success=False)
                self.assertIn("vX.Y.Z", result.stderr)
        self.install("--ref", success=False)
        self.assertFalse(self.curl_log.exists())
        self.assertFalse(self.canonical().exists())

    def test_remote_main_records_main_version(self):
        self.prepare_remote()
        self.install("--remote", "mx-pr")
        self.assertEqual(self.lock_meta("version"), "main")

    def test_tagged_checkout_records_tag_and_dirty_state(self):
        self.git("init", "-q")
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "init")
        self.git("tag", "v0.1.0")
        self.install("mx-pr")
        self.assertEqual(self.lock_meta("version"), "v0.1.0")
        self.write(self.source / "mx-pr/SKILL.md", "edited\n")
        self.install("mx-pr")
        self.assertEqual(self.lock_meta("version"), "v0.1.0-dirty")

    def test_untagged_tree_records_unknown_version(self):
        self.install("mx-pr")
        self.assertEqual(self.lock_meta("version"), "unknown")

    def test_parent_directory_alias_keeps_canonical_readable(self):
        self.canonical().parent.mkdir(parents=True)
        self.agent().parent.parent.mkdir(parents=True)
        self.agent().parent.symlink_to(self.canonical().parent, target_is_directory=True)
        self.install("mx-pr")
        self.assertTrue((self.agent() / "SKILL.md").is_file(), "skill link became unreadable")
        self.assertEqual((self.agent() / "SKILL.md").read_text(), "new skill\n")
        self.assertFalse(self.canonical().is_symlink())

    def test_dangling_canonical_is_repaired_before_migration(self):
        self.write(self.agent() / "SKILL.md", "old skill\n")
        self.canonical().parent.mkdir(parents=True)
        self.canonical().symlink_to(self.base / "missing-checkout", target_is_directory=True)
        self.install("mx-pr")
        self.assertTrue((self.agent() / "SKILL.md").is_file())
        self.assertEqual((self.agent() / "SKILL.md").read_text(), "new skill\n")

    def test_custom_reference_from_non_seed_stays_active_after_updates(self):
        self.write(self.agent(".claude") / "references/config.md", "upstream\n")
        self.write(self.agent() / "references/config.md", "custom\n")
        self.record_legacy(self.agent(".claude"))
        self.install("mx-pr")
        self.assertEqual((self.agent() / "references/config.md").read_text(), "custom\n")
        self.write(self.source / "mx-pr/references/config.md", "upstream v2\n")
        self.install("mx-pr")
        for agent in (".claude", ".codex"):
            self.assertEqual((self.agent(agent) / "references/config.md").read_text(), "custom\n")

    def test_legacy_xdg_and_custom_roots_keep_receiving_updates(self):
        for location in (".config/claude/skills/mx-pr", "custom/skills/mx-pr"):
            with self.subTest(location=location):
                root = self.target / location
                self.write(root / "SKILL.md", "old skill\n")
                self.record_legacy(root)
                self.install("mx-pr")
                self.assertEqual((root / "SKILL.md").read_text(), "new skill\n")
                self.assertTrue(root.is_symlink())

    def test_failed_prune_retains_tracking_and_can_be_retried(self):
        retired = self.canonical("mx-retired")
        self.write(retired / "SKILL.md", "retired\n")
        link = self.agent(skill="mx-retired")
        link.parent.mkdir(parents=True)
        link.symlink_to(retired, target_is_directory=True)
        self.record_legacy(retired, skill="mx-retired")
        stub = self.write(self.base / "bin/rm", '#!/bin/bash\nfor arg in "$@"; do\n'
                          '  if [[ "$arg" == "$MX_FAIL_PATH" ]]; then exit 1; fi\n'
                          'done\nexec /bin/rm "$@"\n')
        stub.chmod(0o755)
        self.env["PATH"] = str(stub.parent) + os.pathsep + self.env["PATH"]
        self.env["MX_FAIL_PATH"] = str(link)
        self.install("mx-pr", "--prune", success=False)
        self.assertTrue((link / "SKILL.md").is_file())
        lock = self.target / ".mx/.mx-harness.lock"
        self.assertIn("mx-retired\troot\t", lock.read_text())
        self.env["MX_FAIL_PATH"] = ""
        self.install("mx-pr", "--prune")
        self.assertFalse(link.is_symlink())
        self.assertNotIn("mx-retired\t", lock.read_text())

    def test_development_leaf_links_update_both_agents_without_editing_checkout(self):
        dev = self.base / "checkout/mx-pr"
        self.write(dev / "SKILL.md", "checkout version\n")
        self.agent(".claude").parent.mkdir(parents=True)
        self.agent(".claude").symlink_to(dev, target_is_directory=True)
        self.agent().parent.mkdir(parents=True)
        self.install("mx-pr")
        for agent in (".claude", ".codex"):
            self.assertEqual((self.agent(agent) / "SKILL.md").read_text(), "new skill\n")
        self.assertEqual((dev / "SKILL.md").read_text(), "checkout version\n")
        backups = list((self.target / ".mx/backups").rglob("claude_skills_mx-pr"))
        self.assertTrue(any(path.is_symlink() and path.resolve() == dev.resolve() for path in backups))

    def test_canonical_link_to_legacy_directory_updates_without_a_cycle(self):
        self.write(self.agent() / "SKILL.md", "old skill\n")
        self.canonical().parent.mkdir(parents=True)
        self.canonical().symlink_to(self.agent(), target_is_directory=True)
        self.install("mx-pr")
        self.assertEqual((self.agent() / "SKILL.md").read_text(), "new skill\n")
        self.assertFalse(self.canonical().is_symlink())

    def test_foreign_parent_alias_fails_before_editing_checkout(self):
        dev = self.base / "checkout/skills"
        self.write(dev / "mx-pr/SKILL.md", "checkout version\n")
        self.agent(".claude").parent.parent.mkdir(parents=True)
        self.agent(".claude").parent.symlink_to(dev, target_is_directory=True)
        self.install("mx-pr", success=False)
        self.assertEqual((dev / "mx-pr/SKILL.md").read_text(), "checkout version\n")
        self.assertFalse(self.canonical().exists())

    def test_source_itself_is_never_migrated_from_custom_lock_root(self):
        self.record_legacy(self.source / "mx-pr")
        self.install("mx-pr", success=False)
        self.assertFalse((self.source / "mx-pr").is_symlink())
        self.assertFalse(self.canonical().exists())

    def test_nested_reference_symlink_does_not_write_to_external_target(self):
        dev = self.base / "checkout/references"
        self.write(dev / "config.md", "upstream\n")
        self.write(self.canonical() / "SKILL.md", "old skill\n")
        (self.canonical() / "references").symlink_to(dev, target_is_directory=True)
        self.record_legacy(self.canonical())
        self.write(self.source / "mx-pr/references/config.md", "upstream v2\n")
        self.install("mx-pr")
        self.assertEqual((dev / "config.md").read_text(), "upstream\n")
        self.assertEqual((self.canonical() / "references/config.md").read_text(), "upstream v2\n")

    def test_conflicting_customizations_fail_without_changing_installations_or_lock(self):
        self.write(self.agent(".claude") / "references/config.md", "claude custom\n")
        self.write(self.agent() / "references/config.md", "codex custom\n")
        self.record_legacy(self.agent(".claude"))
        lock = self.target / ".mx/.mx-harness.lock"
        before = lock.read_text()
        result = self.install("mx-pr", success=False)
        self.assertIn("conflicting local edits", result.stderr)
        self.assertFalse(self.canonical().exists())
        self.assertEqual((self.agent(".claude") / "references/config.md").read_text(), "claude custom\n")
        self.assertEqual((self.agent() / "references/config.md").read_text(), "codex custom\n")
        self.assertEqual(lock.read_text(), before)

    def test_prune_rejects_foreign_parent_before_moving_any_retired_content(self):
        dev = self.base / "checkout/skills"
        self.write(dev / "mx-retired/SKILL.md", "retired checkout\n")
        self.agent(".claude").parent.parent.mkdir(parents=True)
        self.agent(".claude").parent.symlink_to(dev, target_is_directory=True)
        self.record_legacy(self.agent(".claude", "mx-retired"), skill="mx-retired")
        self.install("mx-pr", "--prune", success=False)
        self.assertTrue((dev / "mx-retired").is_dir())
        self.assertIn("mx-retired\troot\t", (self.target / ".mx/.mx-harness.lock").read_text())

    def test_incomplete_reference_scan_fails_before_migration(self):
        self.write(self.canonical() / "SKILL.md", "old canonical\n")
        self.write(self.agent() / "references/private/custom.md", "custom\n")
        real_find = shutil.which("find")
        stub = self.write(self.base / "bin/find", '#!/bin/bash\nfor arg in "$@"; do\n'
                          '  if [[ "$arg" == "$MX_FAIL_PATH" ]]; then exit 1; fi\n'
                          f'done\nexec "{real_find}" "$@"\n')
        stub.chmod(0o755)
        self.env["PATH"] = str(stub.parent) + os.pathsep + self.env["PATH"]
        self.env["MX_FAIL_PATH"] = str(self.agent() / "references")
        self.install("mx-pr", success=False)
        self.assertFalse(self.agent().is_symlink())
        self.assertEqual((self.canonical() / "SKILL.md").read_text(), "old canonical\n")

    def test_prune_removes_canonical_symlink_but_preserves_its_checkout(self):
        dev = self.base / "checkout/mx-retired"
        self.write(dev / "SKILL.md", "checkout\n")
        retired = self.canonical("mx-retired")
        retired.parent.mkdir(parents=True)
        retired.symlink_to(dev, target_is_directory=True)
        self.record_legacy(retired, skill="mx-retired")
        self.install("mx-pr", "--prune")
        self.assertFalse(retired.is_symlink())
        self.assertEqual((dev / "SKILL.md").read_text(), "checkout\n")

    def test_full_install_and_update_refresh_both_agents(self):
        for agent in (".claude", ".codex"):
            self.agent(agent).parent.mkdir(parents=True)
        self.install()
        for skill in SKILLS:
            self.write(self.source / skill / "SKILL.md", "updated skill\n")
        self.install()
        for skill in SKILLS:
            for agent in (".claude", ".codex"):
                entry = self.agent(agent, skill)
                self.assertEqual(entry.resolve(), self.canonical(skill).resolve())
                self.assertEqual((entry / "SKILL.md").read_text(), "updated skill\n")

    def test_remote_update_refreshes_both_agents_and_preserves_local_source(self):
        for agent in (".claude", ".codex"):
            self.agent(agent).parent.mkdir(parents=True)
        self.agent(".claude").symlink_to(self.source / "mx-pr", target_is_directory=True)
        self.prepare_remote()
        self.install("--remote", "mx-pr")
        for agent in (".claude", ".codex"):
            self.assertEqual((self.agent(agent) / "SKILL.md").read_text(), "remote version\n")
        self.assertEqual((self.source / "mx-pr/SKILL.md").read_text(), "new skill\n")

    def test_backup_failure_during_prune_is_reported_and_tracked(self):
        retired = self.canonical("mx-retired")
        self.write(retired / "SKILL.md", "retired\n")
        self.record_legacy(retired, skill="mx-retired")
        self.write(self.target / ".mx/backups", "not a directory\n")
        self.install("mx-pr", "--prune", success=False)
        self.assertEqual((retired / "SKILL.md").read_text(), "retired\n")
        self.assertIn("mx-retired\troot\t", (self.target / ".mx/.mx-harness.lock").read_text())

    def test_missing_skill_entrypoint_leaves_working_installation_unchanged(self):
        self.write(self.agent() / "SKILL.md", "working version\n")
        (self.source / "mx-pr/SKILL.md").unlink()
        self.install("mx-pr", success=False)
        self.assertEqual((self.agent() / "SKILL.md").read_text(), "working version\n")
        self.assertFalse(self.agent().is_symlink())

    def test_remote_update_never_migrates_the_script_checkout(self):
        self.record_legacy(self.source / "mx-pr")
        self.prepare_remote()
        self.install("--remote", "mx-pr", success=False)
        self.assertFalse((self.source / "mx-pr").is_symlink())
        self.assertEqual((self.source / "mx-pr/SKILL.md").read_text(), "new skill\n")
        self.assertFalse(self.canonical().exists())

    # --- install.sh --auto-update ---

    def release(self, tag, installer=None):
        """Serve `tag` the way GitHub does; its mx-pr/SKILL.md reads "<tag> skill"."""
        self.prepare_remote(top=f"mx-harness-{tag[1:]}", skill_text=f"{tag} skill\n",
                            installer=installer, commit=hashlib.sha1(tag.encode()).hexdigest())

    def tags(self, *tags):
        """Serve GitHub's ref list with these annotated tags, each also peeled."""
        refs = "001e# service=git-upload-pack\n0000"
        refs += f"0159{'0' * 40} HEAD\0multi_ack symref=HEAD:refs/heads/main\n"
        for tag in tags:
            refs += f"003f{'1' * 40} refs/tags/{tag}\n0042{'2' * 40} refs/tags/{tag}^{{}}\n"
        path = self.base / "refs"
        path.write_bytes((refs + "0000").encode())
        self.env["MX_REMOTE_REFS"] = str(path)

    def install_release(self, tag):
        self.release(tag)
        self.install("--ref", tag)
        self.assertEqual(self.lock_meta("version"), tag)

    def auto_update(self, **env):
        """Run the installed copy the way every skill does; it must exit 0 silently on stderr."""
        self.curl_log.unlink(missing_ok=True)
        result = subprocess.run(
            ["/bin/bash", str(self.target / ".mx/.mx-harness-install.sh"), "--auto-update"],
            env=dict(self.env, **env), text=True, capture_output=True,
        )
        self.assertEqual((result.returncode, result.stderr), (0, ""), result.stdout)
        return result.stdout

    def curl_calls(self):
        return self.curl_log.read_text().splitlines() if self.curl_log.exists() else []

    def test_auto_update_moves_a_release_install_to_the_newest_tag_of_its_major(self):
        self.install_release("v1.0.0")
        copy = self.target / ".mx/.mx-harness-install.sh"
        self.assertEqual(copy.read_text(), (self.source / "install.sh").read_text())
        self.release("v1.10.0")
        self.tags("v0.9.0", "v1.0.0", "v1.2.0", "v1.10.0", "v1.11.0-rc1", "v2.0.0")
        self.assertEqual(self.auto_update(), "mx-harness updated v1.0.0 -> v1.10.0.\n")
        self.assertEqual(self.lock_meta("version"), "v1.10.0")
        self.assertEqual(self.lock_meta("source"), hashlib.sha1(b"v1.10.0").hexdigest())
        self.assertEqual((self.canonical() / "SKILL.md").read_text(), "v1.10.0 skill\n")
        self.assertFalse((self.target / ".mx/.mx-harness-update.running").exists())

        self.assertEqual(self.auto_update(), "")
        self.assertEqual(len(self.curl_calls()), 1)
        self.assertIn("/info/refs?service=git-upload-pack", self.curl_calls()[0])

    def test_auto_update_skips_silently_when_github_is_unreachable_and_retries(self):
        self.install_release("v1.0.0")
        self.release("v1.1.0")
        self.tags("v1.0.0", "v1.1.0")
        self.assertEqual(self.auto_update(MX_CURL_OFFLINE="1"), "")
        self.assertEqual(self.lock_meta("version"), "v1.0.0")
        self.assertEqual(self.auto_update(), "mx-harness updated v1.0.0 -> v1.1.0.\n")

    def test_auto_update_skips_silently_when_the_release_download_fails_and_retries(self):
        self.install_release("v1.0.0")
        self.tags("v1.0.0", "v1.1.0")
        self.assertEqual(self.auto_update(MX_REMOTE_ARCHIVE=str(self.base / "missing.tgz")), "")
        self.assertEqual(self.lock_meta("version"), "v1.0.0")
        self.release("v1.1.0")
        self.assertEqual(self.auto_update(), "mx-harness updated v1.0.0 -> v1.1.0.\n")

    def test_auto_update_never_downgrades_when_the_installed_tag_is_gone(self):
        self.install_release("v1.2.0")
        self.tags("v1.0.0", "v1.1.0")
        self.assertEqual(self.auto_update(), "")
        self.assertEqual(self.lock_meta("version"), "v1.2.0")
        self.assertEqual(len(self.curl_calls()), 1)

    def test_auto_update_leaves_non_release_installs_and_opt_out_alone(self):
        self.release("v1.1.0")
        self.tags("v1.0.0", "v1.1.0")

        def untouched(label, **env):
            with self.subTest(label):
                self.assertEqual(self.auto_update(**env), "")
                self.assertEqual(self.curl_calls(), [])

        self.install()
        untouched("unknown: untagged working tree")
        self.install("--remote")
        untouched("main")
        self.install("--ref", "v1.0.0")
        for value in ("0", "false", "OFF"):
            untouched(f"turned off with {value}", MX_HARNESS_AUTO_UPDATE=value)
        self.git("init", "-q")
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "release")
        self.git("tag", "v1.0.0")
        self.git("config", "core.abbrev", "no")
        self.install()
        self.assertEqual(self.lock_meta("version"), "v1.0.0")
        untouched("clone on a release tag")

    def test_auto_update_reports_a_failed_install_and_retries_it(self):
        self.install_release("v1.0.0")
        self.release("v1.1.0", installer="#!/bin/bash\necho 'error: broken release' >&2\nexit 3\n")
        self.tags("v1.0.0", "v1.1.0")
        failure = ("mx-harness auto-update to v1.1.0 failed; last installer output:\n"
                   "error: broken release\n")
        self.assertEqual(self.auto_update(), failure)
        self.assertEqual(self.lock_meta("version"), "v1.0.0")
        self.assertFalse((self.target / ".mx/.mx-harness-update.running").exists())
        self.assertEqual(self.auto_update(), failure)

    def test_auto_update_names_each_path_it_moves_to_backups(self):
        (self.target / ".claude").mkdir()
        self.install_release("v1.0.0")
        link = self.agent(".claude")
        dev = self.write(self.base / "dev/mx-pr/SKILL.md", "dev skill\n").parent
        link.unlink()
        link.symlink_to(dev)
        self.release("v1.1.0")
        self.tags("v1.0.0", "v1.1.0")
        updated, moved = self.auto_update().splitlines()
        self.assertEqual(updated, "mx-harness updated v1.0.0 -> v1.1.0.")
        self.assertTrue(moved.startswith(f"  ↳ moved {link} to "), moved)
        self.assertEqual(link.resolve(), self.canonical().resolve())
        self.assertEqual((dev / "SKILL.md").read_text(), "dev skill\n")

    def test_auto_update_leaves_a_running_update_alone_unless_its_mutex_is_stale(self):
        self.install_release("v1.0.0")
        self.release("v1.1.0")
        self.tags("v1.0.0", "v1.1.0")
        running = self.target / ".mx/.mx-harness-update.running"
        running.mkdir()
        self.assertEqual(self.auto_update(), "")
        self.assertEqual(self.lock_meta("version"), "v1.0.0")

        an_hour_ago = time.time() - 3600
        os.utime(running, (an_hour_ago, an_hour_ago))
        self.assertEqual(self.auto_update(), "mx-harness updated v1.0.0 -> v1.1.0.\n")
        self.assertFalse(running.exists())


if __name__ == "__main__":
    unittest.main()
