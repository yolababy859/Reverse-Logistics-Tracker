(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_STATUS (err u102))
(define-constant ERR_ALREADY_EXISTS (err u103))
(define-constant ERR_INVALID_CONDITION (err u104))
(define-constant ERR_DISPUTE_NOT_ALLOWED (err u105))
(define-constant ERR_DISPUTE_ALREADY_EXISTS (err u106))
(define-constant ERR_DISPUTE_RESOLVED (err u107))

(define-data-var next-return-id uint u1)
(define-data-var next-product-id uint u1)
(define-data-var next-dispute-id uint u1)

(define-map returns
    { return-id: uint }
    {
        product-id: uint,
        customer: principal,
        merchant: principal,
        return-reason: (string-ascii 100),
        status: (string-ascii 20),
        created-at: uint,
        updated-at: uint,
        refund-amount: uint,
        condition: (string-ascii 20),
    }
)

(define-map products
    { product-id: uint }
    {
        name: (string-ascii 50),
        original-price: uint,
        merchant: principal,
        category: (string-ascii 30),
        created-at: uint,
    }
)

(define-map return-logistics
    { return-id: uint }
    {
        shipping-carrier: (string-ascii 30),
        tracking-number: (string-ascii 50),
        pickup-scheduled: bool,
        pickup-date: uint,
        received-date: uint,
        inspection-status: (string-ascii 20),
        disposition: (string-ascii 30),
    }
)

(define-map return-sla
    { return-id: uint }
    {
        sla-deadline: uint,
        sla-type: (string-ascii 20),
    }
)

(define-map merchant-stats
    { merchant: principal }
    {
        total-returns: uint,
        total-refunds: uint,
        average-processing-time: uint,
        return-rate: uint,
    }
)

(define-map authorized-inspectors
    { inspector: principal }
    { authorized: bool }
)

(define-map disputes
    { dispute-id: uint }
    {
        return-id: uint,
        customer: principal,
        merchant: principal,
        dispute-reason: (string-ascii 200),
        evidence-hash: (string-ascii 64),
        status: (string-ascii 20),
        filed-at: uint,
        resolved-at: uint,
        arbitrator: (optional principal),
        resolution: (optional (string-ascii 200)),
        customer-compensation: uint,
    }
)

(define-map authorized-arbitrators
    { arbitrator: principal }
    { authorized: bool }
)

(define-map customer-returns-count
    { customer: principal }
    { count: uint }
)

(define-map customer-returns-index
    {
        customer: principal,
        index: uint,
    }
    { return-id: uint }
)

(define-map merchant-returns-count
    { merchant: principal }
    { count: uint }
)

(define-map merchant-returns-index
    {
        merchant: principal,
        index: uint,
    }
    { return-id: uint }
)

(define-read-only (get-return (return-id uint))
    (map-get? returns { return-id: return-id })
)

(define-read-only (get-product (product-id uint))
    (map-get? products { product-id: product-id })
)

(define-read-only (get-return-logistics (return-id uint))
    (map-get? return-logistics { return-id: return-id })
)

(define-read-only (get-merchant-stats (merchant principal))
    (map-get? merchant-stats { merchant: merchant })
)

(define-read-only (is-authorized-inspector (inspector principal))
    (default-to false
        (get authorized (map-get? authorized-inspectors { inspector: inspector }))
    )
)

(define-read-only (get-next-return-id)
    (var-get next-return-id)
)

(define-read-only (get-next-product-id)
    (var-get next-product-id)
)

(define-read-only (get-dispute (dispute-id uint))
    (map-get? disputes { dispute-id: dispute-id })
)

(define-read-only (is-authorized-arbitrator (arbitrator principal))
    (default-to false
        (get authorized
            (map-get? authorized-arbitrators { arbitrator: arbitrator })
        ))
)

(define-read-only (get-next-dispute-id)
    (var-get next-dispute-id)
)

(define-public (register-product
        (name (string-ascii 50))
        (price uint)
        (category (string-ascii 30))
    )
    (let (
            (product-id (var-get next-product-id))
            (current-time stacks-block-height)
        )
        (map-set products { product-id: product-id } {
            name: name,
            original-price: price,
            merchant: tx-sender,
            category: category,
            created-at: current-time,
        })
        (var-set next-product-id (+ product-id u1))
        (ok product-id)
    )
)

