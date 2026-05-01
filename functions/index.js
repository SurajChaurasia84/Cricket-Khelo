const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.onInviteCreated = functions.firestore
    .document('invites/{inviteId}')
    .onCreate(async (snapshot, context) => {
        const inviteData = snapshot.data();
        const inviteLat = inviteData.lat;
        const inviteLng = inviteData.lng;
        const ageGroup = inviteData.ageGroup;

        const usersSnapshot = await admin.firestore().collection('users').get();
        const tokens = [];

        usersSnapshot.forEach(doc => {
            const userData = doc.data();
            const userLat = userData.lat;
            const userLng = userData.lng;
            const userAgeGroup = userData.ageGroup;
            const fcmToken = userData.fcmToken;

            if (fcmToken && userAgeGroup === ageGroup) {
                // Simple distance calculation (approx 5km)
                const distance = calculateDistance(inviteLat, inviteLng, userLat, userLng);
                if (distance <= 5.0) {
                    tokens.push(fcmToken);
                }
            }
        });

        if (tokens.length > 0) {
            const payload = {
                notification: {
                    title: 'New Cricket Match 🏏',
                    body: 'A nearby player invited you for a match!',
                    sound: 'default'
                }
            };
            return admin.messaging().sendToDevice(tokens, payload);
        }
        return null;
    });

function calculateDistance(lat1, lon1, lat2, lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    const c = Math.cos;
    const a = 0.5 - c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) *
        (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * Math.asin(Math.sqrt(a)); // 2 * R; R = 6371 km
}
