/* eslint-disable object-curly-spacing */
/* eslint-disable indent */
/* eslint-disable max-len */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { Storage } = require("@google-cloud/storage");

admin.initializeApp();

const storage = new Storage();

// --- EXISTING FUNCTIONS (unchanged) ---
exports.getRandomWords = functions.https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") {
        res.set("Access-Control-Allow-Methods", "GET");
        res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
        res.set("Access-Control-Max-Age", "3600");
        return res.status(204).send("");
    }
    if (!req.headers.authorization || !req.headers.authorization.startsWith("Bearer ")) {
        return res.status(403).send("Unauthorized: No ID token provided.");
    }
    const idToken = req.headers.authorization.split("Bearer ")[1];
    try {
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        console.log("ID Token verified for user:", decodedToken.uid);
        const bucketName = admin.app().options.storageBucket;
        const filePath = "Words/words.txt";
        const file = storage.bucket(bucketName).file(filePath);
        let wordCount = parseInt(req.query.count) || 1;
        if (wordCount < 1) wordCount = 1;
        if (wordCount > 100) wordCount = 100;
        const data = await file.download();
        const wordsString = data[0].toString("utf8");
        const allWords = wordsString.split(",").map((word) => word.trim()).filter((word) => word.length > 0);
        if (allWords.length === 0) {
            return res.status(500).send("No words found in the file.");
        }
        const randomWords = [];
        for (let i = 0; i < wordCount; i++) {
            const randomIndex = Math.floor(Math.random() * allWords.length);
            randomWords.push(allWords[randomIndex]);
        }
        return res.status(200).json({ words: randomWords });
    } catch (error) {
        console.error("Error in getRandomWords:", error);
        if (error.code === "auth/id-token-expired" || error.code === "auth/invalid-credential") {
            return res.status(401).send("Unauthorized: Invalid or expired ID token.");
        }
        return res.status(500).send("Internal Server Error.");
    }
});

exports.getWordsByLevel = functions.https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") {
        res.set("Access-Control-Allow-Methods", "GET");
        res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
        res.set("Access-Control-Max-Age", "3600");
        return res.status(204).send("");
    }
    if (!req.headers.authorization || !req.headers.authorization.startsWith("Bearer ")) {
        return res.status(403).send("Unauthorized: No ID token provided.");
    }
    const idToken = req.headers.authorization.split("Bearer ")[1];
    try {
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        console.log("ID Token verified for user:", decodedToken.uid);
        const minLevel = parseInt(req.query.minLevel) || 1;
        const maxLevel = parseInt(req.query.maxLevel) || minLevel;
        let wordCount = parseInt(req.query.count) || 1;
        if (wordCount < 1) wordCount = 1;
        if (wordCount > 100) wordCount = 100;
        const bucketName = admin.app().options.storageBucket;
        const filePath = "Words/words.json";
        const file = storage.bucket(bucketName).file(filePath);
        const data = await file.download();
        const jsonString = data[0].toString("utf8");
        const allWords = JSON.parse(jsonString);
        const filteredWords = allWords.filter((w) => w.level >= minLevel && w.level <= maxLevel);
        if (filteredWords.length === 0) {
            return res.status(404).json({ message: `No words found for levels ${minLevel}-${maxLevel}`, words: [] });
        }
        const available = [...filteredWords];
        const actualCount = Math.min(wordCount, available.length);
        const randomWords = [];
        for (let i = 0; i < actualCount; i++) {
            const idx = Math.floor(Math.random() * available.length);
            randomWords.push(available[idx]);
            available.splice(idx, 1);
        }
        return res.status(200).json({
            minLevel,
            maxLevel,
            count: randomWords.length,
            words: randomWords,
        });
    } catch (error) {
        console.error("Error in getWordsByLevel:", error);
        if (error.code === "auth/id-token-expired" || error.code === "auth/invalid-credential") {
            return res.status(401).send("Unauthorized: Invalid or expired ID token.");
        }
        return res.status(500).send("Internal Server Error.");
    }
});

