'use strict';
/**
 * Firebase Admin SDK singleton.
 * Import this everywhere instead of calling initializeApp() directly.
 */
const admin = require('firebase-admin');
const { firebase: cfg } = require('./config');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(require(cfg.serviceAccountPath)),
    projectId: cfg.projectId,
  });
}

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const Timestamp = admin.firestore.Timestamp;
const GeoPoint = admin.firestore.GeoPoint;

module.exports = { admin, db, FieldValue, Timestamp, GeoPoint };
