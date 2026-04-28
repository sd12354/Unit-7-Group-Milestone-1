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

function parseHostIds() {
  const raw = getArg("--host-uids") || getArg("--host-uid");
  if (!raw) return [];
  return raw
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
}

function buildAttendeeIds(hostId, extraCount, index) {
  const attendees = [hostId];
  for (let i = 0; i < extraCount; i += 1) {
    attendees.push(`demo-attendee-${index + 1}-${i + 1}`);
  }
  return attendees;
}

function buildHowardSessions(batchId, hostIds) {
  const now = new Date();
  const hostPool = hostIds.length > 0 ? hostIds : ["demo-host-1", "demo-host-2", "demo-host-3"];

  const startOfToday = new Date(now);
  startOfToday.setHours(0, 0, 0, 0);

  const addHours = (h) => new Date(now.getTime() + h * 60 * 60 * 1000);
  const addDaysAtHour = (daysFromToday, hour, minute = 0) => {
    const date = new Date(startOfToday);
    date.setDate(date.getDate() + daysFromToday);
    date.setHours(hour, minute, 0, 0);
    return date;
  };
  const getHost = (i) => hostPool[i % hostPool.length];

  return [
    {
      title: "Intro to Psychology Quiz Review",
      subjectTag: "Psychology",
      startTime: addDaysAtHour(-3, 16, 0),
      locationText: "Frederick Douglass Hall, Room 101",
      description: "Review memory models, conditioning, and sample quiz questions.",
      maxAttendees: 7,
      extraAttendees: 4
    },
    {
      title: "Biology Lab Concepts Check-in",
      subjectTag: "Biology",
      startTime: addDaysAtHour(-2, 14, 30),
      locationText: "Louis Stokes Health Sciences Library, 2nd Floor",
      description: "Quick review of lab notes and report expectations.",
      maxAttendees: 5,
      extraAttendees: 2
    },
    {
      title: "History Discussion Debrief",
      subjectTag: "History",
      startTime: addDaysAtHour(-1, 18, 15),
      locationText: "Founders Library, Reading Room",
      description: "Compare primary-source notes and finalize discussion takeaways.",
      maxAttendees: 6,
      extraAttendees: 5
    },
    {
      title: "Calculus Midterm Prep",
      subjectTag: "Math",
      startTime: addDaysAtHour(0, 17, 30),
      locationText: "Founders Library, Room 302",
      description: "Practice derivatives + optimization with old exam sets.",
      maxAttendees: 8,
      extraAttendees: 3
    },
    {
      title: "Organic Chemistry Reactions Review",
      subjectTag: "Chemistry",
      startTime: addDaysAtHour(1, 13, 0),
      locationText: "Science & Engineering Facility, Study Lounge 2",
      description: "Focus on substitution/elimination and reaction mechanisms.",
      maxAttendees: 6,
      extraAttendees: 1
    },
    {
      title: "Data Structures Whiteboard Session",
      subjectTag: "Computer Science",
      startTime: addDaysAtHour(2, 19, 0),
      locationText: "The Quad, Blackburn Center Atrium",
      description: "Trees, graphs, and runtime drills before quiz week.",
      maxAttendees: 10,
      extraAttendees: 6
    },
    {
      title: "Political Science Current Events Circle",
      subjectTag: "Political Science",
      startTime: addDaysAtHour(4, 15, 30),
      locationText: "Alain Locke Hall, Seminar Room B",
      description: "Break down this week's readings and prep talking points.",
      maxAttendees: 9,
      extraAttendees: 4
    },
    {
      title: "Microeconomics Problem Set Sprint",
      subjectTag: "Economics",
      startTime: addDaysAtHour(5, 11, 0),
      locationText: "School of Business, Room 211",
      description: "Work through elasticity and market equilibrium questions.",
      maxAttendees: 12,
      extraAttendees: 7
    }
  ].map((session, index) => {
    const hostId = getHost(index);
    const attendeeIds = buildAttendeeIds(hostId, session.extraAttendees ?? 0, index);
    return {
      ...session,
      endTime: null,
      hostId,
      attendeeIds,
      cancelled: false,
      cancellationReason: null,
      cancelledAt: null,
      demoSeed: true,
      demoBatch: batchId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
  });
}

async function upsertHostProfiles(db, hostIds) {
  if (hostIds.length === 0) return;
  const writes = hostIds.map((uid, index) => {
    const profile = {
      displayName: `Demo Host ${index + 1}`,
      bio: "Howard study group host",
      photoURL: null
    };
    return db.collection("users").doc(uid).set(profile, { merge: true });
  });
  await Promise.all(writes);
}

async function main() {
  const projectId = getArg("--project-id") || process.env.FIREBASE_PROJECT_ID;
  const keyPath = getArg("--service-account") || process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const hostIds = parseHostIds();
  const batchId = getArg("--batch") || `demo-${new Date().toISOString().slice(0, 10)}`;
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
  const sessions = buildHowardSessions(batchId, hostIds);

  console.log(`Project: ${projectId}`);
  console.log(`Batch: ${batchId}`);
  console.log(`Sessions to create: ${sessions.length}`);
  if (hostIds.length > 0) {
    console.log(`Host UIDs: ${hostIds.join(", ")}`);
  } else {
    console.log("Host UIDs: using demo-host-1..3");
  }

  if (dryRun) {
    console.log("Dry run enabled. No writes performed.");
    process.exit(0);
  }

  await upsertHostProfiles(db, hostIds);

  const writeBatch = db.batch();
  sessions.forEach((session) => {
    const ref = db.collection("sessions").doc();
    writeBatch.set(ref, session);
  });
  await writeBatch.commit();

  console.log("Demo sessions seeded successfully.");
  console.log("Tip: run clear script with same --batch to remove this seed.");
}

main().catch((error) => {
  console.error("Seed failed:", error.message);
  process.exit(1);
});