(define-public (initiate-return
        (product-id uint)
        (reason (string-ascii 100))
        (condition (string-ascii 20))
    )
    (let (
            (return-id (var-get next-return-id))
            (current-time stacks-block-height)
            (product-data (unwrap! (get-product product-id) ERR_NOT_FOUND))
            (customer tx-sender)
            (merchant (get merchant product-data))
            (customer-count (match (map-get? customer-returns-count { customer: customer })
                entry (get count entry)
                u0
            ))
            (merchant-count (match (map-get? merchant-returns-count { merchant: merchant })
                entry (get count entry)
                u0
            ))
        )
        (map-set returns { return-id: return-id } {
            product-id: product-id,
            customer: customer,
            merchant: merchant,
            return-reason: reason,
            status: "initiated",
            created-at: current-time,
            updated-at: current-time,
            refund-amount: u0,
            condition: condition,
        })
        (map-set customer-returns-index {
            customer: customer,
            index: customer-count,
        } { return-id: return-id }
        )
        (map-set customer-returns-count { customer: customer } { count: (+ customer-count u1) })
        (map-set merchant-returns-index {
            merchant: merchant,
            index: merchant-count,
        } { return-id: return-id }
        )
        (map-set merchant-returns-count { merchant: merchant } { count: (+ merchant-count u1) })
        (var-set next-return-id (+ return-id u1))
        (ok return-id)
    )
)

(define-public (authorize-inspector (inspector principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set authorized-inspectors { inspector: inspector } { authorized: true })
        (ok true)
    )
)

(define-public (revoke-inspector (inspector principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set authorized-inspectors { inspector: inspector } { authorized: false })
        (ok true)
    )
)

(define-public (authorize-arbitrator (arbitrator principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set authorized-arbitrators { arbitrator: arbitrator } { authorized: true })
        (ok true)
    )
)

(define-public (revoke-arbitrator (arbitrator principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set authorized-arbitrators { arbitrator: arbitrator } { authorized: false })
        (ok true)
    )
)

(define-public (update-return-status
        (return-id uint)
        (new-status (string-ascii 20))
    )
    (let (
            (return-data (unwrap! (get-return return-id) ERR_NOT_FOUND))
            (current-time stacks-block-height)
        )
        (asserts!
            (or
                (is-eq tx-sender (get customer return-data))
                (is-eq tx-sender (get merchant return-data))
                (is-authorized-inspector tx-sender)
            )
            ERR_UNAUTHORIZED
        )
        (map-set returns { return-id: return-id }
            (merge return-data {
                status: new-status,
                updated-at: current-time,
            })
        )
        (ok true)
    )
)

(define-public (schedule-pickup
        (return-id uint)
        (carrier (string-ascii 30))
        (tracking (string-ascii 50))
        (pickup-date uint)
    )
    (let ((return-data (unwrap! (get-return return-id) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get merchant return-data)) ERR_UNAUTHORIZED)
        (map-set return-logistics { return-id: return-id } {
            shipping-carrier: carrier,
            tracking-number: tracking,
            pickup-scheduled: true,
            pickup-date: pickup-date,
            received-date: u0,
            inspection-status: "pending",
            disposition: "pending",
        })
        (update-return-status return-id "pickup-scheduled")
    )
)

(define-public (confirm-receipt (return-id uint))
    (let (
            (return-data (unwrap! (get-return return-id) ERR_NOT_FOUND))
            (logistics-data (unwrap! (get-return-logistics return-id) ERR_NOT_FOUND))
            (current-time stacks-block-height)
        )
        (asserts! (is-eq tx-sender (get merchant return-data)) ERR_UNAUTHORIZED)
        (map-set return-logistics { return-id: return-id }
            (merge logistics-data { received-date: current-time })
        )
        (update-return-status return-id "received")
    )
)

(define-public (inspect-return
        (return-id uint)
        (inspection-result (string-ascii 20))
        (disposition (string-ascii 30))
    )
    (let (
            (return-data (unwrap! (get-return return-id) ERR_NOT_FOUND))
            (logistics-data (unwrap! (get-return-logistics return-id) ERR_NOT_FOUND))
        )
        (asserts! (is-authorized-inspector tx-sender) ERR_UNAUTHORIZED)
        (map-set return-logistics { return-id: return-id }
            (merge logistics-data {
                inspection-status: inspection-result,
                disposition: disposition,
            })
        )
        (if (is-eq inspection-result "approved")
            (update-return-status return-id "approved")
            (update-return-status return-id "rejected")
        )
    )
)

