#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");

const skillName = "pwnhustcollege";
const packageRoot = path.resolve(__dirname, "..");

function usage() {
  console.log(`Usage:
  npx pwnhustcollege-skill install [--path <skill-directory>]

Options:
  --path <dir>  Install directly to this skill directory.
  --help        Show this help message.`);
}

function defaultInstallDir() {
  const codexHome = process.env.CODEX_HOME || path.join(os.homedir(), ".codex");
  return path.join(codexHome, "skills", skillName);
}

function parseArgs(argv) {
  const args = [...argv];
  let target = defaultInstallDir();

  const command = args.shift();
  if (command === "--help" || command === "-h") {
    usage();
    process.exit(0);
  }
  if (command !== "install") {
    usage();
    throw new Error("Missing required command: install");
  }

  while (args.length) {
    const arg = args.shift();
    if (arg === "--help" || arg === "-h") {
      usage();
      process.exit(0);
    }
    if (arg === "--path") {
      const value = args.shift();
      if (!value) {
        throw new Error("--path requires a directory");
      }
      target = path.resolve(value);
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  return target;
}

function copySkillFile(relativePath, targetDir) {
  const source = path.join(packageRoot, relativePath);
  const target = path.join(targetDir, relativePath);
  fs.cpSync(source, target, { recursive: true });
}

function install(targetDir) {
  const required = ["SKILL.md", "scripts", "references"];
  for (const entry of required) {
    if (!fs.existsSync(path.join(packageRoot, entry))) {
      throw new Error(`Package is missing required entry: ${entry}`);
    }
  }

  fs.rmSync(targetDir, { recursive: true, force: true });
  fs.mkdirSync(targetDir, { recursive: true });

  for (const entry of required) {
    copySkillFile(entry, targetDir);
  }

  console.log(`Installed ${skillName} skill to ${targetDir}`);
  console.log("Restart Codex to reload skill metadata.");
}

try {
  install(parseArgs(process.argv.slice(2)));
} catch (error) {
  console.error(`Install failed: ${error.message}`);
  process.exit(1);
}
