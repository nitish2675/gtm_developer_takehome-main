# Salesforce Developer — Take-Home Assessment

**Use AI — we assume you will.** Copilot, Cursor, Claude Code, whatever you use day-to-day. With an assistant, the code here is a few hours' work, and we know it. So **we are not measuring hours or whether you can produce the code.** We're measuring the things AI *doesn't* hand you for free:

- **Judgment** — did you make sound calls on data model, when to call the LLM, how to handle secrets, where things can break at scale?
- **Verification** — did you catch where the AI was wrong? (It will be. Provider quirks, malformed JSON, plausible-but-wrong config.)
- **Understanding** — can you explain every line and confidently change it live?

Build the **core (Parts 1–4)**; the bonus (Part 5) is genuinely optional. A clean, well-understood core with honest "what I'd do next" notes beats a sprawling half-working everything. **The live walkthrough (below) is where this is really decided** — the repo just gets you there.

**We don't expect you to finish all of it — that's intentional.** What you choose to build, what you deliberately skip, and *why* is part of what we're assessing. Scope it like a real sprint, prioritise, and explain your calls in the README. We'd much rather see three things done well and reasoned about than everything done halfway.

**Timing:** You have **3 working days** from when you receive this repo to submit. If life gets in the way, tell us — we'd rather adjust the window than have you rush.

---

## Context

We're a marketplace for travel experiences. **Suppliers** list **activities** (tours, attractions, day trips) that happen at a physical **meeting point**, and travelers book them. Internally, our ops and content teams work in Salesforce to onboard suppliers, manage their activities, and turn raw supplier-provided information into polished, customer-facing listings — then help travelers discover what's available in a destination.

This exercise is a slice of that world: take messy supplier input, enrich it (location + structured, AI-extracted detail), and make it **discoverable on a map**.

You'll build this in a **free Salesforce Developer Edition org** and deliver it as an SFDX source-format repo in **GitHub**.

---

## What to build

### Part 1 — Data model
Model an **Activity** (`Activity__c` is fine; a `Supplier__c` parent is a nice touch). Include at least:
- Title + meeting-point address (Street, City, Country, Postal Code)
- `Latitude__c` / `Longitude__c` — **use a Geolocation field** if you can (you'll want it for Part 4's distance search)
- `Supplier_Notes__c` (long text — raw, messy notes from the supplier)
- The **AI-extracted fields** from Part 3 (Category, Duration, Languages, Accessibility, "Good for", Listing Summary)

Justify your modeling choices briefly in the README.

**Seed data:** import the provided **`data/sample-activities.csv`** (10 real activities with deliberately messy supplier notes) — please use it rather than inventing your own, so we're all working from the same input.

### Part 2 — Geocoding integration
When an Activity has a meeting-point address but no coordinates, **geocode it** via an external API and store lat/long.
- **No hardcoded keys or endpoints in Apex.** Suggested: **[OpenCage](https://opencagedata.com/)** (free, no card). Document your choice.
- Handle failures (no result, timeout, bad address). Be bulk-safe (suppliers upload in batches).
- **Apex tests** with `HttpCalloutMock` and meaningful assertions — not coverage theater.

### Part 3 — AI structured extraction (the interesting one)
Send `Supplier_Notes__c` (plus title/city) to an **LLM** and have it return **structured JSON** that you parse and write to typed fields — not just prose. Extract at least:
- `Category__c` (picklist — e.g. Sightseeing, History & Culture, Food & Drink, Outdoor & Adventure, Family, Nightlife)
- `Duration__c`, `Languages__c`, `Accessibility__c` (e.g. wheelchair Yes/No/Partial), `Good_For__c` (e.g. Families / Couples / Solo)
- `Listing_Summary__c` (2–3 sentence customer-facing blurb)

What we're really testing here:
- **Prompt engineering for reliable structured output** (constrain the schema; map free text to your picklist values).
- **Robust parsing & validation** — the model *will* sometimes omit a field, invent a category, or wrap JSON in prose. Handle it; don't let one bad response corrupt the record.
- **Key handling without secrets in source** (Named Credential, protected Custom Metadata, etc.). Note: a key that must go in the URL query string can't use Named Credential merge fields — reason about it.
- ⚠️ **Provider choice:** some providers (notably **Google Gemini**) grant **zero free-tier quota in the EU/EEA** — a card-free key there fails with a quota error. **Groq** and **Mistral** work card-free in Europe. Pick one that works in your region; document it.
- Decide **when** to call the LLM (cost/latency — not on every save). Tests with a mocked callout.

### Part 4 — Discovery map (the LWC)
Build a Lightning Web Component (on an App page or tab — not just the record page) that lets an ops user **discover activities on a map**:
- **Search by city/area** (or a point + radius) and show matching activities as **pins on an interactive map**.
- Suggested stack: **Leaflet + OpenStreetMap tiles** from a **Static Resource** (no key, no card). `lightning-map` is allowed but scores lower — loading a real JS lib is closer to the job.
- **Color the pins by `Category__c`**, and let the user **filter** by category (and ideally by "Good for").
- Show a **list synced with the map** (click a pin → highlight/scroll the list item, and vice-versa).
- Proper **loading / empty / error** states; sensible behavior with many records (clustering or capping + a note).
- Use **geolocation distance** (SOQL `DISTANCE`/`GEOLOCATION`, or justified alternative) for the radius search.

### Part 5 — Nearby attractions *(BONUS — optional)*
On a single activity, show **what's around the meeting point** — the "what else can travelers do here" angle. Free option: **[OpenTripMap](https://opentripmap.com)** (free key) returns POIs by lat/long + radius. Pin or list a few near the meeting point. This is a **third integration**; treat it like the others (no secrets in source, error handling). Skipping it costs nothing — a strong Parts 1–4 is what matters.

---

## Deliverables

1. **GitHub repo**, SFDX source format, deploys cleanly to a fresh Developer Edition org.
2. **README.md** — setup steps, the keys/free accounts a reviewer needs, design decisions, trade-offs, and what you'd do with more time.
3. **AI_USAGE.md** — *graded, not optional:*
   - Which AI tools you used and for what.
   - 2–3 example prompts you found effective (including your **extraction prompt** from Part 3).
   - At least one place the AI was **wrong/misleading** and how you caught it.
   - What you chose **not** to delegate, and why.
4. **Org access for review** — so we can log in and see your work running, create an **active User** in your Dev org for **muna.yaffai@getyourguide.com** (Setup → Users → New User; the **System Administrator** profile is fine). Salesforce emails that address an activation link; please make sure the user is active before you submit.

## Ground rules
- Don't commit secrets. Keep keys in credentials/config, use `.gitignore`.
- A working, well-tested core beats a broken everything. **Scope honestly** and tell us what you cut.
- **Live walkthrough (~30–45 min — where this is really decided):** you screen-share, walk us through *why* you made your key decisions, and make a small change or two live (e.g. add a filter, adjust the extraction schema, or debug something we point at). We're probing understanding and judgment, not memorization.
