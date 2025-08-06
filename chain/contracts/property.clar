;; PropertyChain - A smart contract for tokenizing real estate assets
;; Enables secure blockchain-based ownership transfers with proper verification

;; Define the data storage for real estate records
(define-map real-estate-records
  { asset-id: (string-ascii 36) }
  {
    current-owner: principal,
    asset-description: (string-utf8 500),
    market-value: uint,
    available-for-purchase: bool,
    sale-price: uint,
    registration-block: uint,
    latest-transfer-block: uint
  }
)

;; Map to track authorized validators who can verify real estate transfers
(define-map authorized-validators
  { validator: principal }
  { active-status: bool, region: (string-ascii 50) }
)

;; Map to track pending transfers in custody
(define-map custody-transfers
  { asset-id: (string-ascii 36) }
  {
    purchaser: principal,
    vendor: principal,
    transfer-amount: uint,
    validator-consent: bool,
    purchaser-consent: bool,
    vendor-consent: bool,
    deadline-height: uint
  }
)

;; Define contract administrator who can authorize validators
(define-data-var contract-admin principal tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ASSET-NOT-FOUND (err u101))
(define-constant ERR-ASSET-EXISTS (err u102))
(define-constant ERR-NOT-OWNER (err u103))
(define-constant ERR-NOT-FOR-SALE (err u104))
(define-constant ERR-INSUFFICIENT-FUNDS (err u105))
(define-constant ERR-TRANSFER-NOT-FOUND (err u106))
(define-constant ERR-TRANSFER-EXPIRED (err u107))
(define-constant ERR-ALREADY-AUTHORIZED (err u108))
(define-constant ERR-NOT-VALIDATOR (err u109))
(define-constant ERR-TRANSFER-INCOMPLETE (err u110))
(define-constant ERR-INVALID-INPUT (err u111))
(define-constant ERR-PENDING-TRANSFER (err u112))
(define-constant ERR-NOT-EXPIRED (err u113))

;; Input validation functions
(define-private (is-valid-asset-id (asset-id (string-ascii 36)))
  (> (len asset-id) u0)
)

(define-private (is-valid-description (description (string-utf8 500)))
  (> (len description) u0)
)

(define-private (is-valid-region (region (string-ascii 50)))
  (> (len region) u0)
)

(define-private (is-valid-market-value (value uint))
  (> value u0)
)

(define-private (is-valid-price (price uint))
  (> price u0)
)

;; Check if caller is contract administrator
(define-private (is-contract-admin)
  (is-eq tx-sender (var-get contract-admin))
)

;; Function to register a new real estate record
(define-public (register-asset (asset-id (string-ascii 36)) (asset-description (string-utf8 500)) (market-value uint))
  (begin
    ;; Validate inputs
    (asserts! (is-valid-asset-id asset-id) ERR-INVALID-INPUT)
    (asserts! (is-valid-description asset-description) ERR-INVALID-INPUT)
    (asserts! (is-valid-market-value market-value) ERR-INVALID-INPUT)
    
    (let ((existing-asset (map-get? real-estate-records { asset-id: asset-id })))
      (if (is-some existing-asset)
        ERR-ASSET-EXISTS
        (begin
          (map-set real-estate-records
            { asset-id: asset-id }
            {
              current-owner: tx-sender,
              asset-description: asset-description,
              market-value: market-value,
              available-for-purchase: false,
              sale-price: u0,
              registration-block: block-height,
              latest-transfer-block: block-height
            }
          )
          (ok true)
        )
      )
    )
  )
)

;; Function to update real estate details (only by owner)
(define-public (update-asset-details (asset-id (string-ascii 36)) (asset-description (string-utf8 500)) (market-value uint))
  (begin
    ;; Validate inputs
    (asserts! (is-valid-asset-id asset-id) ERR-INVALID-INPUT)
    (asserts! (is-valid-description asset-description) ERR-INVALID-INPUT)
    (asserts! (is-valid-market-value market-value) ERR-INVALID-INPUT)
    
    (let ((asset (map-get? real-estate-records { asset-id: asset-id })))
      (if (is-none asset)
        ERR-ASSET-NOT-FOUND
        (if (is-eq tx-sender (get current-owner (unwrap-panic asset)))
          (begin
            (map-set real-estate-records
              { asset-id: asset-id }
              (merge (unwrap-panic asset) { asset-description: asset-description, market-value: market-value })
            )
            (ok true)
          )
          ERR-NOT-OWNER
        )
      )
    )
  )
)

