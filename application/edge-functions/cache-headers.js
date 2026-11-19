"use strict";

const HSTS = "max-age=300; includeSubDomains";

function cacheControlFor(uri) {
  if (/^\/public\/products\/[a-z0-9][a-z0-9-]{0,63}\/[a-z0-9][a-z0-9._-]{0,63}\/[a-z0-9][a-z0-9._-]{0,80}\.(png|jpe?g|webp)$/i.test(uri || "")) {
    return "public, max-age=31536000, immutable";
  }
  if (/\.(png|jpe?g|webp|gif)$/i.test(uri || "")) {
    return "public, max-age=86400, s-maxage=604800";
  }
  return "no-cache";
}

function applyCacheHeaders(response, uri) {
  response.headers = response.headers || {};
  response.headers["cache-control"] = [{ key: "Cache-Control", value: cacheControlFor(uri) }];
  response.headers["strict-transport-security"] = [{ key: "Strict-Transport-Security", value: HSTS }];
  return response;
}

function handler(event) {
  const request = event.Records[0].cf.request;
  const response = event.Records[0].cf.response;
  return applyCacheHeaders(response, request.uri);
}

module.exports = { HSTS, cacheControlFor, applyCacheHeaders, handler };
