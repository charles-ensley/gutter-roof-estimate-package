public with sharing class GutterPricingEstimateController {
    
    /**
     * Invocable method for Flow to calculate and update Gutter_Cost_Estimate__c
     * Call this after updating Property_Measurement_Details__c with JSON segments
     */
    @InvocableMethod(label='Calculate Gutter Pricing Estimate' description='Calculates gutter pricing from measurement segments and updates Gutter_Cost_Estimate__c')
    public static void calculateAndUpdateEstimate(List<Id> contactIds) {
        if (contactIds == null || contactIds.isEmpty()) {
            return;
        }
        
        List<Contact> contactsToUpdate = new List<Contact>();
        
        for (Id contactId : contactIds) {
            try {
                Contact contact = [
                    SELECT Property_Measurement_Details__c,
                           Has_Gutter_Guards__c,
                           New_Customer__c,
                           Walkable__c,
                           Copper_Material__c
                    FROM Contact
                    WHERE Id = :contactId
                    LIMIT 1
                ];
                
                if (String.isBlank(contact.Property_Measurement_Details__c)) {
                    continue; // Skip if no measurement data
                }
                
                PricingEstimate estimate = new PricingEstimate();
                estimate.hasGutterGuards = contact.Has_Gutter_Guards__c == 'Yes';
                estimate.isNewCustomer = contact.New_Customer__c == 'Yes';
                
                // Parse JSON segments from Property_Measurement_Details__c
                parsePricingDetails(contact.Property_Measurement_Details__c, estimate);
                
                // Override walkable/copper from Contact fields if set, otherwise use JSON values
                if (String.isNotBlank(contact.Walkable__c)) {
                    estimate.isWalkable = contact.Walkable__c == 'Yes';
                }
                if (String.isNotBlank(contact.Copper_Material__c)) {
                    estimate.hasCopperMaterial = contact.Copper_Material__c == 'Yes';
                }
                
                // Calculate total price
                calculateTotalPrice(estimate);
                
                // Build formatted cost estimate text
                String costEstimateText = buildCostEstimateText(estimate);
                
                // Update the contact with calculated estimate and parsed values
                Contact contactUpdate = new Contact(Id = contactId);
                contactUpdate.Gutter_Cost_Estimate__c = costEstimateText;
                
                // Update walkable and copper fields from JSON if not already set
                if (String.isBlank(contact.Walkable__c) && estimate.isWalkable != null) {
                    contactUpdate.Walkable__c = estimate.isWalkable ? 'Yes' : 'No';
                }
                if (String.isBlank(contact.Copper_Material__c) && estimate.hasCopperMaterial != null) {
                    contactUpdate.Copper_Material__c = estimate.hasCopperMaterial ? 'Yes' : 'No';
                }
                
                contactsToUpdate.add(contactUpdate);
                
            } catch (Exception e) {
                System.debug('Error calculating estimate for contact ' + contactId + ': ' + e.getMessage());
            }
        }
        
        if (!contactsToUpdate.isEmpty()) {
            update contactsToUpdate;
        }
    }
    
    private static String buildCostEstimateText(PricingEstimate estimate) {
        List<String> lines = new List<String>();
        lines.add('Gutter Cleaning Estimate');
        lines.add('');
        
        String walkableLabel = (estimate.isWalkable != null && estimate.isWalkable) ? 'Walkable' : 'Unwalkable';
        
        if (estimate.floor1Footage > 0 && estimate.floor1Cost != null) {
            lines.add('1st Floor: ' + estimate.floor1Footage + ' ft × ' + formatCurrency(estimate.floor1Rate) + '/ft (' + walkableLabel + ') = ' + formatCurrency(estimate.floor1Cost));
        }
        
        if (estimate.floor2Footage > 0 && estimate.floor2Cost != null) {
            lines.add('2nd Floor: ' + estimate.floor2Footage + ' ft × ' + formatCurrency(estimate.floor2Rate) + '/ft (' + walkableLabel + ') = ' + formatCurrency(estimate.floor2Cost));
        }
        
        if (estimate.floor3Footage > 0 && estimate.floor3Cost != null) {
            lines.add('3rd Floor: ' + estimate.floor3Footage + ' ft × ' + formatCurrency(estimate.floor3Rate) + '/ft (' + walkableLabel + ') = ' + formatCurrency(estimate.floor3Cost));
        }
        
        lines.add('');
        lines.add('Gutter Cleaning Subtotal: ' + formatCurrency(estimate.gutterCleaningSubtotal));
        
        if (estimate.hasCopperMaterial != null && estimate.hasCopperMaterial && estimate.copperSurcharge > 0) {
            lines.add('Copper Material Surcharge (10%): ' + formatCurrency(estimate.copperSurcharge));
        }
        
        if (estimate.hasGutterGuards) {
            lines.add('Gutter Guards Multiplier (' + estimate.gutterGuardsMultiplier + 'x): Applied');
        }
        
        if (estimate.functionInspectionFee > 0) {
            lines.add('Function Inspection Fee: ' + formatCurrency(estimate.functionInspectionFee));
        }
        
        if (estimate.isNewCustomer != null && estimate.isNewCustomer && estimate.newCustomerDiscount > 0) {
            lines.add('New Customer Discount: -' + formatCurrency(estimate.newCustomerDiscount));
        }
        
        lines.add('');
        lines.add('Total Estimated Price: ' + formatCurrency(estimate.totalPrice));
        
        return String.join(lines, '\n');
    }
    
    private static String formatCurrency(Decimal amount) {
        return '$' + amount.setScale(2).toPlainString();
    }
    
    @AuraEnabled(cacheable=true)
    public static PricingEstimate getPricingEstimate(Id contactId) {
        if (contactId == null) {
            throw new AuraHandledException('Error retrieving pricing estimate: Contact ID is required');
        }
        
        try {
            List<Contact> contacts = [
                SELECT Property_Measurement_Details__c, 
                       Gutter_Cost_Estimate__c,
                       Has_Gutter_Guards__c,
                       New_Customer__c,
                       Walkable__c,
                       Copper_Material__c
                FROM Contact 
                WHERE Id = :contactId 
                LIMIT 1
            ];
            
            if (contacts.isEmpty()) {
                throw new AuraHandledException('Error retrieving pricing estimate: Contact not found');
            }
            
            Contact contact = contacts[0];
            
            PricingEstimate estimate = new PricingEstimate();
            estimate.hasGutterGuards = contact.Has_Gutter_Guards__c == 'Yes';
            estimate.isNewCustomer = contact.New_Customer__c == 'Yes';
            estimate.isWalkable = contact.Walkable__c == 'Yes';
            estimate.hasCopperMaterial = contact.Copper_Material__c == 'Yes';
            
            // Parse JSON segments from Property_Measurement_Details__c
            if (String.isNotBlank(contact.Property_Measurement_Details__c)) {
                parsePricingDetails(contact.Property_Measurement_Details__c, estimate);
            }
            
            // If Gutter_Cost_Estimate__c exists, use it (for backward compatibility)
            // Otherwise calculate from Property_Measurement_Details__c
            if (String.isNotBlank(contact.Gutter_Cost_Estimate__c)) {
                // Try to parse as JSON first (new format)
                if (contact.Gutter_Cost_Estimate__c.trim().startsWith('{')) {
                    parsePricingDetails(contact.Gutter_Cost_Estimate__c, estimate);
                }
            }
            
            // Calculate total price
            calculateTotalPrice(estimate);
            
            return estimate;
            
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving pricing estimate: ' + e.getMessage());
        }
    }
    
    private static void parseFloorMeasurements(String measurements, PricingEstimate estimate) {
        // Parse floor measurements from text
        // Expected formats: 
        // "1st Floor Linear Footage: 139.40 ft" or 
        // "1st Floor Total: 122.07 ft"
        
        System.debug('=== PARSING FLOOR MEASUREMENTS ===');
        System.debug('Input text length: ' + (measurements != null ? measurements.length() : 0));
        System.debug('First 200 chars: ' + (measurements != null && measurements.length() > 200 ? measurements.substring(0, 200) : measurements));
        
        // Try to find 1st floor (try both formats)
        Pattern floor1Pattern = Pattern.compile('(?i)1st\\s*floor\\s*(?:linear\\s*footage|total)[:\\s]+(\\d+(?:\\.\\d+)?)\\s*ft');
        Matcher matcher = floor1Pattern.matcher(measurements);
        if (matcher.find()) {
            estimate.floor1Footage = Decimal.valueOf(matcher.group(1));
            System.debug('Found floor 1 footage: ' + estimate.floor1Footage);
        } else {
            System.debug('Floor 1 pattern did not match');
        }
        
        // Try to find 2nd floor
        Pattern floor2Pattern = Pattern.compile('(?i)2nd\\s*floor\\s*(?:linear\\s*footage|total)[:\\s]+(\\d+(?:\\.\\d+)?)\\s*ft');
        matcher = floor2Pattern.matcher(measurements);
        if (matcher.find()) {
            estimate.floor2Footage = Decimal.valueOf(matcher.group(1));
            System.debug('Found floor 2 footage: ' + estimate.floor2Footage);
        } else {
            System.debug('Floor 2 pattern did not match');
        }
        
        // Try to find 3rd floor
        Pattern floor3Pattern = Pattern.compile('(?i)3rd\\s*floor\\s*(?:linear\\s*footage|total)[:\\s]+(\\d+(?:\\.\\d+)?)\\s*ft');
        matcher = floor3Pattern.matcher(measurements);
        if (matcher.find()) {
            estimate.floor3Footage = Decimal.valueOf(matcher.group(1));
            System.debug('Found floor 3 footage: ' + estimate.floor3Footage);
        }
    }
    
    private static void parsePricingDetails(String costEstimate, PricingEstimate estimate) {
        System.debug('=== PARSING PRICING DETAILS ===');
        System.debug('Input text length: ' + (costEstimate != null ? costEstimate.length() : 0));
        
        // Try to parse as JSON first
        if (costEstimate != null && costEstimate.trim().startsWith('{')) {
            try {
                Map<String, Object> jsonData = (Map<String, Object>) JSON.deserializeUntyped(costEstimate);
                
                // Parse walkable and copperMaterial from JSON
                if (jsonData.containsKey('walkable')) {
                    String walkableStr = String.valueOf(jsonData.get('walkable'));
                    estimate.isWalkable = walkableStr.equalsIgnoreCase('Yes');
                }
                
                if (jsonData.containsKey('copperMaterial')) {
                    String copperStr = String.valueOf(jsonData.get('copperMaterial'));
                    estimate.hasCopperMaterial = copperStr.equalsIgnoreCase('Yes');
                }
                
                // Parse floor segments and calculate linear footage
                // Store temporarily to compare and assign correctly (larger = Floor 1, smaller = Floor 2)
                Decimal footage1 = 0;
                Decimal footage2 = 0;
                
                if (jsonData.containsKey('floor1Segments')) {
                    Object segments1 = jsonData.get('floor1Segments');
                    if (segments1 instanceof List<Object>) {
                        footage1 = calculateLinearFootage((List<Object>) segments1);
                    }
                }
                
                if (jsonData.containsKey('floor2Segments')) {
                    Object segments2 = jsonData.get('floor2Segments');
                    if (segments2 instanceof List<Object>) {
                        footage2 = calculateLinearFootage((List<Object>) segments2);
                    }
                }
                
                // Assign correctly: larger footage = Floor 1, smaller = Floor 2
                if (footage1 >= footage2) {
                    // floor1Segments has larger or equal footage → assign to Floor 1
                    estimate.floor1Footage = footage1;
                    estimate.floor2Footage = footage2;
                } else {
                    // floor2Segments has larger footage → swap them
                    estimate.floor1Footage = footage2;
                    estimate.floor2Footage = footage1;
                }
                
                // Parse floor 3 (if exists)
                if (jsonData.containsKey('floor3Segments')) {
                    Object segments3 = jsonData.get('floor3Segments');
                    if (segments3 instanceof List<Object>) {
                        List<Object> segList = (List<Object>) segments3;
                        if (!segList.isEmpty()) {
                            estimate.floor3Footage = calculateLinearFootage(segList);
                        }
                    }
                }
                
                System.debug('Successfully parsed JSON data');
                System.debug('Walkable: ' + estimate.isWalkable);
                System.debug('Copper Material: ' + estimate.hasCopperMaterial);
                System.debug('Floor 1: ' + estimate.floor1Footage + ' ft');
                System.debug('Floor 2: ' + estimate.floor2Footage + ' ft');
                System.debug('Floor 3: ' + estimate.floor3Footage + ' ft');
                return;
                
            } catch (Exception e) {
                System.debug('Failed to parse as JSON, falling back to text parsing: ' + e.getMessage());
                System.debug('Error: ' + e.getStackTraceString());
            }
        }
        
        // Fallback to text parsing for backward compatibility
        System.debug('Parsing as text format...');
        System.debug('Full text: ' + costEstimate);
        
        // Parse the total price
        Pattern totalPattern = Pattern.compile('(?i)(?:total\\s*estimated|grand\\s*total)\\s*price[:\\s]+\\$([\\d,]+(?:\\.\\d+)?)');
        Matcher matcher = totalPattern.matcher(costEstimate);
        if (matcher.find()) {
            String priceStr = matcher.group(1).replace(',', '');
            estimate.totalPrice = Decimal.valueOf(priceStr);
        }
        
        // Parse base service fee
        Pattern feePattern = Pattern.compile('(?i)(?:base\\s*service|fixed\\s*base)\\s*fee[:\\s]+\\$([\\d,]+(?:\\.\\d+)?)');
        matcher = feePattern.matcher(costEstimate);
        if (matcher.find()) {
            String feeStr = matcher.group(1).replace(',', '');
            estimate.fudgeFactor = Decimal.valueOf(feeStr);
        }
        
        // Check for gutter guards fee
        Pattern guardsPattern = Pattern.compile('(?i)gutter\\s*guards\\s*(?:fee|surcharge)[:\\s]+(?:N/A|\\$([\\d,]+(?:\\.\\d+)?))');
        matcher = guardsPattern.matcher(costEstimate);
        if (matcher.find() && matcher.group(1) != null) {
            estimate.hasGutterGuards = true;
        }
    }
    
    private static Decimal calculateLinearFootage(List<Object> segments) {
        Decimal total = 0;
        for (Object seg : segments) {
            if (seg != null) {
                try {
                    Decimal segmentValue = Decimal.valueOf(String.valueOf(seg));
                    total += segmentValue;
                } catch (Exception e) {
                    System.debug('Error parsing segment value: ' + seg);
                }
            }
        }
        return total;
    }
    
    private static void calculateTotalPrice(PricingEstimate estimate) {
        // Pricing rates based on walkability:
        // Walkable: 1st Floor $1.37/ft, 2nd Floor $1.50/ft, 3rd Floor $1.76/ft
        // Unwalkable: 1st Floor $1.65/ft, 2nd Floor $1.87/ft, 3rd Floor $2.20/ft
        
        Decimal subtotal = 0;
        Boolean isWalkable = estimate.isWalkable != null && estimate.isWalkable;
        
        // Calculate per-floor costs using walkable/unwalkable rates
        if (estimate.floor1Footage != null && estimate.floor1Footage > 0) {
            Decimal rate1 = isWalkable ? 1.37 : 1.65;
            Decimal floor1Cost = estimate.floor1Footage * rate1;
            subtotal += floor1Cost;
            estimate.floor1Rate = rate1;
            estimate.floor1Cost = floor1Cost;
        }
        
        if (estimate.floor2Footage != null && estimate.floor2Footage > 0) {
            Decimal rate2 = isWalkable ? 1.50 : 1.87;
            Decimal floor2Cost = estimate.floor2Footage * rate2;
            subtotal += floor2Cost;
            estimate.floor2Rate = rate2;
            estimate.floor2Cost = floor2Cost;
        }
        
        if (estimate.floor3Footage != null && estimate.floor3Footage > 0) {
            Decimal rate3 = isWalkable ? 1.76 : 2.20;
            Decimal floor3Cost = estimate.floor3Footage * rate3;
            subtotal += floor3Cost;
            estimate.floor3Rate = rate3;
            estimate.floor3Cost = floor3Cost;
        }
        
        // Store gutter cleaning subtotal before other adjustments
        estimate.gutterCleaningSubtotal = subtotal;
        
        // Copper Material Surcharge: +10%
        if (estimate.hasCopperMaterial != null && estimate.hasCopperMaterial) {
            estimate.copperSurcharge = subtotal * 0.10;
            subtotal += estimate.copperSurcharge;
        } else {
            estimate.copperSurcharge = 0;
        }
        
        // Function Inspection Fee
        // $75 if subtotal < $150, OR 25% (x1.25) if >= $150
        // BUT NOT if customer has gutter guards
        if (!estimate.hasGutterGuards) {
            if (subtotal < 150) {
                estimate.functionInspectionFee = 75.00;
                subtotal += estimate.functionInspectionFee;
            } else {
                // Use 25% multiplier (x1.25) - could be made configurable to 50% (x1.5)
                Decimal inspectionMultiplier = 1.25;
                Decimal preInspectionSubtotal = subtotal;
                subtotal = subtotal * inspectionMultiplier;
                estimate.functionInspectionFee = subtotal - preInspectionSubtotal;
            }
        } else {
            estimate.functionInspectionFee = 0;
        }
        
        // Gutter Guards Multiplier (applied after function inspection)
        // Default to 1st cleaning (x2.2) - can be overridden if we add a field for cleaning number
        // For now, assume 1st cleaning. If estimate already exists, could be 2nd cleaning (x1.5)
        if (estimate.hasGutterGuards) {
            // Check if this might be a 2nd cleaning (if estimate already has data)
            // For now, default to 1st cleaning multiplier
            Boolean isFirstCleaning = true; // TODO: Add field or logic to determine cleaning number
            if (isFirstCleaning) {
                estimate.gutterGuardsMultiplier = 2.2;
                subtotal = subtotal * 2.2;
            } else {
                estimate.gutterGuardsMultiplier = 1.5;
                subtotal = subtotal * 1.5;
            }
        } else {
            estimate.gutterGuardsMultiplier = 1.0;
        }
        
        // New Customer Discount: $25 if total > $300
        if (estimate.isNewCustomer != null && estimate.isNewCustomer && subtotal > 300) {
            estimate.newCustomerDiscount = 25.00;
            subtotal -= estimate.newCustomerDiscount;
        } else {
            estimate.newCustomerDiscount = 0;
        }
        
        estimate.totalPrice = subtotal;
    }
    
    public class PricingEstimate {
        @AuraEnabled public Decimal floor1Footage { get; set; }
        @AuraEnabled public Decimal floor2Footage { get; set; }
        @AuraEnabled public Decimal floor3Footage { get; set; }
        @AuraEnabled public Decimal floor1Rate { get; set; }
        @AuraEnabled public Decimal floor2Rate { get; set; }
        @AuraEnabled public Decimal floor3Rate { get; set; }
        @AuraEnabled public Decimal floor1Cost { get; set; }
        @AuraEnabled public Decimal floor2Cost { get; set; }
        @AuraEnabled public Decimal floor3Cost { get; set; }
        @AuraEnabled public Decimal gutterCleaningSubtotal { get; set; }
        @AuraEnabled public Decimal copperSurcharge { get; set; }
        @AuraEnabled public Decimal gutterGuardsMultiplier { get; set; }
        @AuraEnabled public Decimal functionInspectionFee { get; set; }
        @AuraEnabled public Decimal newCustomerDiscount { get; set; }
        @AuraEnabled public Boolean hasGutterGuards { get; set; }
        @AuraEnabled public Boolean isWalkable { get; set; }
        @AuraEnabled public Boolean hasCopperMaterial { get; set; }
        @AuraEnabled public Boolean isNewCustomer { get; set; }
        @AuraEnabled public Decimal totalPrice { get; set; }
        
        // Legacy fields for backward compatibility
        @AuraEnabled public Decimal fudgeFactor { get; set; }
        @AuraEnabled public Decimal surchargePercent { get; set; }
        
        public PricingEstimate() {
            this.floor1Footage = 0;
            this.floor2Footage = 0;
            this.floor3Footage = 0;
            this.floor1Rate = 0;
            this.floor2Rate = 0;
            this.floor3Rate = 0;
            this.floor1Cost = 0;
            this.floor2Cost = 0;
            this.floor3Cost = 0;
            this.gutterCleaningSubtotal = 0;
            this.copperSurcharge = 0;
            this.gutterGuardsMultiplier = 1.0;
            this.functionInspectionFee = 0;
            this.newCustomerDiscount = 0;
            this.hasGutterGuards = false;
            this.isWalkable = false;
            this.hasCopperMaterial = false;
            this.isNewCustomer = false;
            this.totalPrice = 0;
            // Legacy
            this.fudgeFactor = 0;
            this.surchargePercent = 0;
        }
    }
}
