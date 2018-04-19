//
//  AZDropdownMenu.swift
//  AZDropdownMenu
//
//  Created by Chris Wu on 01/05/2016.
//  Copyright (c) 2016 Chris Wu. All rights reserved.
//

import UIKit

@objc
public protocol AZDropdownMenuDelegate {
    
    @objc func azDropdownMenu(_ menu: AZDropdownMenu, didSelectItemAt indexPath: IndexPath)
    
    @objc optional func azDropdownMenuWillAppear(_ menu: AZDropdownMenu, animated: Bool)
    
    @objc optional func azDropdownMenuDidAppear(_ menu: AZDropdownMenu, animated: Bool)
    
    @objc optional func azDropdownMenuWillDisappear(_ menu: AZDropdownMenu, animated: Bool)
    
    @objc optional func azDropdownMenuDidDisappear(_ menu: AZDropdownMenu, animated: Bool)
    
    @objc optional func azDropdownMenu(_ menu: AZDropdownMenu, shouldDismissOnSelectAt indexPath: IndexPath) -> Bool
}

@objc
open class AZDropdownMenu: UIView {
    
    fileprivate let DROPDOWN_MENU_CELL_KEY : String = "MenuItemCell"
    
    /// The dark overlay behind the menu
    fileprivate let overlay:UIView = UIView()
    fileprivate var menuView: UITableView!
    
    /// Array of titles for the menu
    fileprivate var titles = [String]()
    
    /// Property to figure out if initial layout has been configured
    fileprivate var isSetUpFinished : Bool
    
    /// The handler used when menu item is tapped
    open var cellTapHandler : ((_ indexPath:IndexPath) -> Void)?
    
    open var delegate: AZDropdownMenuDelegate?
    
    open var animateDuration: TimeInterval = 0.3
    
    // MARK: - Configuration options
    
    /// Row height of the menu item
    open var itemHeight : Int = 44 {
        didSet {
            menuView.beginUpdates()
            menuView.rowHeight = menuHeight
            menuView.endUpdates()
        }
    }
    
    /// The color of the menu item
    open var itemColor : UIColor = UIColor.white {
        didSet {
            self.menuConfig?.itemColor = itemColor
        }
    }
    
    /// The background color of the menu item while being tapped
    open var itemSelectionColor : UIColor = UIColor.lightGray {
        didSet {
            self.menuConfig?.itemSelectionColor = itemSelectionColor
        }
    }
    
    /// The font of the item
    open var itemFontName : String = "Helvetica" {
        didSet {
            self.menuConfig?.itemFont = itemFontName
        }
    }
    
    /// The text color of the menu item
    open var itemFontColor : UIColor = UIColor(red: 140/255, green: 134/255, blue: 125/255, alpha: 1.0) {
        didSet {
            self.menuConfig?.itemFontColor = itemFontColor
        }
    }
    
    /// Font size of the menu item
    open var itemFontSize : CGFloat = 14.0 {
        didSet {
            self.menuConfig?.itemFontSize = itemFontSize
        }
    }
    
    /// The alpha for the background overlay
    open var overlayAlpha : CGFloat = 0.5 {
        didSet {
            self.menuConfig?.overlayAlpha = self.overlayAlpha
        }
    }
    
    /// Color for the background overlay
    open var overlayColor : UIColor = UIColor.black {
        didSet {
            self.overlay.backgroundColor = self.overlayColor
            self.menuConfig?.overlayColor = self.overlayColor
        }
    }
    
    open var menuSeparatorStyle:AZDropdownMenuSeperatorStyle = .singleline {
        didSet {
            switch menuSeparatorStyle {
            case .none:
                self.menuView.separatorStyle = .none
                self.menuConfig?.menuSeparatorStyle = .none
            case .singleline:
                self.menuView.separatorStyle = .singleLine
                self.menuConfig?.menuSeparatorStyle = .singleline
            }
        }
    }
    
    open var menuSeparatorColor:UIColor = UIColor.lightGray {
        didSet {
            self.menuConfig?.menuSeparatorColor = self.menuSeparatorColor
            self.menuView.separatorColor = self.menuSeparatorColor
        }
    }
    