;; List real estate for sale
(define-public (list-asset-for-sale (asset-id (string-ascii 36)) (sale-price uint))
  (begin
    ;; Validate inputs
    (asserts! (is-valid-asset-id asset-id) ERR-INVALID-INPUT)
    (asserts! (is-valid-price sale-price) ERR-INVALID-INPUT)
    
    (let ((asset (map-get? real-estate-records { asset-id: asset-id })))
      (if (is-none asset)
        ERR-ASSET-NOT-FOUND
        (if (is-eq tx-sender (get current-owner (unwrap-panic asset)))
          (begin
            (map-set real-estate-records
              { asset-id: asset-id }
              (merge (unwrap-panic asset) { available-for-purchase: true, sale-price: sale-price })
            )
            (ok true)
          )
          ERR-NOT-OWNER
        )
      )
    )
  )
)

;; Remove real estate from sale
(define-public (delist-asset (asset-id (string-ascii 36)))
  (begin
    ;; Validate inputs
    (asserts! (is-valid-asset-id asset-id) ERR-INVALID-INPUT)
    
    (let ((asset (map-get? real-estate-records { asset-id: asset-id })))
      (if (is-none asset)
        ERR-ASSET-NOT-FOUND
        (if (is-eq tx-sender (get current-owner (unwrap-panic asset)))
          (begin
            (map-set real-estate-records
              { asset-id: asset-id }
              (merge (unwrap-panic asset) { available-for-purchase: false })
            )
            (ok true)
          )
          ERR-NOT-OWNER
        )
      )
    )
  )
)

