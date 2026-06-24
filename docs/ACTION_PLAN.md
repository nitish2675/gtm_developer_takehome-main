# Action Plan — GTM Developer Take-Home

## Strategic Scoping Decisions

### BUILD (Parts 1–4 — the core)

| Part | What | Why |
|------|------|-----|
| 1 | Data Model: `Supplier__c` → `Activity__c` with Geolocation field | Foundation for everything; Geolocation compound field enables native DISTANCE() in SOQL |
| 2 | Geocoding: OpenCage via Named Credential | Free/no-card, bulk-safe, clean separation of secrets |
| 3 | AI Extraction: Groq (Llama 3) for structured JSON | Free/no-card, works globally (no EU quota issue like Gemini), fast inference |
| 4 | Discovery Map: Leaflet + OSM tiles as Static Resource | Brief explicitly says this scores higher than lightning-map; real JS lib experience |

### SKIP (and why)

| What | Why |
|------|------|
| Part 5 — Nearby Attractions (OpenTripMap) | Brief says "skipping costs nothing." Time better spent making Parts 1-4 bulletproof and testable |
| Complex clustering on map | Note it in README as "what I'd do next"; cap results at 50 with user messaging instead |
| Trigger-based LLM calls | Cost/latency concern — use an Invocable Action (button/flow) so ops users control when AI runs |
| Over-engineered data model | No Booking__c, no Traveler__c — just Supplier + Activity as the brief scopes it |

---

## Architecture Decisions (defend in walkthrough)

1. **Geolocation compound field** (`Location__c`) instead of separate lat/lng numbers — enables `WHERE DISTANCE(Location__c, GEOLOCATION(:lat,:lng), 'km') < :radius` natively
2. **Named Credential** for OpenCage (key in Auth Header); **Protected Custom Metadata** for Groq API key (key goes in `Authorization: Bearer` header — Named Credential works here too)
3. **Invocable Action** for AI extraction — not a trigger. LLM calls are expensive, slow, and shouldn't fire on every field edit. Ops user clicks "Extract Details" deliberately
4. **Queueable** for geocoding after insert/update (bulk-safe, respects callout limits, retry-friendly)
5. **Leaflet from Static Resource** — no CDN dependency, no API key, full control over version

---

## Execution Order (dependency-driven)

### Phase 1 — Foundation (do first, everything depends on it)

- [ ] **1.1** Create `Supplier__c` object + fields (Name, Email, Phone, Status picklist)
- [ ] **1.2** Create `Activity__c` object + all fields:
  - Title (Name field)
  - Street__c, City__c, Country__c, Postal_Code__c (text)
  - Location__c (Geolocation compound field)
  - Supplier_Notes__c (Long Text Area 32000)
  - Category__c (Picklist: Sightseeing, History & Culture, Food & Drink, Outdoor & Adventure, Family, Nightlife)
  - Duration__c (Text — "2 hours", "1.5h" — freeform from LLM)
  - Languages__c (Multi-select or Text)
  - Accessibility__c (Picklist: Yes, No, Partial)
  - Good_For__c (Multi-select: Families, Couples, Solo, Groups, History Buffs)
  - Listing_Summary__c (Long Text Area 1000)
  - Enrichment_Status__c (Picklist: Pending, Geocoded, Enriched, Failed)
  - Lookup to Supplier__c
- [ ] **1.3** Import `sample-activities.csv` (10 records) — create matching Supplier records
- [ ] **1.4** Commit: "feat: data model + seed data"

### Phase 2 — Geocoding Integration

- [ ] **2.1** Create Named Credential + External Credential for OpenCage
- [ ] **2.2** Write `OpenCageGeocodingService.cls` — single-record geocode method
- [ ] **2.3** Write `ActivityGeocodingQueueable.cls` — bulk handler, processes list of Activity IDs
- [ ] **2.4** Wire trigger or Flow: after insert/update when address present + no coordinates → enqueue
- [ ] **2.5** Write `OpenCageGeocodingServiceTest.cls` with HttpCalloutMock:
  - Happy path: valid address → lat/lng stored
  - No results: bad address → status set to Failed, no crash
  - Timeout/error: graceful handling
  - Bulk: 5 records inserted → all geocoded
