# GTM Activity Locator

A Salesforce app that takes raw, messy supplier notes about travel activities, cleans them up using AI, pins them on a map, and lets ops users find what's available in any city.

---

## What I Built

### Part 1 — Data Model

- A `Supplier__c` object (the company that runs tours)
- An `Activity__c` object linked to it (the actual tour/experience)
- A Geolocation field so we can do "find everything within 10km" searches directly in SOQL
- Address fields, a big text field for raw supplier notes, and structured fields that AI fills in (category, duration, languages, accessibility, who it's good for, a polished listing summary)
- A Permission Set so any user can get access without messing with profiles
- Loaded all 10 sample activities from the CSV

### Part 2 — Geocoding

- When you save an activity with an address but no coordinates, it automatically calls OpenCage to get the lat/lng
- Runs in the background (Queueable) so it doesn't slow down the user's save
- Works in bulk — if you import 50 records at once, it handles them all
- API key stored in Custom Metadata, not in code
- Tests mock the HTTP response so they run without hitting the real API

### Part 3 — AI Extraction

- An "Enrich Activity" button (Flow action) sends the messy supplier notes to Mistral AI
- AI returns structured JSON: picks the right category, extracts duration, figures out languages, determines accessibility, identifies the target audience, and writes a clean 2-sentence listing summary
- If the AI returns garbage, the code catches it — invalid categories default to "Other", broken JSON shows a clear error message in the Flow
- Not triggered on every save (that would be expensive and slow) — ops user clicks it when they're ready
- Tests cover: good response, markdown-wrapped response, hallucinated values, broken JSON, auth errors, rate limits, server errors, empty notes

### Part 4 — Interactive Map

- A Leaflet map loaded from a Static Resource (no external CDN, no API key needed)
- Search by city name, filter by category and "good for" audience
- Pins are color-coded by category with a legend at the bottom
- Click a pin → the list item highlights and scrolls into view
- Click a list item → the map flies to that pin and opens its popup
- Shows a warning if there are more than 50 results ("filter or zoom in to see more")
- Works on the App Page tab AND on individual Activity record pages (auto-shows nearby activities)

### Part 5 — Skipped on purpose

- The brief says skipping this costs nothing
- Parts 1–4 already prove three different integration patterns
- I used the time to write better tests and make things solid for the live walkthrough

---

## How to Set It Up

### You need

- A free Salesforce Developer org → https://developer.salesforce.com/signup
- A free Mistral API key → https://console.mistral.ai
- A free OpenCage API key → https://opencagedata.com/users/sign_up

### Deploy the code

```bash
sf org login web --alias gtm-org
sf project deploy start --target-org gtm-org
```

### After deploying

1. Go to Setup → Custom Metadata Types → Integration Setting → Manage Records
   - Create `MistralKey` with your Mistral key in the API_Key field
   - Create `OpenCage` with your OpenCage key in the API_Key field
2. Assign the permission set (required to use the app):
   ```bash
   sf org assign permset --name GOTOM_TravelExperiencesApplication --target-org gtm-org
   ```
3. Import the sample data from `data/sample-activities.csv` using Data Import Wizard
4. Run the tests:
   ```bash
   sf apex run test --target-org gtm-org --test-level RunLocalTests --code-coverage
   ```
5. Open the **GOTOM Travel Experience** app from the App Launcher — it has tabs for Suppliers, Activities, and the Activity Map

---

## Why I Made These Choices

| Choice                                | Reason                                                                                  |
| ------------------------------------- | --------------------------------------------------------------------------------------- |
| Master-Detail relationship            | An activity without a supplier makes no sense — this enforces that                      |
| Geolocation field                     | Lets me write `WHERE DISTANCE(...) < 10` in SOQL — can't do that with two number fields |
| Mistral instead of Gemini             | Gemini gives zero free quota in EU — literally won't work without a credit card         |
| Flow button instead of trigger for AI | LLM calls are slow and cost money — user should decide when to run them                 |
| Queueable for geocoding               | Doesn't block the save, handles bulk, respects Salesforce callout limits                |
| Leaflet from Static Resource          | No CDN, no API key, works offline, version controlled                                   |
| Cap at 50 results                     | Keeps the map readable — tells the user to filter if there are more                     |
| Restricted picklists                  | If AI hallucinates a value, Salesforce itself rejects it — double safety                |

---

## What I'd Do Next

- Marker clustering for when there are hundreds of activities
- A radius slider on the map so users can control the search area
- Batch Apex to re-run AI extraction when the prompt improves
- Part 5 (nearby POIs from OpenTripMap) as a "what else is near here" widget
- Retry logic with backoff for when APIs are temporarily down
- Jest tests for the LWC component

---

## Test Coverage

| Class                        | Test Class                  | Coverage |
| ---------------------------- | --------------------------- | -------- |
| `ActivityMapController`      | `ActivityMapControllerTest` | 98%      |
| `ActivityGeocodingQueueable` | `ActivityGeocodingTest`     | 92%      |
| `ActivityTriggerHandler`     | `ActivityGeocodingTest`     | 94%      |
| `AIExtractionService`        | `AIExtractionServiceTest`   | 82%      |
| `GetLLMResponse`             | `AIExtractionServiceTest`   | 89%      |
