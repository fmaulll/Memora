# Nudge subscriptions and Settings

Home's gear opens Settings directly. Profile supports permanent-account editing,
credential creation for guests (`/auth/upgrade`), and explicitly confirmed guest
merging (`/auth/merge`). An ordinary login remains separate from a merge.

## Configure before purchase testing

In `Memora/Info.plist`, set:

- `APIBaseURL`: the correct backend origin. The existing local development URL is retained.
- `SubscriptionProductIDs`: real auto-renewable subscription IDs from App Store Connect.
- `PrivacyPolicyURL` and `TermsOfUseURL`: the published HTTPS legal pages.

Product IDs and legal URLs are intentionally empty. The paywall does not invent
prices or offer terms; purchase controls remain unavailable until configured.
Prices and periods come from StoreKit. Any eligible offer is confirmed by Apple.

Use the matching sandbox backend/database for sandbox and TestFlight purchases.
The supplied backend rejects local Xcode StoreKit-test signatures. Apple server
credentials, notifications V2, database migrations, and hourly reconciliation
remain backend/deployment responsibilities described in the backend contract.

## Access and recovery

Auth responses supply the backend account token, free-deck allowance, and
entitlement. StoreKit purchases attach that exact token. Only backend verification
can grant access; expiration/grace deadlines also stop local access. Canceling
renewal does not end a valid paid period. Foreground/session restoration refreshes
status; Settings offers explicit reconciliation and Apple's management sheet.

New transactions remain unfinished until backend processing succeeds. Signed
transactions are also queued in account-scoped Keychain storage, including
restores that StoreKit already considers finished. Transient failures retry with
backoff, on foreground, and after relaunch. Ownership conflicts are surfaced and
never automatically merge accounts. Pending verification copies move only during
an explicitly confirmed guest merge.

AI generation persists the request body and idempotency key per account until its
local deck is saved. Settings can resume interrupted requests after relaunch.
Retries of failed admitted jobs have no request body. HTTP 402 opens the paywall
without discarding the current plan; the user can retry after subscribing.
Generated chapter metadata is not rewritten through deck updates.

The existing first-onboarding-deck preview lock is retained as a client product
flow; the supplied backend does not require subscription for reading existing
content. It must not be treated as server-enforced content protection.

Debug builds include onboarding replay and manual sync. Onboarding replay keeps
the current account and decks, returns Home after the profile step, and does not
reset server allowances. Fake subscription switches have been removed.

## Verification still requiring Apple configuration

Run a real sandbox purchase, restore, pending approval, renewal, cancellation,
refund, account-ownership conflict, and backend outage/relaunch recovery. Confirm
App Store legal links and actual product descriptions before release. Unit tests
cover contract decoding, access deadlines, error payloads, idempotency persistence,
metadata omission, and preserving local study state through an explicit merge.