- [ ] **2.6** Commit: "feat: OpenCage geocoding with bulk-safe queueable"

### Phase 3 — AI Structured Extraction

- [ ] **3.1** Create Protected Custom Metadata Type `AI_Config__mdt` (Endpoint__c, API_Key__c, Model__c) OR Named Credential for Groq
- [ ] **3.2** Write `AIExtractionService.cls`:
  - Builds prompt with supplier notes + title + city
  - Calls Groq API (Llama 3.1 8B — fast, cheap, structured output capable)
  - Parses JSON response with validation (missing fields → default, unknown category → "Sightseeing")
  - Maps extracted values to Activity__c fields
- [ ] **3.3** Write `AIExtractionInvocable.cls` — `@InvocableMethod` for Flow/button use
- [ ] **3.4** Write `AIExtractionServiceTest.cls` with HttpCalloutMock:
  - Clean response → all fields populated correctly
  - Malformed JSON (LLM wraps in ```json``` markers) → still parses
  - Missing field → defaults applied, no exception
  - Invalid category value → mapped to closest valid picklist value or default
- [ ] **3.5** Commit: "feat: Groq LLM extraction with robust parsing"

### Phase 4 — Discovery Map LWC

- [ ] **4.1** Download Leaflet 1.9.x JS+CSS → upload as Static Resource `leaflet`
- [ ] **4.2** Write `ActivityMapController.cls` — Apex controller:
  - `searchActivities(Decimal lat, Decimal lng, Decimal radiusKm, String category, String goodFor)`
  - Uses `DISTANCE(Location__c, GEOLOCATION(:lat, :lng), 'km') < :radius`
  - Returns wrapper with Id, Name, Category, Location, etc.
  - `searchByCity(String city)` — fallback text search
- [ ] **4.3** Write `ActivityMapControllerTest.cls`:
  - Insert activities with known coords → search by radius → correct results returned
  - Category filter → only matching returned
  - Empty results → empty list, no error
- [ ] **4.4** Build `activityMap` LWC:
  - Load Leaflet from Static Resource via `loadScript`/`loadStyle`
  - Search input (city name or lat/lng + radius slider)
  - Map renders with OSM tiles
  - Pins colored by Category__c
  - Filter panel: category checkboxes, "Good For" dropdown
  - List panel synced with map (click pin → highlight list, click list → fly to pin)
  - States: loading spinner, empty "No activities found", error toast
  - Cap at 50 results with message "Showing 50 of N — zoom in or filter to narrow"
- [ ] **4.5** Create Lightning App Page + Tab to host the LWC
- [ ] **4.6** Write Jest test for LWC (mock Apex, verify render states)
- [ ] **4.7** Commit: "feat: Leaflet discovery map with category filters"

### Phase 5 — Polish & Deliverables

- [ ] **5.1** Write `README.md` — setup steps, free accounts needed, design decisions, trade-offs, "what I'd do next"
- [ ] **5.2** Write `AI_USAGE.md` — tools used, effective prompts (include extraction prompt), where AI was wrong, what I didn't delegate
- [ ] **5.3** Create user `muna.yaffai@getyourguide.com` as System Administrator in dev org
- [ ] **5.4** Final deploy to clean org, verify end-to-end
- [ ] **5.5** Commit: "docs: README, AI_USAGE, submission prep"

---

## Key Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Groq free tier rate limits | Batch extraction (process all 10 at once off-hours), not triggered per-save |
| OpenCage 2500/day limit | Queueable with retry; geocode only when address changes |
| Leaflet static resource size | Leaflet core is ~40KB gzipped — well within SF 5MB limit |
| LLM returns invalid JSON | Regex strip markdown fences, try-catch parse, field-level defaults |
| DISTANCE() requires non-null geolocation | WHERE clause guards: `Location__c != NULL` |

---

## "What I'd Do Next" (README talking points)

- Clustering (Leaflet.markercluster) for 1000+ activities
- Batch Apex for nightly re-extraction when prompt/schema changes
- Platform Events for async status updates to the UI during extraction
- Part 5 (OpenTripMap nearby POIs) as a record-page component
- Retry framework with exponential backoff for all callouts
- Field-level security + permission sets for the Activity fields
