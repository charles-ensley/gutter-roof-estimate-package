# Flow Guide - Property Data Extraction and Pricing Calculation

This guide provides step-by-step instructions for creating the Flow that handles property measurement extraction, field updates, and pricing calculation.

## Flow Overview

**Flow Name:** Get Gutter Estimate  
**Type:** Screen Flow  
**Description:** Extracts property measurements using AI, updates Contact fields, and calculates pricing estimate

## Flow Structure

```
Start → Prepare Estimate Screen → Get Contact → Extract Measurements (Prompt) → 
Parse JSON → Update Contact Fields → Calculate Pricing (Apex) → Success Screen → End
```

---

## Step-by-Step Flow Configuration

### 1. Flow Start

**Element:** Start  
**Type:** Screen Flow Start

**Configuration:**
- **Label:** Start
- **Description:** Begin property measurement extraction flow

**Output Variables:**
- `contactId` (Text) - Contact ID from record page or input

---

### 2. Prepare Estimate Screen

**Element:** Screen  
**Type:** Screen

**Purpose:** Collect initial information and confirm contact

**Screen Components:**

1. **Contact Lookup**
   - **API Name:** `selectedContact`
   - **Label:** Select Contact
   - **Required:** Yes
   - **Object:** Contact
   - **Pre-populate:** If `contactId` is provided, use it

2. **Information Text**
   - **Text:** "This flow will analyze aerial imagery to extract property measurements and calculate a gutter cleaning estimate. Please ensure the contact has a complete mailing address."

**Navigation:**
- **Next Button Label:** Continue
- **Previous Button:** None (first screen)

---

### 3. Get Contact Record

**Element:** Get Records  
**Type:** Get Records

**Purpose:** Retrieve contact with all necessary fields

**Configuration:**
- **Object:** Contact
- **Filter:** `Id` equals `{!selectedContact.Id}`
- **Get:** First record

**Fields to Retrieve:**
- `Id`
- `Name`
- `MailingStreet`
- `MailingCity`
- `MailingState`
- `MailingPostalCode`
- `MailingCountry`
- `MailingLatitude`
- `MailingLongitude`
- `Property_Measurement_Details__c`
- `Has_Gutter_Guards__c`
- `Walkable__c`
- `Copper_Material__c`
- `New_Customer__c`

**Store Values:**
- **Variable:** `currentContact` (Record Variable, Contact)

---

### 4. Build Prompt Input

**Element:** Assignment  
**Type:** Assignment

**Purpose:** Construct the prompt text for AI analysis

**Configuration:**

**New Resources:**
- `promptText` (Text) - Store the full prompt

**Formulas:**

```
promptText = 
"You are an expert property measurement analyst specializing in gutter cleaning and roof maintenance estimates. Your task is to analyze aerial imagery of a property and extract precise measurements and assessments.

## Input
Property Address: " + {!currentContact.MailingStreet} + ", " + {!currentContact.MailingCity} + ", " + {!currentContact.MailingState} + " " + {!currentContact.MailingPostalCode} + "

Nearmap Image URL: https://apps.nearmap.com/maps/#/@" + {!currentContact.MailingLatitude} + "," + {!currentContact.MailingLongitude} + ",19z

## Task
Analyze the aerial imagery and extract the following information:

### 1. Property Perimeter Measurements
For each floor level visible in the imagery:
- Identify all perimeter segments (straight-line measurements along the building edges)
- Measure each segment in feet
- List segments in clockwise order around the building perimeter

### 2. Walkability Assessment
Determine if the roof is walkable based on roof pitch/steepness, material type, accessibility factors, and safety considerations.
Output: 'Yes' or 'No'

### 3. Gutter Material Assessment
Identify the gutter material type, looking for distinctive copper coloring or characteristics.
Output: 'Yes' (copper) or 'No' (not copper)

## Output Format
Output ONLY valid JSON with this exact structure:

{
  \"floor1Segments\": [32.74, 29.52, 34.62, 28.84],
  \"floor2Segments\": [49.91, 27.89, 28.57, 7.24, 24.44, 37.83],
  \"floor3Segments\": [],
  \"walkable\": \"Yes\",
  \"copperMaterial\": \"No\"
}

## Critical Instructions
1. Only output raw perimeter segment numbers - do NOT calculate sums
2. Include ALL segments in clockwise order around the building
3. Use empty array [] for floor3Segments if there is no third floor
4. Output ONLY valid JSON - no additional text or explanations
5. Be precise - accuracy is critical for pricing calculations"
```

