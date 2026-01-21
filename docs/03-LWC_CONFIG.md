# Lightning Web Component Configuration

This document provides setup and configuration guides for all Lightning Web Components in the Gutter Roof Estimation system.

## Components Overview

1. **Gutter Pricing Estimate** - Displays pricing breakdown and totals
2. **Nearmap MapBrowser** - Embeds Nearmap aerial imagery with geocoding
3. **Google Street View** - Displays interactive Street View panoramas

---

## 1. Gutter Pricing Estimate Component

### Purpose

Displays a professional pricing breakdown card showing:
- Floor-by-floor linear footage
- Detailed price breakdown with rates
- Total estimated price
- All applicable fees and discounts

### Files

- `lwc/gutterPricingEstimate/gutterPricingEstimate.js`
- `lwc/gutterPricingEstimate/gutterPricingEstimate.html`
- `lwc/gutterPricingEstimate/gutterPricingEstimate.css`
- `lwc/gutterPricingEstimate/gutterPricingEstimate.js-meta.xml`

### Deployment

```bash
sf project deploy start --source-dir force-app/main/default/lwc/gutterPricingEstimate
```

### Adding to Contact Page

1. Navigate to any Contact record
2. Click **Setup gear** → **Edit Page**
3. In Lightning App Builder:
   - Drag **Gutter Pricing Estimate** component from Components panel
   - Drop it in desired location (e.g., right column or below details)
   - Click **Save**
   - Choose activation:
     - **Org Default:** Apply to all users
     - **App, Record Type, and Profile:** Target specific users
   - Click **Activate** → **Save**

### Component Properties

No configuration required. The component automatically:
- Reads `Property_Measurement_Details__c` field
- Calls Apex to calculate pricing
- Displays formatted results

### Dependencies

- **Apex Class:** `GutterPricingEstimateController`
- **Contact Fields:**
  - `Property_Measurement_Details__c`
  - `Gutter_Cost_Estimate__c`
  - `Has_Gutter_Guards__c`
  - `New_Customer__c`
  - `Walkable__c`
  - `Copper_Material__c`

### Features

- **Automatic Updates:** Refreshes when `Property_Measurement_Details__c` changes
- **Responsive Design:** Adapts to mobile and desktop layouts
- **Error Handling:** Shows helpful error messages if data is missing
- **Loading States:** Displays spinner while calculating

---

## 2. Nearmap MapBrowser Component

### Purpose

Embeds Nearmap's MapBrowser application to display aerial imagery and provides geocoding functionality.

### Files

- `lwc/nearmapMapBrowser/nearmapMapBrowser.js`
- `lwc/nearmapMapBrowser/nearmapMapBrowser.html`
- `lwc/nearmapMapBrowser/nearmapMapBrowser.css`
- `lwc/nearmapMapBrowser/nearmapMapBrowser.js-meta.xml`

### Deployment

```bash
sf project deploy start --source-dir force-app/main/default/lwc/nearmapMapBrowser
```

### Adding to Contact Page

1. Navigate to any Contact record
2. Click **Setup gear** → **Edit Page**
3. In Lightning App Builder:
   - Drag **Nearmap MapBrowser** component from Components panel
   - Drop it in desired location
   - Configure properties:
     - **Map Height (pixels):** Default 600, adjust as needed
     - **Show Iframe:** Default false (shows button instead)
     - **Google Maps API Key:** (Optional) For fallback geocoding
   - Click **Save** → **Activate**

### Component Properties

- **Map Height:** Height of the map iframe in pixels (default: 600)
- **Show Iframe:** Whether to show the iframe or just the "Open in Nearmap" button
- **Google Maps API Key:** (Optional) Google API key for fallback geocoding if Nominatim fails

### Dependencies

- **Apex Class:** `AddressGeocoder`
- **Contact Fields:**
  - `MailingStreet`
  - `MailingCity`
  - `MailingState`
  - `MailingPostalCode`
  - `MailingCountry`
  - `MailingLatitude`
  - `MailingLongitude`

### Features

- **Automatic Address Loading:** Uses contact's mailing address
- **Geocoding Button:** "Geocode Address" button populates coordinates
- **Coordinate Display:** Shows current coordinates if available
- **Open in New Window:** Button to open Nearmap in full window
- **Error Handling:** Helpful messages for missing addresses or geocoding failures

### Geocoding Functionality

The component includes a "Geocode Address" button that:
1. Calls `AddressGeocoder.geocodeContact()` Apex method
2. Uses OpenStreetMap Nominatim (free) or Google Geocoding (if API key provided)
3. Updates `MailingLatitude` and `MailingLongitude` fields
4. Refreshes the component to show updated coordinates

### Troubleshooting

**Issue:** Map Not Loading  
**Solution:** Verify CSP Trusted Sites and Remote Site Settings are configured (see Integration docs).

