//
//  AmountSlider.swift
//  TymeComponent
//
//  Created by Dat Hoang on 20/10/2021.
//  Copyright © 2021 TymeDigital Vietnam. All rights reserved.
//

import UIKit
//import AVFAudio

@objc public protocol AmountSliderDelegate {
    @objc optional func beginTracking()
    @objc optional func endTracking()
    @objc optional func valueChanged(_ value: Double)
}

@IBDesignable
public final class AmountSlider: UIControl {
    // MARK: - Public Properties
    @IBInspectable public var minimumValue: Double = -100
    @IBInspectable public var maximumValue: Double = 100
    @IBInspectable public var value: Double = 0.0 {
        didSet {
            setNeedsDisplay()
            updateValue()
        }
    }
    
    @IBInspectable public var tick: Double = 1.0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    @IBInspectable public var markColor: UIColor = UIColor.white
    @IBInspectable public var markWidth: CGFloat = 1.0
    @IBInspectable public var markRadius: CGFloat = 1.0
    @IBInspectable public var markCount: Int = 20
    @IBOutlet public weak var delegate: AmountSliderDelegate?
    
    @IBInspectable public var padding: Double = 10 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // MARK: - Private Properties
    fileprivate var previousValue: Double = 0.0
    fileprivate var previousLocation = CGPoint()
    fileprivate var nextValue: Double = 0.0
    fileprivate var slidePosition: Double = 0.0
    fileprivate var animateDuration = 0.2
    fileprivate var lastTime: TimeInterval = CACurrentMediaTime()
    fileprivate var timer: Timer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    fileprivate var animating = false {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override public func draw(_ rect: CGRect) {
        super.draw(rect)
        let tickSpacing = (Double(frame.width) / Double(markCount))
        slidePosition = -value * tickSpacing / tick + Double(frame.width / 2)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        for index in 0...markCount {
            var relativePosition = (CGFloat(tickSpacing) * CGFloat(index)
                                    + CGFloat(slidePosition) - frame.width/2)
                .truncatingRemainder(dividingBy: frame.width)
            if relativePosition < 0 {
                relativePosition += frame.width
            }

            let spotlightWidth = self.bounds.width / 5
            let screenWidth = self.bounds.width / 2
            var alpha = max(0.2, 1.0 - (abs(relativePosition-screenWidth) / spotlightWidth))
            let middleMark: Double = Double(markCount / 2)
            if (minimumValue...((middleMark - 1) * tick)).contains(value) {
                let remainder = Int(value) % (markCount * Int(tick) / 2)
                let endRange = Double(0.5 + middleMark - Double(remainder)/tick) * tickSpacing
                if (0...endRange).contains(relativePosition) {
                    alpha = 0
                }
            } else if ((maximumValue-((middleMark - 1) * tick))...maximumValue).contains(value) {
                let remainder = Int(value) % (markCount * Int(tick) / 2)
                var endRange = (Double(markCount) - Double(remainder)/tick) * tickSpacing
                if endRange >= self.bounds.width { endRange = endRange - screenWidth + markWidth }
                if (endRange...self.bounds.width).contains(relativePosition) {
                    alpha = 0
                }
            }
            
            ctx.setFillColor(self.markColor.withAlphaComponent(alpha).cgColor)
            let markX = relativePosition - markWidth/2
            let distanceFromMiddle = ceil(abs(markX - screenWidth))
            let roundedHeight = round((frame.height - CGFloat(distanceFromMiddle/tickSpacing) * 2) / 2) * 2
            let height = max(20.0, roundedHeight)
            let rect = CGRect(x: markX,
                              y: (frame.height - height) / 2,
                              width: markWidth,
                              height: height)
            
            let path = UIBezierPath(roundedRect: rect,
                                    cornerRadius: markRadius)
            ctx.addPath(path.cgPath)
            ctx.fillPath()
        }
    }
    
    private func drawStaticMark () {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        for index in 0...markCount {
            let relativePosition = (CGFloat((frame.width) / CGFloat(markCount)) *
                                    CGFloat(index))
                .truncatingRemainder(dividingBy: frame.width)
            let screenWidth = self.bounds.width / 2.0
            let alpha = 1.0 - (abs(relativePosition-screenWidth) / screenWidth)
            ctx.setFillColor(self.markColor.withAlphaComponent(alpha).cgColor)
            
            let distanceFromMiddle = ceil(Double(abs(markCount / 2 - index)))
            let pathX = relativePosition - markWidth / 2
            let roundedHeight = round((frame.height - CGFloat(distanceFromMiddle)) / 2) * 2
            let height = max(20.0, roundedHeight)
            let pathY = (frame.height - height) / 2
            let rect = CGRect(x: pathX, y: pathY, width: markWidth, height: height)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: markRadius)
            ctx.addPath(path.cgPath)
            ctx.fillPath()
        }
    }
    
