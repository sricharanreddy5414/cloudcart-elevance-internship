"use strict";

const ALLOWED = new Set(["w", "h", "format", "q"]);
const SIGNED = new Set(["Expires", "Signature", "Key-Pair-Id", "Policy"]);
const MALICIOUS = [
  /<\s*script/i,
  /union\s+select/i,
  /\.\.\//,
  /javascript:/i,
  /\0/,
  /%00/i,
  /\b(drop|delete|insert|update)\b/i,
];

function safeDecode(value) {
  try {
    return decodeURIComponent(value);
  } catch (error) {
    return null;
  }
}

function parseQuery(querystring) {
  const params = [];
  if (!querystring) {
    return params;
  }
  for (const part of querystring.split("&")) {
    if (!part) {
      continue;
    }
    const index = part.indexOf("=");
    const rawName = index === -1 ? part : part.slice(0, index);
    const rawValue = index === -1 ? "" : part.slice(index + 1);
    const name = safeDecode(rawName);
    const value = safeDecode(rawValue);
    if (name === null || value === null) {
      params.push({ name: rawName, value: rawValue, malformed: true, raw: part });
      continue;
    }
    params.push({ name, value, malformed: false, raw: part });
  }
  return params;
}

function filterQueryString(querystring) {
  const kept = [];
  for (const param of parseQuery(querystring)) {
    if (param.malformed) {
      return { block: true, reason: "malformed-query", querystring: "" };
    }
    if (SIGNED.has(param.name)) {
      kept.push(param.raw);
      continue;
    }
    if (!ALLOWED.has(param.name)) {
      continue;
    }
    if (MALICIOUS.some((pattern) => pattern.test(param.value) || pattern.test(param.name))) {
      return { block: true, reason: "malicious-query", querystring: "" };
    }
    kept.push(`${encodeURIComponent(param.name)}=${encodeURIComponent(param.value)}`);
  }
  return { block: false, reason: "filtered", querystring: kept.join("&") };
}

function blockedResponse() {
  return {
    status: "400",
    statusDescription: "Bad Request",
    headers: {
      "content-type": [{ key: "Content-Type", value: "text/plain" }],
      "cache-control": [{ key: "Cache-Control", value: "no-store" }],
    },
    body: "Query rejected",
  };
}

function handler(event) {
  const request = event.Records[0].cf.request;
  const result = filterQueryString(request.querystring);
  if (result.block) {
    return blockedResponse();
  }
  request.querystring = result.querystring;
  return request;
}

module.exports = { ALLOWED, filterQueryString, handler };
