# Prompt Template - Property Measurement Extraction

This document provides the prompt template for AI-powered property measurement extraction, gutter material assessment, and walkability assessment.

## Overview

The prompt template is designed to be used with Salesforce Prompt Builder or similar AI services (like Einstein Prompt Builder, GPT-4 Vision, or Claude with image analysis). It analyzes aerial imagery (from Nearmap or similar sources) to extract:

1. **Property perimeter measurements** for each floor
2. **Walkability assessment** (whether roof is walkable)
3. **Gutter material assessment** (detecting copper material)

## Prompt Template

```
You are an expert property measurement analyst specializing in gutter cleaning and roof maintenance estimates. Your task is to analyze aerial imagery of a property and extract precise measurements and assessments.

## Input
You will receive:
- Aerial imagery of a property (from Nearmap, Google Maps, or similar source)
- Contact information including address
- Any existing property notes or details

## Task
Analyze the aerial imagery and extract the following information:

### 1. Property Perimeter Measurements

For each floor level visible in the imagery:
- Identify all perimeter segments (straight-line measurements along the building edges)
- Measure each segment in feet
- List segments in clockwise order around the building perimeter
- Calculate total linear footage for each floor

**Important:** 
- Only measure the actual building perimeter (not driveways, decks, or other structures)
- Include all segments, even small ones
- Round measurements to 2 decimal places
- If a floor is not visible or doesn't exist, use an empty array []

### 2. Walkability Assessment

Determine if the roof is walkable based on:
- Roof pitch/steepness
- Roof material type
- Accessibility factors
- Safety considerations

**Criteria:**
- **Walkable:** Low to moderate pitch, standard roofing materials, safe access
- **Unwalkable:** Steep pitch (>45°), slippery materials, unsafe access, or complex roof structure

Output: "Yes" or "No"

### 3. Gutter Material Assessment

Identify the gutter material type:
- Look for distinctive copper coloring (green patina or reddish-brown)
- Check for material characteristics visible in aerial view
- Consider typical materials: aluminum, vinyl, steel, copper

**Note:** Copper gutters are less common and typically have a distinctive appearance. If uncertain, default to "No".

Output: "Yes" (copper) or "No" (not copper)

## Output Format

After extracting all information, output ONLY valid JSON with this exact structure:

```json
{
  "floor1Segments": [32.74, 29.52, 34.62, 28.84],
  "floor2Segments": [49.91, 27.89, 28.57, 7.24, 24.44, 37.83],
  "floor3Segments": [],
  "walkable": "Yes",
  "copperMaterial": "No"
}
```

## Critical Instructions

1. **Only output raw perimeter segment numbers** - do NOT calculate sums
2. **Include ALL segments** in clockwise order around the building
3. **Use empty array []** for floor3Segments if there is no third floor
4. **The system will calculate:** 
   - Linear Footage = sum of segments
   - Total Price = (Footage × Rate) + Fees + Adjustments
5. **Output ONLY valid JSON** - no additional text, explanations, or markdown formatting
6. **Be precise** - accuracy is critical for pricing calculations
7. **If uncertain about a measurement**, use your best estimate but note it in the assessment

## Example Output

For a two-story house with walkable roof and aluminum gutters:

```json
{
  "floor1Segments": [28.5, 45.2, 28.5, 45.2],
  "floor2Segments": [32.1, 38.7, 32.1, 38.7],
  "floor3Segments": [],
  "walkable": "Yes",
  "copperMaterial": "No"
}
```

## Quality Checks

Before finalizing your output, verify:
- ✅ All segment measurements are positive numbers
- ✅ Segments are listed in clockwise order
- ✅ Floor assignments are correct (larger footprint = Floor 1)
- ✅ Walkable assessment is based on visible roof characteristics
- ✅ Copper material assessment is based on visible gutter appearance
- ✅ JSON is valid and parseable
- ✅ No additional text outside the JSON structure

## Notes

- If the property has unusual features (multiple buildings, detached structures), focus on the main building
- For multi-building properties, measure each building separately if possible
- If imagery quality is poor, use your best judgment but note limitations
- Always prioritize accuracy over speed
```

## Usage in Salesforce Flow

### Flow Configuration

1. **Screen Flow Start**
   - Collect contact ID and any additional context

