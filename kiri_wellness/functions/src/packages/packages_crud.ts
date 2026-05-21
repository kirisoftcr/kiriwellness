import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

const db = () => admin.firestore();

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

    const docRef = await db().collection("packages").add({
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

    await db().collection("packages").doc(id).update(updates);
    logger.info("Package updated", id);
    return { success: true };
  }
);

// ── deletePackage ─────────────────────────────────────────────────────────────

export const deletePackage = onCall(
  { region: "us-central1", invoker: "public" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Debes iniciar sesión.");

    const { id } = request.data as { id: string };
    if (!id) throw new HttpsError("invalid-argument", "El ID del paquete es requerido.");

    await db().collection("packages").doc(id).update({
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
    if (!request.auth) throw new HttpsError("unauthenticated", "Debes iniciar sesión.");

    const { clientId, packageId } = request.data as {
      clientId: string;
      packageId: string;
    };

    if (!clientId || !packageId) {
      throw new HttpsError("invalid-argument", "clientId y packageId son requeridos.");
    }

    const [clientSnap, pkgSnap] = await Promise.all([
      db().collection("clients").doc(clientId).get(),
      db().collection("packages").doc(packageId).get(),
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

    const docRef = await db().collection("client_packages").add({
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
    const { token, clientId: directClientId } = request.data as {
      token?: string;
      clientId?: string;
    };

    let resolvedClientId: string | undefined = directClientId;

    // Resolve clientId from token if not passed directly
    if (!resolvedClientId && token) {
      const clientSnap = await db()
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

    const snap = await db()
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

export async function usePackageSession(clientPackageId: string, serviceId: string): Promise<void> {
  const ref = db().collection("client_packages").doc(clientPackageId);

  await db().runTransaction(async (tx) => {
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
