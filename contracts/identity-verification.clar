;; Identity Verification Contract
;; This contract validates user information through trusted sources

(define-data-var admin principal tx-sender)

;; Data maps to store verification status and user information
(define-map verification-status
  { user: principal }
  { verified: bool, timestamp: uint })

(define-map user-information
  { user: principal }
  {
    name: (string-ascii 64),
    document-hash: (buff 32),
    verification-source: (string-ascii 64)
  }
)

;; List of trusted verification sources
(define-map trusted-sources
  { source-id: (string-ascii 64) }
  { active: bool }
)

;; Public functions

;; Add a trusted verification source
(define-public (add-trusted-source (source-id (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (ok (map-set trusted-sources { source-id: source-id } { active: true }))
  )
)

;; Remove a trusted verification source
(define-public (remove-trusted-source (source-id (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (ok (map-set trusted-sources { source-id: source-id } { active: false }))
  )
)

;; Submit user information for verification
(define-public (submit-information
                (name (string-ascii 64))
                (document-hash (buff 32))
                (verification-source (string-ascii 64)))
  (begin
    (asserts! (is-some (map-get? trusted-sources { source-id: verification-source })) (err u404))
    (asserts! (get active (unwrap-panic (map-get? trusted-sources { source-id: verification-source }))) (err u403))

    (map-set user-information
      { user: tx-sender }
      {
        name: name,
        document-hash: document-hash,
        verification-source: verification-source
      }
    )
    (ok true)
  )
)

;; Verify a user (can only be called by admin)
(define-public (verify-user (user principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (is-some (map-get? user-information { user: user })) (err u404))

    (map-set verification-status
      { user: user }
      { verified: true, timestamp: block-height }
    )
    (ok true)
  )
)

;; Check if a user is verified
(define-read-only (is-verified (user principal))
  (if (is-some (map-get? verification-status { user: user }))
    (get verified (unwrap-panic (map-get? verification-status { user: user })))
    false
  )
)

;; Get user information
(define-read-only (get-user-information (user principal))
  (map-get? user-information { user: user })
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (var-set admin new-admin)
    (ok true)
  )
)
