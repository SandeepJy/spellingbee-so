/* eslint-disable object-curly-spacing */
/* eslint-disable indent */
/* eslint-disable max-len */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { Storage } = require("@google-cloud/storage");

admin.initializeApp();

const storage = new Storage();

exports.getRandomWords = functions.https.onRequest(async (req, res) => {
    // --- CORS Configuration ---
    res.set("Access-Control-Allow-Origin", "*"); // Tighten for production if only native iOS app calls this

    if (req.method === "OPTIONS") {
        res.set("Access-Control-Allow-Methods", "GET");
        res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
        res.set("Access-Control-Max-Age", "3600");
        return res.status(204).send("");
    }

    // --- Firebase Authentication ID Token Verification ---
    if (!req.headers.authorization || !req.headers.authorization.startsWith("Bearer ")) {
        console.error("No Firebase ID token was passed as a Bearer token in the Authorization header.");
        return res.status(403).send("Unauthorized: No ID token provided.");
    }

    const idToken = req.headers.authorization.split("Bearer ")[1];

    try {
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        console.log("ID Token successfully verified for user:", decodedToken.uid);

        // --- FIX IS HERE ---
        const bucketName = admin.app().options.storageBucket; // Corrected way to get default bucket
        const filePath = "Words/words.txt";
        const file = storage.bucket(bucketName).file(filePath);

        let wordCount = parseInt(req.query.count) || 1;
        if (wordCount < 1) wordCount = 1;
        if (wordCount > 100) wordCount = 100;

        const data = await file.download();
        const wordsString = data[0].toString("utf8");
        const allWords = wordsString.split(",").map((word) => word.trim()).filter((word) => word.length > 0);

        if (allWords.length === 0) {
            return res.status(500).send("No words found in the file at the specified path.");
        }

        const randomWords = [];
        for (let i = 0; i < wordCount; i++) {
            const randomIndex = Math.floor(Math.random() * allWords.length);
            randomWords.push(allWords[randomIndex]);
        }

        return res.status(200).json({ words: randomWords });
    } catch (error) {
        console.error("Error in getRandomWords function:", error);
        if (error.code === "auth/id-token-expired" || error.code === "auth/invalid-credential") {
            return res.status(401).send("Unauthorized: Invalid or expired ID token.");
        }
        return res.status(500).send("Internal Server Error: Could not process request.");
    }
});
