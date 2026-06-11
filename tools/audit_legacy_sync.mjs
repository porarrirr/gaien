#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import process from "node:process";

const projectId = process.env.FIREBASE_PROJECT_ID ?? await projectFromFirebaseConfig();
const token = process.env.GOOGLE_OAUTH_ACCESS_TOKEN ?? accessTokenFromGcloud();
const endpoint = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`;

const response = await fetch(endpoint, {
  method: "POST",
  headers: {
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    structuredQuery: {
      from: [{ collectionId: "sync", allDescendants: true }],
    },
  }),
});

if (!response.ok) {
  throw new Error(`Firestore query failed: ${response.status} ${await response.text()}`);
}

const rows = await response.json();
const legacyUsers = [];
for (const row of rows) {
  const document = row.document;
  if (!document?.name.endsWith("/sync/default")) continue;

  const fields = document.fields ?? {};
  const hasPayload = typeof fields.payload?.stringValue === "string";
  const format = fields.format?.stringValue ?? null;
  const chunkCount = Number(fields.chunkCount?.integerValue ?? 0);
  if (!hasPayload && format !== "chunked-v2") continue;

  const match = document.name.match(/\/documents\/users\/([^/]+)\/sync\/default$/);
  legacyUsers.push({
    userId: match?.[1] ?? "<unknown>",
    generation: hasPayload ? "payload-v1" : "chunked-v2",
    chunkCount,
    updateTime: document.updateTime ?? null,
  });
}

legacyUsers.sort((left, right) => left.userId.localeCompare(right.userId));
console.log(JSON.stringify({
  projectId,
  auditedAt: new Date().toISOString(),
  legacyUserCount: legacyUsers.length,
  users: legacyUsers,
}, null, 2));

async function projectFromFirebaseConfig() {
  const config = JSON.parse(await readFile(new URL("../.firebaserc", import.meta.url), "utf8"));
  const project = config.projects?.default;
  if (!project) {
    throw new Error("Set FIREBASE_PROJECT_ID or configure projects.default in .firebaserc");
  }
  return project;
}

function accessTokenFromGcloud() {
  try {
    return execFileSync(
      "gcloud",
      ["auth", "application-default", "print-access-token"],
      { encoding: "utf8" },
    ).trim();
  } catch {
    throw new Error(
      "Set GOOGLE_OAUTH_ACCESS_TOKEN or run: gcloud auth application-default login",
    );
  }
}