(define-public (process-refund
        (return-id uint)
        (refund-amount uint)
    )
    (let (
            (return-data (unwrap! (get-return return-id) ERR_NOT_FOUND))
            (current-time stacks-block-height)
        )
        (asserts! (is-eq tx-sender (get merchant return-data)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status return-data) "approved") ERR_INVALID_STATUS)
        (map-set returns { return-id: return-id }
            (merge return-data {
                refund-amount: refund-amount,
                status: "refunded",
                updated-at: current-time,
            })
        )
        (update-merchant-stats (get merchant return-data) refund-amount)
    )
)

(define-private (update-merchant-stats
        (merchant principal)
        (refund-amount uint)
    )
    (let ((current-stats (default-to {
            total-returns: u0,
            total-refunds: u0,
            average-processing-time: u0,
            return-rate: u0,
        }
            (get-merchant-stats merchant)
        )))
        (map-set merchant-stats { merchant: merchant } {
            total-returns: (+ (get total-returns current-stats) u1),
            total-refunds: (+ (get total-refunds current-stats) refund-amount),
            average-processing-time: (get average-processing-time current-stats),
            return-rate: (get return-rate current-stats),
        })
        (ok true)
    )
)

(define-public (bulk-update-status
        (return-ids (list 10 uint))
        (new-status (string-ascii 20))
    )
    (begin
        (asserts! (is-authorized-inspector tx-sender) ERR_UNAUTHORIZED)
        (ok (map update-return-status-helper return-ids
            (list
                new-status                 new-status                 new-status
                new-status                 new-status
                new-status                 new-status                 new-status
                new-status                 new-status
            )))
    )
)

(define-private (update-return-status-helper
        (return-id uint)
        (status (string-ascii 20))
    )
    (match (update-return-status return-id status)
        success
        true
        error
        false
    )
)

(define-read-only (get-returns-by-customer (customer principal))
    (ok (list))
)

(define-read-only (get-returns-by-merchant (merchant principal))
    (ok (list))
)

(define-read-only (get-pending-inspections)
    (ok (list))
)

(define-public (set-disposition-bulk
        (return-ids (list 5 uint))
        (dispositions (list 5 (string-ascii 30)))
    )
    (begin
        (asserts! (is-authorized-inspector tx-sender) ERR_UNAUTHORIZED)
        (ok (map set-disposition-helper return-ids dispositions))
    )
)

(define-private (set-disposition-helper
        (return-id uint)
        (disposition (string-ascii 30))
    )
    (match (get-return-logistics return-id)
        logistics-data (begin
            (map-set return-logistics { return-id: return-id }
                (merge logistics-data { disposition: disposition })
            )
            true
        )
        false
    )
)

(define-read-only (calculate-processing-time (return-id uint))
    (match (get-return return-id)
        return-data (match (get-return-logistics return-id)
            logistics-data (if (> (get received-date logistics-data) u0)
                (- (get received-date logistics-data)
                    (get created-at return-data)
                )
                u0
            )
            u0
        )
        u0
    )
)

(define-public (generate-return-report (merchant principal))
    (let ((stats (default-to {
            total-returns: u0,
            total-refunds: u0,
            average-processing-time: u0,
            return-rate: u0,
        }
            (get-merchant-stats merchant)
        )))
        (asserts! (is-eq tx-sender merchant) ERR_UNAUTHORIZED)
        (ok {
            merchant: merchant,
            total-returns: (get total-returns stats),
            total-refunds: (get total-refunds stats),
            report-generated-at: stacks-block-height,
        })
    )
)

(define-public (approve-return-batch (return-ids (list 5 uint)))
    (begin
        (asserts! (is-authorized-inspector tx-sender) ERR_UNAUTHORIZED)
        (ok (map approve-single-return return-ids))
    )
)

(define-private (approve-single-return (return-id uint))
    (match (update-return-status return-id "approved")
        success
        true
        error
        false
    )
)

(define-public (reject-return-batch (return-ids (list 5 uint)))
    (begin
        (asserts! (is-authorized-inspector tx-sender) ERR_UNAUTHORIZED)
        (ok (map reject-single-return return-ids))
    )
)

(define-private (reject-single-return (return-id uint))
    (match (update-return-status return-id "rejected")
        success
        true
        error
        false
    )
)

