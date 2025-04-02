;; Consent Tracking Contract
;; This contract records user permissions for data sharing

(define-data-var admin principal tx-sender)

;; Data maps to store consent records
(define-map consent-records
  { user: principal, data-type: (string-ascii 64), recipient: principal }
  {
    granted: bool,
    timestamp: uint,
    expiration: uint,
    purpose: (string-ascii 128)
  }
)

;; Public functions

;; Grant consent for data sharing
(define-public (grant-consent
                (data-type (string-ascii 64))
                (recipient principal)
                (expiration uint)
                (purpose (string-ascii 128)))
  (begin
    (map-set consent-records
      { user: tx-sender, data-type: data-type, recipient: recipient }
      {
        granted: true,
        timestamp: block-height,
        expiration: (+ block-height expiration),
        purpose: purpose
      }
    )
    (ok true)
  )
)

;; Revoke consent
(define-public (revoke-consent (data-type (string-ascii 64)) (recipient principal))
  (begin
    (asserts! (is-some (map-get? consent-records { user: tx-sender, data-type: data-type, recipient: recipient })) (err u404))

    (map-set consent-records
      { user: tx-sender, data-type: data-type, recipient: recipient }
      (merge (unwrap-panic (map-get? consent-records { user: tx-sender, data-type: data-type, recipient: recipient }))
             { granted: false })
    )
    (ok true)
  )
)

;; Check if consent is valid
(define-read-only (is-consent-valid (user principal) (data-type (string-ascii 64)) (recipient principal))
  (if (is-some (map-get? consent-records { user: user, data-type: data-type, recipient: recipient }))
    (let ((consent (unwrap-panic (map-get? consent-records { user: user, data-type: data-type, recipient: recipient }))))
      (and
        (get granted consent)
        (<= block-height (get expiration consent))
      )
    )
    false
  )
)

;; Get consent details
(define-read-only (get-consent-details (user principal) (data-type (string-ascii 64)) (recipient principal))
  (map-get? consent-records { user: user, data-type: data-type, recipient: recipient })
)

;; Bulk revoke all consents for a user (can be called by user or admin)
(define-public (bulk-revoke-all-consents (user principal))
  (begin
    (asserts! (or (is-eq tx-sender user) (is-eq tx-sender (var-get admin))) (err u403))
    ;; Note: In a real implementation, we would need to iterate through all consents
    ;; Since Clarity doesn't support iteration, this would require a different approach
    ;; This is a placeholder for the concept
    (ok true)
  )
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (var-set admin new-admin)
    (ok true)
  )
)
