const {onSchedule} = require("firebase-functions/v2/scheduler");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

/**
 * Runs every day at 8:00 AM (Riyadh timezone = UTC+3, so 05:00 UTC)
 * Checks all revision plans and sends notifications for exams tomorrow
 */
exports.sendExamReminderNotifications = onSchedule(
    {
      schedule: "59 2 * * *", // Every day at 05:00 UTC = 08:00 Riyadh
      timeZone: "Asia/Riyadh",
      region: "us-central1",
    },
    async (event) => {
      const db = getFirestore();
      const messaging = getMessaging();

      // Calculate tomorrow's date (in Riyadh timezone)
      const now = new Date();
      const tomorrow = new Date(now);
      tomorrow.setDate(tomorrow.getDate() + 1);

      // Format as YYYY-MM-DD for comparison
      const tomorrowStr = tomorrow.toISOString().split("T")[0];
      console.log(`[FCM] Checking exams for: ${tomorrowStr}`);

      // Fetch all revision plans
      const plansSnapshot = await db.collection("revisionPlans").get();

      if (plansSnapshot.empty) {
        console.log("[FCM] No revision plans found.");
        return;
      }

      const notificationPromises = [];

      for (const doc of plansSnapshot.docs) {
        const plan = doc.data();
        const userId = plan.userId;

        // Normalize the exam date to YYYY-MM-DD string
        let examDateStr = null;

        if (plan.examDate) {
        // Handle Firestore Timestamp
          if (plan.examDate.toDate) {
            examDateStr = plan.examDate.toDate().toISOString().split("T")[0];
          } else if (typeof plan.examDate === "string") {
          // Handle ISO string
            examDateStr = plan.examDate.split("T")[0];
          }
        } else if (plan.examDateIso) {
          examDateStr = plan.examDateIso.split("T")[0];
        }

        // Skip if no exam date or exam is not tomorrow
        if (!examDateStr || examDateStr !== tomorrowStr) continue;

        const folderName = plan.folderName ||
        plan.folder_name ||
        "Your Course";

        console.log(`[FCM] Exam tomorrow for userId: ${userId}`);

        // Get the user's FCM token
        const tokenDoc = await db.collection("fcmTokens").doc(userId).get();
        if (!tokenDoc.exists) {
          console.log(`[FCM] No token found for userId: ${userId}`);
          continue;
        }

        const fcmToken = tokenDoc.data().token;
        if (!fcmToken) continue;

        // Save notification to Firestore for in-app display
        await db.collection("notifications").add({
          userId: userId,
          title: "Exam Reminder 📚",
          body: `Your ${folderName} exam is tomorrow. ` +
            "Don't forget to review and rest well!",
          createdAt: new Date(),
          isRead: false,
          type: "exam_reminder",
          folderName: folderName,
          examDate: examDateStr,
        });

        // Build the notification message
        const message = {
          token: fcmToken,
          notification: {
            title: "Exam Reminder 📚",
            body: `Your ${folderName} exam is tomorrow. ` +
              "Don't forget to review and rest well!",
          },
          data: {
            type: "exam_reminder",
            folderName: folderName,
            examDate: examDateStr,
          },
          android: {
            notification: {
              channelId: "exam_reminders", // Must match Flutter channel ID
              priority: "high",
              icon: "ic_launcher",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        };

        notificationPromises.push(
            messaging
                .send(message)
                .then((response) => {
                  console.log(`[FCM] Sent to ${userId}: ${response}`);
                })
                .catch((error) => {
                  console.error(`[FCM] Failed to ${userId}:`, error.message);
                  // If token is invalid, remove it from Firestore
                  if (
                    error.code === "messaging/invalid-registration-token" ||
              error.code === "messaging/registration-token-not-registered"
                  ) {
                    return db.collection("fcmTokens").doc(userId).delete();
                  }
                }),
        );
      }

      // Send all notifications concurrently
      await Promise.all(notificationPromises);
      console.log(`[FCM] Done. Sent ${notificationPromises.length} alerts.`);
    },
);
