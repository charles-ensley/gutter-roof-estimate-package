import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

// Contact address and geolocation fields
const FIELDS = [
    'Contact.MailingStreet',
    'Contact.MailingCity',
    'Contact.MailingState',
    'Contact.MailingPostalCode',
    'Contact.MailingCountry',
    'Contact.MailingLatitude',
    'Contact.MailingLongitude',
    'Contact.Name'
];

export default class GoogleStreetView extends LightningElement {
    @api recordId;
    @api height = 400; // Configurable height in pixels
    @api width = 600; // Configurable width in pixels
    @api googleMapsApiKey = ''; // API key configured in component settings
    @api heading = 0; // Initial camera heading (0-360)
    @api pitch = 0; // Initial camera pitch (-90 to 90)
    @api fov = 90; // Field of view (10-120, default 90)
    @api zoom = 1; // Deprecated, kept for backward compatibility
    
    contactData;
    error;
    isLoading = true;
    
    // Local state for interactive adjustments
    currentHeading = 0;
    currentPitch = 0;
    currentFov = 90;
    showControls = false;
    sliderValue = 180; // Slider value (0-360), center at 180 = North
    
    connectedCallback() {
        // Initialize current values from component properties
        this.currentHeading = this.heading;
        this.currentPitch = this.pitch;
        this.currentFov = this.fov;
        // Initialize slider value based on heading
        // Map heading (0-360) to slider (0-360) where 180 = North (0°)
        this.sliderValue = this.headingToSliderValue(this.heading);
    }
    
    // Convert heading (0-360) to slider value (0-360)
    // Joystick-style: Center (180) = current heading, Left = pan left (counterclockwise), Right = pan right (clockwise)
    headingToSliderValue(heading) {
        // Map heading to slider where center (180) = North (0°)
        // From North (0°):
        // - Counterclockwise (left): 0° → 270° → 180°
        // - Clockwise (right): 0° → 90° → 180°
        let slider;
        if (heading === 0) {
            slider = 180; // Center = North
        } else if (heading > 0 && heading <= 180) {
            // Right side: clockwise from North (0° to 180°)
            // heading 90° = slider 270, heading 180° = slider 360
            // slider = 180 + heading (90° = 270, 180° = 360)
            slider = 180 + heading;
        } else {
            // Left side: counterclockwise from North (270° to 180°)
            // heading 270° = slider 90, heading 180° = slider 0
            // slider = 360 - heading (270° = 90, 180° = 180... wait that's wrong)
            // Actually: heading 270° should map to slider 90
            // slider = 360 - heading (270° = 90, 180° = 180)
            slider = 360 - heading;
            if (slider === 360) slider = 0;
        }
        return Math.round(slider);
    }
    
