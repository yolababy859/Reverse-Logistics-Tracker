(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_STATUS (err u102))
(define-constant ERR_ALREADY_EXISTS (err u103))
(define-constant ERR_INVALID_CONDITION (err u104))

(define-data-var next-return-id uint u1)
(define-data-var next-product-id uint u1)

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
        )
        (map-set returns { return-id: return-id } {
            product-id: product-id,
            customer: tx-sender,
            merchant: (get merchant product-data),
            return-reason: reason,
            status: "initiated",
            created-at: current-time,
            updated-at: current-time,
            refund-amount: u0,
            condition: condition,
        })
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
            (list new-status new-status new-status new-status new-status
                new-status new-status new-status new-status new-status)
        ))
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

(define-read-only (get-contract-stats)
    (ok {
        total-products: (- (var-get next-product-id) u1),
        total-returns: (- (var-get next-return-id) u1),
        contract-deployed-at: u1,
    })
)