(define-read-only (get-return-history (return-id uint))
    (let (
            (return-data (unwrap! (get-return return-id) ERR_NOT_FOUND))
            (logistics-data (get-return-logistics return-id))
        )
        (ok {
            return-info: return-data,
            logistics-info: logistics-data,
            processing-time: (calculate-processing-time return-id),
        })
    )
)

(define-public (update-tracking
        (return-id uint)
        (new-tracking (string-ascii 50))
    )
    (let (
            (return-data (unwrap! (get-return return-id) ERR_NOT_FOUND))
            (logistics-data (unwrap! (get-return-logistics return-id) ERR_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get merchant return-data)) ERR_UNAUTHORIZED)
        (map-set return-logistics { return-id: return-id }
            (merge logistics-data { tracking-number: new-tracking })
        )
        (ok true)
    )
)

(define-read-only (get-returns-by-status (status (string-ascii 20)))
    (ok (list))
)

(define-public (mark-as-restocked (return-id uint))
    (let (
            (return-data (unwrap! (get-return return-id) ERR_NOT_FOUND))
            (logistics-data (unwrap! (get-return-logistics return-id) ERR_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get merchant return-data)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status return-data) "approved") ERR_INVALID_STATUS)
        (map-set return-logistics { return-id: return-id }
            (merge logistics-data { disposition: "restocked" })
        )
        (update-return-status return-id "restocked")
    )
)

(define-public (mark-as-recycled (return-id uint))
    (let (
            (return-data (unwrap! (get-return return-id) ERR_NOT_FOUND))
            (logistics-data (unwrap! (get-return-logistics return-id) ERR_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get merchant return-data)) ERR_UNAUTHORIZED)
        (map-set return-logistics { return-id: return-id }
            (merge logistics-data { disposition: "recycled" })
        )
        (update-return-status return-id "recycled")
    )
)

(define-public (mark-as-disposed (return-id uint))
    (let (
            (return-data (unwrap! (get-return return-id) ERR_NOT_FOUND))
            (logistics-data (unwrap! (get-return-logistics return-id) ERR_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get merchant return-data)) ERR_UNAUTHORIZED)
        (map-set return-logistics { return-id: return-id }
            (merge logistics-data { disposition: "disposed" })
        )
        (update-return-status return-id "disposed")
    )
)

(define-read-only (get-disposition-summary (merchant principal))
    (ok {
        merchant: merchant,
        restocked: u0,
        recycled: u0,
        disposed: u0,
        total: u0,
    })
)

(define-public (file-dispute
        (return-id uint)
        (reason (string-ascii 200))
        (evidence-hash (string-ascii 64))
    )
    (let (
            (dispute-id (var-get next-dispute-id))
            (current-time stacks-block-height)
            (return-data (unwrap! (get-return return-id) ERR_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get customer return-data)) ERR_UNAUTHORIZED)
        (asserts!
            (or
                (is-eq (get status return-data) "rejected")
                (is-eq (get status return-data) "approved")
                (is-eq (get status return-data) "refunded")
            )
            ERR_DISPUTE_NOT_ALLOWED
        )
        (asserts! (has-no-active-dispute return-id) ERR_DISPUTE_ALREADY_EXISTS)
        (map-set disputes { dispute-id: dispute-id } {
            return-id: return-id,
            customer: (get customer return-data),
            merchant: (get merchant return-data),
            dispute-reason: reason,
            evidence-hash: evidence-hash,
            status: "filed",
            filed-at: current-time,
            resolved-at: u0,
            arbitrator: none,
            resolution: none,
            customer-compensation: u0,
        })
        (map-set return-dispute-tracker { return-id: return-id } {
            dispute-id: dispute-id,
            has-dispute: true,
        })
        (var-set next-dispute-id (+ dispute-id u1))
        (ok dispute-id)
    )
)

(define-map return-dispute-tracker
    { return-id: uint }
    {
        dispute-id: uint,
        has-dispute: bool,
    }
)

(define-private (has-no-active-dispute (return-id uint))
    (is-none (map-get? return-dispute-tracker { return-id: return-id }))
)

(define-public (assign-arbitrator
        (dispute-id uint)
        (arbitrator principal)
    )
    (let ((dispute-data (unwrap! (get-dispute dispute-id) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (is-authorized-arbitrator arbitrator) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status dispute-data) "filed") ERR_DISPUTE_RESOLVED)
        (map-set disputes { dispute-id: dispute-id }
            (merge dispute-data {
                arbitrator: (some arbitrator),
                status: "under-review",
            })
        )
        (ok true)
    )
)

