"use strict";

// Viewer-request handler for the image distribution.
// It does not choose an origin, a bucket, or a region. CloudFront's origin
// stays the private S3 origin configured on the distribution.
// Transformation query parameters are checked and then removed. No encoder
// is packaged, so those parameters must not become cache-key variants.

const EXTENSIONS = new Set(["jpg", "jpeg", "png", "webp"]);
const WIDTHS = new Set(["64", "128", "256", "512", "1024"]);
const QUALITIES = new Set(["60", "75", "80", "90"]);
const SIGNED = new Set(["Expires", "Signature", "Key-Pair-Id", "Policy"]);
const ORIGIN_OVERRIDE = new Set(["origin", "bucket", "url", "host", "uri"]);
const MAX_URI = 512;
const PRODUCT_PATH = /^\/products\/[a-z0-9][a-z0-9-]{0,63}\/[a-z0-9][a-z0-9._-]{0,63}\/[a-z0-9][a-z0-9._-]{0,80}\.(jpg|jpeg|png|webp)$/;

function safeDecode(value) {
  try {
    return decodeURIComponent(value);
  } catch (error) {
    return null;
  }
}

function unwrap(value) {
  let current = value;
  let layers = 0;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    if (!current.includes("%")) {
      return { value: current, layers };
    }
    const next = safeDecode(current);
    if (next === null) {
      return null;
    }
    if (next === current) {
      return { value: current, layers };
    }
    current = next;
    layers += 1;
  }
  return { value: current, layers };
}

function normalizePath(rawUri) {
  if (typeof rawUri !== "string" || rawUri.length === 0 || rawUri.length > MAX_URI) {
    return { error: "path-length" };
  }
  if (/[\u0000\\]/.test(rawUri) || rawUri.includes("\n") || rawUri.includes("\r")) {
    return { error: "invalid-character" };
  }
  const decoded = unwrap(rawUri);
  if (decoded === null) {
    return { error: "malformed-uri" };
  }
  if (decoded.layers > 1) {
    return { error: "double-encoded" };
  }
  if (decoded.value.includes("\u0000") || decoded.value.includes("\\")) {
    return { error: "null-byte" };
  }
  if (decoded.value.includes("..")) {
    return { error: "traversal" };
  }
  const collapsed = decoded.value.replace(/\/{2,}/g, "/");
  if (!PRODUCT_PATH.test(collapsed)) {
    return { error: "invalid-path" };
  }
  return { path: collapsed };
}

function parseQuery(querystring) {
  const list = [];
  if (!querystring) {
    return { list };
  }
  for (const part of querystring.split("&")) {
    if (!part) {
      continue;
    }
    const index = part.indexOf("=");
    const rawName = index === -1 ? part : part.slice(0, index);
    const rawValue = index === -1 ? "" : part.slice(index + 1);
    const name = unwrap(rawName);
    const value = unwrap(rawValue);
    if (name === null || value === null) {
      return { error: "malformed-query" };
    }
    if (name.layers > 1 || value.layers > 1) {
      return { error: "double-encoded" };
    }
    if (name.value.includes("\u0000") || value.value.includes("\u0000")) {
      return { error: "null-byte" };
    }
    list.push({ name: name.value, value: value.value, raw: part });
  }
  return { list };
}

function inspect(request) {
  const method = String(request.method || "GET").toUpperCase();
  if (method !== "GET" && method !== "HEAD") {
    return { error: "method", status: 405 };
  }
  const path = normalizePath(request.uri || "");
  if (path.error) {
    return { error: path.error, status: 400 };
  }
  const params = parseQuery(request.querystring || "");
  if (params.error) {
    return { error: params.error, status: 400 };
  }
  const signed = [];
  const seen = {};
  for (const param of params.list) {
    const lowered = param.name.toLowerCase();
    if (ORIGIN_OVERRIDE.has(lowered)) {
      return { error: "origin-override", status: 400 };
    }
    if (SIGNED.has(param.name)) {
      if (param.value.includes("..") || param.value.includes("\\")) {
        return { error: "malicious-query", status: 400 };
      }
      signed.push(param.raw);
      continue;
    }
    if (param.name === "w" || param.name === "h" || param.name === "format" || param.name === "q") {
      if (Object.prototype.hasOwnProperty.call(seen, param.name)) {
        return { error: "invalid-size", status: 400 };
      }
      seen[param.name] = param.value;
      continue;
    }
  }
  const hasSize = seen.w !== undefined || seen.h !== undefined;
  if (hasSize && (seen.w === undefined || seen.h === undefined || !WIDTHS.has(seen.w) || !WIDTHS.has(seen.h))) {
    return { error: "invalid-size", status: 400 };
  }
  if (seen.format !== undefined && !EXTENSIONS.has(seen.format)) {
    return { error: "invalid-format", status: 400 };
  }
  if (seen.q !== undefined && !QUALITIES.has(seen.q)) {
    return { error: "invalid-quality", status: 400 };
  }
  return {
    path: path.path,
    originPath: `/public${path.path}`,
    querystring: signed.join("&"),
    transformIgnored: Object.keys(seen).length > 0,
  };
}

function reject(status) {
  return {
    status: String(status),
    statusDescription: status === 405 ? "Method Not Allowed" : "Bad Request",
    headers: {
      "content-type": [{ key: "Content-Type", value: "text/plain; charset=utf-8" }],
      "cache-control": [{ key: "Cache-Control", value: "no-store" }],
      "x-content-type-options": [{ key: "X-Content-Type-Options", value: "nosniff" }],
    },
    body: "Request rejected",
  };
}

function handler(event) {
  const request = event.Records[0].cf.request;
  const result = inspect(request);
  if (result.error) {
    return reject(result.status);
  }
  request.uri = result.originPath;
  request.querystring = result.querystring;
  return request;
}

module.exports = {
  EXTENSIONS,
  WIDTHS,
  QUALITIES,
  inspect,
  handler,
};