    /// The text alignment of the menu item
    open var itemAlignment : AZDropdownMenuItemAlignment = .left {
        didSet {
            switch itemAlignment {
            case .right:
                self.menuConfig?.itemAlignment = .right
            case .left:
                self.menuConfig?.itemAlignment = .left
            case .center:
                self.menuConfig?.itemAlignment = .center
            }
        }
    }
    
    /// The image position, default to .Prefix.  Image will be displayed after item's text if set to .Postfix
    open var itemImagePosition : AZDropdownMenuItemImagePosition = .prefix {
        didSet {
            switch itemImagePosition {
            case .prefix:
                self.menuConfig?.itemImagePosition = .prefix
            case .postfix:
                self.menuConfig?.itemImagePosition = .postfix
            }
        }
    }
    
    open var shouldDismissMenuOnDrag : Bool = false
    
    open var isVisible: Bool {
        guard let superview = superview else { return false }
        return isDescendant(of: superview)
    }
    
    fileprivate var calcMenuHeight : CGFloat {
        get {
            return CGFloat(itemHeight * itemDataSource.count)
        }
    }
    
    fileprivate var menuHeight : CGFloat {
        get {
            return (calcMenuHeight > frame.size.height) ? frame.size.height : calcMenuHeight
        }
    }
    
    fileprivate var initialMenuCenter : CGPoint = CGPoint(x: 0, y: 0)
    fileprivate var itemDataSource : [AZDropdownMenuItemData] = []
    fileprivate var reuseId : String?
    fileprivate var menuConfig : AZDropdownMenuConfig?
    
    // MARK: - Initializer
    public init(titles:[String]) {
        self.isSetUpFinished = false
        self.titles = titles
        for title in titles {
            itemDataSource.append(AZDropdownMenuItemData(title: title))
        }
        self.menuConfig = AZDropdownMenuConfig()
        super.init(frame:UIScreen.main.bounds)
        self.accessibilityIdentifier = "AZDropdownMenu"
        self.backgroundColor = UIColor.clear
        self.alpha = 0.95
        self.translatesAutoresizingMaskIntoConstraints = false
        initOverlay()
        initMenu()
    }
    
    public init(dataSource:[AZDropdownMenuItemData]) {
        self.isSetUpFinished = false
        self.itemDataSource = dataSource
        self.menuConfig = AZDropdownMenuConfig()
        super.init(frame:UIScreen.main.bounds)
        self.accessibilityIdentifier = "AZDropdownMenu"
        self.backgroundColor = UIColor.clear
        self.alpha = 0.95
        self.translatesAutoresizingMaskIntoConstraints = false
        initOverlay()
        initMenu()
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View lifecycle
    
    open override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        guard let superview = superview else { return }
        
        updateConstraints(superview: superview)
    }
    