;; Initiate purchase (put funds in custody)
(define-public (initiate-purchase (asset-id (string-ascii 36)))
  (begin
    ;; Validate inputs
    (asserts! (is-valid-asset-id asset-id) ERR-INVALID-INPUT)
    
    (let (
      (asset (map-get? real-estate-records { asset-id: asset-id }))
      (existing-custody (map-get? custody-transfers { asset-id: asset-id }))
    )
      (if (is-none asset)
        ERR-ASSET-NOT-FOUND
        (let ((asset-data (unwrap-panic asset)))
          (if (not (get available-for-purchase asset-data))
            ERR-NOT-FOR-SALE
            (if (is-some existing-custody)
              ERR-PENDING-TRANSFER
              (let ((amount (get sale-price asset-data)))
                (if (< (stx-get-balance tx-sender) amount)
                  ERR-INSUFFICIENT-FUNDS
                  (begin
                    ;; Transfer STX to custody (contract itself)
                    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
                    
                    ;; Create custody entry
                    (map-set custody-transfers
                      { asset-id: asset-id }
                      {
                        purchaser: tx-sender,
                        vendor: (get current-owner asset-data),
                        transfer-amount: amount,
                        validator-consent: false,
                        purchaser-consent: true,
                        vendor-consent: false,
                        deadline-height: (+ block-height u1440)
                      }
                    )
                    (ok true)
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)

;; Vendor approves transfer
(define-public (approve-transfer-as-vendor (asset-id (string-ascii 36)))
  (begin
    ;; Validate inputs
    (asserts! (is-valid-asset-id asset-id) ERR-INVALID-INPUT)
    
    (let (
      (asset (map-get? real-estate-records { asset-id: asset-id }))
      (custody (map-get? custody-transfers { asset-id: asset-id }))
    )
      (if (or (is-none asset) (is-none custody))
        ERR-TRANSFER-NOT-FOUND
        (let (
          (asset-data (unwrap-panic asset))
          (custody-data (unwrap-panic custody))
        )
          (if (not (is-eq tx-sender (get current-owner asset-data)))
            ERR-NOT-OWNER
            (if (> block-height (get deadline-height custody-data))
              ERR-TRANSFER-EXPIRED
              (begin
                (map-set custody-transfers
                  { asset-id: asset-id }
                  (merge custody-data { vendor-consent: true })
                )
                (ok true)
              )
            )
          )
        )
      )
    )
  )
)

;; Validator approves transfer after verification
(define-public (approve-transfer-as-validator (asset-id (string-ascii 36)))
  (begin
    ;; Validate inputs
    (asserts! (is-valid-asset-id asset-id) ERR-INVALID-INPUT)
    
    (let (
      (asset (map-get? real-estate-records { asset-id: asset-id }))
      (custody (map-get? custody-transfers { asset-id: asset-id }))
      (validator-status (map-get? authorized-validators { validator: tx-sender }))
    )
      (if (is-none validator-status)
        ERR-NOT-VALIDATOR
        (if (not (get active-status (unwrap-panic validator-status)))
          ERR-NOT-AUTHORIZED
          (if (or (is-none asset) (is-none custody))
            ERR-TRANSFER-NOT-FOUND
            (let ((custody-data (unwrap-panic custody)))
              (if (> block-height (get deadline-height custody-data))
                ERR-TRANSFER-EXPIRED
                (begin
                  (map-set custody-transfers
                    { asset-id: asset-id }
                    (merge custody-data { validator-consent: true })
                  )
                  (ok true)
                )
              )
            )
          )
        )
      )
    )
  )
)

;; Complete real estate transfer when all approvals are in place
(define-public (complete-transfer (asset-id (string-ascii 36)))
  (begin
    ;; Validate inputs
    (asserts! (is-valid-asset-id asset-id) ERR-INVALID-INPUT)
    
    (let (
      (asset (map-get? real-estate-records { asset-id: asset-id }))
      (custody (map-get? custody-transfers { asset-id: asset-id }))
    )
      (if (or (is-none asset) (is-none custody))
        ERR-TRANSFER-NOT-FOUND
        (let (
          (asset-data (unwrap-panic asset))
          (custody-data (unwrap-panic custody))
        )
          (if (> block-height (get deadline-height custody-data))
            ERR-TRANSFER-EXPIRED
            (if (and 
                  (get vendor-consent custody-data)
                  (get purchaser-consent custody-data)
                  (get validator-consent custody-data)
                )
              (begin
                ;; Transfer funds from custody to vendor
                (try! (as-contract (stx-transfer? (get transfer-amount custody-data) tx-sender (get vendor custody-data))))
                
                ;; Transfer real estate to purchaser
                (map-set real-estate-records
                  { asset-id: asset-id }
                  (merge asset-data { 
                    current-owner: (get purchaser custody-data),
                    available-for-purchase: false,
                    latest-transfer-block: block-height
                  })
                )
                
                ;; Clear the custody
                (map-delete custody-transfers { asset-id: asset-id })
                
                (ok true)
              )
              ERR-TRANSFER-INCOMPLETE
            )
          )
        )
      )
    )
  )
)

;; Cancel transfer and refund - can be called by any party before completion
(define-public (cancel-transfer (asset-id (string-ascii 36)))
  (begin
    ;; Validate inputs
    (asserts! (is-valid-asset-id asset-id) ERR-INVALID-INPUT)
    
    (let (
      (custody (map-get? custody-transfers { asset-id: asset-id }))
    )
      (if (is-none custody)
        ERR-TRANSFER-NOT-FOUND
        (let ((custody-data (unwrap-panic custody)))
          (if (and 
                (not (is-eq tx-sender (get purchaser custody-data)))
                (not (is-eq tx-sender (get vendor custody-data)))
                (not (is-authorized-validator tx-sender))
              )
            ERR-NOT-AUTHORIZED
            (begin
              ;; Refund the purchaser
              (try! (as-contract (stx-transfer? (get transfer-amount custody-data) tx-sender (get purchaser custody-data))))
              
              ;; Clear the custody
              (map-delete custody-transfers { asset-id: asset-id })
              
              (ok true)
            )
          )
        )
      )
    )
  )
)

;; Auto-refund expired transfers - anyone can call
(define-public (refund-expired-transfer (asset-id (string-ascii 36)))
  (begin
    ;; Validate inputs
    (asserts! (is-valid-asset-id asset-id) ERR-INVALID-INPUT)
    
    (let (
      (custody (map-get? custody-transfers { asset-id: asset-id }))
    )
      (if (is-none custody)
        ERR-TRANSFER-NOT-FOUND
        (let ((custody-data (unwrap-panic custody)))
          (if (<= block-height (get deadline-height custody-data))
            ERR-NOT-EXPIRED
            (begin
              ;; Refund the purchaser
              (try! (as-contract (stx-transfer? (get transfer-amount custody-data) tx-sender (get purchaser custody-data))))
              
              ;; Clear the custody
              (map-delete custody-transfers { asset-id: asset-id })
              
              (ok true)
            )
          )
        )
      )
    )
  )
)

;; Add a validator (only contract administrator)
(define-public (add-validator (validator principal) (region (string-ascii 50)))
  (begin
    ;; Validate inputs
    (asserts! (is-valid-region region) ERR-INVALID-INPUT)
    (asserts! (not (is-eq validator (var-get contract-admin))) ERR-INVALID-INPUT)
    
    (if (not (is-contract-admin))
      ERR-NOT-AUTHORIZED
      (let ((existing-validator (map-get? authorized-validators { validator: validator })))
        (if (is-some existing-validator)
          ERR-ALREADY-AUTHORIZED
          (begin
            (map-set authorized-validators
              { validator: validator }
              { active-status: true, region: region }
            )
            (ok true)
          )
        )
      )
    )
  )
)

;; Deactivate a validator (only contract administrator)
(define-public (deactivate-validator (validator principal))
  (begin
    ;; Validate inputs
    (asserts! (not (is-eq validator (var-get contract-admin))) ERR-INVALID-INPUT)
    
    (if (not (is-contract-admin))
      ERR-NOT-AUTHORIZED
      (let ((existing-validator (map-get? authorized-validators { validator: validator })))
        (if (is-none existing-validator)
          ERR-NOT-VALIDATOR
          (begin
            (map-set authorized-validators
              { validator: validator }
              (merge (unwrap-panic existing-validator) { active-status: false })
            )
            (ok true)
          )
        )
      )
    )
  )
)

;; Helper to check if sender is authorized validator
(define-private (is-authorized-validator (user principal))
  (let ((validator-status (map-get? authorized-validators { validator: user })))
    (and (is-some validator-status) (get active-status (unwrap-panic validator-status)))
  )
)

;; Transfer contract administration (only current administrator)
(define-public (transfer-contract-administration (new-admin principal))
  (begin
    ;; Validate inputs
    (asserts! (not (is-eq new-admin (var-get contract-admin))) ERR-INVALID-INPUT)
    
    (if (not (is-contract-admin))
      ERR-NOT-AUTHORIZED
      (begin
        (var-set contract-admin new-admin)
        (ok true)
      )
    )
  )
)

;; Read-only functions for querying the contract state

;; Get real estate details
(define-read-only (get-asset (asset-id (string-ascii 36)))
  (if (is-valid-asset-id asset-id)
    (map-get? real-estate-records { asset-id: asset-id })
    none
  )
)

;; Check if address is the real estate owner
(define-read-only (is-asset-owner (asset-id (string-ascii 36)) (address principal))
  (if (is-valid-asset-id asset-id)
    (let ((asset (map-get? real-estate-records { asset-id: asset-id })))
      (if (is-none asset)
        false
        (is-eq address (get current-owner (unwrap-panic asset)))
      )
    )
    false
  )
)

;; Get custody details
(define-read-only (get-custody-details (asset-id (string-ascii 36)))
  (if (is-valid-asset-id asset-id)
    (map-get? custody-transfers { asset-id: asset-id })
    none
  )
)

;; Check if address is an authorized validator
(define-read-only (is-validator-active (address principal))
  (let ((validator-data (map-get? authorized-validators { validator: address })))
    (if (is-none validator-data)
      false
      (get active-status (unwrap-panic validator-data))
    )
  )
)

;; Get validator details
(define-read-only (get-validator-details (address principal))
  (map-get? authorized-validators { validator: address })
)