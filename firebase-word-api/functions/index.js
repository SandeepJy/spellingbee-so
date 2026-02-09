/* eslint-disable block-spacing */
/* eslint-disable object-curly-spacing */
/* eslint-disable indent */
/* eslint-disable max-len */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { Storage } = require("@google-cloud/storage");

admin.initializeApp();

const storage = new Storage();

// --- EXISTING: getRandomWords ---
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

// --- EXISTING: getWordsByLevel ---
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
        return res.status(200).json({ minLevel, maxLevel, count: randomWords.length, words: randomWords });
    } catch (error) {
        console.error("Error in getWordsByLevel:", error);
        if (error.code === "auth/id-token-expired" || error.code === "auth/invalid-credential") {
            return res.status(401).send("Unauthorized: Invalid or expired ID token.");
        }
        return res.status(500).send("Internal Server Error.");
    }
});

// --- FIXED: getMyRank ---
// Key fixes:
//   1. No minimum-words filter — every user with a soloProgress doc is ranked.
//   2. Users with 0 attempts get accuracy 0 and rank at the bottom.
//   3. totalPlayers always reflects ALL users with a progress doc.
//   4. Ties broken by totalWordsSpelled descending (more experience = better tie-break).
exports.getMyRank = functions.https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") {
        res.set("Access-Control-Allow-Methods", "GET");
        res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
        res.set("Access-Control-Max-Age", "3600");
        return res.status(204).send("");
    }
    if (!req.headers.authorization || !req.headers.authorization.startsWith("Bearer ")) {
        return res.status(403).send("Unauthorized");
    }
    const idToken = req.headers.authorization.split("Bearer ")[1];

    try {
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        const uid = decodedToken.uid;
        const db = admin.firestore();

        // Fetch every soloProgress document — no filtering so totalPlayers is accurate
        const snapshot = await db.collection("soloProgress").get();

        if (snapshot.empty) {
            // No progress docs at all — this user is the only one
            return res.status(200).json({
                rank: 1,
                totalPlayers: 1,
                accuracy: 0,
                username: "",
                totalWordsSpelled: 0,
            });
        }

        // Build full player list including users with 0 attempts
        const players = [];
        let userInList = false;

        snapshot.forEach((doc) => {
            const d = doc.data();
            const attempted = d.totalWordsSpelled || 0;
            const correct = d.totalCorrectWords || 0;
            // Avoid division by zero — 0 attempted = 0% accuracy
            const accuracy = attempted > 0 ? (correct / attempted) * 100 : 0;
            players.push({
                id: doc.id,
                accuracy,
                totalWordsSpelled: attempted,
                level: d.level || 1,
            });
            if (doc.id === uid) userInList = true;
        });

        // If the calling user has no progress doc yet, add them at the bottom
        if (!userInList) {
            players.push({ id: uid, accuracy: 0, totalWordsSpelled: 0, level: 1 });
        }

        // Sort: accuracy DESC, then totalWordsSpelled DESC as tie-breaker
        players.sort((a, b) => {
            if (b.accuracy !== a.accuracy) return b.accuracy - a.accuracy;
            return b.totalWordsSpelled - a.totalWordsSpelled;
        });

        const totalPlayers = players.length;
        const myIndex = players.findIndex((p) => p.id === uid);
        const me = players[myIndex];

        // Fetch username
        let username = "";
        try {
            const userDoc = await db.collection("users").doc(uid).get();
            if (userDoc.exists) {
                const data = userDoc.data();
                username = data.username || data.email || "";
            }
        } catch (_) {/* non-fatal */ }

        return res.status(200).json({
            rank: myIndex + 1,
            totalPlayers,
            accuracy: Math.round(me.accuracy * 10) / 10,
            totalWordsSpelled: me.totalWordsSpelled,
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

// --- FIXED: getTopSpellers ---
// Key fixes:
//   1. Lowered default minWords to 1 so test users with small sample sizes appear.
//   2. Same tie-breaking logic as getMyRank.
//   3. Marks whether the calling user is in the top list.
exports.getTopSpellers = functions.https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") {
        res.set("Access-Control-Allow-Methods", "GET");
        res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
        res.set("Access-Control-Max-Age", "3600");
        return res.status(204).send("");
    }
    if (!req.headers.authorization || !req.headers.authorization.startsWith("Bearer ")) {
        return res.status(403).send("Unauthorized");
    }
    const idToken = req.headers.authorization.split("Bearer ")[1];

    try {
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        const callerUid = decodedToken.uid;
        const db = admin.firestore();

        // For testing keep minWords=1; bump to 10+ in production
        const MIN_WORDS = parseInt(req.query.minWords) || 1;
        const LIMIT = Math.min(parseInt(req.query.limit) || 10, 50);

        const snapshot = await db.collection("soloProgress").get();

        if (snapshot.empty) {
            return res.status(200).json({ players: [] });
        }

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

        // Sort: accuracy DESC, totalWordsSpelled DESC
        players.sort((a, b) => {
            if (b.accuracy !== a.accuracy) return b.accuracy - a.accuracy;
            return b.totalWordsSpelled - a.totalWordsSpelled;
        });

        const top = players.slice(0, LIMIT);

        // Batch-fetch usernames
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
                isCurrentUser: p.id === callerUid,
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