    func updateConstraints(superview: UIView) {
        
        translatesAutoresizingMaskIntoConstraints = false
        
        ["H:|-0-[subview]-0-|", "V:|-0-[subview]-0-|"].forEach { visualFormat in
            superview.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: visualFormat, options: .directionLeadingToTrailing, metrics: nil, views: ["subview": self]))
        }
        
        layoutIfNeeded()
    }
    
    var panGesture: UIPanGestureRecognizer {
        let panGesture  = UIPanGestureRecognizer(target: self, action: #selector(AZDropdownMenu.handlePan(gestureRecognizer:)))
        panGesture.delegate = self
        return panGesture
    }
    
    var touchGesture: UITapGestureRecognizer {
        return UITapGestureRecognizer(target: self, action: #selector(AZDropdownMenu.overlayTapped))
    }
    
    fileprivate func initOverlay() {
        overlay.backgroundColor = self.overlayColor
        overlay.accessibilityIdentifier = "OVERLAY"
        overlay.alpha = 0
        overlay.isUserInteractionEnabled = true
        
        overlay.addGestureRecognizer(touchGesture)
        overlay.addGestureRecognizer(panGesture)
        
        addSubview(overlay)
        
        overlay.translatesAutoresizingMaskIntoConstraints = false
        ["H:|-0-[subview]-0-|", "V:|-0-[subview]-0-|"].forEach { visualFormat in
            addConstraints(NSLayoutConstraint.constraints(withVisualFormat: visualFormat, options: .directionLeadingToTrailing, metrics: nil, views: ["subview": overlay]))
        }
    }
    
    
    fileprivate func initMenu() {
        
        menuView = UITableView(frame: .zero, style: .plain)
        menuView.isUserInteractionEnabled = true
        menuView.rowHeight = CGFloat(itemHeight)
        if self.reuseId == nil {
            self.reuseId = DROPDOWN_MENU_CELL_KEY
        }
        menuView.dataSource = self
        menuView.delegate = self
        menuView.isScrollEnabled = false
        menuView.accessibilityIdentifier = "MENU"
        menuView.separatorColor = menuConfig?.menuSeparatorColor
        
        
        let view = UIView()
        view.backgroundColor = .clear
        view.addGestureRecognizer(touchGesture)
        view.addGestureRecognizer(panGesture)
        
        menuView.tableFooterView = view
        menuView.backgroundColor = .clear
        
        menuView.addGestureRecognizer(panGesture)
        
        menuView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(menuView)
        
        ["H:|-0-[subview]-0-|", "V:|-0-[subview]-0-|"].forEach { visualFormat in
            addConstraints(NSLayoutConstraint.constraints(withVisualFormat: visualFormat, options: .directionLeadingToTrailing, metrics: nil, views: ["subview": menuView]))
        }
        menuView.layoutIfNeeded()
    }
    
    fileprivate func setupInitialLayout() {
        
        let height = NSLayoutConstraint(item: self, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: UIScreen.main.bounds.height)
        let width = NSLayoutConstraint(item: self, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: UIScreen.main.bounds.width)
        
        addConstraints([height, width])
        isSetUpFinished = true
        
    }
    
    fileprivate func animateOvelay(_ alphaValue: CGFloat, interval: Double, completionHandler: (() -> Void)? ) {
        UIView.animate(
            withDuration: interval,
            animations: {
                self.overlay.alpha = alphaValue
        }, completion: { (finished: Bool) -> Void in
            if let completionHandler = completionHandler {
                completionHandler()
            }
        }
        )
    }
    
    @objc func overlayTapped() {
        dismiss(animated: true)
    }
    
    //MARK: - Public methods to control the menu
    
    /**
     Show menu
     
     - parameter view: The view to be attached by the menu, ex. the controller's view
     */
    
    @available(*, deprecated: 1.1.4, renamed: "show(in:animated:)", message: "This function might be removed in later versions")
    open func showMenuFromView(_ view: UIView, animated: Bool = true) {
        
        show(in: view, animated: animated)
    }
    
    open func show(in controller: UIViewController, animated: Bool = true) {
        show(in: controller.view, animated: animated)
    }
    
    open func show(in view: UIView, animated: Bool = true) {
        
        delegate?.azDropdownMenuWillAppear?(self, animated: animated)
        
        view.addSubview(self)
        menuView.layoutIfNeeded()
        
        animateOvelay(overlayAlpha, interval: 0.4, completionHandler: nil)
        menuView.reloadData()
        
        UIView.animate(
            withDuration: animated ? animateDuration : 0,
            delay:0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0.6,
            options:[],
            animations: { self.frame.origin.y = view.frame.origin.y
        }, completion: { self.showCompletion($0, animated: animated) })
    }
    
    @available(*, deprecated: 1.1.4, renamed: "show(in:animated:)", message: "This function might be removed in later versions")
    open func showMenuFromRect(_ rect:CGRect, animated: Bool = true) {
        show(in: rect, animated: animated)
    }
    
    open func show(in rect: CGRect, animated: Bool = true) {
        
        delegate?.azDropdownMenuWillAppear?(self, animated: animated)
        
        let window = UIApplication.shared.keyWindow!
        
        window.addSubview(self)
        
        animateOvelay(overlayAlpha, interval: 0.4, completionHandler: nil)
        menuView.reloadData()
        UIView.animate(
            withDuration: 0.2,
            delay:0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0.6,
            options:[],
            animations: {
                self.frame.origin.y = rect.origin.y
        }, completion: { self.showCompletion($0, animated: animated) })
    }
    
    func showCompletion(_ finished: Bool = true, animated: Bool) {
        
        guard finished else { return }
        
        self.initialMenuCenter = self.menuView.center
        
        self.delegate?.azDropdownMenuDidAppear?(self, animated: animated)
    }
    
    @available(*, deprecated: 1.1.4, renamed: "dismiss(animated:)", message: "This function might be removed in later versions")
    open func hideMenu(_ animated: Bool = true) {
        
        dismiss(animated: animated)
    }
    
    open func dismiss(animated: Bool = true) {
        
        delegate?.azDropdownMenuWillDisappear?(self, animated: animated)
        
        animateOvelay(0.0, interval: 0.1, completionHandler: nil)
        
        UIView.animate(
            withDuration: 0.3, delay: 0.1,
            options: [],
            animations: { self.frame.origin.y = -UIScreen.main.bounds.height },
            completion: { self.hideCompletion($0, animated: animated) })
    }
    
    func hideCompletion(_ finished: Bool = true, animated: Bool) {
        
        guard finished else { return }
        
        menuView.center = initialMenuCenter
        
        removeFromSuperview()
        
        delegate?.azDropdownMenuDidDisappear?(self, animated: animated)
    }
}


// MARK: - UITableViewDataSource
extension AZDropdownMenu: UITableViewDataSource {
    @available(iOS 2.0, *)
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = getCellByData() {
            let item = itemDataSource[indexPath.row]
            if let config = self.menuConfig {
                cell.configureStyle(config)
            }
            cell.frame.size.width = tableView.frame.width
            cell.configureData(item)
            cell.layoutIfNeeded()
            return cell
        }
        return UITableViewCell()
    }
    
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return itemDataSource.count
    }
    
    func getCellByData() -> AZDropdownMenuBaseCell? {
        if let _ = itemDataSource.first?.icon {
            return AZDropdownMenuDefaultCell(reuseIdentifier: DROPDOWN_MENU_CELL_KEY, config: self.menuConfig!)
        } else {
            return AZDropdownMenuBaseCell(style: .default, reuseIdentifier: DROPDOWN_MENU_CELL_KEY)
        }
    }
}