**Issue:** Geocoding Fails  
**Solution:** 
- Verify Remote Site Settings for OpenStreetMap Nominatim
- Check that address fields are populated
- Try providing Google Maps API key for fallback

---

## 3. Google Street View Component

### Purpose

Displays interactive Google Street View panoramas with adjustable camera controls.

### Files

- `lwc/googleStreetView/googleStreetView.js`
- `lwc/googleStreetView/googleStreetView.html`
- `lwc/googleStreetView/googleStreetView.css`
- `lwc/googleStreetView/googleStreetView.js-meta.xml`

### Deployment

```bash
sf project deploy start --source-dir force-app/main/default/lwc/googleStreetView
```

### Adding to Contact Page

1. Navigate to any Contact record
2. Click **Setup gear** → **Edit Page**
3. In Lightning App Builder:
   - Drag **Google Street View** component from Components panel
   - Drop it in desired location
   - Configure properties (REQUIRED):
     - **Google Maps API Key:** Paste your API key
     - **Street View Height (pixels):** Default 400
     - **Initial Camera Heading (0-360):** Default 0 (North)
     - **Initial Camera Pitch (-90 to 90):** Default 0 (Straight ahead)
     - **Initial Zoom Level (0-4):** Default 1
   - Click **Save** → **Activate**

### Component Properties

- **Google Maps API Key:** (REQUIRED) Your Google Maps JavaScript API key
- **Height:** Height of Street View in pixels (default: 400)
- **Width:** Width of Street View (default: 600, responsive)
- **Heading:** Initial camera direction (0-360, where 0=North)
- **Pitch:** Initial camera angle (-90 to 90, where 0=straight ahead)
- **FOV:** Field of view (10-120, default: 90)

### Dependencies

- **Contact Fields:**
  - `MailingStreet`
  - `MailingCity`
  - `MailingState`
  - `MailingPostalCode`
  - `MailingCountry`
  - `MailingLatitude` (preferred for accuracy)
  - `MailingLongitude` (preferred for accuracy)

### Features

- **Interactive Controls:** Adjust heading, pitch, and zoom with sliders
- **Coordinate-Based:** Prefers coordinates over address for accuracy
- **Open in Google Maps:** Button to view in full Google Maps
- **Error Handling:** Graceful handling when Street View unavailable
- **Responsive:** Adapts to container width

### Usage

1. Component automatically loads Street View for contact's address
2. Click **"Adjust View"** to show camera controls
3. Adjust heading (direction), pitch (up/down), and zoom
4. Click **"Apply Changes"** to update the view
5. Click **"Open in Google Maps"** to view in full Google Maps

### Troubleshooting

**Issue:** "Google Maps API Key Required" Warning  
**Solution:** Edit the page and add your API key to the component properties.

**Issue:** Street View Not Available  
**Solution:** Google may not have Street View imagery for this location. Some areas (especially rural) don't have coverage.

**Issue:** Wrong Location  
**Solution:** Ensure coordinates are accurate. Use Nearmap MapBrowser component to re-geocode the address.

---

## Component Layout Recommendations

### Recommended Page Layout

```
┌─────────────────────────────────────────┐
│  Contact Details (Left Column)         │
│  - Name, Account, Email, Phone         │
│  - Property Details Section             │
│    - Has Gutter Guards?                 │
│    - Roof Walkable?                     │
│    - Copper Material?                  │
│    - New Customer?                      │
│    - Property Measurement Details      │
│    - Gutter Cost Estimate              │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│  Right Column                           │
│  ┌───────────────────────────────────┐ │
│  │ Gutter Pricing Estimate           │ │
│  └───────────────────────────────────┘ │
│  ┌───────────────────────────────────┐ │
│  │ Nearmap MapBrowser                │ │
│  └───────────────────────────────────┘ │
│  ┌───────────────────────────────────┐ │
│  │ Google Street View                │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### Mobile Considerations

All components are responsive and adapt to mobile layouts:
- Gutter Pricing Estimate: Stacks floor cards vertically
- Nearmap MapBrowser: Full-width iframe
- Google Street View: Full-width with adjusted controls

---

## Permission Requirements

Users need access to:
- All Contact custom fields (see Basic Config doc)
- Apex classes: `GutterPricingEstimateController`, `AddressGeocoder`
- Lightning Web Components (automatically granted with deployment)

## Testing

After deployment, test each component:

1. **Gutter Pricing Estimate:**
   - Create a Contact with `Property_Measurement_Details__c` populated
   - Verify pricing displays correctly
   - Check that breakdown shows all applicable fees

2. **Nearmap MapBrowser:**
   - Create a Contact with mailing address
   - Verify map loads
   - Test "Geocode Address" button
   - Verify coordinates update

3. **Google Street View:**
   - Create a Contact with coordinates
   - Verify Street View loads
   - Test camera controls
   - Verify "Open in Google Maps" works
