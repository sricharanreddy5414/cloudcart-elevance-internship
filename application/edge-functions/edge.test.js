"use strict";

const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const test = require("node:test");
const cache = require("./cache-headers");
const filter = require("./query-filter");
const signed = require("./signed-url");
const webp = require("./webp");

test("query filter drops unknown parameters and keeps the allow-list", () => {
  const result = filter.filterQueryString("w=200&h=100&utm_source=ad&format=webp");
  assert.equal(result.block, false);
  assert.equal(result.querystring, "w=200&h=100&format=webp");
});

test("query filter blocks a script payload", () => {
  const event = {
    Records: [{ cf: { request: { querystring: "w=%3Cscript%3Ealert(1)%3C%2Fscript%3E" } } }],
  };
  const response = filter.handler(event);
  assert.equal(response.status, "400");
});

test("query filter blocks a traversal value", () => {
  const result = filter.filterQueryString("format=..%2F..%2Fetc");
  assert.equal(result.block, true);
});

test("query filter keeps CloudFront signed URL parameters and drops the rest", () => {
  const result = filter.filterQueryString("w=10&Expires=1700000120&Signature=abc~def&Key-Pair-Id=K1&utm_source=ad");
  assert.equal(result.block, false);
  assert.match(result.querystring, /Expires=1700000120/);
  assert.match(result.querystring, /Signature=abc~def/);
  assert.match(result.querystring, /Key-Pair-Id=K1/);
  assert.equal(result.querystring.includes("utm"), false);
});

test("query filter rejects a broken percent escape", () => {
  const result = filter.filterQueryString("w=%E0%A4%A");
  assert.equal(result.block, true);
  assert.equal(result.reason, "malformed-query");
});

test("cache headers differ for images and pages, and HSTS is not preloaded", () => {
  const image = cache.applyCacheHeaders({ headers: {} }, "/products/hat.png");
  const page = cache.applyCacheHeaders({ headers: {} }, "/admin");
  assert.match(image.headers["cache-control"][0].value, /s-maxage=604800/);
  assert.equal(page.headers["cache-control"][0].value, "no-cache");
  assert.equal(image.headers["strict-transport-security"][0].value, cache.HSTS);
  assert.equal(cache.HSTS.includes("preload"), false);
});

test("webp conversion is refused when the body would exceed the edge limit", async () => {
  const planned = webp.planConversion({
    contentType: "image/jpeg",
    accept: "image/webp",
    bodyByteLength: webp.MAX_BODY_BYTES,
  });
  assert.equal(planned.action, "passthrough");
  const response = await webp.maybeConvert(
    { headers: {} },
    { contentType: "image/jpeg", accept: "image/webp", bodyByteLength: 10, body: Buffer.from("tiny") },
    async () => Buffer.alloc(webp.MAX_BODY_BYTES),
  );
  assert.equal(response.headers["x-cloudcart-webp"][0].value, "exceeds-origin-response-limit");
  assert.equal(response.bodyEncoding, undefined);
});

test("webp conversion replaces a small body when the encoder stays under the limit", async () => {
  const response = await webp.maybeConvert(
    { headers: {} },
    { contentType: "image/png", accept: "image/webp", bodyByteLength: 8, body: Buffer.from("png-data") },
    async () => Buffer.from("webp-bytes"),
  );
  assert.equal(response.headers["content-type"][0].value, "image/webp");
  assert.equal(Buffer.from(response.body, "base64").toString(), "webp-bytes");
});

test("signed URL is acceptable before expiry and rejected after it", () => {
  const { privateKey, publicKey } = crypto.generateKeyPairSync("rsa", { modulusLength: 2048 });
  const privateKeyPem = privateKey.export({ type: "pkcs1", format: "pem" });
  const publicKeyPem = publicKey.export({ type: "pkcs1", format: "pem" });
  const issued = 1_700_000_000;
  const signedUrl = signed.signUrl({
    url: "https://media.example.invalid/products/hat.png",
    issuedEpoch: issued,
    expiresEpoch: issued + 120,
    keyPairId: "KCLOUDCART",
    privateKeyPem,
  });
  const fresh = signed.verifyUrl(signedUrl.url, publicKeyPem, issued + 10);
  const stale = signed.verifyUrl(signedUrl.url, publicKeyPem, issued + 120);
  assert.equal(fresh.acceptable, true);
  assert.equal(stale.acceptable, false);
  assert.equal(stale.expired, true);
});

test("webp origin-response handler does not convert without a packaged encoder", () => {
  const response = webp.handler({
    Records: [{
      cf: {
        request: { headers: { accept: [{ value: "image/webp" }] } },
        response: { headers: { "content-type": [{ value: "image/png" }], "content-length": [{ value: "8" }] } },
      },
    }],
  });
  assert.equal(response.headers["x-cloudcart-webp"][0].value, "encoder-not-in-package");
  assert.equal(response.body, undefined);
});

test("signed URL signer refuses to run as a Lambda@Edge handler", () => {
  const response = signed.handler();
  assert.equal(response.status, "500");
});

test("signed URL refuses a long lifetime", () => {
  const { privateKey } = crypto.generateKeyPairSync("rsa", { modulusLength: 2048 });
  assert.throws(() =>
    signed.signUrl({
      url: "https://media.example.invalid/products/hat.png",
      issuedEpoch: 10,
      expiresEpoch: 10 + signed.MAX_TTL_SECONDS + 1,
      keyPairId: "KCLOUDCART",
      privateKeyPem: privateKey.export({ type: "pkcs1", format: "pem" }),
    }),
  );
});
