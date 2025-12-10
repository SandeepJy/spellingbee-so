/* eslint-disable object-curly-spacing */
/* eslint-disable indent */
/* eslint-disable max-len */
const functions = require("firebase-functions");
const admin = require("firebase-admin"); // Import Firebase Admin SDK
const { Storage } = require("@google-cloud/storage");

// Initialize Firebase Admin SDK
// This is crucial for verifying Firebase ID tokens.
// It automatically picks up credentials when deployed to Cloud Functions.
admin.initializeApp();

const storage = new Storage(); // Initialize Google Cloud Storage client

// HTTP Cloud Function to serve random words
exports.getRandomWords = functions.https.onRequest(async (req, res) => {
    // --- CORS Configuration ---
    // For a purely native iOS app, CORS headers might not be strictly necessary
    // as CORS is a browser security mechanism. However, if your iOS app uses
    // web views, or if you ever intend to access this API from a web client,
    // you'll need them.
    // For production, replace '*' with your specific web app domains
    // (e.g., 'https://your-web-app.com').
    // If only native iOS app calls this, you can remove this line.
    res.set("Access-Control-Allow-Origin", "*");

    if (req.method === "OPTIONS") {
        // Handle CORS preflight requests
        res.set("Access-Control-Allow-Methods", "GET");
        res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
        res.set("Access-Control-Max-Age", "3600");
        return res.status(204).send("");
    }

    // --- Firebase Authentication ID Token Verification ---
    // 1. Check if the Authorization header is present and in the correct format
    if (!req.headers.authorization ||
        !req.headers.authorization.startsWith("Bearer ")) {
        console.error("No Firebase ID token was passed as a Bearer token in the Authorization header.",
            "Make sure you are sending the token in the format \"Bearer <ID_TOKEN>\"");
        return res.status(403).send("Unauthorized: No ID token provided.");
    }

    const idToken = req.headers.authorization.split("Bearer ")[1];

    try {
        // 2. Verify the ID token using the Firebase Admin SDK
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        console.log("ID Token successfully verified for user:", decodedToken.uid);

        // --- Accessing and Processing the Word List ---
        const bucketName = functions.config().firebase.storageBucket; // Automatically gets your project's default bucket
        const filePath = "Words/words.txt"; // <-- UPDATED PATH!
        const file = storage.bucket(bucketName).file(filePath);

        let wordCount = parseInt(req.query.count) || 1; // Get 'count' from query parameter, default to 1
        if (wordCount < 1) wordCount = 1; // Ensure count is at least 1
        if (wordCount > 100) wordCount = 100; // Cap to prevent excessive resource use

        const data = await file.download(); // Download the file content
        const wordsString = data[0].toString("utf8"); // Convert buffer to string
        // Split by comma, trim whitespace, and filter out any empty strings
        const allWords = wordsString.split(",").map((word) => word.trim()).filter((word) => word.length > 0);

        if (allWords.length === 0) {
            return res.status(500).send("No words found in the file at the specified path.");
        }

        // Select random words
        const randomWords = [];
        for (let i = 0; i < wordCount; i++) {
            const randomIndex = Math.floor(Math.random() * allWords.length);
            randomWords.push(allWords[randomIndex]);
        }

        // Return the selected words as JSON
        return res.status(200).json({ words: randomWords });
    } catch (error) {
        console.error("Error in getRandomWords function:", error);
        // Handle specific Firebase Auth errors
        if (error.code === "auth/id-token-expired" || error.code === "auth/invalid-credential") {
            return res.status(401).send("Unauthorized: Invalid or expired ID token.");
        }
        // Handle other errors
        return res.status(500).send("Internal Server Error: Could not process request.");
    }
});
