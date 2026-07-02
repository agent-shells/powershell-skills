#!/usr/bin/env node
"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const packageRoot = path.resolve(__dirname, "..");
const pkg = require(path.join(packageRoot, "package.json"));
const packageName = pkg.name;

function usage() {
  return [
    "Usage:",
    "  powershell-skills install [codex|claude-code|all] [options]",
    "  powershell-skills doctor [options]",
    "  powershell-skills update [codex|claude-code|all] [options]",
    "  powershell-skills --version",
    "",
    "Options:",
    "  --json                 Print machine-readable JSON.",
    "  --codex-home <path>    Override Codex home for install/doctor.",
    "  --claude-home <path>   Override Claude Code home for install/doctor.",
    "  --powershell <path>    PowerShell executable to use for installer dispatch.",
    "  --force                Replace an existing unmanaged skill target.",
    "  --dry-run              Show update actions without running npm.",
    "  --skip-install         Update npm package without re-running skill installers.",
    "  --help                 Show help."
  ].join("\n");
}

function normalizeTarget(target) {
  if (!target) return "all";
  const value = String(target).trim().toLowerCase();
  if (value === "claude") return "claude-code";
  return value;
}

function targetList(target) {
  const normalized = normalizeTarget(target);
  if (normalized === "all") return ["codex", "claude-code"];
  if (normalized === "codex" || normalized === "claude-code") return [normalized];
  throw new Error(`Unsupported target: ${target}`);
}

function parseArgs(argv) {
  const options = {
    json: false,
    dryRun: false,
    force: false,
    skipInstall: false,
    codexHome: null,
    claudeHome: null,
    powershell: null
  };
  const positionals = [];

  for (let i = 0; i < argv.length; i++) {
    const token = argv[i];
    if (token === "--json") {
      options.json = true;
    } else if (token === "--dry-run") {
      options.dryRun = true;
    } else if (token === "--force") {
      options.force = true;
    } else if (token === "--skip-install") {
      options.skipInstall = true;
    } else if (token === "--codex-home") {
      i++;
      if (i >= argv.length) throw new Error("--codex-home requires a value");
      options.codexHome = argv[i];
    } else if (token === "--claude-home") {
      i++;
      if (i >= argv.length) throw new Error("--claude-home requires a value");
      options.claudeHome = argv[i];
    } else if (token === "--powershell") {
      i++;
      if (i >= argv.length) throw new Error("--powershell requires a value");
      options.powershell = argv[i];
    } else if (token === "--help" || token === "-h") {
      options.help = true;
    } else if (token.startsWith("--")) {
      throw new Error(`Unknown option: ${token}`);
    } else {
      positionals.push(token);
    }
  }

  return { options, positionals };
}

function writeJson(value) {
  process.stdout.write(`${JSON.stringify(value, null, 2)}\n`);
}

function fail(message, options, exitCode = 1) {
  if (options && options.json) {
    writeJson({ status: "error", reason: message });
  } else {
    process.stderr.write(`${message}\n`);
  }
  process.exit(exitCode);
}

function defaultCodexHome() {
  if (process.env.CODEX_HOME) return path.resolve(process.env.CODEX_HOME);
  return path.join(os.homedir(), ".codex");
}

function defaultClaudeHome() {
  if (process.env.CLAUDE_HOME) return path.resolve(process.env.CLAUDE_HOME);
  return path.join(os.homedir(), ".claude");
}

function defaultPowerShell() {
  if (process.platform === "win32") return "powershell.exe";
  return "pwsh";
}

function npmExecutable() {
  return process.platform === "win32" ? "npm.cmd" : "npm";
}

