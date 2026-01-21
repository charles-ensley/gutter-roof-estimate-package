# Basic Configuration - Fields and Values

This document describes all custom fields on the Contact object required for the Gutter Roof Estimation system.

## Contact Object Fields

### 1. Has Gutter Guards? (`Has_Gutter_Guards__c`)

**Type:** Picklist  
**Label:** Has Gutter Guards?  
**Description:** Indicates whether the property has gutter guards installed  
**Values:**
- Yes
- No

**Usage:** Affects pricing calculation with multiplier (2.2x for first cleaning, 1.5x for subsequent cleanings)

---

### 2. Property Measurement Details (`Property_Measurement_Details__c`)

**Type:** Long Text Area (32,768 characters)  
**Label:** Property Measurement Details  
**Description:** Detailed measurements and notes about the property dimensions and characteristics  
**Visible Lines:** 5

**Usage:** Stores JSON output from AI prompt template with floor segments:
```json
{
  "floor1Segments": [32.74, 29.52, 34.62, 28.84],
  "floor2Segments": [49.91, 27.89, 28.57, 7.24, 24.44, 37.83],
  "floor3Segments": [],
  "walkable": "Yes",
  "copperMaterial": "No"
}
```

**Format:** The Apex class can parse both JSON format (preferred) and text format with patterns like "1st Floor Linear Footage: 139.40 ft"

---

### 3. Gutter Cost Estimate (`Gutter_Cost_Estimate__c`)

**Type:** Long Text Area (32,768 characters)  
**Label:** Gutter Cost Estimate  
**Description:** Detailed cost estimate breakdown for gutter installation or repair work  
**Visible Lines:** 5

**Usage:** Populated automatically by the Apex class with formatted pricing breakdown:
```
Gutter Cleaning Estimate

1st Floor: 232.8 ft × $1.37/ft (Walkable) = $318.94
2nd Floor: 238.8 ft × $1.50/ft (Walkable) = $358.20

Gutter Cleaning Subtotal: $677.14
Copper Material Surcharge (10%): $0.00
Gutter Guards Multiplier (2.2x): Applied
Function Inspection Fee: $0.00
New Customer Discount: -$25.00

Total Estimated Price: $1,464.71
```

---

### 4. Roof Walkable? (`Walkable__c`)

**Type:** Picklist  
**Label:** Roof Walkable?  
**Description:** Indicates whether the roof is walkable (affects pricing rates per floor)  
**Values:**
- Yes
- No

**Usage:** 
- **Walkable rates:** 1st Floor $1.37/ft, 2nd Floor $1.50/ft, 3rd Floor $1.76/ft
- **Unwalkable rates:** 1st Floor $1.65/ft, 2nd Floor $1.87/ft, 3rd Floor $2.20/ft

**Note:** Can be set manually or extracted from AI prompt template JSON

---

### 5. Copper Material? (`Copper_Material__c`)

**Type:** Picklist  
**Label:** Copper Material?  
**Description:** Indicates whether the gutters are made of copper material (affects pricing with 10% surcharge)  
**Values:**
- Yes
- No

**Usage:** Adds 10% surcharge to gutter cleaning subtotal if Yes

**Note:** Can be set manually or extracted from AI prompt template JSON

---

### 6. New Customer? (`New_Customer__c`)

**Type:** Picklist  
**Label:** New Customer?  
**Description:** Indicates whether this is a new customer (affects pricing discount eligibility)  
**Values:**
- Yes
- No

**Usage:** Applies $25 discount if Yes AND total price > $300

---

## Standard Contact Fields Used

The system also uses these standard Contact fields:

- **Mailing Address Fields:**
  - `MailingStreet`
  - `MailingCity`
  - `MailingState`
  - `MailingPostalCode`
  - `MailingCountry`

- **Geolocation Fields:**
  - `MailingLatitude` (populated by geocoding)
  - `MailingLongitude` (populated by geocoding)

## Field Deployment

All custom fields are located in:
```
force-app/main/default/objects/Contact/fields/
```

Deploy using Salesforce CLI:
```bash
sf project deploy start --source-dir force-app/main/default/objects/Contact
```

## Permission Set Configuration

Ensure users have access to these fields via permission sets or profiles:

- `Contact.Has_Gutter_Guards__c` - Read/Edit
- `Contact.Property_Measurement_Details__c` - Read/Edit
- `Contact.Gutter_Cost_Estimate__c` - Read/Edit
- `Contact.Walkable__c` - Read/Edit
- `Contact.Copper_Material__c` - Read/Edit
- `Contact.New_Customer__c` - Read/Edit
- `Contact.MailingLatitude` - Read/Edit
- `Contact.MailingLongitude` - Read/Edit

## Page Layout Configuration

Add all fields to Contact page layouts in a "Property Details" section:

1. Navigate to **Setup** → **Object Manager** → **Contact** → **Page Layouts**
2. Edit the desired layout
3. Add a new section: **Property Details**
4. Add fields:
   - Has Gutter Guards?
   - Roof Walkable?
   - Copper Material?
   - New Customer?
   - Property Measurement Details
   - Gutter Cost Estimate
