//
//  ViewController.swift
//  Reactive-RxSwift-Sample
//
//  Created by Miel on 2/25/2560 BE.
//  Copyright © 2560 Lumos. All rights reserved.
//
//  This project is followed by the tutorial "The introduction to Reactive Programming you've been missing" made by "Andre Staltz" and use RxSwift instead of RxJS.
//
//  The code is written in Swift 3 & Xcode 8.1
//
//  Using document based on RxSwift version 3.0 link down below
//  >> http://cocoadocs.org/docsets/RxSwift/3.2.0
//  >> http://cocoadocs.org/docsets/RxCocoa/3.2.0
//

import UIKit
import RxSwift
import RxCocoa
import Alamofire
import SwiftyJSON
import Kingfisher

class ViewController: UIViewController {
    //MARK: - IBOutlet
    @IBOutlet private weak var btn_refresh: UIButton!
    @IBOutlet private weak var view_suggest1: UIView!
    @IBOutlet private weak var view_suggest2: UIView!
    @IBOutlet private weak var view_suggest3: UIView!
    
    @IBOutlet private weak var imgv_suggest1: UIImageView!
    @IBOutlet private weak var lbl_suggest1_name: UILabel!
    @IBOutlet private weak var lbl_suggest1_link: UILabel!
    @IBOutlet private weak var btn_suggest1_close: UIButton!
    
    @IBOutlet private weak var imgv_suggest2: UIImageView!
    @IBOutlet private weak var lbl_suggest2_name: UILabel!
    @IBOutlet private weak var lbl_suggest2_link: UILabel!
    @IBOutlet private weak var btn_suggest2_close: UIButton!
    
    @IBOutlet private weak var imgv_suggest3: UIImageView!
    @IBOutlet private weak var lbl_suggest3_name: UILabel!
    @IBOutlet private weak var lbl_suggest3_link: UILabel!
    @IBOutlet private weak var btn_suggest3_close: UIButton!
    
    //MARK: - Properties
    
    //MARK: - View Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        setUpStream()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: - Setup Stream
    private func setUpStream() {
        let refreshClickStream = btn_refresh.rx.controlEvent(.touchUpInside).asObservable()
        let randomUserFunction = { () -> String in
            let randomOffset = Int(arc4random_uniform(500))
            print("randomOffset \(randomOffset)")
            return "https://api.github.com/users?since=\(randomOffset)"
        }
        
        // ControlEvent cannot simulate startup click. "it won’t send any initial value on subscription" from RxCocoa document
        /*
         let requestStream = refreshClickStream.startWith()
         .map { () -> String in
         let randomOffset = Int(arc4random_uniform(500))
         print("randomOffset \(randomOffset)")
         return "https://api.github.com/users?since=\(randomOffset)"
         }
         */
        
        // ControlEvent first hack, using merge() and just() to simulate startup fetching
        let requestStream = Observable
            .of(refreshClickStream.map(randomUserFunction)
                , Observable.just(randomUserFunction()))
            .merge()
        
        let responseStream = requestStream.flatMap({[unowned self] (requestUrl) -> Observable<optionalJsonArray> in
            print(requestUrl)
            return self.getGitHubUser(requestUrl: requestUrl)
        })
        
        /*
         let responseSubscription = responseStream.subscribe(onNext: { (res1) in
         print("res1 = \(res1)")
         }, onError: { (error) in
         print("onError")
         }, onCompleted: {
         print("onCompleted")
         }, onDisposed: {
         print("onDisposed")
         })
         */
        
        /*
         let suggestion1ResponseStream = responseStream.map{(jsonArray) -> JSON? in
         if let listUser = jsonArray, listUser.count > 0 {
         return listUser[Int(arc4random_uniform(UInt32(listUser.count)))]
         }
         return nil
         }
         */
        
        // Create similar style of stream as tutorial
//        setBasicSuggestionStream(responseStream: responseStream, refreshClickStream: refreshClickStream)
        // Create enhance style of stream from tutorial
        setEnhanceSuggestionStream(responseStream: responseStream, refreshClickStream: refreshClickStream)
    }
    
