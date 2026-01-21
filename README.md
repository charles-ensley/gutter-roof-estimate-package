# Gutter Roof Estimation Package

This package contains all components needed to implement a complete gutter cleaning/roof estimation system in Salesforce using AI-powered property measurement extraction, visual mapping integration, and automated pricing calculations.

## Package Contents

1. **Basic Configuration** (`docs/01-BASIC_CONFIG.md`) - Field definitions and values
2. **Integration Documentation** (`docs/02-INTEGRATIONS.md`) - Nearmap and Google Street View setup
3. **LWC Configuration** (`docs/03-LWC_CONFIG.md`) - Lightning Web Component setup guides
4. **Prompt Template** (`docs/04-PROMPT_TEMPLATE.md`) - AI prompt for property measurement extraction
5. **Apex Classes** (`classes/`) - Pricing calculation logic
6. **Lightning Web Components** (`lwc/`) - UI components for pricing display and mapping
7. **Flow Template** (`flows/`) - Flow XML template for property data extraction

## Quick Start

1. Deploy the Contact fields (see `docs/01-BASIC_CONFIG.md`)
2. Deploy the Apex classes (see `classes/`)
3. Deploy the Lightning Web Components (see `lwc/`)
4. Configure integrations (see `docs/02-INTEGRATIONS.md`)
5. Set up the Flow (see `flows/`)
6. Configure the prompt template (see `docs/04-PROMPT_TEMPLATE.md`)

## Overview

This solution enables:
- **AI-powered property measurement extraction** from aerial imagery
- **Visual property inspection** via Nearmap and Google Street View
- **Automated pricing calculations** based on property attributes
- **Professional pricing display** with detailed breakdowns

## Key Features

- Extract perimeter measurements for multi-floor properties
- Assess walkability and material type (copper detection)
- Calculate pricing with multiple factors (walkability, material, gutter guards, customer status)
- Display interactive maps and street-level views
- Generate professional cost estimates with detailed breakdowns

## Support

For questions or issues, refer to the individual documentation files in the `docs/` directory.
