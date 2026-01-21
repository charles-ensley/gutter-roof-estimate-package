import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import getPricingEstimate from '@salesforce/apex/GutterPricingEstimateController.getPricingEstimate';

const FIELDS = [
    'Contact.Property_Measurement_Details__c',
    'Contact.Gutter_Cost_Estimate__c',
    'Contact.Has_Gutter_Guards__c',
    'Contact.New_Customer__c',
    'Contact.Walkable__c',
    'Contact.Copper_Material__c'
];

export default class GutterPricingEstimate extends LightningElement {
    @api recordId;
    
    estimate;
    error;
    isLoading = true;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    contactData({ error, data }) {
        if (data) {
            // Check if Property_Measurement_Details__c has data (JSON segments)
            // The Apex will calculate from this and populate Gutter_Cost_Estimate__c
            const measurementDetails = data.fields?.Property_Measurement_Details__c?.value;
            if (measurementDetails && measurementDetails.trim() !== '') {
                this.loadPricingEstimate();
            } else {
                // No measurement data yet
                this.isLoading = false;
            }
        } else if (error) {
            this.error = error;
            this.isLoading = false;
        }
    }

    loadPricingEstimate() {
        getPricingEstimate({ contactId: this.recordId })
            .then(result => {
                this.estimate = result;
                this.error = undefined;
                this.isLoading = false;
            })
            .catch(error => {
                this.error = error;
                this.estimate = undefined;
                this.isLoading = false;
            });
    }

    get hasEstimate() {
        return this.estimate && !this.isLoading;
    }

    get visibleFloors() {
        if (!this.estimate) return [];
        
        const floors = [];
        
        if (this.estimate.floor1Footage && this.estimate.floor1Footage > 0) {
            floors.push({
                id: 'floor1',
                label: 'FLOOR 1',
                footage: `${this.formatNumber(this.estimate.floor1Footage)} ft`
            });
        }
        
        if (this.estimate.floor2Footage && this.estimate.floor2Footage > 0) {
            floors.push({
                id: 'floor2',
                label: 'FLOOR 2',
                footage: `${this.formatNumber(this.estimate.floor2Footage)} ft`
            });
        }
        
        if (this.estimate.floor3Footage && this.estimate.floor3Footage > 0) {
            floors.push({
                id: 'floor3',
                label: 'FLOOR 3',
                footage: `${this.formatNumber(this.estimate.floor3Footage)} ft`
            });
        }
        
        return floors;
    }
    
    formatNumber(value) {
        if (!value) return '0';
        return Number(value).toFixed(2);
    }
    
    get hasFloors() {
        return this.visibleFloors.length > 0;
    }

    get formattedTotal() {
        if (this.estimate?.totalPrice) {
            return new Intl.NumberFormat('en-US', {
                style: 'currency',
                currency: 'USD',
                minimumFractionDigits: 2
            }).format(this.estimate.totalPrice);
        }
        return '$0.00';
    }

    get priceBreakdown() {
        if (!this.estimate) return [];
        
        const breakdown = [];
        const walkableLabel = (this.estimate.isWalkable) ? 'Walkable' : 'Unwalkable';
        
        // Floor costs
        if (this.estimate.floor1Footage && this.estimate.floor1Footage > 0 && this.estimate.floor1Cost) {
            breakdown.push({
                id: 'floor1',
                label: `1st Floor: ${this.formatNumber(this.estimate.floor1Footage)} ft × ${this.formatCurrency(this.estimate.floor1Rate)}/ft (${walkableLabel})`,
                amount: this.formatCurrency(this.estimate.floor1Cost)
            });
        }
        
        if (this.estimate.floor2Footage && this.estimate.floor2Footage > 0 && this.estimate.floor2Cost) {
            breakdown.push({
                id: 'floor2',
                label: `2nd Floor: ${this.formatNumber(this.estimate.floor2Footage)} ft × ${this.formatCurrency(this.estimate.floor2Rate)}/ft (${walkableLabel})`,
                amount: this.formatCurrency(this.estimate.floor2Cost)
            });
        }
        
        if (this.estimate.floor3Footage && this.estimate.floor3Footage > 0 && this.estimate.floor3Cost) {
            breakdown.push({
                id: 'floor3',
                label: `3rd Floor: ${this.formatNumber(this.estimate.floor3Footage)} ft × ${this.formatCurrency(this.estimate.floor3Rate)}/ft (${walkableLabel})`,
                amount: this.formatCurrency(this.estimate.floor3Cost)
            });
        }
        
        // Gutter Cleaning Subtotal
        if (this.estimate.gutterCleaningSubtotal && this.estimate.gutterCleaningSubtotal > 0) {
            breakdown.push({
                id: 'subtotal',
                label: 'Gutter Cleaning Subtotal',
                amount: this.formatCurrency(this.estimate.gutterCleaningSubtotal),
                isSubtotal: true
            });
        }
        
        // Copper Material Surcharge
        if (this.estimate.hasCopperMaterial && this.estimate.copperSurcharge > 0) {
            breakdown.push({
                id: 'copper',
                label: 'Copper Material Surcharge (10%)',
                amount: this.formatCurrency(this.estimate.copperSurcharge)
            });
        }
        
        // Gutter Guards Multiplier
        if (this.estimate.hasGutterGuards && this.estimate.gutterGuardsMultiplier > 1.0) {
            breakdown.push({
                id: 'guards',
                label: `Gutter Guards Multiplier (${this.estimate.gutterGuardsMultiplier}x)`,
                amount: 'Applied'
            });
        }
        
        // Function Inspection Fee
        if (this.estimate.functionInspectionFee > 0) {
            breakdown.push({
                id: 'inspection',
                label: 'Function Inspection Fee',
                amount: this.formatCurrency(this.estimate.functionInspectionFee)
            });
        }
        
        // New Customer Discount
        if (this.estimate.isNewCustomer && this.estimate.newCustomerDiscount > 0) {
            breakdown.push({
                id: 'discount',
                label: 'New Customer Discount',
                amount: '-' + this.formatCurrency(this.estimate.newCustomerDiscount),
                isDiscount: true
            });
        }
        
        return breakdown;
    }
    
    get hasBreakdown() {
        return this.priceBreakdown.length > 0;
    }

    formatCurrency(value) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            minimumFractionDigits: 2
        }).format(value || 0);
    }
}
