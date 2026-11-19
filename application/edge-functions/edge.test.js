"use strict";

const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const test = require("node:test");
const cache = require("./cache-headers");
const filter = require("./query-filter");
const images = require("./image-request");
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

function imageEvent(uri, querystring, method) {
  return {
    Records: [{
      cf: {
        request: {
          method: method || "GET",
          uri,
          querystring: querystring || "",
        },
      },
    }],
  };
}

test("image handler accepts jpg, png, and webp product paths and prefixes the public key", () => {
  for (const uri of [
    "/products/hat/v1/front.jpg",
    "/products/hat/v1/front.jpeg",
    "/products/hat/v1/front.png",
    "/products/sku-1/abc123/front.webp",
  ]) {
    const result = images.inspect({ method: "GET", uri, querystring: "" });
    assert.equal(result.error, undefined);
    assert.equal(result.originPath, `/public${uri}`);
  }
});

test("image handler accepts a versioned path and strips a valid transform so it cannot split the cache", () => {
  const event = imageEvent(
    "/products/hat/v1/front.jpg",
    "w=256&h=256&format=webp&q=80&utm_source=ad",
  );
  const request = images.handler(event);
  assert.equal(request.uri, "/public/products/hat/v1/front.jpg");
  assert.equal(request.querystring, "");
});

test("image handler keeps CloudFront signed parameters and still rewrites only the object key", () => {
  const request = images.handler(imageEvent(
    "/products/hat/v1/front.png",
    "Expires=1700000120&Signature=abc~def&Key-Pair-Id=K1",
  ));
  assert.equal(request.uri, "/public/products/hat/v1/front.png");
  assert.match(request.querystring, /Expires=1700000120/);
  assert.equal(request.querystring.includes("bucket"), false);
});

test("image handler rejects traversal, encoded traversal, double encoding, and null bytes", () => {
  const cases = [
    ["/products/../secret.jpg", "400"],
    ["/products/hat/v1/%2e%2e/%2e%2e/secret.jpg", "400"],
    ["/products/hat/v1/%252e%252e/front.jpg", "400"],
    ["/products/hat/v1/front.jpg%00.png", "400"],
    ["/products/hat/v1/front.jpg\u0000", "400"],
  ];
  for (const [uri, status] of cases) {
    const response = images.handler(imageEvent(uri));
    assert.equal(response.status, status, uri);
    assert.equal(response.headers["cache-control"][0].value, "no-store");
  }
});

test("image handler rejects unsupported types, methods, sizes, formats, and origin overrides", () => {
  assert.equal(images.handler(imageEvent("/products/hat/v1/front.svg")).status, "400");
  assert.equal(images.handler(imageEvent("/products/hat/v1/front.avif")).status, "400");
  assert.equal(images.handler(imageEvent("/products/hat/v1/front.jpg", "", "POST")).status, "405");
  assert.equal(images.handler(imageEvent("/products/hat/v1/front.jpg", "w=9999&h=256")).status, "400");
  assert.equal(images.handler(imageEvent("/products/hat/v1/front.jpg", "format=svg")).status, "400");
  assert.equal(images.handler(imageEvent("/products/hat/v1/front.jpg", "origin=https://evil.example")).status, "400");
  assert.equal(images.handler(imageEvent("/products/hat/v1/front.jpg", "bucket=other-bucket")).status, "400");
  assert.equal(images.handler(imageEvent("/products/hat/v1/front.jpg", "w=%E0%A4%A&h=256")).status, "400");
});

test("image handler rejects an oversized path and a backslash", () => {
  const longUri = `/products/hat/v1/${"a".repeat(500)}.jpg`;
  assert.equal(images.handler(imageEvent(longUri)).status, "400");
  assert.equal(images.handler(imageEvent("/products/hat/v1/front\\jpg")).status, "400");
});

test("image handler normalizes a duplicated slash to the same object key", () => {
  const request = images.handler(imageEvent("/products//hat/v1/front.jpg"));
  assert.equal(request.uri, "/public/products/hat/v1/front.jpg");
});

test("versioned image responses are immutable and unversioned images keep the shorter cache", () => {
  const versioned = cache.applyCacheHeaders({ headers: {} }, "/public/products/hat/v1/front.jpg");
  const loose = cache.applyCacheHeaders({ headers: {} }, "/products/hat.png");
  assert.equal(versioned.headers["cache-control"][0].value, "public, max-age=31536000, immutable");
  assert.match(loose.headers["cache-control"][0].value, /s-maxage=604800/);
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