**Note:** Adjust the prompt based on your AI service (Einstein Prompt Builder, GPT-4 Vision, Claude, etc.)

---

### 5. Extract Measurements (Prompt Action)

**Element:** Action  
**Type:** Prompt Builder Action (or External Service)

**Purpose:** Call AI service to extract measurements

**Configuration:**

**If using Salesforce Prompt Builder:**
- **Prompt Template:** Use the prompt template from `docs/04-PROMPT_TEMPLATE.md`
- **Input:** `{!promptText}`
- **Model:** GPT-4 Vision or Claude (with image analysis)
- **Image Input:** Nearmap image URL or attached image

**If using External Service (HTTP Callout):**
- **Endpoint:** Your AI service endpoint
- **Method:** POST
- **Headers:** Authorization, Content-Type
- **Body:** JSON with prompt and image URL

**Output:**
- `promptResponse` (Text) - Raw JSON response from AI

**Error Handling:**
- Add decision element to check if response is valid JSON
- If invalid, show error screen and allow retry

---

### 6. Parse JSON Response

**Element:** Assignment  
**Type:** Assignment

**Purpose:** Extract values from JSON response

**Configuration:**

**New Resources:**
- `parsedFloor1Segments` (Text) - JSON array string for floor 1
- `parsedFloor2Segments` (Text) - JSON array string for floor 2
- `parsedFloor3Segments` (Text) - JSON array string for floor 3
- `parsedWalkable` (Text) - "Yes" or "No"
- `parsedCopperMaterial` (Text) - "Yes" or "No"

**Formulas:**

Use `REGEX` or `SUBSTITUTE` functions to extract values, or use an Apex Invocable method for JSON parsing.

**Alternative: Use Apex Invocable Method**

Create a simple Apex invocable method to parse JSON:

```apex
@InvocableMethod(label='Parse Measurement JSON')
public static List<ParseResult> parseMeasurementJSON(List<String> jsonStrings) {
    // Parse JSON and return structured data
}
```

---

### 7. Update Contact Fields

**Element:** Update Records  
**Type:** Update Records

**Purpose:** Update Contact with extracted measurements

**Configuration:**
- **Object:** Contact
- **Record:** `{!currentContact}`

**Fields to Update:**

1. **Property_Measurement_Details__c**
   - **Value:** `{!promptResponse}` (store raw JSON)

2. **Walkable__c** (Optional - only if not already set)
   - **Value:** `{!parsedWalkable}`
   - **Condition:** `{!currentContact.Walkable__c}` is null or blank

3. **Copper_Material__c** (Optional - only if not already set)
   - **Value:** `{!parsedCopperMaterial}`
   - **Condition:** `{!currentContact.Copper_Material__c}` is null or blank

**Error Handling:**
- Add fault path for update failures
- Show error message to user

---

### 8. Calculate Gutter Pricing Estimate (Apex Action)

**Element:** Action  
**Type:** Apex Action

**Purpose:** Calculate and update pricing estimate

**Configuration:**
- **Apex Class:** `GutterPricingEstimateController`
- **Method:** `calculateAndUpdateEstimate`

**Input:**
- `contactIds` (List<Id>) = `[{!currentContact.Id}]`

**Output:**
- None (updates `Gutter_Cost_Estimate__c` directly)

**Error Handling:**
- Add fault path
- Show error message if calculation fails

---

### 9. Success Screen

**Element:** Screen  
**Type:** Screen

**Purpose:** Confirm completion and show results

**Screen Components:**

1. **Success Message**
   - **Text:** "Property measurements extracted successfully! Pricing estimate has been calculated."

2. **Display Fields** (Optional)
   - Show `Gutter_Cost_Estimate__c` from updated contact
   - Or use a Get Records element to retrieve updated contact