function quoteCmdArgument(value) {
  const text = String(value);
  if (text.length === 0) return "\"\"";
  if (!/[ \t&()^|<>"]/ .test(text)) return text;
  return `"${text.replace(/"/g, "\"\"")}"`;
}

function shouldUseCmdWrapper(file) {
  const text = String(file);
  return process.platform === "win32" && (text === "powershell-skills" || /\.(cmd|bat)$/i.test(text));
}

function spawnPortable(file, args, cwd, options = {}) {
  let command = file;
  let commandArgs = args;

  if (shouldUseCmdWrapper(file)) {
    command = process.env.ComSpec || "cmd.exe";
    commandArgs = ["/d", "/s", "/c", [file, ...args].map(quoteCmdArgument).join(" ")];
  }

  return spawnSync(command, commandArgs, {
    cwd,
    encoding: "utf8",
    stdio: options.stdio || "pipe",
    windowsHide: true
  });
}

function runCapture(file, args, cwd) {
  return spawnPortable(file, args, cwd);
}

function extractJson(text) {
  const raw = String(text || "").trim();
  if (!raw) throw new Error("Command produced no JSON output");

  try {
    return JSON.parse(raw);
  } catch (_) {
    const first = raw.indexOf("{");
    const last = raw.lastIndexOf("}");
    if (first >= 0 && last > first) {
      return JSON.parse(raw.slice(first, last + 1));
    }
    throw new Error(`Command produced invalid JSON: ${raw}`);
  }
}

function scriptForTarget(target) {
  if (target === "codex") {
    return {
      script: path.join(packageRoot, "scripts", "install-codex-global.ps1"),
      homeFlag: "-CodexHome",
      homeValue: null
    };
  }
  if (target === "claude-code") {
    return {
      script: path.join(packageRoot, "scripts", "install-claude-global.ps1"),
      homeFlag: "-ClaudeHome",
      homeValue: null
    };
  }
  throw new Error(`Unsupported target: ${target}`);
}

function installOne(target, options) {
  const dispatch = scriptForTarget(target);
  if (!fs.existsSync(dispatch.script)) {
    throw new Error(`Missing installer script: ${dispatch.script}`);
  }

  const ps = options.powershell || defaultPowerShell();
  const psArgs = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", dispatch.script];
  if (target === "codex" && options.codexHome) {
    psArgs.push(dispatch.homeFlag, options.codexHome);
  }
  if (target === "claude-code" && options.claudeHome) {
    psArgs.push(dispatch.homeFlag, options.claudeHome);
  }
  if (options.force) {
    psArgs.push("-Force");
  }

  const result = runCapture(ps, psArgs, packageRoot);
  if (result.error) {
    throw new Error(`Failed to start PowerShell installer: ${result.error.message}`);
  }

  let data;
  try {
    data = extractJson(result.stdout);
  } catch (error) {
    throw new Error(`${target} installer JSON parse failed: ${error.message}; stderr=${result.stderr || ""}`);
  }

  if (result.status !== 0 || data.status !== "success") {
    const reason = data.reason || result.stderr || `installer exit code ${result.status}`;
    throw new Error(`${target} install failed: ${reason}`);
  }

  data.target_agent = target;
  return data;
}

function commandInstall(positionals, options) {
  const requestedTarget = positionals[0] || "all";
  let targets;
  try {
    targets = targetList(requestedTarget);
  } catch (error) {
    fail(error.message, options);
  }

  const results = [];
  try {
    for (const target of targets) {
      results.push(installOne(target, options));
    }
  } catch (error) {
    fail(error.message, options);
  }

  if (options.json) {
    if (results.length === 1) {
      writeJson(results[0]);
    } else {
      writeJson({
        status: "success",
        mode: "multi-install",
        results
      });
    }
    return;
  }

  for (const result of results) {
    process.stdout.write(`[OK] installed ${result.target_agent}: ${result.target}\n`);
  }
}

function addCheck(checks, id, status, message, details = {}) {
  checks.push({ id, status, message, ...details });
}

function commandDoctor(options) {
  const checks = [];
  const requiredFiles = [
    "README.md",
    "LICENSE",
    "scripts/install-codex-global.ps1",
    "scripts/install-claude-global.ps1",
    "core/tests/run-smoke.ps1",
    "adapters/codex/powershell-command-runner/SKILL.md",
    "adapters/claude-code/powershell-command-runner/SKILL.md"
  ];

  const missingFiles = requiredFiles.filter((relativePath) => !fs.existsSync(path.join(packageRoot, relativePath)));
  if (missingFiles.length === 0) {
    addCheck(checks, "package-files", "ok", "Required package files are present.");
  } else {
    addCheck(checks, "package-files", "error", "Required package files are missing.", { missing: missingFiles });
  }

  addCheck(checks, "node", "ok", `Node ${process.version} is running.`);

  const npmResult = runCapture(npmExecutable(), ["--version"], packageRoot);
  if (npmResult.error || npmResult.status !== 0) {
    addCheck(checks, "npm", "warn", "npm is not available on PATH.", { reason: npmResult.error ? npmResult.error.message : npmResult.stderr });
  } else {
    addCheck(checks, "npm", "ok", `npm ${npmResult.stdout.trim()} is available.`);
  }

  const ps = options.powershell || defaultPowerShell();
  const psResult = runCapture(ps, ["-NoProfile", "-Command", "($PSVersionTable.PSVersion).ToString()"], packageRoot);
  if (psResult.error || psResult.status !== 0) {
    addCheck(checks, "powershell", "error", `${ps} is not available.`, { reason: psResult.error ? psResult.error.message : psResult.stderr });
  } else {
    addCheck(checks, "powershell", "ok", `${ps} ${psResult.stdout.trim()} is available.`);
  }

  const pwshResult = runCapture("pwsh", ["-NoProfile", "-Command", "($PSVersionTable.PSVersion).ToString()"], packageRoot);
  if (pwshResult.error || pwshResult.status !== 0) {
    addCheck(checks, "pwsh", "warn", "PowerShell 7 (pwsh) is not available on PATH.", { reason: pwshResult.error ? pwshResult.error.message : pwshResult.stderr });
  } else {
    addCheck(checks, "pwsh", "ok", `pwsh ${pwshResult.stdout.trim()} is available.`);
  }

  const codexHome = options.codexHome ? path.resolve(options.codexHome) : defaultCodexHome();
  const codexSkill = path.join(codexHome, "skills", "powershell-command-runner", "SKILL.md");
  if (fs.existsSync(codexSkill)) {
    addCheck(checks, "codex-skill", "ok", "Codex global skill is installed.", { path: codexSkill });
  } else {
    addCheck(checks, "codex-skill", "warn", "Codex global skill is not installed.", { path: codexSkill });
  }

  const claudeHome = options.claudeHome ? path.resolve(options.claudeHome) : defaultClaudeHome();
  const claudeSkill = path.join(claudeHome, "skills", "powershell-command-runner", "SKILL.md");
  if (fs.existsSync(claudeSkill)) {
    addCheck(checks, "claude-code-skill", "ok", "Claude Code global skill is installed.", { path: claudeSkill });
  } else {
    addCheck(checks, "claude-code-skill", "warn", "Claude Code global skill is not installed.", { path: claudeSkill });
  }

  const hasError = checks.some((check) => check.status === "error");
  const hasWarn = checks.some((check) => check.status === "warn");
  const status = hasError ? "error" : hasWarn ? "warn" : "ok";
  const payload = {
    status,
    package: {
      name: packageName,
      version: pkg.version,
      root: packageRoot
    },
    checks
  };

  if (options.json) {
    writeJson(payload);
  } else {
    process.stdout.write(`powershell-skills ${pkg.version}: ${status}\n`);
    for (const check of checks) {
      process.stdout.write(`[${check.status.toUpperCase()}] ${check.id}: ${check.message}\n`);
    }
  }

  if (hasError) process.exit(1);
}

function commandUpdate(positionals, options) {
  const requestedTarget = positionals[0] || "all";
  try {
    targetList(requestedTarget);
  } catch (error) {
    fail(error.message, options);
  }

  const normalizedTarget = normalizeTarget(requestedTarget);
  const npmCommandDisplay = ["npm", "install", "-g", `${packageName}@latest`];
  const installCommandDisplay = ["powershell-skills", "install", normalizedTarget];

  if (options.codexHome) installCommandDisplay.push("--codex-home", options.codexHome);
  if (options.claudeHome) installCommandDisplay.push("--claude-home", options.claudeHome);
  if (options.force) installCommandDisplay.push("--force");

  if (options.dryRun) {
    const payload = {
      status: "dry-run",
      npm_command: npmCommandDisplay,
      install_command: options.skipInstall ? null : installCommandDisplay
    };
    if (options.json) {
      writeJson(payload);
    } else {
      process.stdout.write(`${payload.npm_command.join(" ")}\n`);
      if (payload.install_command) process.stdout.write(`${payload.install_command.join(" ")}\n`);
    }
    return;
  }

  const npmResult = spawnPortable(npmExecutable(), ["install", "-g", `${packageName}@latest`], packageRoot, {
    stdio: options.json ? "pipe" : "inherit"
  });
  if (npmResult.error || npmResult.status !== 0) {
    fail(`npm update failed: ${npmResult.error ? npmResult.error.message : npmResult.stderr || npmResult.status}`, options);
  }

  if (options.skipInstall) {
    if (options.json) writeJson({ status: "success", npm_command: npmCommandDisplay, install_command: null });
    return;
  }

  const installArgs = ["install", normalizedTarget];
  if (options.codexHome) installArgs.push("--codex-home", options.codexHome);
  if (options.claudeHome) installArgs.push("--claude-home", options.claudeHome);
  if (options.force) installArgs.push("--force");
  if (options.json) installArgs.push("--json");

  const installResult = spawnPortable("powershell-skills", installArgs, packageRoot, {
    stdio: options.json ? "pipe" : "inherit"
  });
  if (installResult.error || installResult.status !== 0) {
    fail(`post-update install failed: ${installResult.error ? installResult.error.message : installResult.stderr || installResult.status}`, options);
  }

  if (options.json) {
    writeJson({
      status: "success",
      npm_command: npmCommandDisplay,
      install_command: installCommandDisplay,
      install_result: installResult.stdout ? extractJson(installResult.stdout) : null
    });
  }
}

function main() {
  const argv = process.argv.slice(2);
  if (argv.length === 0) {
    process.stdout.write(`${usage()}\n`);
    return;
  }

  if (argv.length === 1 && (argv[0] === "--version" || argv[0] === "-v" || argv[0] === "version")) {
    process.stdout.write(`${pkg.version}\n`);
    return;
  }
  if (argv.length === 1 && (argv[0] === "--help" || argv[0] === "-h" || argv[0] === "help")) {
    process.stdout.write(`${usage()}\n`);
    return;
  }

  const command = argv[0];
  let parsed;
  try {
    parsed = parseArgs(argv.slice(1));
  } catch (error) {
    fail(error.message, null);
  }

  if (parsed.options.help) {
    process.stdout.write(`${usage()}\n`);
    return;
  }

  if (command === "install") {
    commandInstall(parsed.positionals, parsed.options);
  } else if (command === "doctor") {
    commandDoctor(parsed.options);
  } else if (command === "update") {
    commandUpdate(parsed.positionals, parsed.options);
  } else {
    fail(`Unknown command: ${command}`, parsed.options);
  }
}

main();
