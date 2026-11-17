"use strict";

const HSTS = "max-age=300; includeSubDomains";

function cacheControlFor(uri) {
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
