//
//  ViewController.swift
//  TextHitKitDemo
//
//  Created by Howard-Zjun on 2026/10/18.
//

import UIKit
import TextHitKit
import SnapKit

class ViewController: UIViewController {

    private lazy var headingLabel: UILabel = {
        let label = UILabel()
        label.text = "TextHitKit 点击测试"
        label.font = .boldSystemFont(ofSize: 24)
        label.numberOfLines = 0
        return label
    }()

    private lazy var instructionsLabel: UILabel = {
        let label = UILabel()
        label.text = "点击浅色区域中的单词，检查文字与点击位置是否对应。点击空白或省略号不应增加命中次数。"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private lazy var latestResult: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        label.numberOfLines = 0
        label.text = "最近命中：暂无"
        label.accessibilityIdentifier = "latestHitResult"
        return label
    }()

    private lazy var resetButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("清空所有命中记录", for: .normal)
        button.addAction(UIAction { [weak self] _ in
            self?.latestResult.text = "最近命中：暂无"
            self?.caseViews.forEach { $0.resetResult() }
        }, for: .touchUpInside)
        return button
    }()

    private lazy var headerStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [headingLabel, instructionsLabel, latestResult, resetButton])
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }()

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.delaysContentTouches = false
        return scrollView
    }()

    private lazy var casesStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = .init(top: 8, leading: 0, bottom: 24, trailing: 0)
        return stack
    }()

    private var caseViews: [TextHitTestCaseView] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        configurePage()
        configureCases()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--verify-text-layout") {
            verifyTextLayout()
        }
        #endif
    }

    #if DEBUG
    /// 通过启动参数运行真实 TextHitLabel 的排版回归检查。
    private func verifyTextLayout() {
        let sentence = "Alpha Bravo Charlie Delta Echo Foxtrot Golf Hotel India Juliet Kilo Lima Mike November Oscar Papa Quebec Romeo Sierra Tango Uniform Victor Whiskey Xray Yankee Zulu"
        var failures: [String] = []
        var results: [String] = []

        func check(_ name: String, label: TextHitLabel, expectedLines: Int) {
            label.setNeedsLayout()
            label.layoutIfNeeded()
            guard let textView = label.subviews.compactMap({ $0 as? UITextView }).first else {
                failures.append(name + "：缺少调试 TextView")
                return
            }
            let manager = textView.layoutManager
            manager.ensureLayout(for: textView.textContainer)
            var lines = 0
            manager.enumerateLineFragments(forGlyphRange: manager.glyphRange(for: textView.textContainer)) { _, _, _, _, _ in
                lines += 1
            }
            let passed = lines == expectedLines
            results.append("\(passed ? "PASS" : "FAIL") \(name)：实际 \(lines) 行，预期 \(expectedLines) 行")
            if !passed { failures.append(name) }
        }

        let label = TextHitLabel(frame: CGRect(x: 0, y: 0, width: 180, height: 400))
        label.font = .systemFont(ofSize: 20)
        label.text = sentence
        label.lineBreakMode = .byTruncatingTail
        label.numberOfLines = 2
        check("纯文本两行尾部截断", label: label, expectedLines: 2)
        label.numberOfLines = 1
        check("动态切为一行", label: label, expectedLines: 1)
        label.numberOfLines = 2
        check("动态恢复两行", label: label, expectedLines: 2)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        label.attributedText = NSAttributedString(string: sentence, attributes: [
            .font: UIFont.systemFont(ofSize: 20), .paragraphStyle: paragraph
        ])
        check("富文本两行尾部截断", label: label, expectedLines: 2)

        for (name, mode) in [("头部", NSLineBreakMode.byTruncatingHead), ("中间", .byTruncatingMiddle)] {
            label.lineBreakMode = mode
            check("富文本两行\(name)截断", label: label, expectedLines: 2)
        }
        FileHandle.standardOutput.write(Data((results.joined(separator: "\n") + "\n").utf8))
        exit(failures.isEmpty ? 0 : 1)
    }
    #endif

    private func configurePage() {
        view.backgroundColor = .systemBackground
        view.addSubview(headerStack)
        view.addSubview(scrollView)
        scrollView.addSubview(casesStack)

        headerStack.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(12)
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide).inset(16)
        }
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(headerStack.snp.bottom).offset(8)
            make.leading.trailing.equalTo(headerStack)
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }
        casesStack.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }
    }

    private func configureCases() {
        for (name, alignment) in [("左对齐", NSTextAlignment.left), ("居中对齐", .center), ("右对齐", .right)] {
            addCase(name, note: "文字垂直居中；分别点击 Alpha、Bravo、Charlie 和四周空白。", height: 100) {
                $0.text = "Alpha Bravo Charlie"
                $0.textAlignment = alignment
            }
        }

        let sentence = "Alpha Bravo Charlie Delta Echo Foxtrot Golf Hotel India Juliet Kilo Lima Mike November Oscar Papa Quebec Romeo Sierra Tango Uniform Victor Whiskey Xray Yankee Zulu"
        addCase("多行自动换行", note: "检查每一行的首尾单词，行间空白不应命中。", height: 220) {
            $0.text = sentence
            $0.numberOfLines = 0
            $0.lineBreakMode = .byWordWrapping
        }

        for (name, mode) in [("头部截断", NSLineBreakMode.byTruncatingHead), ("中间截断", .byTruncatingMiddle), ("尾部截断", .byTruncatingTail)] {
            addCase(name, note: "仅显示一行；点击可见单词应命中，点击省略号不应命中。") {
                $0.text = sentence
                $0.lineBreakMode = mode
            }
        }

        addCase("两行尾部截断", note: "最多显示两行；检查最后一行的单词及省略号。", height: 110) {
            $0.text = sentence
            $0.numberOfLines = 2
            $0.lineBreakMode = .byTruncatingTail
        }

        addCase("富文本混合字体", note: "检查大小字体、字距、居中段落和第二行的位置。", height: 150) { label in
            let text = NSMutableAttributedString(string: "Small LARGE spaced\nSecond line")
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineSpacing = 12
            text.addAttributes([
                .font: UIFont.systemFont(ofSize: 16),
                .paragraphStyle: paragraph
            ], range: NSRange(location: 0, length: text.length))
            text.addAttributes([
                .font: UIFont.boldSystemFont(ofSize: 30),
                .foregroundColor: UIColor.systemRed
            ], range: (text.string as NSString).range(of: "LARGE"))
            text.addAttribute(.kern, value: 4, range: (text.string as NSString).range(of: "spaced"))
            label.numberOfLines = 0
            label.attributedText = text
        }

        addCase("字母数字单词规则", note: "i18n、3D、GPT-4 应完整命中；也支持纯数字、内部撇号和连字符。", height: 140) {
            $0.manager.rule = AlphanumericWordMatchRule()
            $0.text = "i18n 3D GPT-4 H2O MP3 don't well-known 123"
            $0.numberOfLines = 0
            $0.lineBreakMode = .byWordWrapping
        }

        let ruleLabel = addCase("动态切换规则", note: "单词模式匹配单词；邮箱模式只匹配完整邮箱；自定义模式只匹配大写文本。") {
            $0.text = "HELLO hello user@example.com"
        }
        addSelector(["单词", "邮箱", "自定义"], to: ruleLabel) { label, index in
            switch index {
            case 1: label.manager.rule = EmailMatchRule()
            case 2: label.manager.rule = UppercaseMatchRule()
            default: label.manager.rule = WordMatchRule()
            }
        }

        let alignmentLabel = addCase("动态切换对齐", note: "切换后立即点击同一个单词，检查命中位置是否随文字移动。", height: 100) {
            $0.text = "Alpha Bravo"
        }
        addSelector(["左", "中", "右"], to: alignmentLabel) { label, index in
            label.textAlignment = [.left, .center, .right][index]
        }

        let resizingLabel = addCase("动态宽度与换行", note: "切换宽度后检查换行位置及命中位置。", height: 180) {
            $0.text = "Alpha Bravo Charlie Delta Echo Foxtrot Golf Hotel"
            $0.numberOfLines = 0
            $0.lineBreakMode = .byWordWrapping
        }
        // 用左右内边距改变标签宽度，保持测试内容适应设备尺寸。
        if let card = resizingLabel.superview as? UIStackView {
            addSelector(["完整宽度", "缩窄"], to: resizingLabel) { [weak card] _, index in
                card?.directionalLayoutMargins.leading = index == 0 ? 12 : 64
                card?.directionalLayoutMargins.trailing = index == 0 ? 12 : 64
            }
        }

        let enabledLabel = addCase("识别开关", note: "关闭后点击不应触发回调；重新打开后应恢复。") {
            $0.text = "Tap Alpha Bravo"
        }
        addSelector(["开启", "关闭"], to: enabledLabel) { label, index in
            label.needRecognize = index == 0
        }

        addCase("Unicode 回归检查", note: "点击 emoji 后的 hello，应返回完整单词及正确的 UTF-16 范围。") {
            $0.text = "😀 hello"
        }
    }

    @discardableResult
    private func addCase(_ title: String, note: String, height: CGFloat = 80,
                         configure: (TextHitLabel) -> Void) -> TextHitLabel {
        let card = TextHitTestCaseView(title: title, note: note, height: height)
        configure(card.label)
        card.onHit = { [weak self] details in
            self?.latestResult.text = title + "\n" + details
        }
        caseViews.append(card)
        casesStack.addArrangedSubview(card)
        return card.label
    }

    private func addSelector(_ titles: [String], to label: TextHitLabel,
                             action: @escaping (TextHitLabel, Int) -> Void) {
        (label.superview as? TextHitTestCaseView)?.configureSelector(titles, action: action)
    }
}

