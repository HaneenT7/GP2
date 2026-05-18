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

      const now = new Date();
      const riyadhDateStr =
      now.toLocaleDateString("en-US", {timeZone: "Asia/Riyadh"});
      const riyadhToday = new Date(riyadhDateStr);

      const tomorrow = new Date(riyadhToday);
      tomorrow.setDate(tomorrow.getDate() + 1);

      const yr = tomorrow.getFullYear();
      const mo = String(tomorrow.getMonth() + 1).padStart(2, "0");
      const da = String(tomorrow.getDate()).padStart(2, "0");
      const tomorrowStr = `${yr}-${mo}-${da}`;
      console.log(`[FCM] Checking exams for: ${tomorrowStr}`);

      const plansSnapshot = await db.collection("revisionPlans").get();

      if (plansSnapshot.empty) {
        console.log("[FCM] No revision plans found.");
        return;
      }

      const notificationPromises = [];

      for (const doc of plansSnapshot.docs) {
        const plan = doc.data();
        const userId = plan.userId;

        let examDateStr = null;

        if (plan.examDate) {
          if (plan.examDate.toDate) {
            const dateObj = plan.examDate.toDate();
            const riyadhFormat = dateObj.toLocaleDateString("en-US", {
              timeZone: "Asia/Riyadh",
            });
            const parts = riyadhFormat.split("/");

            const mm = parts[0].padStart(2, "0");
            const dd = parts[1].padStart(2, "0");
            const yyyy = parts[2];

            examDateStr = `${yyyy}-${mm}-${dd}`;
          } else if (typeof plan.examDate === "string") {
            examDateStr = plan.examDate.split("T")[0];
          }
        } else if (plan.examDateIso) {
          examDateStr = plan.examDateIso.split("T")[0];
        }

        console.log(
            `[FCM Debug] Plan ID: ${doc.id} | ` +
            `Exam: ${examDateStr} | Target: ${tomorrowStr}`,
        );

        if (!examDateStr || examDateStr !== tomorrowStr) continue;

        const folderName = plan.folderName ||
        plan.folder_name ||
        "Your Course";

        console.log(`[FCM] Exam tomorrow for userId: ${userId}`);

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

        const tokenDoc = await db.collection("fcmTokens").doc(userId).get();
        if (!tokenDoc.exists) {
          console.log(`[FCM] No token found for userId: ${userId}`);
          continue;
        }

        const fcmToken = tokenDoc.data().token;
        if (!fcmToken) continue;

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
              channelId: "exam_reminders",
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
                  if (
                    error.code === "messaging/invalid-registration-token" ||
                    error.code === "messaging/registration-token-not-registered"
                  ) {
                    return db.collection("fcmTokens").doc(userId).delete();
                  }
                }),
        );
      }

      await Promise.all(notificationPromises);
      console.log(`[FCM] Done. Sent ${notificationPromises.length} alerts.`);
    },
);

/**
 * Runs every day at 10:00 PM (Riyadh timezone = UTC+3, so 19:00 UTC)
 * Checks all incomplete tasks for today across all revision plans and sends
 * reminders
 */
exports.sendUnfinishedTasksReminderNotifications = onSchedule(
    {
      schedule: "0 19 * * *", // Every day at 19:00 UTC = 22:00 Riyadh
      timeZone: "Asia/Riyadh",
      region: "us-central1",
    },
    async (event) => {
      const db = getFirestore();
      const messaging = getMessaging();

      const now = new Date();
      const riyadhDateStr =
      now.toLocaleDateString("en-US", {timeZone: "Asia/Riyadh"});
      const riyadhToday = new Date(riyadhDateStr);

      const yr = riyadhToday.getFullYear();
      const mo = String(riyadhToday.getMonth() + 1).padStart(2, "0");
      const da = String(riyadhToday.getDate()).padStart(2, "0");
      const todayStr = `${yr}-${mo}-${da}`;
      console.log(`[FCM] Checking unfinished tasks for today: ${todayStr}`);

      const plansSnapshot = await db.collection("revisionPlans").get();

      if (plansSnapshot.empty) {
        console.log("[FCM] No revision plans found.");
        return;
      }

      const notificationPromises = [];

      for (const doc of plansSnapshot.docs) {
        const plan = doc.data();
        const userId = plan.userId;

        // 1. Check if dailyTasks exists and is a string
        if (!plan.dailyTasks || typeof plan.dailyTasks !== "string") {
          continue;
        }

        let hasUnfinishedTasksToday = false;

        try {
          // 2. Parse the dailyTasks JSON string
          const daysArray = JSON.parse(plan.dailyTasks);

          if (Array.isArray(daysArray)) {
            // 3. Find today's object inside the days array
            const todayObject = daysArray.find((day) => day.date === todayStr);

            // 4. If today's data exists, check its inner tasks array
            if (todayObject && Array.isArray(todayObject.tasks)) {
              hasUnfinishedTasksToday = todayObject.tasks.some(
                  (task) => task.completed === false,
              );
            }
          }
        } catch (e) {
          console.error(`[FCM Error] Failed to parse JSON for doc: ${doc.id}`);
          continue;
        }

        if (!hasUnfinishedTasksToday) {
          continue;
        }

        console.log(`[FCM] Found unfinished tasks for userId: ${userId}`);

        const folderName = plan.folderName ||
        plan.folder_name ||
        "Your Course";

        await db.collection("notifications").add({
          userId: userId,
          title: "Task Reminder 📝",
          body: `You still have pending tasks for ${folderName} today. ` +
            "Complete them before the day ends!",
          createdAt: new Date(),
          isRead: false,
          type: "task_reminder",
          folderName: folderName,
          date: todayStr,
        });

        const tokenDoc = await db.collection("fcmTokens").doc(userId).get();
        if (!tokenDoc.exists) {
          console.log(`[FCM] No token found for userId: ${userId}`);
          continue;
        }

        const fcmToken = tokenDoc.data().token;
        if (!fcmToken) continue;

        const message = {
          token: fcmToken,
          notification: {
            title: "Task Reminder 📝",
            body: `You still have pending tasks for ${folderName} today. ` +
              "Complete them before the day ends!",
          },
          data: {
            type: "task_reminder",
            folderName: folderName,
            date: todayStr,
          },
          android: {
            notification: {
              channelId: "task_reminders",
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
                  console.log(`[FCM] Sent task reminder: ${response}`);
                })
                .catch((error) => {
                  console.error(`[FCM] Failed to ${userId}:`, error.message);
                  if (
                    error.code === "messaging/invalid-registration-token" ||
                    error.code === "messaging/registration-token-not-registered"
                  ) {
                    return db.collection("fcmTokens").doc(userId).delete();
                  }
                }),
        );
      }

      await Promise.all(notificationPromises);
      console.log(`[FCM] Done. Sent ${notificationPromises.length} alerts.`);
    },
);
