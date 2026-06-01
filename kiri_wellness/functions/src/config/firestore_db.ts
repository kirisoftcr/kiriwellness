import { type Firestore, getFirestore } from "firebase-admin/firestore";

const PROD_APP_IDS = new Set<string>([
  "1:1077059237904:web:5167d2323359a1bac23295", // Kiri Wellness Prod Web
  "1:1077059237904:web:25d768ad1406869cc23295", // Kiri Wellness Admin Web Prod
]);

const PROD_HOSTS = new Set<string>([
  "kiri-wellness-prod.web.app",
  "kiri-wellness-admin-prod.web.app",
  "kiriwellness.com",
  "www.kiriwellness.com",
  "admin.kiriwellness.com",
]);

function readAppIdFromCallableRequest(request: unknown): string | undefined {
  const rawRequest = (request as { rawRequest?: unknown })?.rawRequest as
    | {
        get?: (name: string) => string | undefined;
        headers?: Record<string, string | string[] | undefined>;
      }
    | undefined;

  const fromGetter =
    typeof rawRequest?.get === "function"
      ? rawRequest.get("x-firebase-gmpid")
      : undefined;

  const fromHeaders = rawRequest?.headers?.["x-firebase-gmpid"];
  const fromHeadersValue = Array.isArray(fromHeaders)
    ? fromHeaders[0]
    : fromHeaders;

  return fromGetter ?? fromHeadersValue;
}

function readHeaderValue(request: unknown, name: string): string | undefined {
  const rawRequest = (request as { rawRequest?: unknown })?.rawRequest as
    | {
        get?: (headerName: string) => string | undefined;
        headers?: Record<string, string | string[] | undefined>;
      }
    | undefined;

  const fromGetter =
    typeof rawRequest?.get === "function" ? rawRequest.get(name) : undefined;

  const fromHeaders = rawRequest?.headers?.[name.toLowerCase()];
  const fromHeadersValue = Array.isArray(fromHeaders)
    ? fromHeaders[0]
    : fromHeaders;

  return fromGetter ?? fromHeadersValue;
}

function isProdHostRequest(request: unknown): boolean {
  const origin = readHeaderValue(request, "origin");
  const referer = readHeaderValue(request, "referer");

  const urlCandidates = [origin, referer].filter(
    (v): v is string => typeof v === "string" && v.length > 0
  );

  for (const value of urlCandidates) {
    try {
      const host = new URL(value).host.toLowerCase();
      if (PROD_HOSTS.has(host)) return true;
    } catch {
      // Ignore malformed header values
    }
  }

  return false;
}

export function firestoreDatabaseIdForCallable(request: unknown): string {
  const appId = readAppIdFromCallableRequest(request);
  if ((appId && PROD_APP_IDS.has(appId)) || isProdHostRequest(request)) {
    return "production";
  }
  return "(default)";
}

export function firestoreForCallable(request: unknown): Firestore {
  const databaseId = firestoreDatabaseIdForCallable(request);
  return databaseId === "(default)"
    ? getFirestore()
    : getFirestore(databaseId);
}
