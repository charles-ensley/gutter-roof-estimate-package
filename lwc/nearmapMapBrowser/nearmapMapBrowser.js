import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import geocodeContact from '@salesforce/apex/AddressGeocoder.geocodeContact';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';

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

export default class NearmapMapBrowser extends LightningElement {
    @api recordId;
    @api height = 600; // Configurable height in pixels
    @api showIframe = false; // Option to show iframe or just button
    @api googleMapsApiKey = ''; // Optional Google Maps API key for fallback geocoding
    
    contactData;
    error;
    mapUrl;
    showAuthMessage = true;
    @track isGeocoding = false;
    wiredContactResult;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredContact(result) {
        this.wiredContactResult = result;
        const { error, data } = result;
        if (data) {
            this.contactData = data;
            this.error = undefined;
            this.constructMapUrl();
        } else if (error) {
            this.error = error;
            this.contactData = undefined;
            console.error('Error loading contact data:', error);
        }
    }

    constructMapUrl() {
        if (!this.contactData) return;

        const latitude = this.contactData.fields.MailingLatitude?.value;
        const longitude = this.contactData.fields.MailingLongitude?.value;
        const street = this.contactData.fields.MailingStreet?.value || '';
        const city = this.contactData.fields.MailingCity?.value || '';
        const state = this.contactData.fields.MailingState?.value || '';
        const postalCode = this.contactData.fields.MailingPostalCode?.value || '';
        const country = this.contactData.fields.MailingCountry?.value || '';

        // Construct full address for fallback
        const addressParts = [street, city, state, postalCode, country].filter(part => part);
        const fullAddress = addressParts.join(', ');

        // Prefer coordinates if available, otherwise use address
        if (latitude && longitude) {
            // Nearmap MapBrowser with coordinates (more accurate)
            // Format: https://apps.nearmap.com/maps/#/@-33.8688,151.2093,20z
            // The zoom level (z) can be adjusted - 20z is a close street-level view
            this.mapUrl = `https://apps.nearmap.com/maps/#/@${latitude},${longitude},19z`;
        } else if (fullAddress) {
            // Fallback to address-based URL
            const encodedAddress = encodeURIComponent(fullAddress);
            this.mapUrl = `https://apps.nearmap.com/maps/#/@${encodedAddress}`;
        } else {
            // Default to a general view if no address is available
            this.mapUrl = 'https://apps.nearmap.com/maps/';
        }
    }

    get iframeStyle() {
        return `height: ${this.height}px; width: 100%; border: 0;`;
    }

    get hasAddress() {
        if (!this.contactData) return false;
        const street = this.contactData.fields.MailingStreet?.value;
        const city = this.contactData.fields.MailingCity?.value;
        return !!(street || city);
    }

    get contactName() {
        return this.contactData?.fields.Name?.value || 'Contact';
    }

    get noAddressMessage() {
        return `No address information available for ${this.contactName}. Please add an address to view the location in Nearmap.`;
    }

    handleOpenInNearmap() {
        // Open Nearmap in a new window with the address pre-loaded
        if (this.mapUrl) {
            window.open(this.mapUrl, '_blank');
        } else {
            window.open('https://apps.nearmap.com/maps/', '_blank');
        }
    }

    handleLoginClick() {
        // Open Nearmap in a new window for authentication
        window.open('https://apps.nearmap.com/maps/', '_blank', 'width=1200,height=800');
    }

    handleRefresh() {
        // Reload the iframe by reconstructing the URL
        const iframe = this.template.querySelector('iframe');
        if (iframe) {
            iframe.src = iframe.src;
        }
        this.showAuthMessage = false;
    }

