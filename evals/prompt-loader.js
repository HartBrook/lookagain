// Loads a markdown command file, strips frontmatter, interpolates
// $ARGUMENTS.* tokens with test-case variables, and prepends a
// meta-instruction so the model describes its plan without executing.

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

  // Replace $ARGUMENTS.<name> with matching arg_<name> variable.
  // Argument names may contain hyphens (e.g. auto-fix, max-passes).
  const interpolated = stripped.replace(
    /\$ARGUMENTS\.([\w-]+)/g,
    (_match, name) => {
      const key = `arg_${name}`;
      if (key in vars) {
        return vars[key];
      }
      return _match; // leave unresolved tokens as-is
    },
  );

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
