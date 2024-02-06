import { execSync } from "child_process";

const directories = [
  ".",
  "luals_addons/vscode-reascript-extension",
  "luals_addons/LLS-Addons",
];

const command = `git submodule update --init --checkout --depth=1`;

for (const directory of directories) {
  try {
    console.info(`Initializing submodules in ${directory}`);

    execSync(command, {
      stdio: "inherit",
      cwd: directory,
    });
  } catch (error) {
    console.error(
      `Failed to initialize submodules in ${directory}: ${error.message}`,
    );
    process.exit(1);
  }
}
