  const functions = require('firebase-functions');
  const admin = require('firebase-admin');
  admin.initializeApp();

  exports.healthCheck = functions.https.onRequest(async (req, res) => {
    const results = {};

    // Check Firestore
    try {
      await admin.firestore()
        .collection('captionsFileTranscription')
        .limit(1)
        .get();
      results.firestore = 'ok';
    } catch (e) {
      results.firestore = `error: ${e.message}`;
    }

    const allOk = Object.values(results).every(v => v === 'ok');

    res.status(allOk ? 200 : 503).json({
      status: allOk ? 'healthy' : 'degraded',
      timestamp: new Date().toISOString(),
      services: results,
    });
  });