    /**
     Create similar style of stream as tutorial
     
     - Parameters:
       - responseStream: response observable of data from service
       - refreshClickStream: refresh click observable
     */
    private func setBasicSuggestionStream(responseStream:Observable<optionalJsonArray>, refreshClickStream: Observable<()>) {
        let refreshClickClearSuggestionStream = refreshClickStream.map { () -> JSON? in
            return nil
        }
        
        //let close1ClickStream = btn_suggest1_close.rx.controlEvent(.touchUpInside).asObservable()
        // ControlEvent second hack, using merge() to simulate initial empty click stream
        let close1ClickStream = Observable
            .of(btn_suggest1_close.rx.controlEvent(.touchUpInside).asObservable()
                , Observable.just()
            ).merge()
        
        let suggestion1Stream = Observable
            .of(Observable.combineLatest(close1ClickStream.map{()->JSON? in return nil} // startWith() emit close1 stream for hack with combineLastest, simulating a click to the 'close 1' button on startup
                , responseStream, resultSelector: { (_, userJsonArray) -> JSON? in
                    // return one of the lastest set of data from response stream
                    if let listUser = userJsonArray, listUser.count > 0 {
                        return listUser[Int(arc4random_uniform(UInt32(listUser.count)))]
                    }
                    return nil
            })
                ,refreshClickClearSuggestionStream
            )
            .merge()
            .startWith(nil)
        
        _ = suggestion1Stream.subscribe(onNext: {[weak self] (suggestJson) in
            if let suggest = suggestJson {
                // show the first suggestion View element
                print("show the 1st suggestion View element")
                self?.view_suggest1.alpha = 1
                let id = suggest[GitHubJsonKey.id].stringValue
                let name = suggest[GitHubJsonKey.name].stringValue
                self?.lbl_suggest1_name.text = "\(id) \(name)"
                self?.lbl_suggest1_link.text = suggest[GitHubJsonKey.userUrl].string
                let url = URL(string: suggest[GitHubJsonKey.avatarUrl].stringValue)
                self?.imgv_suggest1.kf.setImage(with: url)
            }else {
                // hide the first suggestion View element
                print("hide the 1st suggestion View element")
                self?.view_suggest1.alpha = 0
            }}
            , onError: { (error) in
                print("onError")}
            , onCompleted: {
                print("onCompleted")}
            , onDisposed: {
                print("onDisposed")}
        )
        
        // suggestion 2
        let close2ClickStream = Observable
            .of(btn_suggest2_close.rx.controlEvent(.touchUpInside).asObservable()
                , Observable.just()
            ).merge()
        
        let suggestion2Stream = Observable
            .of(Observable.combineLatest(close2ClickStream.map{()->JSON? in return nil}
                , responseStream, resultSelector: { (_, userJsonArray) -> JSON? in
                    if let listUser = userJsonArray, listUser.count > 0 {
                        return listUser[Int(arc4random_uniform(UInt32(listUser.count)))]
                    }
                    return nil
            })
                ,refreshClickClearSuggestionStream
            )
            .merge()
            .startWith(nil)
        
        _ = suggestion2Stream.subscribe(onNext: {[weak self] (suggestJson) in
            if let suggest = suggestJson {
                // show the second suggestion View element
                print("show the 2nd suggestion View element")
                self?.view_suggest2.alpha = 1
                let id = suggest[GitHubJsonKey.id].stringValue
                let name = suggest[GitHubJsonKey.name].stringValue
                self?.lbl_suggest2_name.text = "\(id) \(name)"
                self?.lbl_suggest2_link.text = suggest[GitHubJsonKey.userUrl].string
                let url = URL(string: suggest[GitHubJsonKey.avatarUrl].stringValue)
                self?.imgv_suggest2.kf.setImage(with: url)
            }else {
                // hide the second suggestion View element
                print("hide the 2nd suggestion View element")
                self?.view_suggest2.alpha = 0
            }}
        )
        
        // suggestion 3
        let close3ClickStream = Observable
            .of(btn_suggest3_close.rx.controlEvent(.touchUpInside).asObservable()
                , Observable.just()
            ).merge()
        
        let suggestion3Stream = Observable
            .of(Observable.combineLatest(close3ClickStream.map{()->JSON? in return nil}
                , responseStream, resultSelector: { (_, userJsonArray) -> JSON? in
                    if let listUser = userJsonArray, listUser.count > 0 {
                        return listUser[Int(arc4random_uniform(UInt32(listUser.count)))]
                    }
                    return nil
            })
                ,refreshClickClearSuggestionStream
            )
            .merge()
            .startWith(nil)
        
        _ = suggestion3Stream.subscribe(onNext: {[weak self] (suggestJson) in
            if let suggest = suggestJson {
                // show the third suggestion View element
                print("show the 3rd suggestion View element")
                self?.view_suggest3.alpha = 1
                let id = suggest[GitHubJsonKey.id].stringValue
                let name = suggest[GitHubJsonKey.name].stringValue
                self?.lbl_suggest3_name.text = "\(id) \(name)"
                self?.lbl_suggest3_link.text = suggest[GitHubJsonKey.userUrl].string
                let url = URL(string: suggest[GitHubJsonKey.avatarUrl].stringValue)
                self?.imgv_suggest3.kf.setImage(with: url)
            }else {
                // hide the third suggestion View element
                print("hide the 3rd suggestion View element")
                self?.view_suggest3.alpha = 0
            }}
        )
    }
    