    handleDismissAuth() {
        this.showAuthMessage = false;
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

    get hasCoordinates() {
        if (!this.contactData) return false;
        const latitude = this.contactData.fields.MailingLatitude?.value;
        const longitude = this.contactData.fields.MailingLongitude?.value;
        return !!(latitude && longitude);
    }

    get locationInfo() {
        if (!this.contactData) return '';
        const latitude = this.contactData.fields.MailingLatitude?.value;
        const longitude = this.contactData.fields.MailingLongitude?.value;
        if (latitude && longitude) {
            return `Coordinates: ${latitude.toFixed(6)}, ${longitude.toFixed(6)}`;
        }
        return '';
    }

    get geocodeButtonLabel() {
        return this.hasCoordinates ? 'Re-geocode Address' : 'Geocode Address';
    }

    get geocodeButtonVariant() {
        return this.hasCoordinates ? 'neutral' : 'success';
    }

    handleGeocodeAddress() {
        this.isGeocoding = true;
        console.log('Starting geocoding for contact:', this.recordId);
        
        // Always force update to allow re-geocoding if coordinates are wrong
        // Pass Google API key if available for fallback geocoding
        geocodeContact({ 
            contactId: this.recordId, 
            forceUpdate: true,
            googleApiKey: this.googleMapsApiKey || null
        })
            .then(result => {
                console.log('Geocoding result:', result);
                if (result) {
                    this.showToast('Success', 'Address geocoded successfully!', 'success');
                    // Refresh the contact data
                    return refreshApex(this.wiredContactResult);
                } else {
                    console.warn('Geocoding returned false - no coordinates found');
                    // This shouldn't happen now since we throw exceptions, but keep as fallback
                    const street = this.contactData?.fields.MailingStreet?.value;
                    const city = this.contactData?.fields.MailingCity?.value;
                    
                    let message = 'Could not geocode this address. ';
                    if (!street && !city) {
                        message += 'Please add a street address or city.';
                    } else {
                        message += 'The address may not be recognized by the geocoding service. ';
                        message += 'Try adding more details (state, zip code, country) or check the address format.';
                    }
                    
                    this.showToast('Warning', message, 'warning');
                }
            })
            .catch(error => {
                console.error('Geocoding error caught:', error);
                console.error('Error type:', typeof error);
                console.error('Error keys:', Object.keys(error));
                console.error('Error body:', error.body);
                console.error('Error message:', error.message);
                console.error('Full error object:', JSON.stringify(error, Object.getOwnPropertyNames(error), 2));
                
                let errorMessage = 'Error geocoding address. ';
                
                // Try multiple ways to extract error message
                if (error.body) {
                    if (typeof error.body === 'string') {
                        errorMessage += error.body;
                    } else if (error.body.message) {
                        errorMessage += error.body.message;
                    } else if (Array.isArray(error.body) && error.body.length > 0) {
                        const firstError = error.body[0];
                        if (firstError.message) {
                            errorMessage += firstError.message;
                        } else if (firstError.errorCode) {
                            errorMessage += `${firstError.errorCode}: ${firstError.message || 'Unknown error'}`;
                        } else {
                            errorMessage += JSON.stringify(firstError);
                        }
                    } else {
                        errorMessage += JSON.stringify(error.body);
                    }
                } else if (error.message) {
                    errorMessage += error.message;
                } else {
                    errorMessage += 'Please check the address is valid and try again.';
                }
                
                // Add helpful context based on error type
                if (errorMessage.toLowerCase().includes('rate limit') || errorMessage.includes('429')) {
                    errorMessage += ' Please wait a moment and try again.';
                } else if (errorMessage.toLowerCase().includes('no results') || errorMessage.toLowerCase().includes('not found')) {
                    // Check if coordinates already exist
                    if (this.hasCoordinates) {
                        errorMessage += ' The geocoding service could not find this address, but coordinates already exist. ';
                        errorMessage += 'If the current coordinates are correct, you may not need to re-geocode.';
                    } else {
                        errorMessage += ' Try adding more address details (city, state, zip code) or verify the address spelling.';
                    }
                } else if (errorMessage.toLowerCase().includes('timeout')) {
                    errorMessage += ' The geocoding service may be slow. Please try again.';
                }
                
                this.showToast('Error', errorMessage, 'error');
            })
            .finally(() => {
                this.isGeocoding = false;
                console.log('Geocoding process completed');
            });
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}

