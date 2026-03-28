# Project Architecture - wawapp-ai

## Overview
WawApp is a multi-platform ride-hailing and logistics solution built with Flutter and Firebase. It follows a mono-repo structure to share logic and models between different user roles.

## Repository Structure
- **apps/**: Contains the main applications.
  - `wawapp_client`: The application for riders/customers.
  - `wawapp_driver`: The application for drivers.
  - `wawapp_admin`: Administrative dashboard for managing the system.
- **packages/**: Shared logic and UI components.
  - `auth_shared`: Common authentication logic (Phone + PIN, OTP).
  - `ui_shared`: Reusable design components and design system.
- **functions/**: Firebase Cloud Functions (Node.js/TypeScript) for server-side logic, secure payments, and order matching.

## Backend Integration
- **Auth**: Firebase Phone Authentication for identity, coupled with a custom PIN system stored in Firestore.
- **Database**: Google Cloud Firestore (NoSQL).
- **Storage**: Firebase Storage for documents and profile images.
- **Functions**: Handles sensitive operations (Wallet management, Order assignment, Token generation).
- **Rules**: Strict Firestore security rules (`firestore.rules`) enforce data isolation between drivers and clients.
