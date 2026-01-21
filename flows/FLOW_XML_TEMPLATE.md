# Flow XML Template Structure

This document provides a reference structure for the Flow XML. Note that actual Flow XML is complex and best created through the Flow Builder UI, then exported. This template shows the key elements and structure.

## Flow Metadata Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Flow xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>60.0</apiVersion>
    <description>Extracts property measurements using AI and calculates gutter pricing estimate</description>
    <environments>Default</environments>
    <formulas/>
    <interviewLabel>Get Gutter Estimate {!$Flow.CurrentDateTime}</interviewLabel>
    <label>Get Gutter Estimate</label>
    <processMetadataValues/>
    <start>
        <!-- Flow start element -->
    </start>
    <status>Active</status>
    <variables>
        <!-- Flow variables -->
    </variables>
</Flow>
```

## Key Flow Elements

### Variables

```xml
<variables>
    <!-- Input Variable -->
    <name>contactId</name>
    <apexClass/>
    <dataType>String</dataType>
    <isCollection>false</isCollection>
    <isInput>true</isInput>
    <isOutput>false</isOutput>
    
    <!-- Record Variable -->
    <name>currentContact</name>
    <dataType>SObject</dataType>
    <isCollection>false</isCollection>
    <sobjectType>Contact</sobjectType>
    
    <!-- Text Variables -->
    <name>promptText</name>
    <dataType>String</dataType>
    
    <name>promptResponse</name>
    <dataType>String</dataType>
</variables>
```

### Screen Elements

```xml
<screens>
    <name>PrepareEstimate</name>
    <label>Prepare Estimate</label>
    <locationX>50</locationX>
    <locationY>50</locationY>
    <allowBack>false</allowBack>
    <allowFinish>false</allowFinish>
    <allowPause>false</allowPause>
    <fields>
        <!-- Contact Lookup Field -->
        <name>selectedContact</name>
        <fieldType>Lookup</fieldType>
        <isRequired>true</isRequired>
        <label>Select Contact</label>
        <object>Contact</object>
    </fields>
    <helpText>This flow will analyze aerial imagery to extract property measurements and calculate a gutter cleaning estimate.</helpText>
</screens>
```

### Get Records Element

```xml
<getRecords>
    <name>GetContact</name>
    <label>Get Contact</label>
    <locationX>50</locationX>
    <locationY>200</locationY>
    <assignNullValuesIfNoRecordsFound>false</assignNullValuesIfNoRecordsFound>
    <connector>
        <targetReference>NextElement</targetReference>
    </connector>
    <filterLogic>1</filterLogic>
    <filters>
        <field>Id</field>
        <operator>EqualTo</operator>
        <value>
            <elementReference>selectedContact.Id</elementReference>
        </value>
    </filters>
    <getFirstRecordOnly>true</getFirstRecordOnly>
    <object>Contact</object>
    <storeOutputAutomatically>true</storeOutputAutomatically>
    <outputReference>currentContact</outputReference>
    <queriedFields>
        <field>Id</field>
        <field>Name</field>
        <field>MailingStreet</field>
        <field>MailingCity</field>
        <field>MailingState</field>
        <field>MailingPostalCode</field>
        <field>MailingCountry</field>
        <field>MailingLatitude</field>
        <field>MailingLongitude</field>
        <field>Property_Measurement_Details__c</field>
        <field>Has_Gutter_Guards__c</field>
        <field>Walkable__c</field>
        <field>Copper_Material__c</field>
        <field>New_Customer__c</field>
    </queriedFields>
</getRecords>
```

### Assignment Element

```xml
<assignments>
    <name>BuildPrompt</name>
    <label>Build Prompt</label>
    <locationX>50</locationX>
    <locationY>350</locationY>
    <assignments>
        <field>promptText</field>
        <value>
            <stringValue>You are an expert property measurement analyst... [Full prompt text]</stringValue>
        </value>
    </assignments>
    <connector>
        <targetReference>ExtractMeasurements</targetReference>
    </connector>
