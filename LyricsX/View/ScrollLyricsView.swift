//
//  ScrollLyricsView.swift
//
//  This file is part of LyricsX
//  Copyright (C) 2017  Xander Deng
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Cocoa

protocol ScrollLyricsViewDelegate: class {
    func doubleClickLyricsLine(at position: TimeInterval)
}

class ScrollLyricsView: NSScrollView {
    
    weak var delegate: ScrollLyricsViewDelegate?
    
    private var textView: NSTextView!
    
    var fadeStripWidth: CGFloat = 24
    
    private var ranges: [(TimeInterval, NSRange)] = []
    private var highlightedRange: NSRange? = nil
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        drawsBackground = false
        borderType = .noBorder
        hasHorizontalScroller = false
        hasVerticalScroller = false
        textView = NSTextView(frame: frame).then {
            $0.font = NSFont.systemFont(ofSize: 12)
            $0.textColor = #colorLiteral(red: 0.7540688515, green: 0.7540867925, blue: 0.7540771365, alpha: 1)
            $0.alignment = .center
            $0.drawsBackground = false
            $0.isEditable = false
            $0.isSelectable = false
            $0.autoresizingMask = [.viewWidthSizable]
        }
        documentView = textView
    }
    
    func setupTextContents(lyrics: Lyrics?) {
        guard let lyrics = lyrics else {
            ranges = []
            textView.string = ""
            highlightedRange = nil
            return
        }
        
        var lrcContent = ""
        var newRanges: [(TimeInterval, NSRange)] = []
        let enabledLrc = lyrics.lyrics.filter({ $0.enabled && $0.sentence != "" })
        for line in enabledLrc {
            var lineStr = line.sentence
            if let trans = line.translation, defaults[.PreferBilingualLyrics] {
                lineStr += "\n" + trans
            }
            let range = NSRange(location: lrcContent.characters.count, length: lineStr.characters.count)
            newRanges.append(line.position, range)
            lrcContent += lineStr
            if line != enabledLrc.last {
                lrcContent += "\n\n"
            }
        }
        ranges = newRanges
        textView.string = lrcContent
        highlightedRange = nil
        textView.textStorage?.addAttribute(NSForegroundColorAttributeName, value: #colorLiteral(red: 0.7540688515, green: 0.7540867925, blue: 0.7540771365, alpha: 1), range: NSMakeRange(0, textView.string!.characters.count))
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        updateFadeEdgeMask()
        updateEdgeInset()
    }
    
    override func mouseUp(with event: NSEvent) {
        guard event.clickCount == 2 else {
            super.mouseUp(with: event)
            return
        }
        
        let clickPoint = textView.convert(event.locationInWindow, from: nil)
        let clickRange = ranges.filter { (_, range) in
            let bounding = textView.layoutManager!.boundingRect(forGlyphRange: range, in: textView.textContainer!)
            return bounding.contains(clickPoint)
        }
        if let (position, _) = clickRange.first {
            delegate?.doubleClickLyricsLine(at: position)
        }
    }
    
    func updateFadeEdgeMask() {
        let location = fadeStripWidth / frame.height
        wantsLayer = true
        layer?.mask = CAGradientLayer().then {
            $0.frame = bounds
            $0.colors = [#colorLiteral(red: 0, green: 0, blue: 0, alpha: 0).cgColor, #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1).cgColor, #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1).cgColor, #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0).cgColor]
            $0.locations = [0, location as NSNumber, (1 - location) as NSNumber, 1]
            $0.startPoint = .zero
            $0.endPoint = CGPoint(x: 0, y: 1)
        }
    }
    
    func updateEdgeInset() {
        guard ranges.count > 0 else {
            return
        }
        
        let bounding1 = textView.layoutManager!.boundingRect(forGlyphRange: ranges.first!.1, in: textView.textContainer!)
        let topInset = frame.height/2 - bounding1.height/2
        let bounding2 = textView.layoutManager!.boundingRect(forGlyphRange: ranges.last!.1, in: textView.textContainer!)
        let BottomInset = frame.height/2 - bounding2.height/2
        automaticallyAdjustsContentInsets = false
        contentInsets = EdgeInsets(top: topInset, left: 0, bottom: BottomInset, right: 0)
    }
    
    func highlight(position: TimeInterval) {
        guard ranges.count > 0 else {
            return
        }
        
        var left = ranges.startIndex
        var right = ranges.endIndex - 1
        while left <= right {
            let mid = (left + right) / 2
            if ranges[mid].0 <= position {
                left = mid + 1
            } else {
                right = mid - 1
            }
        }
        let range = ranges[right.clamped(to: ranges.indexes)].1
        
        if highlightedRange == range {
            return
        }
        
        highlightedRange.map { textView.textStorage?.addAttribute(NSForegroundColorAttributeName, value: #colorLiteral(red: 0.7540688515, green: 0.7540867925, blue: 0.7540771365, alpha: 1), range: $0) }
        textView.textStorage?.addAttribute(NSForegroundColorAttributeName, value: #colorLiteral(red: 0.8866666667, green: 1, blue: 0.8, alpha: 1), range: range)
        
        highlightedRange = range
    }
    
    func scroll(position: TimeInterval) {
        guard ranges.count > 0 else {
            return
        }
        
        var left = ranges.startIndex
        var right = ranges.endIndex - 1
        while left <= right {
            let mid = (left + right) / 2
            if ranges[mid].0 <= position {
                left = mid + 1
            } else {
                right = mid - 1
            }
        }
        let range = ranges[right.clamped(to: ranges.indexes)].1
        
        let bounding = textView.layoutManager!.boundingRect(forGlyphRange: range, in: textView.textContainer!)
        
        let point = NSPoint(x: 0, y: bounding.midY - frame.height / 2)
        textView.scroll(point)
    }
    
}

extension NSRange: Equatable {
    
    public static func ==(lhs: NSRange, rhs: NSRange) -> Bool {
        return lhs.location == rhs.location && lhs.length == rhs.length
    }
    
}
