//
//  PetNode.swift
//  liveondesk
//

import SpriteKit

// MARK: - Eye Style

enum EyeStyle {
    case normal, surprised, closed, happy, peeking
}

// MARK: - PetNode

/// Self-contained visual representation of the desktop pet.
///
/// Owns all visual sub-nodes (body, ears, eyes, nose, mouth) and exposes
/// methods to change expressions and play state-specific animations.
/// Physics body is assigned externally by PetScene since collision
/// categories belong to the scene's domain.
class PetNode: SKNode {
    let petRadius: CGFloat

    // Sub-node references for animations
    private var bodyNode: SKShapeNode!

    init(radius: CGFloat = 32) {
        self.petRadius = radius
        super.init()
        setupVisuals()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Visual Setup

    private func setupVisuals() {
        bodyNode = SKShapeNode(circleOfRadius: petRadius)
        bodyNode.fillColor   = NSColor(red: 0.85, green: 0.55, blue: 0.20, alpha: 1.0)
        bodyNode.strokeColor = NSColor(red: 0.60, green: 0.35, blue: 0.10, alpha: 1.0)
        bodyNode.lineWidth   = 2
        bodyNode.name        = "body"
        addChild(bodyNode)

        addChild(makeEar(at: CGPoint(x: -20, y: petRadius - 4)))
        addChild(makeEar(at: CGPoint(x:  20, y: petRadius - 4)))

        let leftEye = makeEyeContainer()
        leftEye.name     = "leftEye"
        leftEye.position = CGPoint(x: -11, y: 8)
        addChild(leftEye)

        let rightEye = makeEyeContainer()
        rightEye.name     = "rightEye"
        rightEye.position = CGPoint(x: 11, y: 8)
        addChild(rightEye)

        let nose = SKShapeNode(circleOfRadius: 5)
        nose.fillColor   = NSColor(red: 1.0, green: 0.4, blue: 0.55, alpha: 1.0)
        nose.strokeColor = .clear
        nose.position    = CGPoint(x: 0, y: -2)
        nose.name        = "nose"
        addChild(nose)

        let mouth = SKShapeNode()
        let mpath = CGMutablePath()
        mpath.move(to: CGPoint(x: -8, y: -10))
        mpath.addQuadCurve(to: CGPoint(x: 8, y: -10), control: CGPoint(x: 0, y: -16))
        mouth.path        = mpath
        mouth.strokeColor = NSColor(red: 0.5, green: 0.2, blue: 0.1, alpha: 1.0)
        mouth.lineWidth   = 2
        mouth.name        = "mouth"
        addChild(mouth)
    }

    // MARK: - Sub-node Factories

    private func makeEyeContainer() -> SKNode {
        let eye   = SKNode()
        let white = SKShapeNode(circleOfRadius: 7)
        white.fillColor = .white; white.strokeColor = .clear
        eye.addChild(white)
        let pupil = SKShapeNode(circleOfRadius: 3.5)
        pupil.fillColor   = NSColor(red: 0.15, green: 0.1, blue: 0.1, alpha: 1)
        pupil.strokeColor = .clear
        pupil.position    = CGPoint(x: 1, y: -1)
        eye.addChild(pupil)
        return eye
    }

    private func makeEar(at position: CGPoint) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: -8,  y: 14))
        path.addLine(to: CGPoint(x:  8,  y: 14))
        path.closeSubpath()
        let ear = SKShapeNode(path: path)
        ear.fillColor   = NSColor(red: 0.85, green: 0.55, blue: 0.20, alpha: 1.0)
        ear.strokeColor = NSColor(red: 0.60, green: 0.35, blue: 0.10, alpha: 1.0)
        ear.lineWidth   = 2
        ear.position    = position
        ear.name        = "ear"
        return ear
    }

    // MARK: - Expressions

    func setEyeStyle(_ style: EyeStyle) {
        for side in ["leftEye", "rightEye"] {
            guard let eye = childNode(withName: side) else { continue }
            eye.removeAllChildren()

            switch style {
            case .normal:
                let white = SKShapeNode(circleOfRadius: 7)
                white.fillColor = .white; white.strokeColor = .clear
                eye.addChild(white)
                let pupilOffset = CGPoint(x: side == "leftEye" ? -1 : 1, y: -1)
                let pupil = SKShapeNode(circleOfRadius: 3.5)
                pupil.fillColor   = NSColor(red: 0.15, green: 0.1, blue: 0.1, alpha: 1)
                pupil.strokeColor = .clear
                pupil.position    = pupilOffset
                eye.addChild(pupil)

            case .surprised:
                let white = SKShapeNode(circleOfRadius: 9)
                white.fillColor = .white; white.strokeColor = .clear
                eye.addChild(white)
                let pupil = SKShapeNode(circleOfRadius: 5)
                pupil.fillColor = .black; pupil.strokeColor = .clear
                eye.addChild(pupil)

            case .closed:
                let arc = SKShapeNode()
                let path = CGMutablePath()
                path.move(to: CGPoint(x: -7, y: 0))
                path.addQuadCurve(to: CGPoint(x: 7, y: 0), control: CGPoint(x: 0, y: -5))
                arc.path        = path
                arc.strokeColor = NSColor(red: 0.2, green: 0.1, blue: 0.1, alpha: 1)
                arc.lineWidth   = 2.5
                eye.addChild(arc)

            case .happy:
                // Upward curve — happy/smiling eyes (used during dancing)
                let arc = SKShapeNode()
                let path = CGMutablePath()
                path.move(to: CGPoint(x: -7, y: 0))
                path.addQuadCurve(to: CGPoint(x: 7, y: 0), control: CGPoint(x: 0, y: 5))
                arc.path        = path
                arc.strokeColor = NSColor(red: 0.2, green: 0.1, blue: 0.1, alpha: 1)
                arc.lineWidth   = 2.5
                eye.addChild(arc)

            case .peeking:
                // Half-open eye — used when hiding
                let white = SKShapeNode(circleOfRadius: 5)
                white.fillColor = .white; white.strokeColor = .clear
                eye.addChild(white)
                let pupil = SKShapeNode(circleOfRadius: 3)
                pupil.fillColor   = NSColor(red: 0.15, green: 0.1, blue: 0.1, alpha: 1)
                pupil.strokeColor = .clear
                pupil.position    = CGPoint(x: side == "leftEye" ? -1 : 1, y: 0)
                eye.addChild(pupil)
                // Half-lid line over the eye
                let lid = SKShapeNode()
                let lidPath = CGMutablePath()
                lidPath.move(to: CGPoint(x: -6, y: 3))
                lidPath.addLine(to: CGPoint(x: 6, y: 3))
                lid.path        = lidPath
                lid.strokeColor = NSColor(red: 0.6, green: 0.35, blue: 0.10, alpha: 1)
                lid.lineWidth   = 2
                eye.addChild(lid)
            }
        }
    }

    // MARK: - ZZZ Animation

    func showZZZ() {
        hideZZZ()
        let container = SKNode()
        container.name     = "zzz"
        container.position = CGPoint(x: petRadius + 5, y: petRadius + 5)
        addChild(container)

        let emitZ = SKAction.run { [weak container] in
            guard let c = container else { return }
            let z = SKLabelNode(text: "z")
            z.fontSize  = [11, 15, 19].randomElement()!
            z.fontName  = "Helvetica-Bold"
            z.fontColor = NSColor(red: 0.5, green: 0.6, blue: 0.9, alpha: 0.85)
            z.position  = CGPoint(x: CGFloat.random(in: -4...4), y: 0)
            c.addChild(z)
            z.run(.sequence([
                .group([
                    .moveBy(x: CGFloat.random(in: 5...12), y: 38, duration: 1.4),
                    .fadeOut(withDuration: 1.4)
                ]),
                .removeFromParent()
            ]))
        }
        container.run(.repeatForever(.sequence([emitZ, .wait(forDuration: 0.9)])), withKey: "emit")
    }

    func hideZZZ() {
        childNode(withName: "zzz")?.removeFromParent()
    }

    // MARK: - Dance Animation

    /// Plays a repeating side-to-side sway with squash-and-stretch.
    func startDancing() {
        stopDancing()
        let swayRight = SKAction.rotate(toAngle: .pi / 14, duration: 0.25)
        let swayLeft  = SKAction.rotate(toAngle: -.pi / 14, duration: 0.25)
        let center    = SKAction.rotate(toAngle: 0, duration: 0.15)

        let bounce = SKAction.sequence([
            .scaleY(to: 0.9, duration: 0.12),
            .scaleY(to: 1.1, duration: 0.12),
            .scaleY(to: 1.0, duration: 0.08),
        ])

        let danceStep = SKAction.sequence([
            .group([swayRight, bounce]),
            .group([swayLeft, bounce]),
            center
        ])
        run(.repeatForever(danceStep), withKey: "dance")
    }

    func stopDancing() {
        removeAction(forKey: "dance")
        zRotation = 0
        yScale = 1.0
    }

    // MARK: - Jump Animation

    /// Plays a preparatory squish before the physics jump impulse is applied.
    /// Returns the total duration of the squish so the caller can time the impulse.
    @discardableResult
    func playJumpSquish() -> TimeInterval {
        let squish = SKAction.sequence([
            .scaleY(to: 0.75, duration: 0.1),
            .scaleY(to: 1.15, duration: 0.08),
            .scaleY(to: 1.0, duration: 0.06),
        ])
        run(squish, withKey: "jumpSquish")
        return 0.24
    }

    // MARK: - Hide Animation

    /// Shrinks the pet down to simulate it squeezing into a corner.
    func playHideAnimation() {
        removeAction(forKey: "hideAnim")
        run(.sequence([
            .group([
                .scale(to: 0.6, duration: 0.35),
                .fadeAlpha(to: 0.7, duration: 0.35)
            ])
        ]), withKey: "hideAnim")
    }

    /// Restores the pet from hiding.
    func playUnhideAnimation() {
        removeAction(forKey: "hideAnim")
        run(.sequence([
            .group([
                .scale(to: 1.0, duration: 0.25),
                .fadeAlpha(to: 1.0, duration: 0.25)
            ])
        ]), withKey: "hideAnim")
    }
}
