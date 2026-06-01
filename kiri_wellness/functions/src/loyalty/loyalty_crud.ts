import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { getAdminEmail, sendEmail } from "../config/brevo";
import { type Firestore } from "firebase-admin/firestore";
import { firestoreForCallable } from "../config/firestore_db";

// ── Types ─────────────────────────────────────────────────────────────────────

interface LoyaltyRule {
  id: string;
  name: string;
  milestone: number;
  isRecurring: boolean;
  serviceId: string;
  serviceName: string;
  description: string;
  validityDays: number;
  enabled: boolean;
}

interface LoyaltyConfig {
  enabled: boolean;
  rules: LoyaltyRule[];
  rewardEmailSubject: string;
}

// ── getLoyaltySettings ────────────────────────────────────────────────────────

export const getLoyaltySettings = onCall(
  { region: "us-central1", invoker: "public", enforceAppCheck: false },
  async (request) => {
    const database = firestoreForCallable(request);
    const snap = await database.collection("settings").doc("loyalty").get();
    if (!snap.exists) {
      return { enabled: false, rules: [], rewardEmailSubject: "🎁 ¡Tienes una regalía en Kiri Wellness!" };
    }
    return snap.data();
  }
);

// ── updateLoyaltySettings ─────────────────────────────────────────────────────