    /**
     Create enhance style of stream from tutorial
     
     - Parameters:
       - responseStream: response observable of data from service
       - refreshClickStream: refresh click observable
     */
    private func setEnhanceSuggestionStream(responseStream: Observable<optionalJsonArray>, refreshClickStream: Observable<()>) {
        let responseShareStream = responseStream.share() // share() for multicasting response stream == publish().refCount()
    
        let close1ClickStream = createCloseSuggestionStream(btn_close: btn_suggest1_close)
        let close2ClickStream = createCloseSuggestionStream(btn_close: btn_suggest2_close)
        let close3ClickStream = createCloseSuggestionStream(btn_close: btn_suggest3_close)
        
        let suggestion1Stream = createSuggestionStream(closeClickStream: close1ClickStream, responseStream: responseShareStream, refreshClickStream: refreshClickStream)
        let suggestion2Stream = createSuggestionStream(closeClickStream: close2ClickStream, responseStream: responseShareStream, refreshClickStream: refreshClickStream)
        let suggestion3Stream = createSuggestionStream(closeClickStream: close3ClickStream, responseStream: responseShareStream, refreshClickStream: refreshClickStream)
        
        _ = suggestion1Stream.subscribe(onNext: {[unowned self] (suggestJson) in
            self.renderSuggestionItem(suggestJson: suggestJson, view_container: self.view_suggest1, lbl_name: self.lbl_suggest1_name, lbl_link: self.lbl_suggest1_link, imgv_avatar: self.imgv_suggest1)
        })
        
        _ = suggestion2Stream.subscribe(onNext: {[unowned self] (suggestJson) in
            self.renderSuggestionItem(suggestJson: suggestJson, view_container: self.view_suggest2, lbl_name: self.lbl_suggest2_name, lbl_link: self.lbl_suggest2_link, imgv_avatar: self.imgv_suggest2)
        })
        
        _ = suggestion3Stream.subscribe(onNext: {[unowned self] (suggestJson) in
            self.renderSuggestionItem(suggestJson: suggestJson, view_container: self.view_suggest3, lbl_name: self.lbl_suggest3_name, lbl_link: self.lbl_suggest3_link, imgv_avatar: self.imgv_suggest3)
        })
    }
    
    private func createCloseSuggestionStream(btn_close: UIButton) -> Observable<Void> {
        return Observable
            .of(btn_close.rx.controlEvent(.touchUpInside).asObservable()
                , Observable.just()
            ).merge()
    }
    
    private func createSuggestionStream(closeClickStream: Observable<Void>, responseStream: Observable<optionalJsonArray>, refreshClickStream: Observable<()>) -> Observable<JSON?> {
        return Observable
            .of(Observable.combineLatest(closeClickStream.map{()->JSON? in return nil}
                , responseStream, resultSelector: { (_, userJsonArray) -> JSON? in
                    if let listUser = userJsonArray, listUser.count > 0 {
                        return listUser[Int(arc4random_uniform(UInt32(listUser.count)))]
                    }
                    return nil
            })
                ,refreshClickStream.map { () -> JSON? in
                    return nil
                }
            )
            .merge()
            .startWith(nil)
    }
    
    private func renderSuggestionItem(suggestJson: JSON?, view_container: UIView, lbl_name: UILabel, lbl_link: UILabel, imgv_avatar: UIImageView) {
        if let suggest = suggestJson {
            // show the third suggestion View element
            print("show the 3rd suggestion View element")
            view_container.alpha = 1
            let id = suggest[GitHubJsonKey.id].stringValue
            let name = suggest[GitHubJsonKey.name].stringValue
            lbl_name.text = "\(id) \(name)"
            lbl_link.text = suggest[GitHubJsonKey.userUrl].string
            let url = URL(string: suggest[GitHubJsonKey.avatarUrl].stringValue)
            imgv_avatar.kf.setImage(with: url)
        }else {
            // hide the third suggestion View element
            print("hide the 3rd suggestion View element")
            view_container.alpha = 0
        }
    }

    //MARK: - Methods
    private func getGitHubUser(requestUrl: String) -> Observable<optionalJsonArray> {
        return Observable.create({ (observer) -> Disposable in
            weak var request: DataRequest? = Alamofire.request(requestUrl, method: .get, parameters: nil, encoding: JSONEncoding.default)
                .responseJSON { (response) in
                    guard response.result.isSuccess else {
                        // got an error in getting the data, need to handle it
                        print(response.result.error!)
                        observer.on(.error(response.result.error!))
                        return
                    }
                    
                    guard let value = response.result.value else {
                        print("error no data received from service")
                        observer.on(.error(ServiceError.noData))
                        return
                    }
                    
                    //                    print(value)
                    let jsonData = JSON(value).array
                    
                    observer.on(.next(jsonData))
                    observer.on(.completed)
            }
            
            return Disposables.create{
                print("request observer has been dispose. request = \(request)")
                // cancel the request
                request?.cancel()
            }
        })
    }
    
    //MARK: - Utils
    typealias optionalJsonArray = [JSON]?
    
    enum ServiceError: Error {
        case noData
        case jsonType
    }
    
    struct GitHubJsonKey {
        static let id = "id"
        static let name = "login"
        static let userUrl = "url"
        static let avatarUrl = "avatar_url"
    }
}