private final class TextHitTestCaseView: UIStackView {

    private lazy var headingLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 17)
        label.numberOfLines = 0
        return label
    }()

    private lazy var instructionsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private lazy var hitLabel: TextHitLabel = {
        let label = TextHitLabel()
        label.needRecognize = true
        label.font = .systemFont(ofSize: 20)
        label.backgroundColor = .tertiarySystemFill
        label.layer.cornerRadius = 6
        label.clipsToBounds = true
        label.detectionBlock = { [weak self] word, range in
            self?.showResult(word: word, range: range)
        }
        return label
    }()

    private lazy var resultLabel: UILabel = {
        let label = UILabel()
        label.text = "命中 0 次，等待点击"
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.numberOfLines = 0
        return label
    }()

    private lazy var selector: UISegmentedControl = {
        let selector = UISegmentedControl()
        selector.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.selectionAction?(self.hitLabel, self.selector.selectedSegmentIndex)
        }, for: .valueChanged)
        return selector
    }()

    var label: TextHitLabel { hitLabel }
    var onHit: ((String) -> Void)?
    private var hitCount = 0
    private var selectionAction: ((TextHitLabel, Int) -> Void)?

    init(title: String, note: String, height: CGFloat) {
        super.init(frame: .zero)
        axis = .vertical
        spacing = 10
        isLayoutMarginsRelativeArrangement = true
        directionalLayoutMargins = .init(top: 12, leading: 12, bottom: 12, trailing: 12)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12

        headingLabel.text = title
        instructionsLabel.text = note
        hitLabel.accessibilityIdentifier = "测试区域：" + title
        resultLabel.accessibilityIdentifier = "测试结果：" + title
        [headingLabel, instructionsLabel, hitLabel, resultLabel].forEach { addArrangedSubview($0) }
        hitLabel.snp.makeConstraints { make in
            make.height.equalTo(height)
        }
    }

    required init(coder: NSCoder) {
        fatalError("测试卡片仅支持代码初始化")
    }

    func configureSelector(_ titles: [String], action: @escaping (TextHitLabel, Int) -> Void) {
        selectionAction = action
        selector.removeAllSegments()
        for (index, title) in titles.enumerated() {
            selector.insertSegment(withTitle: title, at: index, animated: false)
        }
        selector.selectedSegmentIndex = 0
        if selector.superview == nil {
            insertArrangedSubview(selector, at: 2)
        }
    }

    func resetResult() {
        hitCount = 0
        resultLabel.text = "命中 0 次，等待点击"
        resultLabel.textColor = .label
    }

    private func showResult(word: String, range: NSRange) {
        hitCount += 1
        let source = hitLabel.attributedText?.string ?? hitLabel.text ?? ""
        let sourceLength = (source as NSString).length
        let validRange = range.location != NSNotFound && range.location >= 0 && range.length >= 0
            && range.location <= sourceLength && range.length <= sourceLength - range.location
        let matchesSource = validRange && (source as NSString).substring(with: range) == word
        let details = "\(word) | 范围 \(range.location), \(range.length) | \(matchesSource ? "范围一致" : "范围异常")"
        resultLabel.text = "命中 \(hitCount) 次\n" + details
        resultLabel.textColor = matchesSource ? .label : .systemRed
        onHit?(details)
    }
}

private struct UppercaseMatchRule: TextMatchRule {
    var pattern: String { "[A-Z]+" }
}
