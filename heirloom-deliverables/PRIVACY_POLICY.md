# Heirloom Privacy Policy

**Effective Date:** January 1, 2025
**Last Updated:** December 8, 2024

## Overview

Heirloom ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our iOS mobile application and related services (collectively, the "Service").

**Key Principles:**
- **Privacy-First Design:** Most processing happens on your device
- **Minimal Data Collection:** We only collect what's necessary for functionality
- **User Control:** You own your data and can delete it anytime
- **No Advertising:** We never sell your data or show ads
- **Transparent Practices:** Clear communication about data usage

## Information We Collect

### 1. Information You Provide Directly

**Account Information (Optional):**
- Apple ID (via Sign in with Apple only)
- No email addresses, phone numbers, or passwords stored by us

**Recipe Content:**
- Recipe titles, ingredients, instructions, notes
- Photos you capture or import
- Cookbook attribution information
- Recipe card customizations (backgrounds, stickers, annotations)
- Collections and tags you create

**User-Generated Content:**
- Handwritten annotations on recipe cards
- Custom notes and modifications
- Shopping list items and check-off states
- Dinner party event details

### 2. Automatically Collected Information

**Device Information:**
- Device model and iOS version (for compatibility)
- App version number (for support)
- Crash logs and performance data (via Apple's analytics)

**Usage Analytics (Optional):**
- Feature usage patterns (aggregated, anonymized)
- Error logs for debugging
- Performance metrics
- You can opt out in Settings → Privacy

**Important:** We use privacy-preserving analytics. Events are:
- Anonymized (no personal identifiers)
- Aggregated across users
- Never linked to Apple ID or device ID
- Used solely for product improvement

### 3. Information from Third-Party Services

**Recipe Import:**
- When you import a recipe from a URL, we fetch publicly available recipe data
- Parsing happens on-device when possible
- Complex recipes may be sent to our secure server (GPT-4o-mini API) for parsing
- We immediately delete parsed content; nothing is stored server-side

**iOS Reminders Integration:**
- You can export shopping lists to Apple Reminders
- This uses Apple's EventKit API on your device
- We never access other reminders or calendar data
- Requires your explicit permission

**iCloud Sync (Optional):**
- If enabled, your recipes sync via Apple's CloudKit
- Data is encrypted and stored in your personal iCloud account
- We cannot access your iCloud data
- Apple's Privacy Policy applies to iCloud storage

**CloudKit Sharing (Optional):**
- When you share a styled recipe card, it's stored in CloudKit's public database
- Shared cards include: recipe content, styling, and your chosen display name
- You control what's shared; unshared recipes remain private

## How We Use Your Information

We use collected information for the following purposes:

### Core Functionality
- **Recipe Management:** Store, organize, and display your recipe collection
- **Smart Parsing:** Extract ingredients and instructions from URLs and photos
- **Shopping Lists:** Aggregate ingredients across recipes with automatic categorization
- **Reminders Export:** Generate iOS Grocery-type reminders with your permission
- **Personalization:** Save your card styling preferences and customizations
- **Sync:** Keep your recipes consistent across your Apple devices via iCloud

### Product Improvement
- **Analytics:** Understand which features are used most (anonymized)
- **Error Detection:** Identify and fix crashes or bugs
- **Performance:** Optimize app speed and responsiveness
- **Compatibility:** Ensure the app works across iOS versions

### Communication (Only When Necessary)
- **Critical Updates:** Security patches or data migration notices
- **Feature Announcements:** Major new capabilities (if you opt in)
- **Support:** Respond to your help requests

**We will never:**
- Send promotional emails
- Use your data for advertising
- Sell your information to third parties
- Share your recipes without explicit permission

## Data Storage and Security

### On-Device Storage
- **Primary Storage:** All recipes are stored locally on your iPhone using SwiftData
- **Encryption:** Data is protected by iOS's built-in encryption (when device is locked)
- **Security:** Only accessible by the Heirloom app and your iCloud account

### iCloud Sync (Optional)
- **Apple-Managed:** Data syncs through Apple's CloudKit infrastructure
- **Encryption:** End-to-end encrypted in transit and at rest
- **Ownership:** Stored in your personal iCloud account, not our servers
- **Privacy:** We cannot access your iCloud data

### CloudKit Public Database (Shared Recipes Only)
- **Limited Data:** Only recipes you explicitly share are stored publicly
- **No Personal Info:** Shared cards don't include your Apple ID or email
- **Revocable:** You can stop sharing or delete shared cards anytime

### Server-Side Processing (Temporary)
- **LLM Parsing:** Complex recipes may be sent to OpenAI's API for parsing
- **Immediate Deletion:** Content is deleted from our servers after parsing
- **No Training:** Your recipes are never used to train AI models (OpenAI API policy)
- **Security:** All API calls use HTTPS encryption

### Image Storage
- **Local Storage:** Recipe photos are stored on your device
- **iCloud Photos:** Synced via CloudKit (encrypted)
- **Optimization:** We create compressed versions for performance

## Data Retention

- **Active Recipes:** Retained as long as you use the app
- **Deleted Recipes:** Removed immediately from device; iCloud deletion follows Apple's schedule
- **Shared Recipes:** Remain in CloudKit until you remove them
- **Analytics:** Aggregated data retained for 2 years maximum
- **Crash Logs:** Deleted after 90 days
- **Account Deletion:** If you delete the app, all local data is removed; iCloud data persists until you delete it from your iCloud account

## Your Privacy Rights

### Access and Control
- **View Data:** All your recipes are accessible in the app
- **Export:** Export individual recipes as PDFs or share via CloudKit
- **Delete:** Delete individual recipes or all data at once
- **Sync Control:** Turn iCloud sync on/off in Settings

### GDPR Rights (EU Users)
If you're in the European Economic Area, you have the right to:
- **Access:** Request a copy of your data
- **Rectification:** Correct inaccurate data
- **Erasure:** Request deletion ("right to be forgotten")
- **Data Portability:** Export your data in a structured format
- **Object:** Opt out of optional data processing (analytics)

**To exercise these rights:** Email privacy@heirloomapp.com

### CCPA Rights (California Users)
If you're a California resident, you have the right to:
- **Know:** What personal information we collect and how it's used
- **Delete:** Request deletion of your personal information
- **Opt-Out:** Opt out of data "sale" (we don't sell data, so this is N/A)
- **Non-Discrimination:** Exercise rights without penalty

**To exercise these rights:** Email privacy@heirloomapp.com

### Children's Privacy (COPPA)
Heirloom is not directed to children under 13. We do not knowingly collect information from children under 13. If we discover we've collected data from a child under 13, we'll delete it immediately.

## Third-Party Services

We use the following third-party services:

### OpenAI (GPT-4o-mini API)
- **Purpose:** Fallback recipe parsing for complex sites
- **Data Shared:** Recipe URL and fetched HTML (temporarily)
- **Privacy Policy:** https://openai.com/privacy
- **Data Retention:** Deleted immediately after parsing per API settings

### Mixpanel (Analytics - Optional)
- **Purpose:** Understand feature usage and improve the app
- **Data Shared:** Anonymized usage events, no personal identifiers
- **Privacy Policy:** https://mixpanel.com/legal/privacy-policy
- **Opt-Out:** Available in Settings → Privacy

### Apple Services
- **CloudKit:** Data sync and sharing (encrypted)
- **EventKit:** Reminders integration (on-device only)
- **Sign in with Apple:** Authentication (no email required)
- **Privacy Policy:** https://apple.com/legal/privacy

**We do not use:**
- Advertising networks
- Social media trackers
- User profiling services
- Data brokers

## Cookies and Tracking

**Mobile App:** We do not use cookies in the iOS app. All data is stored via iOS frameworks (SwiftData, CloudKit).

**Website:** If we launch a marketing website, we will:
- Not use tracking cookies without consent
- Provide cookie preferences
- Only use essential cookies for functionality

## Data Sharing and Disclosure

### We Do Not Sell Your Data
We do not sell, rent, or trade your personal information to third parties for monetary or other valuable consideration.

### Limited Sharing Scenarios

**Service Providers:**
- OpenAI for recipe parsing (temporary, deleted after use)
- Mixpanel for analytics (anonymized, if you opt in)
- Apple for iCloud sync and Reminders (encrypted, Apple-managed)

**Legal Requirements:**
We may disclose information if required by:
- Valid legal process (subpoena, court order)
- Government requests (with transparency where legally permitted)
- Protection of rights, property, or safety
- Enforcement of Terms of Service

**Business Transfer:**
If Heirloom is acquired or merged, your data may transfer to the new entity. You'll be notified, and the new entity must honor this Privacy Policy.

**With Your Consent:**
We may share data in ways not described here if we have your explicit consent.

## International Data Transfers

**Primary Storage:** Your data is stored on your device and in your iCloud account (region-specific)

**Server Processing:** Recipe parsing via OpenAI may involve data transfers to the United States. We use:
- Standard contractual clauses (SCCs) for GDPR compliance
- Encryption in transit (HTTPS/TLS)
- Immediate deletion after processing

## Changes to This Privacy Policy

We may update this Privacy Policy to reflect:
- Changes in legal requirements
- New features or services
- Improvements to privacy practices

**Notification:**
- Material changes will be communicated via in-app notice
- "Last Updated" date will be revised
- Continued use constitutes acceptance

**Your Rights:**
If you disagree with changes, you can stop using the app and delete your data.

## Data Security Measures

We implement industry-standard security practices:

### Technical Safeguards
- **Encryption:** HTTPS for all network requests, iOS encryption at rest
- **API Security:** Secure tokens, rate limiting, CORS policies
- **Access Control:** Minimal server access, principle of least privilege
- **Monitoring:** Automated alerts for suspicious activity

### Organizational Safeguards
- **Privacy by Design:** Minimize data collection from architecture level
- **Employee Training:** Limited team with privacy awareness
- **Vendor Management:** Third-party services vetted for privacy practices
- **Incident Response:** Plan in place for potential breaches

**Breach Notification:**
In the unlikely event of a data breach, we will:
- Notify affected users within 72 hours (GDPR requirement)
- Provide details about the breach and mitigation steps
- Report to relevant authorities as required by law

## Contact Us

**Privacy Questions or Requests:**
Email: privacy@heirloomapp.com

**General Support:**
Email: support@heirloomapp.com

**Data Protection Officer (EU):**
For GDPR inquiries, contact: dpo@heirloomapp.com

**Mailing Address:**
[Company Legal Address - To Be Determined]

**Response Time:** We aim to respond to privacy requests within 30 days.

---

## Summary (TL;DR)

✓ **Privacy-First:** Most processing happens on your device
✓ **Minimal Data:** We only collect what's needed for features
✓ **No Ads:** We don't sell your data or show advertisements
✓ **User Control:** Delete your data anytime
✓ **Optional Sync:** iCloud sync is opt-in and Apple-managed
✓ **Transparent:** Clear communication about any server-side processing
✓ **GDPR/CCPA Compliant:** Full rights for EU and California users

**Your recipes are yours.** We're just helping you organize and share them beautifully.

---

**Document Version:** 1.0
**Last Reviewed:** December 8, 2024
**Next Review:** June 2025
