🖥️ Como correr

// bash
# Flutter
cd gym_app && flutter test test/unit/
 
# Cloud Functions
cd gym_app/functions && npm test

# Run APP
flutter run -d chrome

# Deploy para web
flutter build web --release
firebase deploy --only hosting

# Stripe
https://dashboard.stripe.com/apikeys