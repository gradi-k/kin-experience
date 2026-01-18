# Firebase Seed - Method 1 (Script Import)

Generated: 2026-01-18

This folder helps you migrate your local fake data files into Firebase Firestore, so the app becomes fully dynamic.

## 1) What gets created in Firestore
Collections (recommended):
- sites
- restos
- hotels
- events
- entreprises
- shoppings
Optional:
- reels
- ads

## 2) Where to put userPhotoUrl (for reviews)
Store it INSIDE each review document (collection: `reviews`) as:
- userPhotoUrl: string (download URL of the user's avatar in Storage)

Example review doc:
{
  placeId: "hotel1",
  placeName: "Pullman Kinshasa",
  category: "hotel",
  userId: "UID",
  userName: "Jean Claude",
  userEmail: "x@y.com",
  userPhotoUrl: "https://firebasestorage....",   <-- HERE
  rating: 5,
  comment: "Top!",
  photoUrl: "https://firebasestorage....",       <-- review photo (optional)
  createdAt: <serverTimestamp>
}

## 3) Import steps (Node)
1) Create Firebase project (already done) and enable Firestore.
2) Get a Service Account key:
   Firebase Console -> Project Settings -> Service accounts -> Generate new private key
   Save it as: `serviceAccountKey.json` in THIS folder.

3) Install dependency:
   npm i firebase-admin

4) Set env var (Windows PowerShell example):
   $env:GOOGLE_APPLICATION_CREDENTIALS="/mnt/data/firebase_seed_method1/serviceAccountKey.json"

5) Run:
   node import_to_firestore.js

## 4) Notes
- If some JSON files contain an `_error`, that means parsing your Dart file was not fully compatible.
  You can still import the other collections, and we can adjust the parser for the missing ones.
