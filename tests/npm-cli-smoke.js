"use strict";

const assert = require("assert");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const repoRoot = path.resolve(__dirname, "..");
const cliPath = path.join(repoRoot, "bin", "powershell-skills.js");
const pkg = require(path.join(repoRoot, "package.json"));

function runCli(args, options = {}) {
  const result = spawnSync(process.execPath, [cliPath, ...args], {
    cwd: repoRoot,
    encoding: "utf8",
    ...options
  });
  return result;
}

function assertExit(result, expected, label) {
  assert.strictEqual(
    result.status,
    expected,
    `${label} exit code. stdout=${result.stdout} stderr=${result.stderr}`
  );
}

function parseJson(result, label) {
  try {
    return JSON.parse(result.stdout.trim());
  } catch (error) {
    throw new Error(`${label} did not produce JSON. stdout=${result.stdout} stderr=${result.stderr}`);
  }
}

function tempDir(name) {
  return fs.mkdtempSync(path.join(os.tmpdir(), `powershell-skills-${name}-`));
}

function removeDir(dir) {
  if (dir && fs.existsSync(dir)) {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

const tempRoots = [];

try {
  const version = runCli(["--version"]);
  assertExit(version, 0, "--version");
  assert.strictEqual(version.stdout.trim(), pkg.version, "CLI version should match package.json");

  const help = runCli(["--help"]);
  assertExit(help, 0, "--help");
  assert.match(help.stdout, /Usage:/, "help should include usage");

  const doctorCodexHome = tempDir("doctor-codex");
  const doctorClaudeHome = tempDir("doctor-claude");
  tempRoots.push(doctorCodexHome, doctorClaudeHome);
  const doctor = runCli(["doctor", "--json", "--codex-home", doctorCodexHome, "--claude-home", doctorClaudeHome]);
  assertExit(doctor, 0, "doctor --json");
  const doctorData = parseJson(doctor, "doctor --json");
  assert.match(doctorData.status, /^(ok|warn)$/);
  assert.strictEqual(doctorData.package.name, pkg.name);
  assert.strictEqual(doctorData.package.version, pkg.version);
  assert.ok(Array.isArray(doctorData.checks), "doctor checks should be an array");
  assert.ok(doctorData.checks.some((check) => check.id === "package-files" && check.status === "ok"), "doctor should verify package files");

  const codexHome = tempDir("codex-home");
  tempRoots.push(codexHome);
  const codexInstall = runCli(["install", "codex", "--codex-home", codexHome, "--json"]);
  assertExit(codexInstall, 0, "install codex");
  const codexInstallData = parseJson(codexInstall, "install codex");
  assert.strictEqual(codexInstallData.status, "success");
  assert.ok(fs.existsSync(path.join(codexHome, "skills", "powershell-command-runner", "SKILL.md")), "Codex SKILL.md should be installed");

  const claudeHome = tempDir("claude-home");
  tempRoots.push(claudeHome);
  const claudeInstall = runCli(["install", "claude-code", "--claude-home", claudeHome, "--json"]);
  assertExit(claudeInstall, 0, "install claude-code");
  const claudeInstallData = parseJson(claudeInstall, "install claude-code");
  assert.strictEqual(claudeInstallData.status, "success");
  assert.ok(fs.existsSync(path.join(claudeHome, "skills", "powershell-command-runner", "SKILL.md")), "Claude Code SKILL.md should be installed");

  const allCodexHome = tempDir("all-codex-home");
  const allClaudeHome = tempDir("all-claude-home");
  tempRoots.push(allCodexHome, allClaudeHome);
  const allInstall = runCli([
    "install",
    "all",
    "--codex-home",
    allCodexHome,
    "--claude-home",
    allClaudeHome,
    "--json"
  ]);
  assertExit(allInstall, 0, "install all");
  const allInstallData = parseJson(allInstall, "install all");
  assert.strictEqual(allInstallData.status, "success");
  assert.strictEqual(allInstallData.results.length, 2);

  const updateDryRun = runCli(["update", "--dry-run", "--json"]);
  assertExit(updateDryRun, 0, "update --dry-run --json");
  const updateDryRunData = parseJson(updateDryRun, "update --dry-run --json");
  assert.strictEqual(updateDryRunData.status, "dry-run");
  assert.deepStrictEqual(updateDryRunData.npm_command, ["npm", "install", "-g", `${pkg.name}@latest`]);
  assert.deepStrictEqual(updateDryRunData.install_command, ["powershell-skills", "install", "all"]);
} finally {
  for (const dir of tempRoots.reverse()) {
    removeDir(dir);
  }
}

console.log("[OK] npm CLI smoke tests passed");
