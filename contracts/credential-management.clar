;; Credential Management Contract
;; This contract issues verifiable claims about users

(define-data-var admin principal tx-sender)

;; Data maps to store credentials
(define-map credentials
  { user: principal, credential-id: (string-ascii 64) }
  {
    issuer: principal,
    data: (string-utf8 256),
    issued-at: uint,
    expires-at: uint,
    revoked: bool
  }
)

;; Map of authorized issuers
(define-map authorized-issuers
  { issuer: principal }
  { authorized: bool }
)

;; Public functions

;; Authorize an issuer
(define-public (authorize-issuer (issuer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (ok (map-set authorized-issuers { issuer: issuer } { authorized: true }))
  )
)

;; Revoke issuer authorization
(define-public (revoke-issuer-authorization (issuer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (ok (map-set authorized-issuers { issuer: issuer } { authorized: false }))
  )
)

;; Issue a credential
(define-public (issue-credential
                (user principal)
                (credential-id (string-ascii 64))
                (data (string-utf8 256))
                (validity-period uint))
  (begin
    (asserts! (is-authorized tx-sender) (err u403))

    (map-set credentials
      { user: user, credential-id: credential-id }
      {
        issuer: tx-sender,
        data: data,
        issued-at: block-height,
        expires-at: (+ block-height validity-period),
        revoked: false
      }
    )
    (ok true)
  )
)

;; Revoke a credential
(define-public (revoke-credential (user principal) (credential-id (string-ascii 64)))
  (begin
    (asserts! (is-authorized tx-sender) (err u403))
    (asserts! (is-some (map-get? credentials { user: user, credential-id: credential-id })) (err u404))
    (asserts! (is-eq tx-sender (get issuer (unwrap-panic (map-get? credentials { user: user, credential-id: credential-id })))) (err u403))

    (map-set credentials
      { user: user, credential-id: credential-id }
      (merge (unwrap-panic (map-get? credentials { user: user, credential-id: credential-id }))
             { revoked: true })
    )
    (ok true)
  )
)

;; Check if a credential is valid
(define-read-only (is-credential-valid (user principal) (credential-id (string-ascii 64)))
  (if (is-some (map-get? credentials { user: user, credential-id: credential-id }))
    (let ((cred (unwrap-panic (map-get? credentials { user: user, credential-id: credential-id }))))
      (and
        (not (get revoked cred))
        (<= block-height (get expires-at cred))
      )
    )
    false
  )
)

;; Get credential details
(define-read-only (get-credential (user principal) (credential-id (string-ascii 64)))
  (map-get? credentials { user: user, credential-id: credential-id })
)

;; Helper function to check if an issuer is authorized
(define-read-only (is-authorized (issuer principal))
  (if (is-some (map-get? authorized-issuers { issuer: issuer }))
    (get authorized (unwrap-panic (map-get? authorized-issuers { issuer: issuer })))
    false
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
