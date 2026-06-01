import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { randomUUID } from "crypto";
import { SECRET_NAMES, getAdminEmail, sendEmail } from "../config/brevo";
import { type Firestore } from "firebase-admin/firestore";
import { firestoreForCallable } from "../config/firestore_db";

// ── Types ─────────────────────────────────────────────────────────────────────

interface PackageServiceEntry {
  serviceId: string;
  serviceName: string;
  sessionCount: number;
}

interface ClientPackageServiceEntry {
  serviceId: string;
  serviceName: string;
  totalSessions: number;
  usedSessions: number;
}

// ── createPackage ─────────────────────────────────────────────────────────────

export const createPackage = onCall(
  { region: "us-central1", invoker: "public" },
  async (request) => {
    const database = firestoreForCallable(request);

    if (!request.auth) throw new HttpsError("unauthenticated", "Debes iniciar sesión.");

    const { name, description, price, services, discountPercent, validityDays } = request.data as {
      name: string;
      description: string;
      price: number;
      services: PackageServiceEntry[];
      discountPercent: number;
      validityDays: number;
    };

    if (!name || !services || services.length === 0) {
      throw new HttpsError("invalid-argument", "Nombre y servicios son requeridos.");
    }

    const docRef = await database.collection("packages").add({
      name,
      description: description ?? "",
      price: Number(price) || 0,
      services: services.map((s) => ({
        serviceId: s.serviceId,
        serviceName: s.serviceName,
        sessionCount: Number(s.sessionCount) || 1,
      })),
      discountPercent: Number(discountPercent) || 0,
      validityDays: Number(validityDays) || 30,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info("Package created", docRef.id);
    return { id: docRef.id };
  }
);

// ── updatePackage ─────────────────────────────────────────────────────────────

export const updatePackage = onCall(
  { region: "us-central1", invoker: "public" },
  async (request) => {
    const database = firestoreForCallable(request);

    if (!request.auth) throw new HttpsError("unauthenticated", "Debes iniciar sesión.");

    const { id, name, description, price, services, discountPercent, validityDays, isActive } = request.data as {
      id: string;
      name?: string;
      description?: string;
      price?: number;
      services?: PackageServiceEntry[];
      discountPercent?: number;
      validityDays?: number;
      isActive?: boolean;
    };

    if (!id) throw new HttpsError("invalid-argument", "El ID del paquete es requerido.");

    const updates: Record<string, unknown> = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (name !== undefined) updates["name"] = name;
    if (description !== undefined) updates["description"] = description;
    if (price !== undefined) updates["price"] = Number(price);
    if (services !== undefined) updates["services"] = services.map((s) => ({
      serviceId: s.serviceId,
      serviceName: s.serviceName,
      sessionCount: Number(s.sessionCount) || 1,
    }));
    if (discountPercent !== undefined) updates["discountPercent"] = Number(discountPercent);
    if (validityDays !== undefined) updates["validityDays"] = Number(validityDays);
    if (isActive !== undefined) updates["isActive"] = Boolean(isActive);

    await database.collection("packages").doc(id).update(updates);
    logger.info("Package updated", id);
    return { success: true };
  }
);

// ── deletePackage ─────────────────────────────────────────────────────────────

export const deletePackage = onCall(
  { region: "us-central1", invoker: "public" },
  async (request) => {
    const database = firestoreForCallable(request);

    if (!request.auth) throw new HttpsError("unauthenticated", "Debes iniciar sesión.");

    const { id } = request.data as { id: string };
    if (!id) throw new HttpsError("invalid-argument", "El ID del paquete es requerido.");

    await database.collection("packages").doc(id).update({
      isActive: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info("Package deactivated", id);
    return { success: true };
  }
);

// ── assignPackageToClient ─────────────────────────────────────────────────────
// Admin assigns a package to a client, creating the client_packages record.

export const assignPackageToClient = onCall(
  { region: "us-central1", invoker: "public" },
  async (request) => {
    const database = firestoreForCallable(request);

    if (!request.auth) throw new HttpsError("unauthenticated", "Debes iniciar sesión.");

    const { clientId, packageId } = request.data as {
      clientId: string;
      packageId: string;
    };

    if (!clientId || !packageId) {
      throw new HttpsError("invalid-argument", "clientId y packageId son requeridos.");
    }

    const [clientSnap, pkgSnap] = await Promise.all([
      database.collection("clients").doc(clientId).get(),
      database.collection("packages").doc(packageId).get(),
    ]);

    if (!clientSnap.exists) throw new HttpsError("not-found", "Cliente no encontrado.");
    if (!pkgSnap.exists) throw new HttpsError("not-found", "Paquete no encontrado.");

    const pkg = pkgSnap.data()!;
    const rawServices: PackageServiceEntry[] = (pkg["services"] as PackageServiceEntry[] ?? []);

    const totalSessions = rawServices.reduce((sum, s) => sum + (Number(s.sessionCount) || 1), 0);
    const validityDays: number = pkg["validityDays"] ?? 30;
    const purchasedAt = new Date();
    const expiresAt = new Date(purchasedAt.getTime() + validityDays * 24 * 60 * 60 * 1000);

    const clientPackageServices: ClientPackageServiceEntry[] = rawServices.map((s) => ({
      serviceId: s.serviceId,
      serviceName: s.serviceName,
      totalSessions: Number(s.sessionCount) || 1,
      usedSessions: 0,
    }));

    const docRef = await database.collection("client_packages").add({
      clientId,
      packageId,
      packageName: pkg["name"] ?? "",
      packageDescription: pkg["description"] ?? "",
      services: clientPackageServices,
      totalSessions,
      usedSessions: 0,
      purchasedAt: admin.firestore.Timestamp.fromDate(purchasedAt),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      status: "active",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info("Package assigned to client", { clientId, packageId, docRef: docRef.id });
    return { id: docRef.id };
  }
);

// ── getClientPackages ─────────────────────────────────────────────────────────
// Client portal: returns all packages for a client identified by token or clientId.

export const getClientPackages = onCall(
  { region: "us-central1", invoker: "public", enforceAppCheck: false },
  async (request) => {
    const database = firestoreForCallable(request);

    const { token, clientId: directClientId } = request.data as {
      token?: string;
      clientId?: string;
    };

    let resolvedClientId: string | undefined = directClientId;

    // Resolve clientId from token if not passed directly
    if (!resolvedClientId && token) {
      const clientSnap = await database
        .collection("clients")
        .where("clientToken", "==", token)
        .limit(1)
        .get();
      if (!clientSnap.empty) {
        resolvedClientId = clientSnap.docs[0].id;
      }
    }

    if (!resolvedClientId) {
      throw new HttpsError("not-found", "Cliente no encontrado.");
    }

    const snap = await database
      .collection("client_packages")
      .where("clientId", "==", resolvedClientId)
      .orderBy("purchasedAt", "desc")
      .get();

    const now = new Date();

    const packages = snap.docs.map((doc) => {
      const data = doc.data();
      const expiresAt: admin.firestore.Timestamp = data["expiresAt"];
      const isExpired = expiresAt.toDate() < now;
      const usedSessions: number = data["usedSessions"] ?? 0;
      const totalSessions: number = data["totalSessions"] ?? 0;
      const isComplete = usedSessions >= totalSessions;

      let status: string = data["status"] ?? "active";
      if (status === "active" && isExpired) status = "expired";
      if (status === "active" && isComplete) status = "completed";

      return {
        id: doc.id,
        packageId: data["packageId"],
        packageName: data["packageName"],
        packageDescription: data["packageDescription"] ?? "",
        services: data["services"] ?? [],
        totalSessions,
        usedSessions,
        purchasedAt: (data["purchasedAt"] as admin.firestore.Timestamp).toDate().toISOString(),
        expiresAt: expiresAt.toDate().toISOString(),
        status,
      };
    });

    return { packages };
  }
);

// ── usePackageSession ─────────────────────────────────────────────────────────
// Internal helper — called by admin_crud when a package appointment is completed.
// Increments usedSessions both at the top level and for the specific service.

export async function usePackageSession(
  clientPackageId: string,
  serviceId: string,
  database: Firestore = admin.firestore()
): Promise<void> {
  const ref = database.collection("client_packages").doc(clientPackageId);

  await database.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new Error(`client_package ${clientPackageId} not found`);

    const data = snap.data()!;
    const services: ClientPackageServiceEntry[] = data["services"] ?? [];
    const updatedServices = services.map((s) => {
      if (s.serviceId === serviceId) {
        return { ...s, usedSessions: (s.usedSessions ?? 0) + 1 };
      }
      return s;
    });

    const newUsed: number = (data["usedSessions"] ?? 0) + 1;
    const totalSessions: number = data["totalSessions"] ?? 0;
    const newStatus = newUsed >= totalSessions ? "completed" : "active";

    // Check expiry
    const expiresAt: admin.firestore.Timestamp = data["expiresAt"];
    const finalStatus = expiresAt.toDate() < new Date() ? "expired" : newStatus;

    tx.update(ref, {
      services: updatedServices,
      usedSessions: newUsed,
      status: finalStatus,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  logger.info("Package session used", { clientPackageId, serviceId });
}

// ── createPackageAppointment ──────────────────────────────────────────────────
// Client books an appointment from a package session.
// The CF looks up service duration/price from Firestore, checks slot availability,
// and stores clientPackageId on the appointment for admin_crud to track.

export const createPackageAppointment = onCall(
  { region: "us-central1", invoker: "public", enforceAppCheck: false },
  async (request) => {
    const database = firestoreForCallable(request);

    const { clientId, clientPackageId, serviceId, serviceName, date, time, notes } =
      request.data as {
        clientId: string;
        clientPackageId: string;
        serviceId: string;
        serviceName?: string;
        date: string;
        time: string;
        notes?: string;
      };

    if (!clientId || !clientPackageId || !serviceId || !date || !time) {
      throw new HttpsError("invalid-argument", "Faltan campos requeridos.");
    }

    // 1. Validate package ownership + sessions remaining
    const pkgRef = database.collection("client_packages").doc(clientPackageId);
    const pkgSnap = await pkgRef.get();
    if (!pkgSnap.exists) throw new HttpsError("not-found", "Paquete no encontrado.");

    const pkgData = pkgSnap.data()!;
    if (pkgData["clientId"] !== clientId) {
      throw new HttpsError("permission-denied", "No tienes permiso para usar este paquete.");
    }
    if (pkgData["status"] !== "active") {
      throw new HttpsError("failed-precondition", "El paquete no está activo.");
    }

    const services: ClientPackageServiceEntry[] = pkgData["services"] ?? [];
    const svcEntry = services.find((s) => s.serviceId === serviceId);
    if (!svcEntry) {
      throw new HttpsError("not-found", "Servicio no encontrado en el paquete.");
    }
    if (svcEntry.usedSessions >= svcEntry.totalSessions) {
      throw new HttpsError("failed-precondition", "No tienes sesiones disponibles para este servicio.");
    }

    // 2. Look up service details (duration + price)
    const svcSnap = await database.collection("services").doc(serviceId).get();
    const serviceDurationMin: number = svcSnap.exists
      ? ((svcSnap.data()?.["durationMinutes"] as number) ?? 60)
      : 60;
    const servicePrice: number = svcSnap.exists
      ? ((svcSnap.data()?.["price"] as number) ?? 0)
      : 0;
    const resolvedName: string =
      serviceName ?? svcEntry.serviceName ?? (svcSnap.exists ? ((svcSnap.data()?.["name"] as string) ?? "") : "");

    // 3. Check slot availability
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
      const [exH, exM] = (d["time"] as string).split(":").map(Number);
      const exStart = exH * 60 + exM;
      const exDuration: number = (d["serviceDurationMin"] as number) ?? 60;
      const exEnd = exStart + exDuration + breakMinutes;
      if (reqStart < exEnd && reqEnd > exStart) {
        throw new HttpsError(
          "already-exists",
          "El horario seleccionado ya no está disponible. Por favor elige otro."
        );
      }
    }

    // 4. Get client data
    const clientSnap = await database.collection("clients").doc(clientId).get();
    if (!clientSnap.exists) throw new HttpsError("not-found", "Cliente no encontrado.");
    const clientData = clientSnap.data()!;

    // 5. Create appointment linked to the package
    const appointmentRef = database.collection("appointments").doc();
    await appointmentRef.set({
      clientId,
      clientCode: clientData["clientCode"] ?? "",
      clientName: clientData["firstName"] ?? "",
      clientLastName: clientData["lastName"] ?? "",
      clientEmail: clientData["email"] ?? "",
      serviceId,
      serviceName: resolvedName,
      serviceDurationMin,
      servicePrice,
      date,
      time,
      notes: notes ?? "",
      clientPackageId,
      status: "requested",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info("Package appointment created", appointmentRef.id);
    return { appointmentId: appointmentRef.id };
  }
);

// ── requestPackage ────────────────────────────────────────────────────────────
// Public: a prospective client requests to buy a package.
// Creates / finds the client record, stores a client_package with status="pending",
// and notifies the admin by email.

export const requestPackage = onCall(
  { region: "us-central1", invoker: "public", enforceAppCheck: false, secrets: SECRET_NAMES },
  async (request) => {
    const database = firestoreForCallable(request);

    const { packageId, firstName, lastName, email, phone, notes } = request.data as {
      packageId: string;
      firstName: string;
      lastName: string;
      email: string;
      phone: string;
      notes?: string;
    };

    if (!packageId || !firstName || !email || !phone) {
      throw new HttpsError("invalid-argument", "Faltan campos requeridos.");
    }

    // 1. Load package
    const pkgSnap = await database.collection("packages").doc(packageId).get();
    if (!pkgSnap.exists) throw new HttpsError("not-found", "Paquete no encontrado.");
    const pkg = pkgSnap.data()!;

    // 2. Find or create client
    const clientsRef = database.collection("clients");
    const counterRef = database.doc("counters/clients");
    const normalEmail = email.toLowerCase().trim();

    let clientId: string;
    let clientCode: string;

    const existingSnap = await clientsRef
      .where("email", "==", normalEmail)
      .limit(1)
      .get();

    if (!existingSnap.empty) {
      clientId = existingSnap.docs[0].id;
      clientCode = existingSnap.docs[0].data()["clientCode"] as string;
      // Backfill phone / name if they were empty
      const updates: Record<string, unknown> = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
      if (!existingSnap.docs[0].data()["phone"]) updates["phone"] = phone;
      if (!existingSnap.docs[0].data()["firstName"]) updates["firstName"] = firstName;
      if (!existingSnap.docs[0].data()["lastName"]) updates["lastName"] = lastName ?? "";
      await existingSnap.docs[0].ref.update(updates);
    } else {
      // New client
      const newClientRef = clientsRef.doc();
      clientId = newClientRef.id;
      let nextCode = "";
      await database.runTransaction(async (tx) => {
        const counterSnap = await tx.get(counterRef);
        const lastId = counterSnap.exists ? ((counterSnap.data()?.["lastId"] as number) ?? 0) : 0;
        const nextId = lastId + 1;
        nextCode = `KW-${String(nextId).padStart(5, "0")}`;
        tx.set(counterRef, { lastId: nextId }, { merge: true });
        tx.set(newClientRef, {
          firstName,
          lastName: lastName ?? "",
          phone,
          email: normalEmail,
          clientCode: nextCode,
          clientToken: randomUUID(),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      clientCode = nextCode;
    }

    // 3. Create client_package with status "pending"
    const rawServices: PackageServiceEntry[] = (pkg["services"] as PackageServiceEntry[] ?? []);
    const totalSessions = rawServices.reduce((sum, s) => sum + (Number(s.sessionCount) || 1), 0);
    const validityDays: number = pkg["validityDays"] ?? 30;
    const purchasedAt = new Date();
    const expiresAt = new Date(purchasedAt.getTime() + validityDays * 24 * 60 * 60 * 1000);

    const clientPackageServices: ClientPackageServiceEntry[] = rawServices.map((s) => ({
      serviceId: s.serviceId,
      serviceName: s.serviceName,
      totalSessions: Number(s.sessionCount) || 1,
      usedSessions: 0,
    }));

    const docRef = await database.collection("client_packages").add({
      clientId,
      packageId,
      packageName: pkg["name"] ?? "",
      packageDescription: pkg["description"] ?? "",
      services: clientPackageServices,
      totalSessions,
      usedSessions: 0,
      purchasedAt: admin.firestore.Timestamp.fromDate(purchasedAt),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      status: "pending",
      requestNotes: notes ?? "",
      clientFirstName: firstName,
      clientLastName: lastName ?? "",
      clientEmail: normalEmail,
      clientPhone: phone,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 4. Notify admin
    try {
      const settingsSnap = await database.collection("settings").doc("global").get();
      const adminEmails: string[] = settingsSnap.data()?.["adminEmails"] ?? [];
      const recipients = adminEmails.length > 0
        ? adminEmails.map((e) => ({ email: e, name: "Kiri Wellness Admin" }))
        : [{ email: getAdminEmail(), name: "Kiri Wellness Admin" }];

      await sendEmail({
        to: recipients,
        subject: `📦 Nueva solicitud de paquete – ${pkg["name"]}`,
        htmlContent: `
<!DOCTYPE html><html lang="es"><body style="font-family:Arial,sans-serif;background:#F9F6F2;padding:32px;">
<div style="max-width:520px;margin:0 auto;background:#fff;border-radius:12px;padding:32px;box-shadow:0 2px 8px rgba(0,0,0,0.08);">
  <h2 style="color:#4A5240;margin:0 0 8px">📦 Solicitud de Paquete</h2>
  <p style="color:#555;margin:0 0 24px">Un cliente desea adquirir un paquete. Por favor aprueba o rechaza desde el portal de administración.</p>
  <table style="width:100%;border-collapse:collapse;font-size:14px;">
    <tr><td style="padding:8px 0;color:#888;width:140px">Paquete</td><td style="padding:8px 0;font-weight:600">${pkg["name"]}</td></tr>
    <tr><td style="padding:8px 0;color:#888">Precio</td><td style="padding:8px 0">₡${Number(pkg["price"]).toLocaleString()}</td></tr>
    <tr><td style="padding:8px 0;color:#888">Cliente</td><td style="padding:8px 0">${firstName} ${lastName ?? ""}</td></tr>
    <tr><td style="padding:8px 0;color:#888">Correo</td><td style="padding:8px 0">${normalEmail}</td></tr>
    <tr><td style="padding:8px 0;color:#888">Teléfono</td><td style="padding:8px 0">${phone}</td></tr>
    <tr><td style="padding:8px 0;color:#888">Código cliente</td><td style="padding:8px 0">${clientCode}</td></tr>
    ${notes ? `<tr><td style="padding:8px 0;color:#888">Notas</td><td style="padding:8px 0">${notes}</td></tr>` : ""}
  </table>
</div></body></html>`,
      });
    } catch (e) {
      logger.warn("Failed to send package request email to admin", e);
    }

    logger.info("Package request created", { docRef: docRef.id, clientId });
    return { id: docRef.id, clientCode };
  }
);

// ── approveClientPackage ──────────────────────────────────────────────────────
// Admin approves a pending package request → sets status "active", emails client.

export const approveClientPackage = onCall(
  { region: "us-central1", invoker: "public", secrets: SECRET_NAMES },
  async (request) => {
    const database = firestoreForCallable(request);

    if (!request.auth) throw new HttpsError("unauthenticated", "Debes iniciar sesión.");

    const { clientPackageId } = request.data as { clientPackageId: string };
    if (!clientPackageId) throw new HttpsError("invalid-argument", "clientPackageId requerido.");

    const pkgRef = database.collection("client_packages").doc(clientPackageId);
    const pkgSnap = await pkgRef.get();
    if (!pkgSnap.exists) throw new HttpsError("not-found", "Paquete de cliente no encontrado.");

    const pkgData = pkgSnap.data()!;
    if (pkgData["status"] !== "pending") {
      throw new HttpsError("failed-precondition", "El paquete no está pendiente de aprobación.");
    }

    await pkgRef.update({
      status: "active",
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Notify client by email
    try {
      const clientSnap = await database.collection("clients").doc(pkgData["clientId"] as string).get();
      const clientData = clientSnap.data() ?? {};
      const clientEmail = clientData["email"] as string | undefined;
      if (clientEmail) {
        await sendEmail({
          to: [{ email: clientEmail, name: clientData["firstName"] as string }],
          subject: `✅ Tu paquete "${pkgData["packageName"]}" fue aprobado – Kiri Wellness`,
          htmlContent: `
<!DOCTYPE html><html lang="es"><body style="font-family:Arial,sans-serif;background:#F9F6F2;padding:32px;">
<div style="max-width:520px;margin:0 auto;background:#fff;border-radius:12px;padding:32px;box-shadow:0 2px 8px rgba(0,0,0,0.08);">
  <h2 style="color:#4A5240;margin:0 0 8px">✅ ¡Tu paquete fue aprobado!</h2>
  <p style="color:#555">Hola <strong>${clientData["firstName"] ?? ""}</strong>, tu paquete <strong>${pkgData["packageName"]}</strong> ha sido aprobado y ya está activo.</p>
  <p style="color:#555;margin:0 0 24px">Puedes empezar a usarlo agendando tus sesiones en <a href="https://kiriwellness.com/my-appointments" style="color:#9D87BC">Mis Citas</a>.</p>
  <table style="width:100%;border-collapse:collapse;font-size:14px;">
    <tr><td style="padding:8px 0;color:#888;width:140px">Paquete</td><td style="padding:8px 0;font-weight:600">${pkgData["packageName"]}</td></tr>
    <tr><td style="padding:8px 0;color:#888">Sesiones</td><td style="padding:8px 0">${pkgData["totalSessions"]} sesiones</td></tr>
  </table>
  <div style="margin-top:24px;text-align:center;">
    <a href="https://kiriwellness.com/my-appointments" style="background:#9D87BC;color:white;padding:12px 28px;border-radius:8px;text-decoration:none;font-weight:600;display:inline-block;">Ver mis paquetes</a>
  </div>
</div></body></html>`,
        });
      }
    } catch (e) {
      logger.warn("Failed to send approval email to client", e);
    }

    logger.info("Client package approved", clientPackageId);
    return { success: true };
  }
);

// ── rejectClientPackage ───────────────────────────────────────────────────────
// Admin rejects a pending package request.

export const rejectClientPackage = onCall(
  { region: "us-central1", invoker: "public", secrets: SECRET_NAMES },
  async (request) => {
    const database = firestoreForCallable(request);

    if (!request.auth) throw new HttpsError("unauthenticated", "Debes iniciar sesión.");

    const { clientPackageId, reason } = request.data as {
      clientPackageId: string;
      reason?: string;
    };
    if (!clientPackageId) throw new HttpsError("invalid-argument", "clientPackageId requerido.");

    const pkgRef = database.collection("client_packages").doc(clientPackageId);
    const pkgSnap = await pkgRef.get();
    if (!pkgSnap.exists) throw new HttpsError("not-found", "Paquete de cliente no encontrado.");

    const pkgData = pkgSnap.data()!;
    if (pkgData["status"] !== "pending") {
      throw new HttpsError("failed-precondition", "El paquete no está pendiente.");
    }

    await pkgRef.update({
      status: "rejected",
      rejectReason: reason ?? "",
      rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Notify client
    try {
      const clientSnap = await database.collection("clients").doc(pkgData["clientId"] as string).get();
      const clientData = clientSnap.data() ?? {};
      const clientEmail = clientData["email"] as string | undefined;
      if (clientEmail) {
        await sendEmail({
          to: [{ email: clientEmail, name: clientData["firstName"] as string }],
          subject: `Actualización sobre tu solicitud de paquete – Kiri Wellness`,
          htmlContent: `
<!DOCTYPE html><html lang="es"><body style="font-family:Arial,sans-serif;background:#F9F6F2;padding:32px;">
<div style="max-width:520px;margin:0 auto;background:#fff;border-radius:12px;padding:32px;box-shadow:0 2px 8px rgba(0,0,0,0.08);">
  <h2 style="color:#4A5240;margin:0 0 8px">Sobre tu solicitud de paquete</h2>
  <p style="color:#555">Hola <strong>${clientData["firstName"] ?? ""}</strong>, lamentablemente no pudimos procesar tu solicitud para el paquete <strong>${pkgData["packageName"]}</strong> en este momento.</p>
  ${reason ? `<p style="color:#555">Motivo: ${reason}</p>` : ""}
  <p style="color:#555">Para más información contáctanos al <strong>8650-0843</strong> o escríbenos a <a href="mailto:evelyn@kiriwellness.com" style="color:#9D87BC">evelyn@kiriwellness.com</a>.</p>
</div></body></html>`,
        });
      }
    } catch (e) {
      logger.warn("Failed to send rejection email to client", e);
    }

    logger.info("Client package rejected", clientPackageId);
    return { success: true };
  }
);