(define-public (resolve-dispute
        (dispute-id uint)
        (resolution-text (string-ascii 200))
        (compensation uint)
    )
    (let (
            (dispute-data (unwrap! (get-dispute dispute-id) ERR_NOT_FOUND))
            (current-time stacks-block-height)
        )
        (asserts!
            (is-eq tx-sender
                (unwrap! (get arbitrator dispute-data) ERR_UNAUTHORIZED)
            )
            ERR_UNAUTHORIZED
        )
        (asserts! (is-eq (get status dispute-data) "under-review")
            ERR_DISPUTE_RESOLVED
        )
        (map-set disputes { dispute-id: dispute-id }
            (merge dispute-data {
                status: "resolved",
                resolved-at: current-time,
                resolution: (some resolution-text),
                customer-compensation: compensation,
            })
        )
        (ok true)
    )
)

(define-public (appeal-dispute
        (dispute-id uint)
        (appeal-reason (string-ascii 200))
    )
    (let ((dispute-data (unwrap! (get-dispute dispute-id) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get customer dispute-data)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status dispute-data) "resolved")
            ERR_DISPUTE_NOT_ALLOWED
        )
        (map-set disputes { dispute-id: dispute-id }
            (merge dispute-data { status: "appealed" })
        )
        (ok true)
    )
)

(define-read-only (get-disputes-by-customer (customer principal))
    (ok (list))
)

(define-read-only (get-disputes-by-merchant (merchant principal))
    (ok (list))
)

(define-read-only (get-pending-disputes)
    (ok (list))
)

(define-read-only (get-dispute-summary (dispute-id uint))
    (match (get-dispute dispute-id)
        dispute-data (match (get-return (get return-id dispute-data))
            return-data (ok {
                dispute-info: dispute-data,
                return-info: return-data,
                days-since-filed: (if (> (get filed-at dispute-data) u0)
                    (- stacks-block-height (get filed-at dispute-data))
                    u0
                ),
            })
            ERR_NOT_FOUND
        )
        ERR_NOT_FOUND
    )
)

(define-read-only (get-contract-stats)
    (ok {
        total-products: (- (var-get next-product-id) u1),
        total-returns: (- (var-get next-return-id) u1),
        total-disputes: (- (var-get next-dispute-id) u1),
        contract-deployed-at: u1,
    })
)

(define-read-only (get-customer-returns-count (customer principal))
    (match (map-get? customer-returns-count { customer: customer })
        entry (get count entry)
        u0
    )
)

(define-read-only (get-customer-return-at
        (customer principal)
        (index uint)
    )
    (match (map-get? customer-returns-index {
        customer: customer,
        index: index,
    })
        entry (some (get return-id entry))
        none
    )
)

(define-read-only (get-merchant-returns-count (merchant principal))
    (match (map-get? merchant-returns-count { merchant: merchant })
        entry (get count entry)
        u0
    )
)

(define-read-only (get-merchant-return-at
        (merchant principal)
        (index uint)
    )
    (match (map-get? merchant-returns-index {
        merchant: merchant,
        index: index,
    })
        entry (some (get return-id entry))
        none
    )
)

(define-public (set-return-sla
        (return-id uint)
        (deadline uint)
        (sla-type (string-ascii 20))
    )
    (let ((return-data (unwrap! (get-return return-id) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get merchant return-data)) ERR_UNAUTHORIZED)
        (map-set return-sla { return-id: return-id } {
            sla-deadline: deadline,
            sla-type: sla-type,
        })
        (ok true)
    )
)

(define-public (clear-return-sla (return-id uint))
    (let ((return-data (unwrap! (get-return return-id) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get merchant return-data)) ERR_UNAUTHORIZED)
        (map-delete return-sla { return-id: return-id })
        (ok true)
    )
)

(define-read-only (get-return-sla (return-id uint))
    (map-get? return-sla { return-id: return-id })
)

(define-read-only (get-return-sla-status (return-id uint))
    (match (map-get? return-sla { return-id: return-id })
        entry (let (
                (deadline (get sla-deadline entry))
                (current-height stacks-block-height)
            )
            (if (>= current-height deadline)
                (ok {
                    status: "breached",
                    sla-deadline: deadline,
                    blocks-remaining: u0,
                })
                (ok {
                    status: "active",
                    sla-deadline: deadline,
                    blocks-remaining: (- deadline current-height),
                })
            )
        )
        ERR_NOT_FOUND
    )
)
