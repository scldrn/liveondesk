//
//  PetScene.swift
//  liveondesk
//

import SpriteKit

// MARK: - Physics Categories

enum Physics {
    static let pet:      UInt32 = 0x1
    static let platform: UInt32 = 0x2
}

// MARK: - PetScene

class PetScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Properties

    private var petNode: PetNode!
    private let detector = WindowDetector()
    private var platformNodes: [CGWindowID: SKNode] = [:]
    private var currentPlatforms: [WindowPlatform] = []

    private var state: PetState = .falling
    private var contactCount = 0
    private var walkDirection: CGFloat = 1.0

    private let walkSpeed: CGFloat  = 110
    private let petRadius: CGFloat  = 32
    private let jumpImpulse: CGFloat = 280   // Vertical impulse for jumping onto square windows

    /// Cooldown to prevent rapid re-jumping after landing.
    private var jumpCooldownUntil: TimeInterval = 0

    /// The square window the pet is currently targeting for a jump.
    private var jumpTarget: WindowPlatform?

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        physicsWorld.gravity = CGVector(dx: 0, dy: -500)
        physicsWorld.contactDelegate = self

        setupGround()
        setupPet()
        startWindowDetection()
        scheduleThoughts()
        scheduleContextChecks()
    }

    // MARK: - Setup

    private func setupGround() {
        let ground = SKNode()
        ground.physicsBody = SKPhysicsBody(
            edgeFrom: CGPoint(x: 0, y: 2),
            to:       CGPoint(x: size.width, y: 2)
        )
        ground.physicsBody?.isDynamic = false
        ground.physicsBody?.friction = 1.0
        ground.physicsBody?.categoryBitMask = Physics.platform
        addChild(ground)
    }

    private func setupPet() {
        petNode = PetNode(radius: petRadius)

        let physics = SKPhysicsBody(circleOfRadius: petRadius)
        physics.restitution        = 0.05
        physics.friction           = 1.0
        physics.linearDamping      = 0.2
        physics.allowsRotation     = false
        physics.categoryBitMask    = Physics.pet
        physics.collisionBitMask   = Physics.platform
        physics.contactTestBitMask = Physics.platform
        petNode.physicsBody = physics

        petNode.position = CGPoint(x: size.width / 2, y: size.height - 50)
        addChild(petNode)
    }

    private func startWindowDetection() {
        detector.onWindowsChanged = { [weak self] platforms in
            self?.currentPlatforms = platforms
            self?.updatePlatforms(platforms)
        }
        detector.start()
    }

    // MARK: - Platform Management

    private func updatePlatforms(_ platforms: [WindowPlatform]) {
        let newIDs = Set(platforms.map { $0.windowID })

        // Remove stale platforms
        for id in Set(platformNodes.keys).subtracting(newIDs) {
            platformNodes[id]?.removeFromParent()
            platformNodes.removeValue(forKey: id)
        }

        // Add or update platforms
        for platform in platforms {
            let node = platformNodes[platform.windowID] ?? {
                let n = SKNode()
                addChild(n)
                platformNodes[platform.windowID] = n
                return n
            }()

            let body = SKPhysicsBody(
                edgeFrom: CGPoint(x: platform.minX, y: platform.topEdgeY),
                to:       CGPoint(x: platform.maxX, y: platform.topEdgeY)
            )
            body.isDynamic = false
            body.friction = 1.0
            body.categoryBitMask = Physics.platform
            node.physicsBody = body
        }
    }

    // MARK: - Context Checks (Music, Hiding Opportunities)

    /// Periodically checks environmental context to trigger dancing or hiding.
    private func scheduleContextChecks() {
        run(.repeatForever(.sequence([
            .wait(forDuration: 3.0),
            .run { [weak self] in self?.checkEnvironmentContext() }
        ])), withKey: "contextCheck")
    }

    private func checkEnvironmentContext() {
        // --- Music detection → dancing ---
        if isMusicAppActive() && state == .idle || state == .walking {
            if state != .dancing {
                transition(to: .dancing)
            }
        } else if state == .dancing && !isMusicAppActive() {
            transition(to: .idle)
        }

        // --- Hiding opportunities ---
        if state == .walking, let hideSpot = nearestHidingSpot() {
            // 20% chance to hide when passing near a corner window
            let distToSpot = abs(petNode.position.x - hideSpot.centerX)
            if distToSpot < 80 && Double.random(in: 0...1) < 0.20 {
                transition(to: .hiding)
            }
        }
    }

    // MARK: - State Machine

    private func transition(to newState: PetState) {
        guard newState != state else { return }
        let oldState = state
        state = newState
        removeAction(forKey: "stateDuration")

        // Clean up previous state's visuals
        cleanupState(oldState)

        switch newState {
        case .falling:
            petNode.setEyeStyle(.surprised)
            petNode.hideZZZ()
            if let phrase = ThoughtProvider.phrase(for: .falling) {
                showThought(phrase)
            }

        case .walking:
            petNode.setEyeStyle(.normal)
            petNode.hideZZZ()

            // Thought after landing/waking
            run(.sequence([
                .wait(forDuration: 0.6),
                .run { [weak self] in
                    guard let self, self.state == .walking else { return }
                    self.maybeShowThought()
                }
            ]))

            // After walking 5-10s, settle down
            let walkDuration = SKAction.wait(forDuration: Double.random(in: 5...10))
            run(.sequence([walkDuration, .run { [weak self] in
                self?.transition(to: .idle)
            }]), withKey: "stateDuration")

        case .idle:
            petNode.setEyeStyle(.normal)
            petNode.hideZZZ()

            // After idling 4-8s, fall asleep
            let idleDuration = SKAction.wait(forDuration: Double.random(in: 4...8))
            run(.sequence([idleDuration, .run { [weak self] in
                self?.transition(to: .sleeping)
            }]), withKey: "stateDuration")

        case .sleeping:
            petNode.setEyeStyle(.closed)
            petNode.showZZZ()
            petNode.childNode(withName: "thought")?.removeFromParent()

            let sleepDuration = SKAction.wait(forDuration: Double.random(in: 6...14))
            run(.sequence([sleepDuration, .run { [weak self] in
                self?.transition(to: .walking)
            }]), withKey: "stateDuration")

        case .jumping:
            petNode.setEyeStyle(.surprised)
            petNode.hideZZZ()
            showThought(["¡Allá voy!", "¡Salto!", "¡Wheee!", "¡Arriba!"].randomElement()!)

            // Squish animation then physics impulse
            let squishDuration = petNode.playJumpSquish()
            run(.sequence([
                .wait(forDuration: squishDuration),
                .run { [weak self] in
                    self?.applyJumpImpulse()
                }
            ]))

        case .dancing:
            petNode.setEyeStyle(.happy)
            petNode.hideZZZ()
            petNode.startDancing()
            showThought(["♪ ♫ ♪", "¡A bailar!", "¡Música!", "🎵 Groovy 🎵"].randomElement()!)

            // Dance for 8-15s then reconsider
            let danceDuration = SKAction.wait(forDuration: Double.random(in: 8...15))
            run(.sequence([danceDuration, .run { [weak self] in
                guard let self else { return }
                if isMusicAppActive() {
                    // Still playing music — keep dancing but refresh thought
                    self.maybeShowThought()
                } else {
                    self.transition(to: .idle)
                }
            }]), withKey: "stateDuration")

        case .hiding:
            petNode.setEyeStyle(.peeking)
            petNode.hideZZZ()
            petNode.playHideAnimation()
            showThought(["Shhh...", "No me ven 👀", "Escondido", "🤫"].randomElement()!)

            // Stay hidden 4-8s then emerge
            let hideDuration = SKAction.wait(forDuration: Double.random(in: 4...8))
            run(.sequence([hideDuration, .run { [weak self] in
                self?.petNode.playUnhideAnimation()
                self?.transition(to: .walking)
            }]), withKey: "stateDuration")
        }
    }

    /// Cleans up visual effects from the previous state before entering a new one.
    private func cleanupState(_ oldState: PetState) {
        switch oldState {
        case .dancing:
            petNode.stopDancing()
        case .hiding:
            petNode.playUnhideAnimation()
        default:
            break
        }
    }

    // MARK: - Physics Contacts

    func didBegin(_ contact: SKPhysicsContact) {
        guard isPetContact(contact) else { return }
        contactCount += 1
        if contactCount == 1 {
            if state == .falling {
                transition(to: .walking)
            } else if state == .jumping {
                // Landed from a jump
                jumpTarget = nil
                transition(to: .walking)
            }
        }
    }

    func didEnd(_ contact: SKPhysicsContact) {
        guard isPetContact(contact) else { return }
        contactCount = max(0, contactCount - 1)

        run(.sequence([
            .wait(forDuration: 0.15),
            .run { [weak self] in
                guard let self, self.contactCount == 0 else { return }
                self.transition(to: .falling)
            }
        ]), withKey: "fallCheck")
    }

    private func isPetContact(_ contact: SKPhysicsContact) -> Bool {
        contact.bodyA.categoryBitMask == Physics.pet ||
        contact.bodyB.categoryBitMask == Physics.pet
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        guard let body = petNode.physicsBody else { return }

        switch state {
        case .walking:
            if contactCount > 0 {
                body.velocity = CGVector(dx: walkDirection * walkSpeed, dy: body.velocity.dy)
            }
            checkPlatformEdges()

            // Check for nearby square windows to jump onto (with cooldown)
            if currentTime > jumpCooldownUntil {
                checkForJumpOpportunity()
            }

        case .idle:
            body.velocity = CGVector(dx: body.velocity.dx * 0.85, dy: body.velocity.dy)

        case .sleeping:
            body.velocity = CGVector(dx: body.velocity.dx * 0.85, dy: body.velocity.dy)

        case .dancing:
            // Gentle sway — no horizontal movement
            body.velocity = CGVector(dx: body.velocity.dx * 0.9, dy: body.velocity.dy)

        case .hiding:
            // Stay put
            body.velocity = CGVector(dx: 0, dy: body.velocity.dy)

        case .falling, .jumping:
            break
        }

        // Fallback: fast downward velocity → force falling state
        if state != .falling && state != .jumping && body.velocity.dy < -150 {
            contactCount = 0
            transition(to: .falling)
        }

        // Screen boundary enforcement
        if petNode.position.x < 40             { walkDirection =  1 }
        if petNode.position.x > size.width - 40 { walkDirection = -1 }
    }

    // MARK: - Platform Edge Detection

    private func checkPlatformEdges() {
        guard let edges = nearestPlatformEdges() else { return }
        let margin: CGFloat = 40
        if petNode.position.x <= edges.minX + margin { walkDirection =  1 }
        if petNode.position.x >= edges.maxX - margin { walkDirection = -1 }
    }

    private func nearestPlatformEdges() -> (minX: CGFloat, maxX: CGFloat)? {
        let px = petNode.position.x
        let py = petNode.position.y
        let standingThreshold: CGFloat = 25

        var best: (minX: CGFloat, maxX: CGFloat, dist: CGFloat)?
        let groundDist = abs(py - petRadius - 2)
        if groundDist < standingThreshold {
            best = (0, size.width, groundDist)
        }

        for p in currentPlatforms {
            guard px >= p.minX && px <= p.maxX else { continue }
            let dist = abs(py - petRadius - p.topEdgeY)
            guard dist < standingThreshold else { continue }
            if best == nil || dist < best!.dist {
                best = (p.minX, p.maxX, dist)
            }
        }

        return best.map { ($0.minX, $0.maxX) }
    }

    // MARK: - Jump Logic

    /// Looks for square windows above or near the pet's current position.
    /// If found, initiates a jump toward the nearest one.
    private func checkForJumpOpportunity() {
        let px = petNode.position.x
        let py = petNode.position.y

        // Find square windows whose top edge is above us and horizontally reachable
        let candidates = currentPlatforms.filter { p in
            p.shape == .square &&
            p.topEdgeY > py + 20 &&                          // Above us
            p.topEdgeY < py + 350 &&                         // Not unreachably high
            abs(p.centerX - px) < 200                        // Horizontally close
        }

        guard let target = candidates.min(by: { a, b in
            abs(a.centerX - px) < abs(b.centerX - px)
        }) else { return }

        // 30% chance per check to decide to jump (creates natural hesitation)
        guard Double.random(in: 0...1) < 0.30 else { return }

        jumpTarget = target
        transition(to: .jumping)
    }

    /// Applies the actual physics impulse for a jump toward jumpTarget.
    private func applyJumpImpulse() {
        guard let body = petNode.physicsBody else { return }
        guard let target = jumpTarget else {
            // No target — just do a small hop
            body.applyImpulse(CGVector(dx: 0, dy: jumpImpulse * 0.6))
            return
        }

        let dx = target.centerX - petNode.position.x
        let horizontalImpulse = dx.clamped(to: -120...120)
        body.applyImpulse(CGVector(dx: horizontalImpulse, dy: jumpImpulse))

        // Set cooldown so we don't re-trigger immediately
        jumpCooldownUntil = CACurrentMediaTime() + 4.0
    }

    // MARK: - Hiding Spot Detection

    /// Returns the nearest small/corner window that qualifies as a hiding spot.
    private func nearestHidingSpot() -> WindowPlatform? {
        let px = petNode.position.x

        return currentPlatforms
            .filter { $0.shape == .small }
            .min(by: { abs($0.centerX - px) < abs($1.centerX - px) })
    }

    // MARK: - Thought Bubbles

    private func scheduleThoughts() {
        run(.repeatForever(.sequence([
            .wait(forDuration: 12, withRange: 8),
            .run { [weak self] in self?.maybeShowThought() }
        ])), withKey: "thinking")
    }

    private func maybeShowThought() {
        guard petNode.childNode(withName: "thought") == nil else { return }
        guard let phrase = ThoughtProvider.phrase(for: state) else { return }
        showThought(phrase)
    }

    private func showThought(_ phrase: String) {
        petNode.childNode(withName: "thought")?.removeFromParent()

        let bubble = ThoughtBubble(text: phrase)
        bubble.name = "thought"

        let nearRightEdge = petNode.position.x > size.width * 0.65
        bubble.position = CGPoint(
            x: nearRightEdge ? -(18 + 95) : 18,
            y: petRadius + 48
        )

        petNode.addChild(bubble)
        bubble.present(duration: 4.5)
    }
}

// MARK: - CGFloat Clamping

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
