;; M&A Advisor Verification Contract
;; Validates and manages merger and acquisition advisors

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ADVISOR_EXISTS (err u101))
(define-constant ERR_ADVISOR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Advisor status types
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_REVOKED u3)

;; Data structures
(define-map advisors
  { advisor: principal }
  {
    status: uint,
    verification-date: uint,
    credentials: (string-ascii 256),
    specialization: (string-ascii 128),
    rating: uint
  }
)

(define-map advisor-stats
  { advisor: principal }
  {
    deals-completed: uint,
    total-value: uint,
    success-rate: uint
  }
)

(define-data-var total-advisors uint u0)

;; Register new advisor
(define-public (register-advisor (credentials (string-ascii 256)) (specialization (string-ascii 128)))
  (let ((advisor tx-sender))
    (asserts! (is-none (map-get? advisors { advisor: advisor })) ERR_ADVISOR_EXISTS)
    (map-set advisors
      { advisor: advisor }
      {
        status: STATUS_PENDING,
        verification-date: block-height,
        credentials: credentials,
        specialization: specialization,
        rating: u0
      }
    )
    (map-set advisor-stats
      { advisor: advisor }
      {
        deals-completed: u0,
        total-value: u0,
        success-rate: u0
      }
    )
    (var-set total-advisors (+ (var-get total-advisors) u1))
    (ok advisor)
  )
)

;; Verify advisor (admin only)
(define-public (verify-advisor (advisor principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? advisors { advisor: advisor })) ERR_ADVISOR_NOT_FOUND)
    (map-set advisors
      { advisor: advisor }
      (merge (unwrap-panic (map-get? advisors { advisor: advisor }))
        { status: STATUS_VERIFIED, verification-date: block-height }
      )
    )
    (ok true)
  )
)

;; Update advisor rating
(define-public (update-rating (advisor principal) (new-rating uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? advisors { advisor: advisor })) ERR_ADVISOR_NOT_FOUND)
    (asserts! (<= new-rating u100) ERR_INVALID_STATUS)
    (map-set advisors
      { advisor: advisor }
      (merge (unwrap-panic (map-get? advisors { advisor: advisor }))
        { rating: new-rating }
      )
    )
    (ok true)
  )
)

;; Get advisor info
(define-read-only (get-advisor (advisor principal))
  (map-get? advisors { advisor: advisor })
)

;; Get advisor stats
(define-read-only (get-advisor-stats (advisor principal))
  (map-get? advisor-stats { advisor: advisor })
)

;; Check if advisor is verified
(define-read-only (is-verified (advisor principal))
  (match (map-get? advisors { advisor: advisor })
    advisor-data (is-eq (get status advisor-data) STATUS_VERIFIED)
    false
  )
)
