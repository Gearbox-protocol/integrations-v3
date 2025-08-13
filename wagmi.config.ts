import { readdirSync, readFileSync } from "node:fs";
import { basename, join, relative } from "node:path";

import { defineConfig } from "@wagmi/cli";
import { foundry } from "@wagmi/cli/plugins";

interface JsonFile {
  abi: any[];
  [key: string]: any;
}

const ARTIFACTS_DIR = "out";
const CONTRACTS_DIR = "contracts";
const CONTRACTS_SUBDIRS = ["adapters", "helpers", "interfaces"];

function filterArtifacts(): string[] {
  const result: string[] = [];
  const uniqJsons = new Set<string>();
  const solFiles = listSolFiles();

  try {
    const entries = readdirSync(ARTIFACTS_DIR, {
      withFileTypes: true,
      recursive: true,
    });

    for (const entry of entries) {
      if (entry.isFile() && entry.name.endsWith(".json")) {
        const fullPath = join(entry.parentPath, entry.name);
        const relPath = relative(ARTIFACTS_DIR, fullPath);
        const filename = basename(fullPath);
        if (
          !uniqJsons.has(filename) &&
          shouldInclude(solFiles, fullPath, relPath)
        ) {
          uniqJsons.add(filename);
          result.push(relPath);
        }
      }
    }
  } catch (e) {
    console.error(e);
  }

  return result;
}

function shouldInclude(
  solFiles: string[],
  fullPath: string,
  relativePath: string,
): boolean {
  const blocklist = [
    /abstract|mock|test|harness|live|deployer|build\-info/i,
    /^Std/,
  ];
  try {
    // only include artifacts for sol files within the contracts
    if (!solFiles.some(f => relativePath.includes(f))) {
      return false;
    }

    for (const item of blocklist) {
      if (item.test(relativePath)) {
        return false;
      }
    }

    // filter out artifacts that do not contain abi
    const content = readFileSync(fullPath, "utf-8");
    const data: JsonFile = JSON.parse(content);
    return data.abi && Array.isArray(data.abi) && data.abi.length > 0;
  } catch (e) {
    console.error(`error processing file ${relativePath}: ${e}`);
    return false;
  }
}

function listSolFiles(): string[] {
  const result: string[] = [];
  for (const subdir of CONTRACTS_SUBDIRS) {
    const entries = readdirSync(join(CONTRACTS_DIR, subdir), {
      withFileTypes: true,
      recursive: true,
    });
    result.push(
      ...entries
        .filter(entry => entry.isFile() && entry.name.endsWith(".sol"))
        .map(e => e.name),
    );
  }
  return result;
}

export default defineConfig({
  out: "src/generated/index.ts",
  plugins: [
    foundry({
      project: ".",
      artifacts: ARTIFACTS_DIR,
      include: filterArtifacts(),
      exclude: [
        "**/IZapper.sol/**",
        "**/IERC20ZapperDeposits.sol/**",
        "**/IETHZapperDeposits.sol/**",
      ],
      forge: {
        clean: false,
        build: false,
        rebuild: false,
      },
    }),
  ],
});
