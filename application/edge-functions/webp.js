"use strict";

// Lambda@Edge origin-response bodies cannot exceed 1 MB, including headers.
const MAX_BODY_BYTES = 1000 * 1000;

function planConversion(input) {
  const contentType = (input.contentType || "").toLowerCase();
  const accept = (input.accept || "").toLowerCase();
  const bodyByteLength = input.bodyByteLength || 0;
  if (!contentType.startsWith("image/")) {
    return { action: "passthrough", reason: "not-image" };
  }
  if (contentType.includes("webp")) {
    return { action: "passthrough", reason: "already-webp" };
  }
  if (!accept.includes("image/webp")) {
    return { action: "passthrough", reason: "client-does-not-accept-webp" };
  }
  if (bodyByteLength >= MAX_BODY_BYTES) {
    return { action: "passthrough", reason: "exceeds-origin-response-limit" };
  }
  return { action: "convert", reason: "accepted" };
}

function header(response, name, value) {
  response.headers = response.headers || {};
  response.headers[name.toLowerCase()] = [{ key: name, value: value }];
}

async function maybeConvert(response, input, encoder) {
  const plan = planConversion(input);
  if (plan.action !== "convert") {
    header(response, "X-CloudCart-WebP", plan.reason);
    return response;
  }
  const encoded = Buffer.from(await encoder(input.body || Buffer.alloc(0)));
  if (encoded.length >= MAX_BODY_BYTES) {
    header(response, "X-CloudCart-WebP", "exceeds-origin-response-limit");
    return response;
  }
  response.body = encoded.toString("base64");
  response.bodyEncoding = "base64";
  header(response, "Content-Type", "image/webp");
  header(response, "X-CloudCart-WebP", "converted");
  return response;
}

module.exports = { MAX_BODY_BYTES, planConversion, maybeConvert };
