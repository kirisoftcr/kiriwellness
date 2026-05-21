import * as admin from "firebase-admin";

// Initialize Firebase Admin (only once)
admin.initializeApp();

// Export all Cloud Functions
export { createBooking } from "./booking/create_booking";
export { onAppointmentCreated } from "./booking/on_appointment_created";
export { sendReminders } from "./reminders/send_reminders";
export { listServices, createService, updateService, deleteService } from "./services/services_crud";
export { createSchedule, updateSchedule, deleteSchedule } from "./schedule/schedule_crud";
export { getAvailableSlots } from "./booking/get_available_slots";
export { getAppointmentsByToken } from "./booking/get_appointments_by_token";
export { lookupClientByEmail, sendVerificationCode, verifyClientCode, cancelAppointmentByClient, confirmAppointmentByClient } from "./booking/client_portal";
export { getSettings, updateSettings, updateAppointmentStatus } from "./services/admin_crud";
export { getLoyaltySettings, updateLoyaltySettings, redeemLoyaltyReward } from "./loyalty/loyalty_crud";