3. **Navigation Buttons**
   - **Finish Button:** "Done" → Navigate to Contact record
   - **Back Button:** None

**Navigation:**
- **Finish:** Navigate to Record
  - **Record:** `{!currentContact.Id}`
  - **Object:** Contact

---

### 10. Error Handling Screens

**Element:** Screen  
**Type:** Screen

**Create separate error screens for:**

1. **Invalid JSON Response**
   - Message: "The AI response was not in the expected format. Please try again or enter measurements manually."
   - Options: Retry or Cancel

2. **Geocoding Required**
   - Message: "Address coordinates are required. Please geocode the address first using the Nearmap component."
   - Option: Cancel

3. **Calculation Error**
   - Message: "An error occurred while calculating the estimate. Please check the property measurement data."
   - Option: Cancel

---

## Flow Variables Summary

### Input Variables
- `contactId` (Text) - Optional, from record page

### Screen Components
- `selectedContact` (Contact) - Selected contact from lookup

### Record Variables
- `currentContact` (Contact) - Retrieved contact record

### Text Variables
- `promptText` (Text) - Constructed prompt
- `promptResponse` (Text) - AI response JSON
- `parsedFloor1Segments` (Text) - Extracted floor 1 segments
- `parsedFloor2Segments` (Text) - Extracted floor 2 segments
- `parsedFloor3Segments` (Text) - Extracted floor 3 segments
- `parsedWalkable` (Text) - Extracted walkable assessment
- `parsedCopperMaterial` (Text) - Extracted copper material assessment

---

## Decision Points

### Decision 1: Check if Contact Has Coordinates

**Element:** Decision  
**Type:** Decision

**Outcome 1:** `{!currentContact.MailingLatitude}` is not null AND `{!currentContact.MailingLongitude}` is not null
- **Path:** Continue to prompt building

**Outcome 2:** Default (no coordinates)
- **Path:** Show "Geocoding Required" error screen

---

### Decision 2: Validate JSON Response

**Element:** Decision  
**Type:** Decision

**Outcome 1:** `{!promptResponse}` contains `"floor1Segments"`
- **Path:** Continue to parsing

**Outcome 2:** Default (invalid JSON)
- **Path:** Show "Invalid JSON Response" error screen

---

## Flow Activation

1. **Save Flow**
2. **Activate Flow**
3. **Add to Contact Record Page:**
   - Use Flow component in Lightning App Builder
   - Or create a button/quick action to launch flow

---

## Testing Checklist

- [ ] Flow launches from Contact record page
- [ ] Contact lookup works correctly
- [ ] Prompt is constructed with correct address
- [ ] AI service returns valid JSON
- [ ] JSON is parsed correctly
- [ ] Contact fields are updated
- [ ] Pricing calculation runs successfully
- [ ] Success screen displays correctly
- [ ] Error handling works for invalid responses
- [ ] Error handling works for missing coordinates

---

## Alternative: Simplified Flow (Manual Entry)

If AI extraction is not available, create a simplified flow for manual entry:

1. **Screen:** Enter Measurements
   - Text input for floor segments (comma-separated)
   - Picklist for Walkable (Yes/No)
   - Picklist for Copper Material (Yes/No)

2. **Assignment:** Format as JSON
   - Convert manual inputs to JSON format

3. **Update Contact:** Same as step 7

4. **Calculate Pricing:** Same as step 8

---

## Integration with Nearmap Component

To integrate with Nearmap MapBrowser component:

1. **Add Flow Button to Nearmap Component:**
   - Create a custom button in the component
   - Launch flow when clicked
   - Pass contact ID automatically

2. **Pre-populate Coordinates:**
   - Flow can use coordinates from Nearmap
   - Include in prompt for better accuracy

---

## Notes

- Flow can be triggered from:
  - Contact record page (Flow component)
  - Quick action button
  - Custom button in LWC component
  - Automated trigger (not recommended for user interaction)

- Consider adding:
  - Progress indicators during AI processing
  - Ability to review/edit extracted measurements
  - Option to attach custom images
  - History tracking of estimates

- For production:
  - Add error logging
  - Add performance monitoring
  - Consider batch processing for multiple contacts
  - Add user permissions checks
