# Creator referrals

## How it works today

There is no creator list and no admin screen. **Any code is accepted as
typed.** To onboard a creator you just agree a code with them and tell them to
say it in their video. Nothing to deploy, nothing to configure.

The user taps "Have a creator code?" on the signup screen and types it. It is
uppercased and stripped of punctuation, so `jane`, `Jane` and `JANE!` all
become `JANE`.

## Where the code goes

| Destination | What it gives you |
| --- | --- |
| Firestore `users/{uid}.referral_code` | Who came from whom |
| Firebase Analytics `referral_applied` event | Signup counts per code |
| Firebase Analytics user property `referral_code` | Every later event sliceable by creator |
| RevenueCat campaign + `referral_code` attribute | **Revenue per creator**, the payout number |

## Reading the numbers at payout time

- **Money**: RevenueCat, filter or chart by campaign. This is the figure to pay against.
- **Funnel**: Firebase Analytics, compare `sign_up` against `referral_applied`,
  then subscriptions, using the user property.
- **Headcount**: Firestore, query `users` where `referral_code == 'JANE'`.

## Rules that keep this clean

**Use short, unmistakable codes.** First name only, no digits, no similar
looking pairs. `JANE` is good. `JAYNE01` invites typos.

**Never reuse a code.** If a partnership ends, retire the code rather than
giving it to someone else, or the history becomes unreadable.

**Keep the roster below.** Nothing in the app validates codes, so this file is
the only record of which code belongs to whom.

## Known limitation

A mistyped code becomes its own bucket that belongs to nobody. With a handful
of creators this is easy to spot. Past roughly ten, it gets expensive.

## The upgrade, when you need it

Add a Firestore `creators` collection (code, name, payout rate, active) and
validate the code at signup. Then unrecognised codes are rejected at entry,
creators are added from the Firebase console with no app release, and reports
show real names rather than codes.

Trigger for doing this: more than about ten active creators, or the first time
an unattributed bucket appears that you cannot trace.

## Roster

| Code | Creator | Platform | Agreed rate | Started | Active |
| --- | --- | --- | --- | --- | --- |
| | | | | | |
