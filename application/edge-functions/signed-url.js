"use strict";

const crypto = require("crypto");

const MAX_TTL_SECONDS = 300;

function cloudfrontSafe(value) {
  return value.replace(/\+/g, "-").replace(/=/g, "_").replace(/\//g, "~");
}

function restoreBase64(value) {
  const pad = value.length % 4 === 0 ? "" : "=".repeat(4 - (value.length % 4));
  return value.replace(/-/g, "+").replace(/_/g, "=").replace(/~/g, "/") + pad;
}

function cannedPolicy(resource, expiresEpoch) {
  return JSON.stringify({
    Statement: [
      {
        Resource: resource,
        Condition: { DateLessThan: { "AWS:EpochTime": expiresEpoch } },
      },
    ],
  });
}

function signUrl(options) {
  const ttl = options.expiresEpoch - options.issuedEpoch;
  if (ttl < 1 || ttl > MAX_TTL_SECONDS) {
    throw new Error("signed URL lifetime must be between 1 and 300 seconds");
  }
  const policy = cannedPolicy(options.url, options.expiresEpoch);
  const signer = crypto.createSign("RSA-SHA1");
  signer.update(policy);
  const signature = cloudfrontSafe(signer.sign(options.privateKeyPem, "base64"));
  const signed = `${options.url}?Expires=${options.expiresEpoch}&Signature=${signature}&Key-Pair-Id=${encodeURIComponent(options.keyPairId)}`;
  return { url: signed, policy };
}

function verifyUrl(url, publicKeyPem, nowEpoch) {
  const parsed = new URL(url);
  const expires = Number(parsed.searchParams.get("Expires"));
  const signature = parsed.searchParams.get("Signature");
  const resource = `${parsed.origin}${parsed.pathname}`;
  const policy = cannedPolicy(resource, expires);
  const verifier = crypto.createVerify("RSA-SHA1");
  verifier.update(policy);
  const signatureOk = verifier.verify(publicKeyPem, Buffer.from(restoreBase64(signature), "base64"));
  const expired = nowEpoch >= expires;
  return { signatureOk, expired, acceptable: signatureOk && !expired };
}

module.exports = { MAX_TTL_SECONDS, signUrl, verifyUrl };
