//
//  MarqueeTextView.swift
//  Tuneful
//

import SwiftUI
import AppKit

/// Single-line text that scrolls endlessly when it is wider than `width`.
///
/// The scrolling is one Core Animation translation on a layer holding two copies of the text,
/// so the render server moves it and the app does no per-frame work.
struct MarqueeText: NSViewRepresentable {
    let text: String
    let width: CGFloat

    func makeNSView(context: Context) -> MarqueeNSView {
        MarqueeNSView()
    }

    func updateNSView(_ nsView: MarqueeNSView, context: Context) {
        nsView.configure(text: text, width: width)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: MarqueeNSView, context: Context) -> CGSize? {
        CGSize(width: width, height: nsView.textHeight)
    }
}

final class MarqueeNSView: NSView {
    private static let gap: CGFloat = 30
    private static let pointsPerSecond: CGFloat = 30
    private static let animationKey = "marquee"

    private let content = NSView()
    private let first = MarqueeNSView.makeLabel()
    private let second = MarqueeNSView.makeLabel()
    private var text = ""
    private var visibleWidth: CGFloat = 0

    var textHeight: CGFloat { ceil(first.intrinsicContentSize.height) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        content.wantsLayer = true
        content.addSubview(first)
        content.addSubview(second)
        addSubview(content)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(text newText: String, width newWidth: CGFloat) {
        guard newText != text || newWidth != visibleWidth else { return }
        text = newText
        visibleWidth = newWidth
        first.stringValue = newText
        second.stringValue = newText
        needsLayout = true
    }

    override func layout() {
        super.layout()

        let textWidth = ceil(text.stringWidth(with: Constants.StatusBar.marqueeFont))
        let height = textHeight
        let y = floor((bounds.height - height) / 2)
        let scrolls = textWidth > visibleWidth
        let period = textWidth + MarqueeNSView.gap

        content.frame = NSRect(x: 0, y: y, width: scrolls ? period + textWidth : textWidth, height: height)
        first.frame = NSRect(x: 0, y: 0, width: textWidth, height: height)
        second.frame = NSRect(x: period, y: 0, width: textWidth, height: height)
        second.isHidden = !scrolls

        content.layer?.removeAnimation(forKey: MarqueeNSView.animationKey)
        if scrolls && window != nil {
            let animation = CABasicAnimation(keyPath: "transform.translation.x")
            animation.fromValue = 0
            animation.toValue = -period
            animation.duration = Double(period / MarqueeNSView.pointsPerSecond)
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            animation.repeatCount = .infinity
            content.layer?.add(animation, forKey: MarqueeNSView.animationKey)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        needsLayout = true
    }

    private static func makeLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = Constants.StatusBar.marqueeFont
        label.lineBreakMode = .byClipping
        label.usesSingleLineMode = true
        label.maximumNumberOfLines = 1
        return label
    }
}
