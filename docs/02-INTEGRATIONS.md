# Integration Documentation

This document covers the setup and configuration of external integrations used in the Gutter Roof Estimation system.

## Table of Contents

1. [Nearmap Integration](#nearmap-integration)
2. [Google Street View Integration](#google-street-view-integration)
3. [OpenStreetMap Geocoding](#openstreetmap-geocoding)

---

## Nearmap Integration

### Overview

Nearmap provides high-resolution aerial imagery that can be embedded directly in Salesforce Contact record pages. The Nearmap MapBrowser component allows users to view properties from above and geocode addresses.

### Prerequisites

- Active Nearmap subscription with MapBrowser access
- Nearmap login credentials

### Salesforce Configuration

#### 1. Add Nearmap to Trusted URLs for Redirects

1. Navigate to **Setup** → **Session Settings**
2. Scroll to **Trusted URLs for Redirects**
3. Click **New Trusted URL**
4. Enter:
   - **API Name:** `Nearmap_MapBrowser`
   - **URL:** `https://apps.nearmap.com`
5. Click **Save**

#### 2. Configure Remote Site Settings

1. Navigate to **Setup** → **Remote Site Settings**
2. Click **New Remote Site**
3. Enter:
   - **Remote Site Name:** `Nearmap`
   - **Remote Site URL:** `https://apps.nearmap.com`
   - Check **Active**
4. Click **Save**

#### 3. Add to CSP Trusted Sites

1. Navigate to **Setup** → **CSP Trusted Sites**
2. Click **New Trusted Site**
3. Enter:
   - **Trusted Site Name:** `Nearmap_MapBrowser`
   - **Trusted Site URL:** `https://apps.nearmap.com`
   - Enable all checkboxes:
     - ☑ Connect (XHR/WebSocket/EventSource)
     - ☑ Font
     - ☑ Image
     - ☑ Media (Audio/Video)
     - ☑ Object (Applet/Embed/Object)
     - ☑ Script
     - ☑ Style
     - ☑ Frame (iframe)
4. Click **Save**

### Component Usage

The Nearmap MapBrowser component (`nearmapMapBrowser`) automatically:
- Loads the contact's mailing address
- Displays the location in Nearmap MapBrowser
- Provides a "Geocode Address" button to populate coordinates
- Shows a button to open Nearmap in a new window

### Authentication

- **First-time use:** Users log in with Nearmap credentials in the iframe
- **Subsequent use:** Session may persist if cookies are enabled
- **Note:** Some browsers may require third-party cookies to be allowed

### Troubleshooting

**Issue:** "This page isn't available"  
**Solution:** Verify CSP Trusted Sites and Trusted URLs are configured correctly.

**Issue:** Login Required Every Time  
**Solution:** Check browser settings to allow third-party cookies.

**Issue:** Map Not Displaying Location  
**Solution:** Verify the contact has a complete mailing address.

---

## Google Street View Integration

### Overview

Google Street View provides interactive 360° panoramic street-level imagery. The Google Street View component displays Street View panoramas directly within Salesforce Contact record pages.

### Prerequisites

- Google Maps JavaScript API key
- Google Cloud project with billing enabled
- Maps JavaScript API enabled

### Getting Your API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Navigate to **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **API Key**
5. Copy your API key
6. Click **Restrict Key** (recommended):
   - Under **API restrictions**, select **Restrict key**
   - Enable: **Maps JavaScript API**
   - Optionally enable: **Street View Static API**
   - Under **Application restrictions**, restrict by HTTP referrer:
     - Add: `*.force.com/*`
     - Add: `*.salesforce.com/*`
7. Click **Save**

### API Key Billing

- Google Maps requires billing to be enabled
- Street View has a generous free tier: **$200 free credit per month**
- Typical usage: ~$7 per 1,000 panorama loads
- [View pricing details](https://developers.google.com/maps/billing-and-pricing/pricing)

### Salesforce Configuration

#### CSP Trusted Sites

The deployment includes these CSP Trusted Sites:
- `Google_Maps_API` (https://maps.googleapis.com)
- `Google_Maps_Content` (https://maps.gstatic.com)

**Manual Configuration:**

1. Go to **Setup** → **CSP Trusted Sites**
2. Edit **Google_Maps_API**:
   - ☑️ **connect-src** (Connect/XHR)
   - ☑️ **script-src** (Scripts)
   - ☑️ **style-src** (Styles)
   - ☑️ **img-src** (Images)
   - ☑️ **font-src** (Fonts)
   - **Context:** All
   - **Active:** ☑️
3. Edit **Google_Maps_Content**:
   - ☑️ **connect-src** (Connect/XHR)
   - ☑️ **img-src** (Images)
   - ☑️ **font-src** (Fonts)
   - **Context:** All
   - **Active:** ☑️
4. Click **Save** for each

### Component Configuration

When adding the Google Street View component to a Contact page:

1. Navigate to Contact record → **Setup gear** → **Edit Page**
2. Drag **Google Street View** component onto the page
3. Configure:
   - **Google Maps API Key:** Paste your API key (REQUIRED)
   - **Street View Height (pixels):** Default 400
   - **Initial Camera Heading (0-360):** Default 0 (North)
   - **Initial Camera Pitch (-90 to 90):** Default 0 (Straight ahead)
   - **Initial Zoom Level (0-4):** Default 1
4. Click **Save** → **Activate**

### Usage

The component automatically:
- Loads the contact's address
- Uses latitude/longitude coordinates (from geocoding)
- Displays an interactive Street View panorama
- Provides controls to adjust heading, pitch, and zoom

### Requirements

- Contact must have a **Mailing Address**
- Contact must have **MailingLatitude** and **MailingLongitude** populated
  - Use the Nearmap MapBrowser component's "Geocode Address" button to populate these

### Troubleshooting

**Issue:** "Google Maps API Key Required" Warning  
**Solution:** Edit the page in Lightning App Builder and add your API key to the component's "Google Maps API Key" property.

**Issue:** "Failed to load Google Maps API"  
**Solution:**
- Verify your API key is correct
- Check that Maps JavaScript API is enabled in Google Cloud Console
- Verify billing is enabled
- Check CSP Trusted Sites are configured correctly

**Issue:** Street View Shows Wrong Location  
**Solution:** Use the Nearmap MapBrowser component to re-geocode the address.

**Issue:** "Street View Not Available"  
**Solution:** Google may not have Street View imagery for this location. Try clicking "Open in Google Maps" to verify.

---

## OpenStreetMap Geocoding

### Overview

The system uses OpenStreetMap's free Nominatim geocoding service to convert addresses into latitude/longitude coordinates. This is used by the Nearmap MapBrowser component's "Geocode Address" button.

### Configuration

#### Remote Site Settings

1. Navigate to **Setup** → **Remote Site Settings**
2. Click **New Remote Site**
3. Enter:
   - **Remote Site Name:** `OpenStreetMap_Nominatim`
   - **Remote Site URL:** `https://nominatim.openstreetmap.org`
   - Check **Active**
4. Click **Save**

### Usage

The geocoding is handled automatically by the `AddressGeocoder` Apex class when users click "Geocode Address" in the Nearmap MapBrowser component.

### Rate Limits

- Nominatim allows **1 request per second**
- The system includes rate limit handling and error messages
- For higher volume, consider using Google Geocoding API (requires API key)

### Fallback to Google Geocoding

The `AddressGeocoder` class supports optional Google Geocoding API fallback:
- If Nominatim fails and a Google API key is provided, it will attempt Google Geocoding
- Configure Google API key in the Nearmap MapBrowser component properties

### Troubleshooting

**Issue:** Rate Limit Exceeded  
**Solution:** Wait a moment and try again. Nominatim allows 1 request per second.

**Issue:** No Results Found  
**Solution:** 
- Verify the address is complete and correct
- Try adding more details (city, state, zip code)
- Check address spelling

---

## Security Best Practices

### API Key Restrictions

1. **Restrict by HTTP referrer:**
   - Add: `*.force.com/*`
   - Add: `*.salesforce.com/*`
   - Add your My Domain if applicable

2. **Restrict by API:**
   - Only enable required APIs
   - Disable unused APIs

3. **Rotate keys periodically:**
   - Generate new keys every 6-12 months
   - Update in all Lightning App Builder configurations

### User Permissions

- Components respect Salesforce record-level security
- Users can only see maps/Street View for Contacts they have access to
- No additional permission sets required beyond field-level security
