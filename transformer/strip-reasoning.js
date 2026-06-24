// Strips the `reasoning` field (and Anthropic `thinking`) from the outgoing
// request body. NVIDIA NIM's OpenAI-compatible endpoint rejects `reasoning`
// with: 400 "Unsupported parameter(s): `reasoning`".
//
// Registered via ~/.claude-code-router/config.json -> transformers[].path
// and applied per-provider via Providers[].transformer.use = ["strip-reasoning"].
module.exports = class StripReasoning {
  name = "strip-reasoning";

  transformRequestIn(request) {
    if (request && typeof request === "object") {
      delete request.reasoning;
      delete request.thinking;
    }
    return request;
  }
};