export const updateLoyaltySettings = onCall(
  { region: "us-central1", invoker: "public" },
  async (request) => {
    const database = firestoreForCallable(request);

    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const data = request.data as LoyaltyConfig;

    // Validate rules
    if (data.rules && !Array.isArray(data.rules)) {
      throw new HttpsError("invalid-argument", "El campo 'rules' debe ser un arreglo.");
    }

    for (const rule of (data.rules ?? [])) {
      if (!rule.id || !rule.milestone || rule.milestone < 1) {
        throw new HttpsError(
          "invalid-argument",
          `Regla inválida: cada regla debe tener un 'id' y 'milestone' ≥ 1.`
        );
      }
    }

    await database.collection("settings").doc("loyalty").set(
      {
        enabled: Boolean(data.enabled),
        rules: (data.rules ?? []).map((r) => ({
          id: r.id,
          name: r.name ?? "",
          milestone: Number(r.milestone),
          isRecurring: Boolean(r.isRecurring ?? true),
          serviceId: r.serviceId ?? "",
          serviceName: r.serviceName ?? "",
          description: r.description ?? "",
          validityDays: Number(r.validityDays ?? 30),
          enabled: Boolean(r.enabled ?? true),
        })),
        rewardEmailSubject:
          data.rewardEmailSubject ?? "🎁 ¡Tienes una regalía en Kiri Wellness!",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    logger.info("Loyalty settings updated");
    return { success: true };
  }
);

// ── redeemLoyaltyReward ───────────────────────────────────────────────────────

export const redeemLoyaltyReward = onCall(
  { region: "us-central1", invoker: "public" },
  async (request) => {
    const database = firestoreForCallable(request);

    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const { clientId, rewardId, appointmentId } = request.data as {
      clientId: string;
      rewardId: string;
      appointmentId: string;
    };

    if (!clientId || !rewardId || !appointmentId) {
      throw new HttpsError("invalid-argument", "clientId, rewardId y appointmentId son requeridos.");
    }

    const rewardRef = database
      .collection("clients")
      .doc(clientId)
      .collection("rewards")
      .doc(rewardId);

    const rewardSnap = await rewardRef.get();
    if (!rewardSnap.exists) {
      throw new HttpsError("not-found", "Regalía no encontrada.");
    }

    const reward = rewardSnap.data()!;

    if (reward["status"] !== "pending") {
      throw new HttpsError(
        "failed-precondition",
        `Esta regalía ya fue ${reward["status"] === "redeemed" ? "canjeada" : "expirada"}.`
      );
    }

    // Check expiry
    if (reward["expiresAt"]) {
      const expiresAt = (reward["expiresAt"] as admin.firestore.Timestamp).toDate();
      if (new Date() > expiresAt) {
        await rewardRef.update({ status: "expired" });
        throw new HttpsError("failed-precondition", "Esta regalía ha expirado.");
      }
    }

    await rewardRef.update({
      status: "redeemed",
      redeemedAt: admin.firestore.FieldValue.serverTimestamp(),
      redeemedAppointmentId: appointmentId,
    });

    logger.info(`Reward ${rewardId} redeemed for client ${clientId}`);
    return { success: true };
  }
);

// ── checkAndGrantRewards ──────────────────────────────────────────────────────
// Esta función es llamada internamente por updateAppointmentStatus cuando
// una cita cambia a "completed". Evalúa todas las reglas y crea las regalías
// que correspondan.

export async function checkAndGrantRewards(
  clientId: string,
  completedCount: number,
  database: Firestore = admin.firestore()
): Promise<void> {
  // Leer configuración de regalías
  const configSnap = await database.collection("settings").doc("loyalty").get();
  if (!configSnap.exists) return;

  const config = configSnap.data() as LoyaltyConfig;
  if (!config.enabled) return;

  const rules = (config.rules ?? []).filter((r) => r.enabled);
  if (rules.length === 0) return;

  // Leer datos del cliente para notificación
  const clientSnap = await database.collection("clients").doc(clientId).get();
  const client = clientSnap.data();

  const rewardsToGrant: LoyaltyRule[] = [];

  for (const rule of rules) {
    const m = rule.milestone;
    if (m <= 0) continue;

    if (rule.isRecurring) {
      // Se otorga cada vez que el contador es múltiplo del milestone
      if (completedCount % m === 0) {
        rewardsToGrant.push(rule);
      }
    } else {
      // Se otorga una sola vez: exactamente cuando alcanza el milestone
      if (completedCount === m) {
        rewardsToGrant.push(rule);
      }
    }
  }

  if (rewardsToGrant.length === 0) return;

  // Crear documentos de regalía y notificar al cliente
  const batch = database.batch();

  for (const rule of rewardsToGrant) {
    const rewardRef = database
      .collection("clients")
      .doc(clientId)
      .collection("rewards")
      .doc();

    const earnedAt = new Date();
    const expiresAt =
      rule.validityDays > 0
        ? new Date(earnedAt.getTime() + rule.validityDays * 24 * 60 * 60 * 1000)
        : null;

    batch.set(rewardRef, {
      ruleId: rule.id,
      earnedAtMilestone: completedCount,
      serviceId: rule.serviceId,
      serviceName: rule.serviceName,
      description: rule.description,
      earnedAt: admin.firestore.Timestamp.fromDate(earnedAt),
      expiresAt: expiresAt
        ? admin.firestore.Timestamp.fromDate(expiresAt)
        : null,
      status: "pending",
      redeemedAt: null,
      redeemedAppointmentId: null,
    });

    logger.info(
      `Granting reward "${rule.name}" (milestone ${completedCount}) to client ${clientId}`
    );
  }

  await batch.commit();

  // Enviar email de notificación al cliente si tiene correo
  if (client?.["email"]) {
    try {
      const clientName: string = client["name"] ?? client["firstName"] ?? "Cliente";
      const clientLastName: string = client["lastName"] ?? "";

      for (const rule of rewardsToGrant) {
        const expiresLine =
          rule.validityDays > 0
            ? `<p style="color:#666;font-size:14px;">⏳ Tu regalía es válida por <strong>${rule.validityDays} días</strong>.</p>`
            : "";

        const html = `
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f5f5f5;font-family:Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f5f5f5;padding:32px 0;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;overflow:hidden;max-width:600px;width:100%;">
        <!-- Header -->
        <tr>
          <td style="background:linear-gradient(135deg,#6B4FA0 0%,#9B7CC8 100%);padding:32px;text-align:center;">
            <h1 style="color:#fff;margin:0;font-size:24px;">🎁 ¡Felicitaciones, ${clientName}!</h1>
            <p style="color:rgba(255,255,255,0.85);margin:8px 0 0;font-size:15px;">Has ganado una regalía especial en Kiri Wellness</p>
          </td>
        </tr>
        <!-- Body -->
        <tr>
          <td style="padding:32px;">
            <p style="font-size:16px;color:#333;margin:0 0 16px;">
              ¡Llegaste a tu cita número <strong>${completedCount}</strong>! Como reconocimiento a tu fidelidad, te obsequiamos:
            </p>
            <div style="background:#f3eeff;border-left:4px solid #6B4FA0;border-radius:8px;padding:20px 24px;margin:0 0 20px;">
              <h2 style="color:#6B4FA0;margin:0 0 8px;font-size:20px;">✨ ${rule.serviceName}</h2>
              <p style="color:#444;margin:0;font-size:15px;">${rule.description}</p>
            </div>
            ${expiresLine}
            <p style="font-size:14px;color:#666;margin:24px 0 0;">
              Para agendar tu cita con esta regalía, comunícate con nosotros o agenda directamente desde tu portal.
            </p>
          </td>
        </tr>
        <!-- Footer -->
        <tr>
          <td style="background:#f9f9f9;padding:20px 32px;text-align:center;border-top:1px solid #eee;">
            <p style="color:#999;font-size:12px;margin:0;">Kiri Wellness · Costa Rica</p>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;

        await sendEmail({
          to: [{ email: client["email"], name: `${clientName} ${clientLastName}`.trim() }],
          subject: config.rewardEmailSubject,
          htmlContent: html,
        });

        logger.info(`Reward email sent to ${client["email"]} for rule "${rule.name}"`);
      }
    } catch (emailErr) {
      logger.error("Failed to send reward notification email", emailErr);
    }
  }

  // Notificar también al admin
  try {
    const settingsSnap = await database.collection("settings").doc("global").get();
    const settingsData = settingsSnap.data();
    const adminEmails: string[] =
      Array.isArray(settingsData?.["adminEmails"]) && settingsData!["adminEmails"].length > 0
        ? settingsData!["adminEmails"]
        : [getAdminEmail()];

    const clientName = client?.["name"] ?? client?.["firstName"] ?? "Cliente";
    const clientCode = client?.["clientCode"] ?? "";

    await sendEmail({
      to: adminEmails.map((e) => ({ email: e })),
      subject: `🎁 Regalía otorgada – ${clientName} (${clientCode})`,
      htmlContent: `
        <p>El cliente <strong>${clientName} ${client?.["lastName"] ?? ""}</strong> (<code>${clientCode}</code>) 
        alcanzó la cita #${completedCount} y se le otorgaron las siguientes regalías:</p>
        <ul>${rewardsToGrant.map((r) => `<li><strong>${r.serviceName}</strong>: ${r.description}</li>`).join("")}</ul>
      `,
    });
  } catch (adminNotifyErr) {
    logger.error("Failed to send admin reward notification", adminNotifyErr);
  }
}

// ── buildLoyaltyProgressHtml ──────────────────────────────────────────────────
// Builds an HTML snippet showing the client's progress toward their next
// loyalty reward(s). Returns null if the program is disabled or has no rules.

export async function buildLoyaltyProgressHtml(
  clientId: string,
  database: Firestore = admin.firestore()
): Promise<string | null> {
  try {
    const configSnap = await database.collection("settings").doc("loyalty").get();
    if (!configSnap.exists) return null;

    const config = configSnap.data() as LoyaltyConfig;
    if (!config.enabled) return null;

    const rules = (config.rules ?? []).filter((r) => r.enabled && r.milestone > 0);
    if (rules.length === 0) return null;

    const clientSnap = await database.collection("clients").doc(clientId).get();
    const completedCount: number = clientSnap.data()?.["completedAppointments"] ?? 0;

    // Build progress rows — one per active rule
    const rows = rules.map((rule) => {
      const m = rule.milestone;
      // For recurring rules, find the next multiple above current count
      const nextTarget = rule.isRecurring
        ? (Math.floor(completedCount / m) + 1) * m
        : m;
      const remaining = nextTarget - completedCount;

      if (remaining <= 0) {
        // Client already earned this milestone (reward was just granted)
        return `
          <tr>
            <td style="padding:10px 14px;vertical-align:top;">
              <span style="font-size:20px;">🎁</span>
            </td>
            <td style="padding:10px 14px 10px 0;">
              <p style="margin:0;font-size:14px;color:#2E7D32;font-weight:600;">¡Ya ganaste: ${rule.serviceName}!</p>
              <p style="margin:4px 0 0;font-size:12px;color:#666;">Comunícate con nosotros para agendar tu sesión gratuita.</p>
            </td>
          </tr>`;
      }

      // Progress bar percentage
      const prevTarget = rule.isRecurring
        ? Math.floor(completedCount / m) * m
        : 0;
      const progress = Math.round(((completedCount - prevTarget) / (nextTarget - prevTarget)) * 100);

      const sessionWord = remaining === 1 ? "sesión" : "sesiones";

      return `
        <tr>
          <td style="padding:10px 14px;vertical-align:top;">
            <span style="font-size:20px;">⭐</span>
          </td>
          <td style="padding:10px 14px 10px 0;width:100%;">
            <p style="margin:0 0 4px;font-size:14px;color:#3d3d3d;font-weight:600;">
              Te faltan <strong style="color:#7B9E87;">${remaining} ${sessionWord}</strong> para ganar: ${rule.serviceName}
            </p>
            <!-- Progress bar -->
            <div style="background:#e8e8e8;border-radius:8px;height:8px;width:100%;margin:6px 0 4px;">
              <div style="background:#7B9E87;border-radius:8px;height:8px;width:${progress}%;"></div>
            </div>
            <p style="margin:0;font-size:11px;color:#999;">${completedCount} de ${nextTarget} sesiones completadas</p>
          </td>
        </tr>`;
    });

    return `
      <table width="100%" cellpadding="0" cellspacing="0"
        style="border:1.5px solid #c8e6c9;border-radius:10px;overflow:hidden;margin-bottom:24px;background:#f1f8f2;">
        <tr>
          <td colspan="2" style="padding:12px 14px 4px;">
            <p style="margin:0;font-size:12px;font-weight:700;color:#7B9E87;text-transform:uppercase;letter-spacing:1px;">
              🏆 Tu progreso de regalías
            </p>
          </td>
        </tr>
        ${rows.join("")}
      </table>`;
  } catch (err) {
    logger.warn("Could not build loyalty progress HTML", err);
    return null;
  }
}

// ── createRewardAppointment ───────────────────────────────────────────────────
// Public CF for client portal: books an appointment using a pending reward.
// Does NOT require Firebase auth — validates via clientId + rewardId.

export const createRewardAppointment = onCall(
  { region: "us-central1", invoker: "public", enforceAppCheck: false },
  async (request) => {
    const database = firestoreForCallable(request);

    const { clientId, rewardId, serviceId, serviceName, date, time, notes } =
      request.data as {
        clientId: string;
        rewardId: string;
        serviceId: string;
        serviceName?: string;
        date: string;
        time: string;
        notes?: string;
      };

    if (!clientId || !rewardId || !serviceId || !date || !time) {
      throw new HttpsError("invalid-argument", "Faltan campos requeridos.");
    }

    // 1. Validate reward
    const rewardRef = database
      .collection("clients")
      .doc(clientId)
      .collection("rewards")
      .doc(rewardId);
    const rewardSnap = await rewardRef.get();
    if (!rewardSnap.exists) throw new HttpsError("not-found", "Regalía no encontrada.");

    const reward = rewardSnap.data()!;
    if (reward["status"] !== "pending") {
      throw new HttpsError(
        "failed-precondition",
        `Esta regalía ya fue ${
          reward["status"] === "redeemed" ? "canjeada" : "expirada"
        }.`
      );
    }
    if (reward["expiresAt"]) {
      const expiresAt = (reward["expiresAt"] as admin.firestore.Timestamp).toDate();
      if (new Date() > expiresAt) {
        await rewardRef.update({ status: "expired" });
        throw new HttpsError("failed-precondition", "Esta regalía ha expirado.");
      }
    }
    if (reward["serviceId"] !== serviceId) {
      throw new HttpsError("invalid-argument", "El servicio no coincide con la regalía.");
    }

    // 2. Look up client info
    const clientSnap = await database.collection("clients").doc(clientId).get();
    if (!clientSnap.exists) throw new HttpsError("not-found", "Cliente no encontrado.");
    const clientData = clientSnap.data()!;

    // 3. Look up service details
    const svcSnap = await database.collection("services").doc(serviceId).get();
    const serviceDurationMin: number = svcSnap.exists
      ? ((svcSnap.data()?.["durationMinutes"] as number) ?? 60)
      : 60;
    const resolvedName: string =
      serviceName ??
      (svcSnap.exists ? ((svcSnap.data()?.["name"] as string) ?? "") : "");

    // 4. Check slot availability
    const [reqH, reqM] = time.split(":").map(Number);
    const reqStart = reqH * 60 + reqM;
    const reqEnd = reqStart + serviceDurationMin;

    const settingsSnap = await database.collection("settings").doc("global").get();
    const breakMinutes: number = settingsSnap.exists
      ? ((settingsSnap.data()?.["breakMinutes"] as number) ?? 30)
      : 30;

    const conflictSnap = await database
      .collection("appointments")
      .where("date", "==", date)
      .where("status", "in", ["requested", "confirmed"])
      .get();

    for (const doc of conflictSnap.docs) {
      const d = doc.data();
      const existT = d["time"] as string;
      const existDur = (d["serviceDurationMin"] as number) ?? 60;
      const [eh, em] = existT.split(":").map(Number);
      const eStart = eh * 60 + em;
      const eEnd = eStart + existDur + breakMinutes;
      if (reqStart < eEnd && reqEnd + breakMinutes > eStart) {
        throw new HttpsError("failed-precondition", `El horario ${time} no está disponible.`);
      }
    }

    // 5. Create appointment (confirmed automatically — it's a reward)
    const aptRef = database.collection("appointments").doc();
    await aptRef.set({
      clientId,
      clientCode: clientData["clientCode"] ?? "",
      clientName: (clientData["name"] as string) ?? (clientData["firstName"] as string) ?? "",
      clientLastName: (clientData["lastName"] as string) ?? "",
      clientPhone: (clientData["phone"] as string) ?? "",
      clientEmail: (clientData["email"] as string) ?? "",
      serviceId,
      serviceName: resolvedName,
      serviceDurationMin,
      servicePrice: 0,
      date,
      time,
      status: "confirmed",
      notes: notes ?? null,
      rewardId,
      isReward: true,
      clientPackageId: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 6. Mark reward as redeemed
    await rewardRef.update({
      status: "redeemed",
      redeemedAt: admin.firestore.FieldValue.serverTimestamp(),
      redeemedAppointmentId: aptRef.id,
    });

    logger.info(`Reward appointment created: ${aptRef.id} for client ${clientId}`);
    return { success: true, appointmentId: aptRef.id };
  }
);
