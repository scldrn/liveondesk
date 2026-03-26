//
//  ThoughtBubble.swift
//  liveondesk
//

import SpriteKit
import AppKit

class ThoughtBubble: SKNode {

    init(text: String, maxWidth: CGFloat = 190) {
        super.init()

        let padding = CGSize(width: 14, height: 10)

        let font = NSFont(name: "Helvetica Neue", size: 13) ?? NSFont.systemFont(ofSize: 13)
        let textWidth = maxWidth - padding.width * 2
        let textRect = (text as NSString).boundingRect(
            with: CGSize(width: textWidth, height: 300),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        let textSize = CGSize(width: ceil(textRect.width), height: ceil(textRect.height))

        let bubbleSize = CGSize(
            width:  max(textSize.width + padding.width * 2, 60),
            height: textSize.height + padding.height * 2
        )

        let bubbleRect = CGRect(
            x: -bubbleSize.width / 2, y: -bubbleSize.height / 2,
            width: bubbleSize.width,  height: bubbleSize.height
        )

        // Sombra
        let shadow = SKShapeNode(rect: bubbleRect, cornerRadius: 12)
        shadow.fillColor   = NSColor(white: 0, alpha: 0.08)
        shadow.strokeColor = .clear
        shadow.position    = CGPoint(x: 2, y: -2)
        addChild(shadow)

        // Burbuja
        let bubble = SKShapeNode(rect: bubbleRect, cornerRadius: 12)
        bubble.fillColor   = .white
        bubble.strokeColor = NSColor(white: 0.70, alpha: 1)
        bubble.lineWidth   = 1.5
        addChild(bubble)

        // Texto
        let label = SKLabelNode()
        label.text                    = text
        label.fontName                = "Helvetica Neue"
        label.fontSize                = 13
        label.fontColor               = NSColor(white: 0.15, alpha: 1)
        label.numberOfLines           = 0
        label.preferredMaxLayoutWidth = textWidth
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode   = .center
        label.position = .zero
        addChild(label)

        // Puntos de pensamiento apuntando al pet
        let dotSpecs: [(CGPoint, CGFloat)] = [
            (CGPoint(x: -bubbleSize.width / 2 + 14, y: -bubbleSize.height / 2 - 5),  5),
            (CGPoint(x: -bubbleSize.width / 2 + 7,  y: -bubbleSize.height / 2 - 12), 4),
            (CGPoint(x: -bubbleSize.width / 2,       y: -bubbleSize.height / 2 - 18), 3),
        ]
        for (pos, r) in dotSpecs {
            let dot = SKShapeNode(circleOfRadius: r)
            dot.fillColor   = .white
            dot.strokeColor = NSColor(white: 0.70, alpha: 1)
            dot.lineWidth   = 1.5
            dot.position    = pos
            addChild(dot)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Aparece con pop suave, espera, desaparece. Key evita animaciones apiladas.
    func present(duration: TimeInterval = 4.0) {
        removeAction(forKey: "bubble")
        alpha = 0
        setScale(0.75)
        run(.sequence([
            .group([
                .fadeIn(withDuration: 0.25),
                .scale(to: 1.0, duration: 0.25)
            ]),
            .wait(forDuration: duration),
            .group([
                .fadeOut(withDuration: 0.35),
                .scale(to: 0.85, duration: 0.35)
            ]),
            .removeFromParent()
        ]), withKey: "bubble")
    }
}
