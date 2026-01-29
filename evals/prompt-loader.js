// Loads a markdown command file, strips frontmatter, replaces the
// $ARGUMENTS placeholder with a key=value string built from test-case
// variables, and prepends a meta-instruction so the model describes
// its plan without executing.

const fs = require("fs");
const path = require("path");

/**
 * @param {object} context
 * @param {Record<string, string>} context.vars
 * @returns {string}
 */
function generatePrompt(context) {
  const { vars } = context;
  const filePath = path.resolve(__dirname, "..", vars.prompt_file);
  const raw = fs.readFileSync(filePath, "utf-8");

  // Strip YAML frontmatter (between opening and closing ---)
  const stripped = raw.replace(/^---\n[\s\S]*?\n---\n/, "");

  // Build a key=value argument string from all vars prefixed with arg_.
  // e.g. { arg_passes: "5", arg_auto-fix: "false" } → "passes=5 auto-fix=false"
  const argPairs = Object.entries(vars)
    .filter(([k]) => k.startsWith("arg_"))
    .map(([k, v]) => `${k.slice(4)}=${v}`)
    .join(" ");

  // Replace the $ARGUMENTS placeholder with the built argument string.
  // This mirrors what Claude Code does at runtime: $ARGUMENTS is replaced
  // with the raw text the user typed after the command name.
  const interpolated = stripped.replace(/\$ARGUMENTS/g, argPairs);

  const meta = [
    "You are analyzing a Claude Code plugin command prompt.",
    "Describe step-by-step what you would do given this command and its configuration.",
    "Be specific about how each configuration value affects your behavior.",
    "Do NOT execute anything — just describe your plan.",
    "",
    "---",
    "",
  ].join("\n");

  return meta + interpolated;
}

module.exports = generatePrompt;