    // Convert slider value (0-360) to heading (0-360)
    // Joystick-style: Center (180) = current heading, Left = pan left (counterclockwise), Right = pan right (clockwise)
    sliderValueToHeading(sliderValue) {
        // Map slider to heading where center (180) = North (0°)
        // When dragging LEFT (slider decreases from 180), rotate COUNTERCLOCKWISE (toward West)
        // When dragging RIGHT (slider increases from 180), rotate CLOCKWISE (toward East)
        // 
        // From North (0°):
        // - Counterclockwise (left): 0° → 270° → 180° → 90° → 0°
        // - Clockwise (right): 0° → 90° → 180° → 270° → 0°
        //
        // Desired mapping:
        // - slider 0 (far left) → West (270°) - 90° counterclockwise from North
        // - slider 90 (quarter left) → South (180°) - 180° counterclockwise from North  
        // - slider 180 (center) → North (0°)
        // - slider 270 (quarter right) → East (90°) - 90° clockwise from North
        // - slider 360 (far right) → South (180°) - 180° clockwise from North
        let heading;
        if (sliderValue === 180) {
            heading = 0; // Center = North
        } else if (sliderValue < 180) {
            // Left side: dragging left rotates counterclockwise (heading decreases)
            // When slider decreases from 180, heading decreases counterclockwise: 0° → 270° → 180°
            // slider 180 → 0° (North), slider 90 → 270° (West), slider 0 → 180° (South)
            // Counterclockwise: heading = (0 - (180 - sliderValue)) % 360 = (sliderValue - 180) % 360
            // slider 180: (180 - 180) % 360 = 0° ✓
            // slider 170: (170 - 180) % 360 = 350° ✓ (slightly west of north)
            // slider 90: (90 - 180) % 360 = 270° ✓ (West)
            // slider 0: (0 - 180) % 360 = 180° ✓ (South)
            heading = (sliderValue - 180) % 360;
            if (heading < 0) heading += 360;
        } else {
            // Right side: dragging right rotates clockwise
            // slider 180 → 0° (North) - handled above
            // slider 270 → 90° (East), slider 360 → 180° (South)
            // Linear: heading = (sliderValue - 180) * 180 / 180 = sliderValue - 180
            // slider 180: 0° ✓ (handled above)
            // slider 270: 90° ✓
            // slider 360: 180° ✓
            heading = sliderValue - 180;
        }
        return Math.round(heading);
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredContact({ error, data }) {
        if (data) {
            this.contactData = data;
            this.error = undefined;
            this.isLoading = false;
        } else if (error) {
            this.error = error;
            this.contactData = undefined;
            this.isLoading = false;
            console.error('Error loading contact data:', error);
        }
    }

    get streetViewImageUrl() {
        if (!this.contactData || !this.googleMapsApiKey) {
            return null;
        }

        const latitude = this.contactData.fields.MailingLatitude?.value;
        const longitude = this.contactData.fields.MailingLongitude?.value;

        // Prefer coordinates if available (more accurate)
        if (latitude && longitude) {
            // Google Street View Static API using coordinates
            // Use current values (which can be adjusted with sliders)
            const params = new URLSearchParams({
                size: `${this.width}x${this.height}`,
                location: `${latitude},${longitude}`,
                heading: this.currentHeading.toString(),
                pitch: this.currentPitch.toString(),
                fov: this.currentFov.toString(),
                key: this.googleMapsApiKey,
                source: 'outdoor' // Prefer outdoor street-level imagery
            });

            return `https://maps.googleapis.com/maps/api/streetview?${params.toString()}`;
        }

        // Fallback to address if no coordinates
        const street = this.contactData.fields.MailingStreet?.value;
        const city = this.contactData.fields.MailingCity?.value;
        const state = this.contactData.fields.MailingState?.value;
        const postalCode = this.contactData.fields.MailingPostalCode?.value;
        const country = this.contactData.fields.MailingCountry?.value;

        const addressParts = [street, city, state, postalCode, country].filter(part => part);
        const fullAddress = addressParts.join(', ');

        if (!fullAddress) {
            return null;
        }

        const params = new URLSearchParams({
            size: `${this.width}x${this.height}`,
            location: fullAddress,
            heading: this.currentHeading.toString(),
            pitch: this.currentPitch.toString(),
            fov: this.currentFov.toString(),
            key: this.googleMapsApiKey,
            source: 'outdoor'
        });

        return `https://maps.googleapis.com/maps/api/streetview?${params.toString()}`;
    }

    get imageStyle() {
        return `width: 100%; height: ${this.height}px; object-fit: cover; cursor: pointer;`;
    }

    get hasAddress() {
        if (!this.contactData) return false;
        const street = this.contactData.fields.MailingStreet?.value;
        const city = this.contactData.fields.MailingCity?.value;
        return !!(street || city);
    }

    get hasCoordinates() {
        if (!this.contactData) return false;
        const latitude = this.contactData.fields.MailingLatitude?.value;
        const longitude = this.contactData.fields.MailingLongitude?.value;
        return !!(latitude && longitude);
    }

    get contactName() {
        return this.contactData?.fields.Name?.value || 'Contact';
    }

    get fullAddress() {
        if (!this.contactData) return '';
        const street = this.contactData.fields.MailingStreet?.value || '';
        const city = this.contactData.fields.MailingCity?.value || '';
        const state = this.contactData.fields.MailingState?.value || '';
        const postalCode = this.contactData.fields.MailingPostalCode?.value || '';
        const country = this.contactData.fields.MailingCountry?.value || '';
        const addressParts = [street, city, state, postalCode, country].filter(part => part);
        return addressParts.join(', ');
    }

    get showApiKeyWarning() {
        return !this.googleMapsApiKey || this.googleMapsApiKey.trim() === '';
    }

    handleImageClick() {
        this.handleOpenInGoogleMaps();
    }

    handleOpenInGoogleMaps() {
        const latitude = this.contactData?.fields.MailingLatitude?.value;
        const longitude = this.contactData?.fields.MailingLongitude?.value;
        
        if (latitude && longitude) {
            const url = `https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=${latitude},${longitude}&heading=${this.heading}&pitch=${this.pitch}&fov=${this.fov}`;
            window.open(url, '_blank');
        } else if (this.fullAddress) {
            const encodedAddress = encodeURIComponent(this.fullAddress);
            const url = `https://www.google.com/maps/search/?api=1&query=${encodedAddress}`;
            window.open(url, '_blank');
        }
    }

    handleImageError(event) {
        console.error('Street View image failed to load');
        this.error = { message: 'Street View imagery not available for this location or invalid API key.' };
    }

    toggleControls() {
        this.showControls = !this.showControls;
    }

    handleHeadingChange(event) {
        // Slider value changes (0-360), convert to heading (0-360)
        this.sliderValue = parseInt(event.target.value, 10);
        const oldHeading = this.currentHeading;
        this.currentHeading = this.sliderValueToHeading(this.sliderValue);
        console.log(`Slider: ${this.sliderValue} → Heading: ${this.currentHeading}° (was ${oldHeading}°)`);
    }

    handlePitchChange(event) {
        this.currentPitch = parseInt(event.target.value, 10);
    }

    handleFovChange(event) {
        this.currentFov = parseInt(event.target.value, 10);
    }

    applyChanges() {
        // Force re-render by updating the template
        // The getter will use the new values automatically
        this.showControls = false;
    }

    resetToDefaults() {
        this.currentHeading = this.heading;
        this.currentPitch = this.pitch;
        this.currentFov = this.fov;
        this.sliderValue = this.headingToSliderValue(this.heading);
    }

    get controlsButtonLabel() {
        return this.showControls ? 'Hide Controls' : 'Adjust View';
    }

    get directionLabel() {
        const heading = this.currentHeading;
        if (heading >= 337.5 || heading < 22.5) return 'North';
        if (heading >= 22.5 && heading < 67.5) return 'Northeast';
        if (heading >= 67.5 && heading < 112.5) return 'East';
        if (heading >= 112.5 && heading < 157.5) return 'Southeast';
        if (heading >= 157.5 && heading < 202.5) return 'South';
        if (heading >= 202.5 && heading < 247.5) return 'Southwest';
        if (heading >= 247.5 && heading < 292.5) return 'West';
        if (heading >= 292.5 && heading < 337.5) return 'Northwest';
        return '';
    }
}