    private func drawMark() {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        for index in 0...markCount {
            var relativePosition = (CGFloat((frame.width) / CGFloat(markCount)) * CGFloat(index)
                                    + CGFloat(slidePosition) - frame.width / 2)
                .truncatingRemainder(dividingBy: frame.width)
            if relativePosition < 0 {
                relativePosition += frame.width
            }
            let screenWidth = self.bounds.width / 2.0
            let alpha = 1.0 - (abs(relativePosition-screenWidth) / screenWidth)
            ctx.setFillColor(self.markColor.withAlphaComponent(alpha).cgColor)
            
            let pathX = relativePosition - markWidth / 2
            let rect = CGRect(x: pathX, y: 0, width: markWidth, height: frame.height)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: markRadius)
            ctx.addPath(path.cgPath)
            ctx.fillPath()
        }
    }
    
    override public func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        guard tick != 0 else { return false }
        delegate?.beginTracking?()
        animating = true
        previousLocation = touch.location(in: self)
        return true
    }
    
    override public func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        guard tick != 0 else { return false }
        animating = true
        let location = touch.location(in: self)
        let deltaLocation = Double(location.x - previousLocation.x)
        let deltaValue = deltaLocation / (Double(frame.width) / Double(markCount)) * tick
        previousLocation = location
        let calculatedValue = self.value - deltaValue
        if calculatedValue <= minimumValue {
            self.value = minimumValue
        } else if calculatedValue >= maximumValue {
            self.value = maximumValue
        } else {
            self.value = calculatedValue
        }
        triggerFeedback()
        return true
    }
    
    override public func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        guard tick != 0 else { return }
        delegate?.endTracking?()
        animating = false
        let calculatedValue = round(value * (10.0/tick) / 10.0) * (10.0 / (10.0/tick))
        if calculatedValue < minimumValue {
            animateWithValueUpdate(minimumValue)
        } else if calculatedValue > maximumValue {
            animateWithValueUpdate(maximumValue)
        } else {
            animateWithValueUpdate(calculatedValue)
        }
    }
    
    public func animateWithValueUpdate(_ nextValue: Double) {
        previousValue = value
        self.nextValue = nextValue
        if nextValue == previousValue { return }

        stopAnimation()
        lastTime = CACurrentMediaTime()
        timer = Timer.scheduledTimer(timeInterval: animateDuration / 4,
                      target: self,
                      selector: #selector(step),
                      userInfo: nil,
                      repeats: true)
    }
    
    @objc func step() {
        let currentTime: TimeInterval = CACurrentMediaTime()
        let elapsedTime = currentTime - self.lastTime
        let time: TimeInterval = min(animateDuration, elapsedTime)
        value = nextAnimatedStep(currentTime: time,
                                 startValue: previousValue,
                                 endValue: nextValue,
                                 duration: animateDuration
                                )
        if time >= animateDuration {
            stopAnimation()
        }
    }

    fileprivate func nextAnimatedStep(currentTime: Double,
                                      startValue: Double,
                                      endValue: Double,
                                      duration: Double) -> Double {
        let totalMovingRange = endValue - startValue
        return totalMovingRange * pow(currentTime/duration, 2) + startValue
    }
    
    fileprivate func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }
    
    fileprivate func updateValue() {
        let roundedValue = tick * round(value / tick)
        if Int(roundedValue) % Int(tick) == 0 { delegate?.valueChanged?(roundedValue) }
    }
    
    fileprivate func triggerFeedback() {
//        AudioServicesPlaySystemSoundWithCompletion(1157, nil)
        if #available(iOS 13.0, *) {
            Vibration.soft.vibrate()
        } else {
            Vibration.selection.vibrate()
        }
    }
}
