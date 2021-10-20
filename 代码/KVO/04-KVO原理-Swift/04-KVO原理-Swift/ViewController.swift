//
//  ViewController.swift
//  04-KVO原理-Swift
//
//  Created by TT-Fangss on 2021/10/12.
//

import UIKit

@objcMembers class Person: NSObject {
    @objc dynamic var age: NSInteger = 0
    
    func printObjectInfo() {
        print("-----")
        print("对象：\(self)")
        
        let cls_object: AnyClass = object_getClass(self)!  // 类对象
        let super_cls_object: AnyClass = class_getSuperclass(cls_object)!  // 类对象的父类对象（person->superclass_isa）
        let meta_cls_object: AnyClass = object_getClass(cls_object)!  // 元类对象（person->isa->isa）
        print("class 对象: \(cls_object)");
        print("class 对象的 superclass 对象: \(super_cls_object)");
        print("metaclass 对象: \(meta_cls_object)");

        let age_sel = #selector(setter: self.age)
        let age_imp = method(for: age_sel)
        print("setAge: \(String(describing: age_imp))")
        
        printMethodNamesOfClass(cls: cls_object)
    }
}

func printMethodNamesOfClass(cls: AnyClass) {
    var count: UInt32 = 0
    var methodNames = [String]()
    if let methodList = class_copyMethodList(cls, &count) {
        for i in 0..<count {
            let method = methodList[Int(i)]
            let sel = method_getName(method)
            let methodName = NSStringFromSelector(sel)
            methodNames.append(methodName)
        }
        
        free(methodList)
        
        print("对象方法列表: \(methodNames)")
    }
    
}

class ViewController: UIViewController {
    @IBOutlet weak var nameLabel: UILabel!
    @objc var person = Person()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
    }
    
    deinit {
        self.unregisterAsObserver()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        print("keyPath: \(keyPath ?? ""), object: \(object ?? ""), change: \(String(describing: change))")
    }
    
    @IBAction func changedClick() {
        person.age = 10
        nameLabel.text = "\(person.age)"
    }
    
    @IBAction func registerAsObserver() {
        print("添加 Observer 之前")
        person.printObjectInfo()
        
        person.addObserver(self, forKeyPath: "age", options: [.new, .old], context: nil)
        
        print("添加 Observer 之后")
        person.printObjectInfo()
        person.age = 10
        print("结束")
    }
    
    @IBAction func unregisterAsObserver() {
        person.removeObserver(self, forKeyPath: "age")
        person.printObjectInfo()
        
//        let name: String = "_4_KVO原理_Swift.Person"
//        let cls: AnyClass = objc_getClass(name.cString(using: .utf8)!)! as! AnyClass
//        printMethodNamesOfClass(cls: cls)
        
        print("--")
    }
    
}

