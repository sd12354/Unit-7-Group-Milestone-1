#!/usr/bin/env node

/* eslint-disable no-console */
const admin = require("firebase-admin");

function getArg(flag) {
  const index = process.argv.indexOf(flag);
  if (index === -1 || index + 1 >= process.argv.length) return null;
  return process.argv[index + 1];
}

function hasFlag(flag) {
  return process.argv.includes(flag);
}

async function deleteByQuery(db, query) {
  let deleted = 0;
  let snapshot = await query.limit(100).get();
  while (!snapshot.empty) {
    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    deleted += snapshot.size;
    snapshot = await query.limit(100).get();
  }
  return deleted;
}

async function main() {
  const projectId = getArg("--project-id") || process.env.FIREBASE_PROJECT_ID;
  const keyPath = getArg("--service-account") || process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const batchId = getArg("--batch");
  const dryRun = hasFlag("--dry-run");

  if (!projectId) {
    throw new Error("Missing Firebase project id. Pass --project-id or set FIREBASE_PROJECT_ID.");
  }
  if (!keyPath) {
    throw new Error(
      "Missing service account key path. Pass --service-account or set GOOGLE_APPLICATION_CREDENTIALS."
    );
  }

  const serviceAccount = require(keyPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId
  });

  const db = admin.firestore();
  let query = db.collection("sessions").where("demoSeed", "==", true);
  if (batchId) {
    query = query.where("demoBatch", "==", batchId);
  }

  const previewSnapshot = await query.get();
  console.log(`Project: ${projectId}`);
  console.log(`Matching demo sessions: ${previewSnapshot.size}`);
  if (batchId) console.log(`Batch filter: ${batchId}`);

  if (dryRun) {
    console.log("Dry run enabled. No deletes performed.");
    process.exit(0);
  }

  const deleted = await deleteByQuery(db, query);
  console.log(`Deleted demo sessions: ${deleted}`);
}

main().catch((error) => {
  console.error("Clear failed:", error.message);
  process.exit(1);
});
