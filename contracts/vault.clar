;; VRTX - Decentralized Asset Management Platform
;; A DeFi protocol for automated yield optimization and asset management on Stacks

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERR_VAULT_NOT_FOUND (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_VAULT_PAUSED (err u104))
(define-constant ERR_STRATEGY_NOT_FOUND (err u105))
(define-constant ERR_WITHDRAWAL_LOCKED (err u106))
(define-constant MIN_DEPOSIT u1000000) ;; 1 STX minimum deposit
(define-constant PROTOCOL_FEE_BASIS_POINTS u250) ;; 2.5% protocol fee
(define-constant LOCK_PERIOD u144) ;; ~24 hours in blocks

;; Data Variables
(define-data-var total-vaults uint u0)
(define-data-var protocol-paused bool false)
(define-data-var total-tvl uint u0)
(define-data-var protocol-treasury principal CONTRACT_OWNER)

;; Data Maps
(define-map vaults
  { vault-id: uint }
  {
    owner: principal,
    strategy: (string-ascii 20),
    total-deposited: uint,
    total-shares: uint,
    created-at: uint,
    last-harvest: uint,
    paused: bool,
    lock-period: uint
  }
)

(define-map user-positions
  { user: principal, vault-id: uint }
  {
    shares: uint,
    deposited-amount: uint,
    last-deposit: uint,
    rewards-claimed: uint
  }
)

(define-map strategies
  { strategy-name: (string-ascii 20) }
  {
    active: bool,
    apy-estimate: uint, ;; basis points (e.g., 1000 = 10%)
    risk-level: uint,   ;; 1-5 scale
    description: (string-ascii 100),
    created-at: uint
  }
)

(define-map vault-performance
  { vault-id: uint, period: uint }
  {
    start-value: uint,
    end-value: uint,
    yield-generated: uint,
    fees-collected: uint
  }
)

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (calculate-shares (amount uint) (total-deposited uint) (total-shares uint))
  (if (is-eq total-shares u0)
    amount ;; First deposit gets 1:1 shares
    (/ (* amount total-shares) total-deposited)
  )
)

(define-private (calculate-withdrawal-amount (shares uint) (total-deposited uint) (total-shares uint))
  (if (is-eq total-shares u0)
    u0
    (/ (* shares total-deposited) total-shares)
  )
)

(define-private (calculate-protocol-fee (amount uint))
  (/ (* amount PROTOCOL_FEE_BASIS_POINTS) u10000)
)

;; Public Functions