</assignments>
```

### Action Element (Apex Invocable)

```xml
<actionCalls>
    <name>CalculatePricing</name>
    <label>Calculate Gutter Pricing Estimate</label>
    <locationX>50</locationX>
    <locationY>500</locationY>
    <actionName>GutterPricingEstimateController.calculateAndUpdateEstimate</actionName>
    <actionType>apex</actionType>
    <connector>
        <targetReference>SuccessScreen</targetReference>
    </connector>
    <inputParameters>
        <name>contactIds</name>
        <value>
            <elementReference>currentContact.Id</elementReference>
        </value>
    </inputParameters>
    <faultConnector>
        <targetReference>ErrorScreen</targetReference>
    </faultConnector>
</actionCalls>
```

### Update Records Element

```xml
<recordUpdates>
    <name>UpdateContactFields</name>
    <label>Update Contact Fields</label>
    <locationX>50</locationX>
    <locationY>650</locationY>
    <inputReference>currentContact</inputReference>
    <inputAssignments>
        <field>Property_Measurement_Details__c</field>
        <value>
            <elementReference>promptResponse</elementReference>
        </value>
    </inputAssignments>
    <connector>
        <targetReference>CalculatePricing</targetReference>
    </connector>
</recordUpdates>
```

### Decision Element

```xml
<decisions>
    <name>HasCoordinates</name>
    <label>Has Coordinates?</label>
    <locationX>50</locationX>
    <locationY>800</locationY>
    <defaultConnectorLabel>No Coordinates</defaultConnectorLabel>
    <rules>
        <name>HasCoordinates</name>
        <conditionLogic>and</conditionLogic>
        <conditions>
            <leftValueReference>currentContact.MailingLatitude</leftValueReference>
            <operator>IsNull</operator>
            <rightValue>
                <booleanValue>false</booleanValue>
            </rightValue>
        </conditions>
        <conditions>
            <leftValueReference>currentContact.MailingLongitude</leftValueReference>
            <operator>IsNull</operator>
            <rightValue>
                <booleanValue>false</booleanValue>
            </rightValue>
        </conditions>
        <connector>
            <targetReference>BuildPrompt</targetReference>
        </connector>
        <label>Has Coordinates</label>
    </rules>
    <connector>
        <targetReference>GeocodingErrorScreen</targetReference>
    </connector>
</decisions>
```

## Complete Flow Structure (Conceptual)

```
Start
  ↓
PrepareEstimate Screen
  ↓
GetContact (Get Records)
  ↓
HasCoordinates? (Decision)
  ├─ Yes → BuildPrompt (Assignment)
  └─ No → GeocodingErrorScreen
  ↓
ExtractMeasurements (Action - Prompt Builder)
  ↓
ValidateJSON? (Decision)
  ├─ Valid → UpdateContactFields (Update Records)
  └─ Invalid → InvalidJSONErrorScreen
  ↓
CalculatePricing (Action - Apex)
  ├─ Success → SuccessScreen
  └─ Error → CalculationErrorScreen
  ↓
End
```

## Exporting Flow XML

To get the actual Flow XML:

1. **Create Flow in Flow Builder**
   - Follow the guide in `FLOW_GUIDE.md`
   - Build the flow step by step

2. **Export Flow XML:**
   ```bash
   sf project retrieve start --metadata Flow:Get_Gutter_Estimate
   ```

3. **Flow XML Location:**
   ```
   force-app/main/default/flows/Get_Gutter_Estimate.flow-meta.xml
   ```

## Notes

- Flow XML is complex and best created through the UI
- This template provides structure reference only
- Actual implementation should use Flow Builder
- Export existing flows to see complete XML structure
- Flow XML format changes with Salesforce API versions

## Recommended Approach

1. **Use Flow Builder UI** to create the flow
2. **Follow FLOW_GUIDE.md** for step-by-step instructions
3. **Export Flow XML** after creation for version control
4. **Test thoroughly** before deploying to production
