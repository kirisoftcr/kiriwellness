import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { firestoreForCallable } from "../config/firestore_db";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface ServiceData {
  name: string;
  description: string;
  price: number;
  durationMinutes: number;
  category: string;
  isActive: boolean;
  benefits: string[];
  imageUrl?: string | null;
}

// ---------------------------------------------------------------------------
// listServices
// ---------------------------------------------------------------------------

export const listServices = onCall(
  { region: "us-central1", invoker: "public" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const snap = await firestoreForCallable(request)
      .collection("services")
      .orderBy("name")
      .get();

    return snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  }
);

// ---------------------------------------------------------------------------
// createService
// ---------------------------------------------------------------------------

export const createService = onCall(
  { region: "us-central1", invoker: "public" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const data = request.data as ServiceData;

    if (!data.name || data.name.trim() === "") {
      throw new HttpsError("invalid-argument", "El nombre es requerido.");
    }

    const ref = firestoreForCallable(request).collection("services").doc();
    await ref.set({
      name: data.name.trim(),
      description: data.description ?? "",
      price: Number(data.price) || 0,
      durationMinutes: Number(data.durationMinutes) || 60,
      category: data.category?.trim() || "General",
      isActive: data.isActive !== false,
      benefits: data.benefits ?? [],
      imageUrl: data.imageUrl ?? null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info("Service created", ref.id);
    return { id: ref.id };
  }
);

// ---------------------------------------------------------------------------
// updateService
// ---------------------------------------------------------------------------

export const updateService = onCall(
  { region: "us-central1", invoker: "public" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const payload = request.data as Record<string, unknown> & { id: string };
    const { id, ...fields } = payload;

    if (!id) {
      throw new HttpsError("invalid-argument", "El id del servicio es requerido.");
    }

    // Build only the fields that were provided
    const update: Record<string, unknown> = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (fields.name !== undefined) update.name = String(fields.name).trim();
    if (fields.description !== undefined) update.description = fields.description;
    if (fields.price !== undefined) update.price = Number(fields.price);
    if (fields.durationMinutes !== undefined) update.durationMinutes = Number(fields.durationMinutes);
    if (fields.category !== undefined) update.category = String(fields.category).trim() || "General";
    if (fields.isActive !== undefined) update.isActive = Boolean(fields.isActive);
    if (fields.benefits !== undefined) update.benefits = fields.benefits;
    if (fields.imageUrl !== undefined) update.imageUrl = fields.imageUrl ?? null;

    await firestoreForCallable(request).collection("services").doc(id).update(update);

    logger.info("Service updated", id);
    return { id };
  }
);

// ---------------------------------------------------------------------------
// deleteService
// ---------------------------------------------------------------------------

export const deleteService = onCall(
  { region: "us-central1", invoker: "public" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const { id } = request.data as { id: string };

    if (!id) {
      throw new HttpsError("invalid-argument", "El id del servicio es requerido.");
    }

    await firestoreForCallable(request).collection("services").doc(id).delete();

    logger.info("Service deleted", id);
    return { id };
  }
);