;; Create a new vault with a specific strategy
(define-public (create-vault (strategy (string-ascii 20)) (lock-period uint))
  (let (
    (vault-id (+ (var-get total-vaults) u1))
    (strategy-info (map-get? strategies { strategy-name: strategy }))
  )
    (asserts! (not (var-get protocol-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (is-some strategy-info) ERR_STRATEGY_NOT_FOUND)
    (asserts! (get active (unwrap-panic strategy-info)) ERR_STRATEGY_NOT_FOUND)
    
    (map-set vaults
      { vault-id: vault-id }
      {
        owner: tx-sender,
        strategy: strategy,
        total-deposited: u0,
        total-shares: u0,
        created-at: block-height,
        last-harvest: block-height,
        paused: false,
        lock-period: lock-period
      }
    )
    
    (var-set total-vaults vault-id)
    (ok vault-id)
  )
)

;; Deposit STX into a vault
(define-public (deposit (vault-id uint) (amount uint))
  (let (
    (vault-info (map-get? vaults { vault-id: vault-id }))
    (user tx-sender)
    (existing-position (default-to 
      { shares: u0, deposited-amount: u0, last-deposit: u0, rewards-claimed: u0 }
      (map-get? user-positions { user: user, vault-id: vault-id })
    ))
  )
    (asserts! (not (var-get protocol-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (>= amount MIN_DEPOSIT) ERR_INVALID_AMOUNT)
    (asserts! (is-some vault-info) ERR_VAULT_NOT_FOUND)
    
    (let (
      (vault (unwrap-panic vault-info))
      (shares-to-mint (calculate-shares amount (get total-deposited vault) (get total-shares vault)))
    )
      (asserts! (not (get paused vault)) ERR_VAULT_PAUSED)
      
      ;; Transfer STX to contract
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      
      ;; Update vault info
      (map-set vaults
        { vault-id: vault-id }
        (merge vault {
          total-deposited: (+ (get total-deposited vault) amount),
          total-shares: (+ (get total-shares vault) shares-to-mint)
        })
      )
      
      ;; Update user position
      (map-set user-positions
        { user: user, vault-id: vault-id }
        {
          shares: (+ (get shares existing-position) shares-to-mint),
          deposited-amount: (+ (get deposited-amount existing-position) amount),
          last-deposit: block-height,
          rewards-claimed: (get rewards-claimed existing-position)
        }
      )
      
      ;; Update total TVL
      (var-set total-tvl (+ (var-get total-tvl) amount))
      
      (ok shares-to-mint)
    )
  )
)

;; Withdraw from vault
(define-public (withdraw (vault-id uint) (shares uint))
  (let (
    (vault-info (map-get? vaults { vault-id: vault-id }))
    (user tx-sender)
    (user-position (map-get? user-positions { user: user, vault-id: vault-id }))
  )
    (asserts! (not (var-get protocol-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (is-some vault-info) ERR_VAULT_NOT_FOUND)
    (asserts! (is-some user-position) ERR_INSUFFICIENT_BALANCE)
    
    (let (
      (vault (unwrap-panic vault-info))
      (position (unwrap-panic user-position))
      (withdrawal-amount (calculate-withdrawal-amount shares (get total-deposited vault) (get total-shares vault)))
      (protocol-fee (calculate-protocol-fee withdrawal-amount))
      (user-amount (- withdrawal-amount protocol-fee))
    )
      (asserts! (not (get paused vault)) ERR_VAULT_PAUSED)
      (asserts! (<= shares (get shares position)) ERR_INSUFFICIENT_BALANCE)
      (asserts! (>= block-height (+ (get last-deposit position) (get lock-period vault))) ERR_WITHDRAWAL_LOCKED)
      (asserts! (> withdrawal-amount u0) ERR_INVALID_AMOUNT)
      
      ;; Update vault info
      (map-set vaults
        { vault-id: vault-id }
        (merge vault {
          total-deposited: (- (get total-deposited vault) withdrawal-amount),
          total-shares: (- (get total-shares vault) shares)
        })
      )
      
      ;; Update user position
      (map-set user-positions
        { user: user, vault-id: vault-id }
        (merge position {
          shares: (- (get shares position) shares),
          deposited-amount: (- (get deposited-amount position) withdrawal-amount)
        })
      )
      
      ;; Transfer protocol fee to treasury
      (try! (as-contract (stx-transfer? protocol-fee tx-sender (var-get protocol-treasury))))
      
      ;; Transfer remaining amount to user
      (try! (as-contract (stx-transfer? user-amount tx-sender user)))
      
      ;; Update total TVL
      (var-set total-tvl (- (var-get total-tvl) withdrawal-amount))
      
      (ok user-amount)
    )
  )
)

;; Add a new investment strategy
(define-public (add-strategy (name (string-ascii 20)) (apy-estimate uint) (risk-level uint) (description (string-ascii 100)))
  (begin
    (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
    (asserts! (and (>= risk-level u1) (<= risk-level u5)) ERR_INVALID_AMOUNT)
    
    (map-set strategies
      { strategy-name: name }
      {
        active: true,
        apy-estimate: apy-estimate,
        risk-level: risk-level,
        description: description,
        created-at: block-height
      }
    )
    (ok true)
  )
)

;; Harvest yield for a vault (simulated yield generation)
(define-public (harvest-vault (vault-id uint) (yield-amount uint))
  (let (
    (vault-info (map-get? vaults { vault-id: vault-id }))
  )
    (asserts! (is-some vault-info) ERR_VAULT_NOT_FOUND)
    
    (let ((vault (unwrap-panic vault-info)))
      (asserts! (or (is-contract-owner) (is-eq tx-sender (get owner vault))) ERR_NOT_AUTHORIZED)
      
      ;; Update vault with new yield
      (map-set vaults
        { vault-id: vault-id }
        (merge vault {
          total-deposited: (+ (get total-deposited vault) yield-amount),
          last-harvest: block-height
        })
      )
      
      ;; Record performance
      (map-set vault-performance
        { vault-id: vault-id, period: block-height }
        {
          start-value: (get total-deposited vault),
          end-value: (+ (get total-deposited vault) yield-amount),
          yield-generated: yield-amount,
          fees-collected: (calculate-protocol-fee yield-amount)
        }
      )
      
      (ok yield-amount)
    )
  )
)

;; Toggle vault pause status
(define-public (toggle-vault-pause (vault-id uint))
  (let (
    (vault-info (map-get? vaults { vault-id: vault-id }))
  )
    (asserts! (is-some vault-info) ERR_VAULT_NOT_FOUND)
    
    (let ((vault (unwrap-panic vault-info)))
      (asserts! (or (is-contract-owner) (is-eq tx-sender (get owner vault))) ERR_NOT_AUTHORIZED)
      
      (map-set vaults
        { vault-id: vault-id }
        (merge vault { paused: (not (get paused vault)) })
      )
      (ok (not (get paused vault)))
    )
  )
)

;; Toggle protocol pause
(define-public (toggle-protocol-pause)
  (begin
    (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
    (var-set protocol-paused (not (var-get protocol-paused)))
    (ok (var-get protocol-paused))
  )
)

;; Update protocol treasury
(define-public (update-treasury (new-treasury principal))
  (begin
    (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
    (var-set protocol-treasury new-treasury)
    (ok true)
  )
)

;; Read-only Functions

;; Get vault information
(define-read-only (get-vault-info (vault-id uint))
  (map-get? vaults { vault-id: vault-id })
)

;; Get user position in a vault
(define-read-only (get-user-position (user principal) (vault-id uint))
  (map-get? user-positions { user: user, vault-id: vault-id })
)

;; Get strategy information
(define-read-only (get-strategy-info (strategy-name (string-ascii 20)))
  (map-get? strategies { strategy-name: strategy-name })
)

;; Get vault performance data
(define-read-only (get-vault-performance (vault-id uint) (period uint))
  (map-get? vault-performance { vault-id: vault-id, period: period })
)

;; Calculate current value of user's position
(define-read-only (get-position-value (user principal) (vault-id uint))
  (match (get-user-position user vault-id)
    position (match (get-vault-info vault-id)
      vault (some (calculate-withdrawal-amount 
                    (get shares position) 
                    (get total-deposited vault) 
                    (get total-shares vault)))
      none)
    none
  )
)

;; Get total number of vaults
(define-read-only (get-total-vaults)
  (var-get total-vaults)
)

;; Get protocol statistics
(define-read-only (get-protocol-stats)
  {
    total-tvl: (var-get total-tvl),
    total-vaults: (var-get total-vaults),
    protocol-paused: (var-get protocol-paused),
    treasury: (var-get protocol-treasury)
  }
)

;; Check if user can withdraw (lock period check)
(define-read-only (can-withdraw (user principal) (vault-id uint))
  (match (get-user-position user vault-id)
    position (match (get-vault-info vault-id)
      vault (>= block-height (+ (get last-deposit position) (get lock-period vault)))
      false)
    false
  )
)