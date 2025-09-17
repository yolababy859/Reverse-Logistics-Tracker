# 📦 Reverse Logistics Tracker

A comprehensive smart contract for managing product returns, refunds, and reverse logistics operations on the Stacks blockchain.

## 🚀 Features

- **Product Registration**: Register products with merchants for return tracking
- **Return Initiation**: Customers can initiate returns with reasons and condition descriptions
- **Inspector Authorization**: Authorized inspectors can review and approve/reject returns
- **Logistics Tracking**: Complete tracking from pickup scheduling to final disposition
- **Batch Operations**: Bulk status updates and disposition management
- **Merchant Analytics**: Track return statistics and generate reports
- **Multiple Dispositions**: Support for restocking, recycling, and disposal workflows

## 📋 Core Functions

### Product Management
- `register-product` - Register a product for return tracking
- `get-product` - Retrieve product information

### Return Management
- `initiate-return` - Start a return process
- `get-return` - Get return details
- `update-return-status` - Update return status
- `get-return-history` - Complete return audit trail

### Logistics Operations
- `schedule-pickup` - Schedule return pickup with carrier
- `confirm-receipt` - Confirm receipt at processing facility
- `update-tracking` - Update tracking information

### Inspector Functions
- `authorize-inspector` - Grant inspector permissions (contract owner only)
- `revoke-inspector` - Remove inspector permissions (contract owner only)
- `inspect-return` - Inspect and approve/reject returns
- `approve-return-batch` - Bulk approve returns
- `reject-return-batch` - Bulk reject returns

### Disposition Management
- `mark-as-restocked` - Mark approved returns as restocked
- `mark-as-recycled` - Mark returns for recycling
- `mark-as-disposed` - Mark returns for disposal
- `set-disposition-bulk` - Bulk disposition updates

### Analytics & Reporting
- `generate-return-report` - Generate merchant return statistics
- `get-merchant-stats` - Get merchant performance metrics
- `get-disposition-summary` - Summary of disposition outcomes
- `get-contract-stats` - Overall contract statistics

## 🔧 Usage Example

```clarity
;; Register a product
(contract-call? .reverse-logistics-tracker register-product "iPhone 15" u999 "Electronics")

;; Initiate a return
(contract-call? .reverse-logistics-tracker initiate-return u1 "Defective screen" "damaged")

;; Schedule pickup (merchant only)
(contract-call? .reverse-logistics-tracker schedule-pickup u1 "FedEx" "1234567890" u100)

;; Confirm receipt (merchant only)
(contract-call? .reverse-logistics-tracker confirm-receipt u1)

;; Inspect return (authorized inspector only)
(contract-call? .reverse-logistics-tracker inspect-return u1 "approved" "restock")

;; Process refund (merchant only)
(contract-call? .reverse-logistics-tracker process-refund u1 u800)
```

## 🏗️ Contract States

### Return Status Flow
1. **initiated** - Customer starts return
2. **pickup-scheduled** - Merchant schedules pickup
3. **received** - Item received at processing facility
4. **approved/rejected** - Inspector decision
5. **refunded** - Refund processed (approved items)
6. **restocked/recycled/disposed** - Final disposition

### Product Conditions
- `new` - Unopened/unused
- `like-new` - Minimal wear
- `good` - Normal wear
- `fair` - Significant wear
- `damaged` - Requires repair/refurbishment

## 🛡️ Security Features

- **Role-based Access**: Merchants, customers, and inspectors have specific permissions
- **Status Validation**: Prevents invalid state transitions
- **Owner Controls**: Contract owner manages inspector authorization
- **Data Integrity**: Immutable audit trail for all operations

## 🧪 Testing

```bash
npm install
npm test
```

## 📊 Analytics

The contract provides comprehensive analytics including:
- Total returns per merchant
- Processing time metrics
- Disposition breakdowns
- Return rate calculations
- Historical data tracking

## 🔗 Integration

This contract can be integrated with:
- E-commerce platforms for automated return processing
- Logistics providers for tracking integration
- Payment systems for automated refunds
- Analytics dashboards for business intelligence

## 📄 License

MIT License - See LICENSE file for details
