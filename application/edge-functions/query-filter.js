"use strict";

const ALLOWED = new Set(["w", "h", "format", "q"]);
const MALICIOUS = [
  /<\s*script/i,
  /union\s+select/i,
  /\.\.\//,
  /javascript:/i,
  /\0/,
  /%00/i,
  /\b(drop|delete|insert|update)\b/i,
];

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
    const name = decodeURIComponent(index === -1 ? part : part.slice(0, index));
    const value = decodeURIComponent(index === -1 ? "" : part.slice(index + 1));
    params.push({ name, value });
  }
  return params;
}

function filterQueryString(querystring) {
  const kept = [];
  for (const param of parseQuery(querystring)) {
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