2. **Get Contact Record**
   - Retrieve contact with address and any existing property details

3. **Prepare Prompt Input**
   - Build prompt text using the template above
   - Include contact address
   - Include any existing property notes
   - Reference the aerial imagery source (Nearmap URL, image attachment, etc.)

4. **Call Prompt Action**
   - Use Salesforce Prompt Builder action or external AI service
   - Pass the prepared prompt
   - Configure to expect JSON output

5. **Parse JSON Response**
   - Extract `floor1Segments`, `floor2Segments`, `floor3Segments`
   - Extract `walkable` and `copperMaterial`
   - Validate JSON structure

6. **Update Contact Fields**
   - Set `Property_Measurement_Details__c` = JSON string
   - Optionally set `Walkable__c` and `Copper_Material__c` from JSON

7. **Call Apex Action**
   - Invoke `GutterPricingEstimateController.calculateAndUpdateEstimate()`
   - Pass contact ID
   - This will calculate and populate `Gutter_Cost_Estimate__c`

8. **Display Success Screen**
   - Show confirmation
   - Optionally display the calculated estimate

## Integration with Nearmap

If using Nearmap imagery:

1. **Get Nearmap Image URL**
   - Use Nearmap MapBrowser component to get the property location
   - Construct Nearmap image URL with coordinates
   - Format: `https://apps.nearmap.com/maps/#/@{latitude},{longitude},19z`

2. **Include in Prompt**
   - Add Nearmap URL to prompt context
   - Or download image and attach to prompt as image input

3. **Alternative: Image Attachment**
   - User can attach Nearmap screenshot
   - Include in prompt as image input

## Integration with Google Street View

For additional context:

1. **Include Street View URL**
   - Add Google Street View URL to prompt
   - Helps assess walkability and material type

2. **Format:**
   ```
   Street View: https://www.google.com/maps/@?api=1&map_action=pano&viewpoint={lat},{lng}
   ```

## Expected JSON Schema

```json
{
  "floor1Segments": [number, number, ...],  // Array of perimeter segment lengths in feet
  "floor2Segments": [number, number, ...],  // Array of perimeter segment lengths in feet
  "floor3Segments": [number, number, ...],  // Array of perimeter segment lengths in feet, or []
  "walkable": "Yes" | "No",                 // Whether roof is walkable
  "copperMaterial": "Yes" | "No"            // Whether gutters are copper material
}
```

## Validation Rules

The Apex class validates:
- JSON structure is valid
- Arrays contain numeric values
- Walkable and copperMaterial are "Yes" or "No"
- Floor segments are assigned correctly (larger = Floor 1)

## Error Handling

If the prompt returns invalid JSON:
1. Flow should catch the error
2. Display error message to user
3. Allow user to retry or manually enter data
4. Optionally log error for review

## Best Practices

1. **Provide Clear Context**
   - Include full address
   - Include any known property details
   - Reference the imagery source

2. **Use High-Quality Imagery**
   - Prefer recent aerial imagery
   - Ensure good resolution
   - Include multiple angles if possible

3. **Validate Output**
   - Check JSON is parseable
   - Verify measurements are reasonable
   - Confirm assessments make sense

4. **Handle Edge Cases**
   - Multi-building properties
   - Unusual roof shapes
   - Poor image quality
   - Missing floors

5. **User Review**
   - Allow users to review extracted data
   - Provide option to edit measurements
   - Show confidence indicators if available

## Example Flow Variables

```
$Flow.CurrentContactId - Contact ID
$Flow.PropertyAddress - Full address string
$Flow.NearmapImageUrl - Nearmap image URL
$Flow.PromptResponse - JSON response from AI
$Flow.ParsedSegments - Parsed segment arrays
$Flow.WalkableAssessment - "Yes" or "No"
$Flow.CopperAssessment - "Yes" or "No"
```

## Troubleshooting

**Issue:** Invalid JSON returned  
**Solution:** Add validation step in Flow to check JSON structure before parsing.

**Issue:** Measurements seem inaccurate  
**Solution:** Provide higher resolution imagery or multiple angles.

**Issue:** Walkability assessment incorrect  
**Solution:** Include Street View imagery for better roof pitch assessment.

**Issue:** Copper material detection unreliable  
**Solution:** Copper assessment may be difficult from aerial view. Consider manual override option.