// MARK: - UITableViewDelegate
extension AZDropdownMenu: UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath as IndexPath, animated:true)
        cellTapHandler?(indexPath as IndexPath)
        
        delegate?.azDropdownMenu(self, didSelectItemAt: indexPath)
        
        if let cell = tableView.cellForRow(at: indexPath as IndexPath) {
            cell.backgroundColor = itemSelectionColor
        }
        
        let shouldHide = delegate?.azDropdownMenu?(self, shouldDismissOnSelectAt: indexPath) ?? true
        
        shouldHide ? dismiss(animated: true) : ()
    }
    
    public func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath as IndexPath) {
            cell.backgroundColor = itemColor
        }
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return CGFloat(itemHeight)
    }
    
}

// MARK: - UIGestureRecognizerDelegate
extension AZDropdownMenu: UIGestureRecognizerDelegate {
    
    @objc public func handlePan(gestureRecognizer: UIPanGestureRecognizer) {
        guard self.shouldDismissMenuOnDrag == true else {
            return
        }
        
        if gestureRecognizer.isKind(of: UIPanGestureRecognizer.self) {
            if let touchedView = gestureRecognizer.view, touchedView == self.menuView {
                let translationView = gestureRecognizer.translation(in: self)
                switch gestureRecognizer.state {
                case .changed:
                    let center = touchedView.center
                    let targetPoint = center.y + translationView.y
                    let newLocation = targetPoint < initialMenuCenter.y ? targetPoint : initialMenuCenter.y
                    touchedView.center = CGPoint(x: center.x,y :newLocation)
                    gestureRecognizer.setTranslation(CGPoint(x: 0,y :0), in: touchedView)
                case .ended:
                    if touchedView.center.y < initialMenuCenter.y {
                        dismiss(animated: true)
                    }
                default:break
                }
            }
        }
    }
}


/**
 *  Menu's model object
 */
public struct AZDropdownMenuItemData {
    
    public let title:String
    public let icon:UIImage?
    
    public init(title:String) {
        self.title = title
        self.icon = nil
    }
    
    public init(title:String, icon:UIImage) {
        self.title = title
        self.icon = icon
    }
}
