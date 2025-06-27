;; Data Room Management Contract
;; Manages virtual data rooms for M&A deals

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_ROOM_NOT_FOUND (err u301))
(define-constant ERR_DOCUMENT_NOT_FOUND (err u302))
(define-constant ERR_ACCESS_DENIED (err u303))

;; Access levels
(define-constant ACCESS_NONE u0)
(define-constant ACCESS_READ u1)
(define-constant ACCESS_WRITE u2)
(define-constant ACCESS_ADMIN u3)

;; Data structures
(define-map data-rooms
  { room-id: uint }
  {
    deal-id: uint,
    owner: principal,
    created-at: uint,
    name: (string-ascii 128),
    description: (string-ascii 256)
  }
)

(define-map room-access
  { room-id: uint, user: principal }
  {
    access-level: uint,
    granted-by: principal,
    granted-at: uint
  }
)

(define-map documents
  { room-id: uint, doc-id: uint }
  {
    name: (string-ascii 128),
    hash: (string-ascii 64),
    category: (string-ascii 64),
    uploaded-by: principal,
    uploaded-at: uint,
    access-level: uint
  }
)

(define-data-var next-room-id uint u1)
(define-data-var next-doc-id uint u1)

;; Create data room
(define-public (create-data-room
  (deal-id uint)
  (name (string-ascii 128))
  (description (string-ascii 256)))
  (let ((room-id (var-get next-room-id)))
    (map-set data-rooms
      { room-id: room-id }
      {
        deal-id: deal-id,
        owner: tx-sender,
        created-at: block-height,
        name: name,
        description: description
      }
    )
    ;; Grant admin access to creator
    (map-set room-access
      { room-id: room-id, user: tx-sender }
      {
        access-level: ACCESS_ADMIN,
        granted-by: tx-sender,
        granted-at: block-height
      }
    )
    (var-set next-room-id (+ room-id u1))
    (ok room-id)
  )
)

;; Grant access to user
(define-public (grant-access (room-id uint) (user principal) (access-level uint))
  (let ((room (unwrap! (map-get? data-rooms { room-id: room-id }) ERR_ROOM_NOT_FOUND)))
    (asserts! (has-admin-access room-id tx-sender) ERR_UNAUTHORIZED)
    (map-set room-access
      { room-id: room-id, user: user }
      {
        access-level: access-level,
        granted-by: tx-sender,
        granted-at: block-height
      }
    )
    (ok true)
  )
)

;; Upload document
(define-public (upload-document
  (room-id uint)
  (name (string-ascii 128))
  (hash (string-ascii 64))
  (category (string-ascii 64))
  (access-level uint))
  (let ((doc-id (var-get next-doc-id)))
    (asserts! (has-write-access room-id tx-sender) ERR_UNAUTHORIZED)
    (map-set documents
      { room-id: room-id, doc-id: doc-id }
      {
        name: name,
        hash: hash,
        category: category,
        uploaded-by: tx-sender,
        uploaded-at: block-height,
        access-level: access-level
      }
    )
    (var-set next-doc-id (+ doc-id u1))
    (ok doc-id)
  )
)

;; Check admin access
(define-private (has-admin-access (room-id uint) (user principal))
  (match (map-get? room-access { room-id: room-id, user: user })
    access-data (is-eq (get access-level access-data) ACCESS_ADMIN)
    false
  )
)

;; Check write access
(define-private (has-write-access (room-id uint) (user principal))
  (match (map-get? room-access { room-id: room-id, user: user })
    access-data (>= (get access-level access-data) ACCESS_WRITE)
    false
  )
)

;; Check read access
(define-private (has-read-access (room-id uint) (user principal))
  (match (map-get? room-access { room-id: room-id, user: user })
    access-data (>= (get access-level access-data) ACCESS_READ)
    false
  )
)

;; Get data room info
(define-read-only (get-data-room (room-id uint))
  (map-get? data-rooms { room-id: room-id })
)

;; Get document info
(define-read-only (get-document (room-id uint) (doc-id uint))
  (if (has-read-access room-id tx-sender)
    (map-get? documents { room-id: room-id, doc-id: doc-id })
    none
  )
)

;; Get user access level
(define-read-only (get-access-level (room-id uint) (user principal))
  (map-get? room-access { room-id: room-id, user: user })
)
