const functions = require("firebase-functions");
const { GoogleAuth } = require("google-auth-library");
const fetch = require("node-fetch");

exports.parseExpenses = functions.https.onCall(async (data, context) => {
  const transcript = data.transcript;
  if (!transcript) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Transcript is required"
    );
  }

  const projectId = "YOUR_PROJECT_ID"; // e.g. couple-expenses-467221
  const location = "us-central1";      // or whatever region your Vertex AI is in
  const model = "gemini-2.5-flash-lite";

  const url = `https://${location}-aiplatform.googleapis.com/v1/projects/${projectId}/locations/${location}/publishers/google/models/${model}:generateContent`;

  const auth = new GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/cloud-platform"],
  });
  const client = await auth.getClient();
  const token = await client.getAccessToken();

  const body = {
    contents: [{ role: "user", parts: [{ text: transcript }] }],
    generation_config: {
      temperature: 0.0,
      response_mime_type: "application/json",
      // include your response_schema if you want
    },
  };

  const resp = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token.token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!resp.ok) {
    const text = await resp.text();
    throw new functions.https.HttpsError(
      "internal",
      `Vertex AI error: ${resp.status} ${text}`
    );
  }

  const result = await resp.json();
  return result;
});
