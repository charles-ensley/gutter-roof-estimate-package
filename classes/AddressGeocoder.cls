/**
 * AddressGeocoder - Utility class to geocode addresses using a free geocoding service
 * This helps populate MailingLatitude and MailingLongitude fields on Contact records
 */
public with sharing class AddressGeocoder {
    
    /**
     * Geocode a single contact's mailing address
     * @param contactId The ID of the contact to geocode
     * @param forceUpdate If true, re-geocode even if coordinates already exist
     * @param googleApiKey Optional Google Maps API key for fallback geocoding
     * @return Boolean indicating success
     */
    @AuraEnabled
    public static Boolean geocodeContact(Id contactId, Boolean forceUpdate, String googleApiKey) {
        try {
            Contact con = [
                SELECT Id, MailingStreet, MailingCity, MailingState, 
                       MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude
                FROM Contact 
                WHERE Id = :contactId 
                LIMIT 1
            ];
            
            // Skip if already geocoded (unless force update is requested)
            if (!forceUpdate && con.MailingLatitude != null && con.MailingLongitude != null) {
                return true;
            }
            
            // Build address string
            List<String> addressParts = new List<String>();
            if (String.isNotBlank(con.MailingStreet)) addressParts.add(con.MailingStreet);
            if (String.isNotBlank(con.MailingCity)) addressParts.add(con.MailingCity);
            if (String.isNotBlank(con.MailingState)) addressParts.add(con.MailingState);
            if (String.isNotBlank(con.MailingPostalCode)) addressParts.add(con.MailingPostalCode);
            if (String.isNotBlank(con.MailingCountry)) addressParts.add(con.MailingCountry);
            
            if (addressParts.isEmpty()) {
                return false;
            }
            
            String fullAddress = String.join(addressParts, ', ');
            
            // Try geocoding with Nominatim first (free)
            Map<String, Decimal> coordinates = null;
            Exception lastException = null;
            
            try {
                coordinates = geocodeAddress(fullAddress);
            } catch (GeocodingException e) {
                lastException = e;
                System.debug('Nominatim geocoding failed: ' + e.getMessage());
                
                // If Google API key is provided, try Google Geocoding as fallback
                if (String.isNotBlank(googleApiKey)) {
                    System.debug('Attempting Google Geocoding API as fallback');
                    try {
                        coordinates = geocodeAddressWithGoogle(fullAddress, googleApiKey);
                        System.debug('Google Geocoding succeeded');
                    } catch (Exception googleEx) {
                        System.debug('Google Geocoding also failed: ' + googleEx.getMessage());
                        throw new GeocodingException('Both geocoding services failed. Nominatim: ' + e.getMessage() + '. Google: ' + googleEx.getMessage());
                    }
                } else {
                    // No Google API key, just throw the Nominatim exception
                    throw e;
                }
            }
            
            // If we get here, geocoding succeeded
            con.MailingLatitude = coordinates.get('latitude');
            con.MailingLongitude = coordinates.get('longitude');
            update con;
            System.debug('Successfully updated contact ' + contactId + ' with coordinates');
            return true;
        } catch (GeocodingException e) {
            // Re-throw geocoding exceptions so they can be caught by the LWC
            System.debug('GeocodingException in geocodeContact: ' + e.getMessage());
            throw e;
        } catch (Exception e) {
            System.debug('Error geocoding contact: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new GeocodingException('Error geocoding contact: ' + e.getMessage());
        }
    }
    
    /**
     * Geocode an address using OpenStreetMap Nominatim API (free, no API key required)
     * Tries multiple address formats for better results
     * @param address The full address string
     * @return Map with 'latitude' and 'longitude' keys, or throws exception if geocoding fails
     */
    public static Map<String, Decimal> geocodeAddress(String address) {
        // Try multiple address formats for better results
        List<String> addressFormats = new List<String>();
        
        // Original format
        addressFormats.add(address);
        
        // Try without country (sometimes better for US addresses)
        if (address.contains(', United States')) {
            addressFormats.add(address.replace(', United States', ''));
        }
        
        // Try with abbreviated state
        if (address.contains(', CT,')) {
            addressFormats.add(address.replace(', CT,', ', Connecticut,'));
        }
        
        // Try without zip code (sometimes zip codes confuse Nominatim)
        String addressWithoutZip = address.replaceAll(',\\s*\\d{5}(-\\d{4})?', '');
        if (!addressWithoutZip.equals(address)) {
            addressFormats.add(addressWithoutZip);
        }
        
        Exception lastException = null;
        
        // Try each format until one works
        for (String addressFormat : addressFormats) {
            try {
                System.debug('Trying geocoding with format: ' + addressFormat);
                Map<String, Decimal> result = geocodeAddressWithNominatim(addressFormat);
                if (result != null) {
                    System.debug('Successfully geocoded with format: ' + addressFormat);
                    return result;
                }
            } catch (GeocodingException e) {
                lastException = e;
                System.debug('Format failed: ' + addressFormat + ' - ' + e.getMessage());
                // Continue to next format
            } catch (Exception e) {
                lastException = new GeocodingException('Error geocoding address: ' + e.getMessage());
                System.debug('Unexpected error with format: ' + addressFormat + ' - ' + e.getMessage());
            }
        }
        
        // If all formats failed, throw the last exception
        if (lastException != null) {
            throw lastException;
        }
        
        throw new GeocodingException('No results found for address: ' + address + '. Please verify the address is correct.');
    }
    
    /**
     * Internal method to geocode using Nominatim API
     */
    private static Map<String, Decimal> geocodeAddressWithNominatim(String address) {
        try {
            // URL encode the address
            String encodedAddress = EncodingUtil.urlEncode(address, 'UTF-8');
            
            // Nominatim API endpoint (free, rate-limited: 1 request per second)
            // Using structured query format for better results
            String endpoint = 'https://nominatim.openstreetmap.org/search?q=' + encodedAddress + 
                            '&format=json&limit=1&addressdetails=1';
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            // Nominatim requires a valid User-Agent header - use org-specific identifier
            req.setHeader('User-Agent', 'Salesforce-AddressGeocoder/1.0 (Contact Management)');
            req.setHeader('Accept-Language', 'en-US,en;q=0.9');
            req.setTimeout(15000); // Increased timeout
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Geocoding response status: ' + res.getStatusCode());
            System.debug('Geocoding response body: ' + res.getBody().substring(0, Math.min(500, res.getBody().length())));
            
            // Handle different HTTP status codes
            if (res.getStatusCode() == 200) {
                String responseBody = res.getBody();
                
                // Check if response is empty or invalid JSON
                if (String.isBlank(responseBody)) {
                    System.debug('Empty response from Nominatim');
                    throw new GeocodingException('Empty response from geocoding service. Please try again.');
                }
                
                List<Object> results;
                try {
                    results = (List<Object>) JSON.deserializeUntyped(responseBody);
                } catch (Exception jsonEx) {
                    System.debug('Failed to parse JSON response: ' + jsonEx.getMessage());
                    throw new GeocodingException('Invalid response from geocoding service. Please try again.');
                }
                
                if (results != null && !results.isEmpty()) {
                    Map<String, Object> location = (Map<String, Object>) results[0];
                    
                    // Validate that lat/lon exist
                    if (location.containsKey('lat') && location.containsKey('lon')) {
                        Map<String, Decimal> coordinates = new Map<String, Decimal>();
                        coordinates.put('latitude', Decimal.valueOf(String.valueOf(location.get('lat'))));
                        coordinates.put('longitude', Decimal.valueOf(String.valueOf(location.get('lon'))));
                        
                        System.debug('Successfully geocoded address: ' + address + ' -> ' + coordinates);
                        return coordinates;
                    } else {
                        System.debug('Response missing lat/lon fields');
                        throw new GeocodingException('Geocoding service returned invalid data. Please try again.');
                    }
                } else {
                    System.debug('No results found for address: ' + address);
                    throw new GeocodingException('No results found for address: ' + address);
                }
            } else if (res.getStatusCode() == 429) {
                // Rate limit exceeded
                System.debug('Rate limit exceeded (429). Please wait before trying again.');
                throw new GeocodingException('Rate limit exceeded. Please wait a moment and try again. (Nominatim allows 1 request per second)');
            } else if (res.getStatusCode() == 403) {
                // Forbidden - possibly User-Agent issue
                System.debug('Access forbidden (403). Check User-Agent header.');
                throw new GeocodingException('Geocoding service access denied (403). Please contact your administrator.');
            } else if (res.getStatusCode() >= 400) {
                System.debug('HTTP error status: ' + res.getStatusCode() + ', Body: ' + res.getBody().substring(0, Math.min(200, res.getBody().length())));
                throw new GeocodingException('Geocoding service error (HTTP ' + res.getStatusCode() + '). Please try again later.');
            } else {
                System.debug('Unexpected HTTP status: ' + res.getStatusCode());
                throw new GeocodingException('Geocoding service returned unexpected response: HTTP ' + res.getStatusCode());
            }
        } catch (GeocodingException e) {
            System.debug('GeocodingException: ' + e.getMessage());
            throw e; // Re-throw to surface the error
        } catch (Exception e) {
            System.debug('Error calling geocoding service: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new GeocodingException('Error geocoding address: ' + e.getMessage());
        }
    }
    
    /**
     * Custom exception class for geocoding errors
     */
    public class GeocodingException extends Exception {}
    
    /**
     * Batch geocode multiple contacts
     * @param contactIds List of contact IDs to geocode
     */
    @Future(callout=true)
    public static void geocodeContactsBatch(List<Id> contactIds) {
        for (Id contactId : contactIds) {
            geocodeContact(contactId, true, null); // No Google API key in batch mode
            // Add small delay to respect rate limits (1 request per second for Nominatim)
            // Note: Sleep is not available in Apex, so this should be handled by calling code
        }
    }
    
    /**
     * Geocode an address using Google Geocoding API (requires API key)
     * @param address The full address string
     * @param apiKey Google Maps API key
     * @return Map with 'latitude' and 'longitude' keys, or throws exception if geocoding fails
     */
    private static Map<String, Decimal> geocodeAddressWithGoogle(String address, String apiKey) {
        try {
            // URL encode the address
            String encodedAddress = EncodingUtil.urlEncode(address, 'UTF-8');
            
            // Google Geocoding API endpoint
            String endpoint = 'https://maps.googleapis.com/maps/api/geocode/json?address=' + encodedAddress + 
                            '&key=' + apiKey;
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setTimeout(15000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Google Geocoding response status: ' + res.getStatusCode());
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                String status = (String) response.get('status');
                
                if (status == 'OK') {
                    List<Object> results = (List<Object>) response.get('results');
                    if (results != null && !results.isEmpty()) {
                        Map<String, Object> result = (Map<String, Object>) results[0];
                        Map<String, Object> geometry = (Map<String, Object>) result.get('geometry');
                        Map<String, Object> location = (Map<String, Object>) geometry.get('location');
                        
                        Map<String, Decimal> coordinates = new Map<String, Decimal>();
                        coordinates.put('latitude', Decimal.valueOf(String.valueOf(location.get('lat'))));
                        coordinates.put('longitude', Decimal.valueOf(String.valueOf(location.get('lng'))));
                        
                        System.debug('Successfully geocoded with Google: ' + address + ' -> ' + coordinates);
                        return coordinates;
                    } else {
                        throw new GeocodingException('Google Geocoding returned no results for address: ' + address);
                    }
                } else if (status == 'ZERO_RESULTS') {
                    throw new GeocodingException('Google Geocoding found no results for address: ' + address);
                } else if (status == 'OVER_QUERY_LIMIT') {
                    throw new GeocodingException('Google Geocoding API quota exceeded. Please check your API key billing.');
                } else if (status == 'REQUEST_DENIED') {
                    throw new GeocodingException('Google Geocoding API request denied. Please verify your API key and enable Geocoding API.');
                } else {
                    throw new GeocodingException('Google Geocoding API error: ' + status);
                }
            } else {
                throw new GeocodingException('Google Geocoding API HTTP error: ' + res.getStatusCode());
            }
        } catch (GeocodingException e) {
            throw e;
        } catch (Exception e) {
            System.debug('Error calling Google Geocoding API: ' + e.getMessage());
            throw new GeocodingException('Error calling Google Geocoding API: ' + e.getMessage());
        }
    }
}