// --- NEW: Get the calling user's leaderboard rank by accuracy ---
//
// Reads all soloProgress documents, computes accuracy for each user
// (totalCorrectWords / totalWordsSpelled * 100), ranks them descending,
// and returns the calling user's position plus total player count.
//
// Query params:  none required
// Response: { rank: 3, totalPlayers: 2203, accuracy: 94.2, username: "BeeMaster" }
exports.getMyRank = functions.https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") {
        res.set("Access-Control-Allow-Methods", "GET");
        res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
        res.set("Access-Control-Max-Age", "3600");
        return res.status(204).send("");
    }

    // Auth
    if (!req.headers.authorization || !req.headers.authorization.startsWith("Bearer ")) {
        return res.status(403).send("Unauthorized");
    }
    const idToken = req.headers.authorization.split("Bearer ")[1];

    try {
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        const uid = decodedToken.uid;

        // Fetch all soloProgress documents in one read
        const db = admin.firestore();
        const snapshot = await db.collection("soloProgress").get();

        if (snapshot.empty) {
            return res.status(200).json({ rank: 1, totalPlayers: 1, accuracy: 0, username: "" });
        }

        // Build ranked list — only include users who have attempted at least one word
        const players = [];
        snapshot.forEach((doc) => {
            const d = doc.data();
            const attempted = d.totalWordsSpelled || 0;
            if (attempted > 0) {
                const accuracy = (d.totalCorrectWords || 0) / attempted * 100;
                players.push({ id: doc.id, accuracy });
            }
        });

        // Sort descending by accuracy
        players.sort((a, b) => b.accuracy - a.accuracy);

        const totalPlayers = players.length;
        const myIndex = players.findIndex((p) => p.id === uid);

        if (myIndex === -1) {
            // User hasn't played yet — place them last
            return res.status(200).json({
                rank: totalPlayers + 1,
                totalPlayers: totalPlayers + 1,
                accuracy: 0,
                username: "",
            });
        }

        const myAccuracy = players[myIndex].accuracy;

        // Fetch username from users collection
        let username = "";
        try {
            const userDoc = await db.collection("users").doc(uid).get();
            if (userDoc.exists) {
                username = userDoc.data().username || userDoc.data().email || "";
            }
        } catch (_) {
            // Non-fatal — username is cosmetic
        }

        return res.status(200).json({
            rank: myIndex + 1,
            totalPlayers,
            accuracy: Math.round(myAccuracy * 10) / 10,
            username,
        });
    } catch (error) {
        console.error("Error in getMyRank:", error);
        if (error.code === "auth/id-token-expired" || error.code === "auth/invalid-credential") {
            return res.status(401).send("Unauthorized: Invalid or expired token.");
        }
        return res.status(500).send("Internal Server Error.");
    }
});

// --- NEW: Get top 10 spellers globally (by accuracy, min 10 words attempted) ---
//
// Response: { players: [ { rank, username, accuracy, level, totalWordsSpelled }, ... ] }
exports.getTopSpellers = functions.https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") {
        res.set("Access-Control-Allow-Methods", "GET");
        res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
        res.set("Access-Control-Max-Age", "3600");
        return res.status(204).send("");
    }

    // Auth
    if (!req.headers.authorization || !req.headers.authorization.startsWith("Bearer ")) {
        return res.status(403).send("Unauthorized");
    }
    const idToken = req.headers.authorization.split("Bearer ")[1];

    try {
        await admin.auth().verifyIdToken(idToken);

        const db = admin.firestore();

        // Minimum words attempted to qualify for the leaderboard
        // (avoids someone with 1 word correct showing 100%)
        const MIN_WORDS = parseInt(req.query.minWords) || 10;
        const LIMIT = Math.min(parseInt(req.query.limit) || 10, 50);

        const snapshot = await db.collection("soloProgress").get();

        if (snapshot.empty) {
            return res.status(200).json({ players: [] });
        }

        // Collect qualifying players
        const players = [];
        snapshot.forEach((doc) => {
            const d = doc.data();
            const attempted = d.totalWordsSpelled || 0;
            if (attempted >= MIN_WORDS) {
                const accuracy = (d.totalCorrectWords || 0) / attempted * 100;
                players.push({
                    id: doc.id,
                    accuracy,
                    level: d.level || 1,
                    totalWordsSpelled: attempted,
                });
            }
        });

        // Sort and take top N
        players.sort((a, b) => b.accuracy - a.accuracy);
        const top = players.slice(0, LIMIT);

        // Fetch usernames in parallel
        const userRefs = top.map((p) => db.collection("users").doc(p.id).get());
        const userDocs = await Promise.all(userRefs);

        const result = top.map((p, i) => {
            const uDoc = userDocs[i];
            let username = "Anonymous";
            if (uDoc.exists) {
                username = uDoc.data().username || uDoc.data().email || "Anonymous";
            }
            return {
                rank: i + 1,
                username,
                accuracy: Math.round(p.accuracy * 10) / 10,
                level: p.level,
                totalWordsSpelled: p.totalWordsSpelled,
            };
        });

        return res.status(200).json({ players: result });
    } catch (error) {
        console.error("Error in getTopSpellers:", error);
        if (error.code === "auth/id-token-expired" || error.code === "auth/invalid-credential") {
            return res.status(401).send("Unauthorized: Invalid or expired token.");
        }
        return res.status(500).send("Internal Server Error.");
    }
});
