importScripts('https://www.gstatic.com/firebasejs/11.10.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.10.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAeVdBsIpGBTm9x2NlQKJKKarLRMmEVv3U',
  authDomain: 'gymbt-4ef87.firebaseapp.com',
  projectId: 'gymbt-4ef87',
  storageBucket: 'gymbt-4ef87.firebasestorage.app',
  messagingSenderId: '844686321044',
  appId: '1:844686321044:web:fbedc9ce24285d303f9b81',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  self.registration.showNotification(notification.title || 'GymBT', {
    body: notification.body || '',
    icon: '/icons/Icon-192.png',
    data: payload.data || {},
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const link = event.notification.data?.link || '/';
  event.waitUntil(clients.openWindow(link));
});
