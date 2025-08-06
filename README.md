# PropertyChain Smart Contract

A comprehensive Clarity smart contract for tokenizing and managing real estate assets on the Stacks blockchain. PropertyChain enables secure, transparent property ownership transfers with built-in escrow and multi-party verification.

## Overview

PropertyChain digitizes real estate transactions by creating blockchain-based property records and facilitating secure ownership transfers through a multi-signature escrow system. The contract ensures all transfers are properly verified by authorized validators before completion.

## Key Features

- **Asset Registration**: Register real estate properties with detailed descriptions and valuations
- **Secure Transfers**: Multi-party approval system with escrow protection
- **Validator Network**: Authorized validators verify transaction legitimacy
- **Automatic Refunds**: Built-in expiration and refund mechanisms
- **Ownership Tracking**: Complete audit trail of property ownership history

## Core Components

### Data Storage

- **Real Estate Records**: Stores property details, ownership, valuation, and sale status
- **Custody Transfers**: Manages pending transactions in escrow with approval tracking
- **Authorized Validators**: Registry of approved validators with regional jurisdictions

### User Roles

1. **Property Owners**: Can register, update, list, and transfer their assets
2. **Purchasers**: Can initiate purchases and provide consent for transfers
3. **Validators**: Authorized entities who verify transfer legitimacy
4. **Contract Administrator**: Manages validator authorization and contract ownership

## Transaction Flow

1. **Property Registration**: Owner registers asset with description and market value
2. **Listing for Sale**: Owner sets asking price and makes property available
3. **Purchase Initiation**: Buyer deposits funds into escrow and initiates transfer
4. **Multi-Party Approval**: Vendor, purchaser, and validator must all approve
5. **Transfer Completion**: Once all approvals received, ownership transfers and funds released
6. **Automatic Cleanup**: Escrow cleared and property records updated

## Key Functions

### Property Management
- `register-asset`: Register new real estate property
- `update-asset-details`: Update property description and valuation
- `list-asset-for-sale`: List property with asking price
- `delist-asset`: Remove property from sale

### Transfer Operations
- `initiate-purchase`: Start purchase process with escrow deposit
- `approve-transfer-as-vendor`: Seller approves the transaction
- `approve-transfer-as-validator`: Validator verifies and approves
- `complete-transfer`: Execute final ownership transfer
- `cancel-transfer`: Cancel pending transfer with refund
- `refund-expired-transfer`: Auto-refund expired transactions

### Administration
- `add-validator`: Authorize new validator (admin only)
- `deactivate-validator`: Remove validator authorization (admin only)
- `transfer-contract-administration`: Change contract administrator

### Query Functions
- `get-asset`: Retrieve property details
- `is-asset-owner`: Check ownership status
- `get-custody-details`: View escrow transaction details
- `is-validator-active`: Check validator status

## Security Features

- **Multi-signature Escrow**: Requires approval from buyer, seller, and validator
- **Time-locked Transfers**: Automatic expiration prevents stuck transactions
- **Access Controls**: Role-based permissions for different operations
- **Validator Network**: Authorized third-party verification system
- **Automatic Refunds**: Built-in protection against lost funds

## Error Handling

The contract includes comprehensive error codes for various scenarios:
- Authorization failures
- Asset not found or already exists
- Ownership verification
- Transfer state validation
- Expired transactions
- Insufficient funds

## Usage Example

```clarity
;; Register a new property
(contract-call? .propertychain register-asset 
  "property-123-uuid" 
  u"3BR house, downtown, 2000 sq ft" 
  u500000)

;; List property for sale
(contract-call? .propertychain list-asset-for-sale 
  "property-123-uuid" 
  u450000)

;; Initiate purchase (buyer)
(contract-call? .propertychain initiate-purchase 
  "property-123-uuid")

;; Approve transfer (seller)
(contract-call? .propertychain approve-transfer-as-vendor 
  "property-123-uuid")

;; Approve transfer (validator)
(contract-call? .propertychain approve-transfer-as-validator 
  "property-123-uuid")

;; Complete the transfer
(contract-call? .propertychain complete-transfer 
  "property-123-uuid")
```

## Deployment Requirements

- Stacks blockchain environment
- Clarity smart contract support
- STX tokens for transaction fees and escrow deposits
- Authorized validator network setup
