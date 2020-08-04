import UIKit
import WebKit
import CoreLocation
import Starscream
import FBSDKLoginKit
import FBSDKCoreKit
import UserNotifications
import GoogleSignIn
import FacebookCore

fileprivate var aView: UIView?

class ViewController: UIViewController,
    WebSocketDelegate,
    WKUIDelegate,
    WKNavigationDelegate,
GIDSignInDelegate {
    
    //    ----------------------------------------
    //    ----------------------------------------
    var socket: WebSocket!
    var isConnected = false
    let server = WebSocketServer()
    //    ----------------------------------------
    //    ----------------------------------------
    
    var webView: WKWebView!
    
    var locationManager = CLLocationManager()
    
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    
    
    @IBOutlet weak var loadingView: UIView!
    //    ----------------------------------------
    //    ----------------------------------------
    let preferences = UserDefaults.standard
    
    let PREFERENCES = "vouz";
    let PREFERENCES_U = "username";
    let PREFERENCES_P = "password";
    let PREFERENCES_L = "language";
    let PREFERENCES_S = "socket";
    let PREFERENCES_UID = "id_usuario";
    let PREFERENCES_NU = "nombre_usuario";
    let PREFERENCES_FN = "facebook_user";
    //    ----------------------------------------
    //    ----------------------------------------
    
    private var loadingObservation: NSKeyValueObservation?
    
    let center = UNUserNotificationCenter.current()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = .black
        return spinner
    }()
    
    
    func convertToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
    

    func showNotification(message: String){
        
        let dict = convertToDictionary(text: message)
        
        let content = UNMutableNotificationContent()
        content.title = "Vouz"
        content.body = dict!["mensaje"] as Any as! String
        content.badge = 1
        
        let date = Date().addingTimeInterval(1)
        
        let dateComponents =
            Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        
        let trigger =
            UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let uuidString = UUID().uuidString
        
        let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: trigger)
        
        center.add(request) { (error) in
            
        }
    }
    
    @IBOutlet weak var webViewContainer: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        GIDSignIn.sharedInstance()?.delegate = self
        
        /*
         * Revision de permisos para desplegar notificaciones
         */
        center.requestAuthorization(options: [.alert, .sound, .badge]){ (granted, error) in}
        
        UNUserNotificationCenter.current().delegate = self
        
        /*
         * Revision de permisos de ubicacion
         */
        if CLLocationManager.locationServicesEnabled(){
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
        }
        
        /*
         * Creacion de los metodos de conexion entre el WebView WebView -> Nativo
         */
        let contentController = WKUserContentController()
        contentController.add(
            self,
            name: "geocodeAddress"
        )
        
        contentController.add(
            self,
            name: "getUserCurrentPosition"
        )
        
        contentController.add(
            self,
            name: "saveUserCredentials"
        )
        
        contentController.add(
            self,
            name: "deleteUserCredentials"
        )
        
        contentController.add(
            self,
            name: "saveWebSocketURL"
        )
        
        contentController.add(
            self,
            name: "hideLoadingDialog"
        )
        
        contentController.add(
            self,
            name: "facebookLogin"
        )
        
        contentController.add(
            self,
            name: "googleLogin"
        )
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        
        webView = WKWebView(frame: webViewContainer.bounds, configuration: config)
        self.webView.navigationDelegate = self
        
        
        /*
         * WebView listener
         */
        loadingObservation = webView.observe(\.isLoading, options: [.new, .old]) { [weak self] (_, change) in
            guard self != nil else { return }
            
            let new = change.newValue!
            let old = change.oldValue!
            
            if (new && !old) {
                self!.displayLoadingDialog()
            }
                
            else if (!new && old) {
                self!.hideLoadingDialog()
                
                if (AccessToken.isCurrentAccessTokenActive) {
                    
                    self!.getFacebookUserInfo()
                    
                } else if(GIDSignIn.sharedInstance()?.currentUser != nil){
                    
                    GIDSignIn.sharedInstance()?.presentingViewController = self
                    GIDSignIn.sharedInstance()?.signIn()
                    
                } else if(self!.checkSavedCredentials()){
                    self!.displayLoadingDialog()
                    self!.credentialsSignIn()
                }
            }
        }
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        webViewContainer.addSubview(webView)
        
        webView.leadingAnchor.constraint(equalTo: webViewContainer.leadingAnchor, constant: 0).isActive = true
        webView.trailingAnchor.constraint(equalTo: webViewContainer.trailingAnchor, constant: 0).isActive = true
        webView.topAnchor.constraint(equalTo: webViewContainer.topAnchor, constant: 0).isActive = true
        webView.bottomAnchor.constraint(equalTo: webViewContainer.bottomAnchor, constant: 0).isActive = true
        
        // 4
        DispatchQueue.main.async {
            if let url = URL(string: Constants.BASE_URL) {
                self.webView.load(URLRequest(url: url))
            }
        }
        
        checkLocationServices()
    }
    
    func getGoogleuserInfo(){
        
    }
    
    
    func getFacebookUserInfo() {
        guard let accessToken = FBSDKLoginKit.AccessToken.current else { return }
        let graphRequest = FBSDKLoginKit.GraphRequest(graphPath: "me",
                                                      parameters: ["fields": "email, name"],
                                                      tokenString: accessToken.tokenString,
                                                      version: nil,
                                                      httpMethod: .get)
        graphRequest.start { (connection, result, error) -> Void in
            if error == nil {
                print("result \(String(describing: result))")
                
                
                if let userInfo = result as? [String: Any] {
                    let email = userInfo["email"] as? String
                    
                    let facebookUserData = [
                        "email": email,
                        "token": accessToken.tokenString,
                        "type": "facebook",
                        "device": "ios"
                    ]
                    
                    let jsonData = try! JSONSerialization.data(withJSONObject: facebookUserData, options: [])
                    let decoded = String(data: jsonData, encoding: .utf8)!
                    
                    print(decoded)
                    let requestBody = "'facebookSignIn', " + "'" + decoded + "'";
                    
                    print(requestBody)
                    
                    let sendData = "javascript:callMethodFromDevice(" + requestBody + ")"
                    
                    print(sendData)
                    
                    self.webView.evaluateJavaScript(sendData, completionHandler: nil)
                }
            }
            else {
                print("error \(String(describing: error))")
            }
        }
    }
    
    func displayLoadingDialog(){
//        aView = UIView(frame: self.view.bounds)
//        aView?.backgroundColor = UIColor.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
//
//        let ai = UIActivityIndicatorView(style: .whiteLarge)
//        ai.center = aView!.center
//        ai.startAnimating()
//        aView?.addSubview(ai)
//        self.view.addSubview(aView!)
    }
    
    func hideLoadingDialog(){
//        aView?.removeFromSuperview()
//        aView = nil
        
//        loadingView?.removeFromSuperview()
        UIView.animate(withDuration: 0.2, animations: {self.loadingView?.alpha = 0.0},
        completion: {(value: Bool) in
            self.loadingView?.removeFromSuperview()
                    })
    }
    
    /*
     * Inicio de sesion con las credenciales guardadas
     */
    
    func credentialsSignIn(){
        let user:String = self.preferences.string(forKey: self.PREFERENCES_U) ?? ""
        let pass:String = self.preferences.string(forKey: self.PREFERENCES_P) ?? ""
        let lang:String = self.preferences.string(forKey: self.PREFERENCES_L) ?? ""
        
        let userDict = ["username": user, "password": pass, "language": lang]
        
        let jsonData = try! JSONSerialization.data(withJSONObject: userDict, options: [])
        let decoded = String(data: jsonData, encoding: .utf8)!
        
        print(decoded)
        let requestBody = "'vouzSignIn', " + "'" + decoded + "'";
        
        print(requestBody)
        
        let sendData = "javascript:callMethodFromDevice(" + requestBody + ")"
        
        print(sendData)
        
        webView.evaluateJavaScript(sendData, completionHandler: nil)
    }
    
    func checkSavedCredentials() -> Bool{
        let user:String = self.preferences.string(forKey: self.PREFERENCES_U) ?? ""
        let pass:String = self.preferences.string(forKey: self.PREFERENCES_P) ?? ""
        let lang:String = self.preferences.string(forKey: self.PREFERENCES_L) ?? ""
        
        return user.count > 0 && pass.count > 0 && lang.count > 0
        
    }
    
    func setUpLocationManager(){
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func checkLocationServices(){
        if CLLocationManager.locationServicesEnabled(){
            setUpLocationManager()
            checkLocationAuthorizations()
        } else {
            
        }
    }
    
    func handleError(_ error: Error?) {
        if let e = error as? WSError {
            print("websocket encountered an error: \(e.message)")
        } else if let e = error {
            print("websocket encountered an error: \(e.localizedDescription)")
        } else {
            print("websocket encountered an error")
        }
    }
    
    func checkLocationAuthorizations(){
        switch CLLocationManager.authorizationStatus() {
        case .authorizedWhenInUse:
            break
        case .denied:
            break
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted:
            break
        case .authorizedAlways:
            break
        default:
            break
        }
    }
    
    func geocodeAddress(dict: NSDictionary) {
        let geocoder = CLGeocoder()
        let street = dict["street"] as? String ?? ""
        let city = dict["city"] as? String ?? ""
        let state = dict["state"] as? String ?? ""
        let country = dict["country"] as? String ?? ""
        
        let addressString = "\(street), \(city), \(state), \(country)"
        print(addressString)
        geocoder.geocodeAddressString(addressString, completionHandler: geocodeComplete)
    }
    
    func geocodeComplete(placemarks: [CLPlacemark]?, error: Error?) {
        print("geocodeComplete")
        print(latitude)
        print(longitude)
        
    }
    
}

extension ViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        print("11111 name")
        print(message.name)
        print("11111 name")
        
        if message.name == "geocodeAddress", let dict = message.body as? NSDictionary {
            geocodeAddress(dict: dict)
        } else if(message.name == "getUserCurrentPosition"){
            
            let currentPosition = ["lat": -16.52961578, "lng": -68.09710864]
            //            let currentPosition = ["lat": latitude, "lng": longitude]
            
            print(currentPosition)
            
            let jsonData = try! JSONSerialization.data(withJSONObject: currentPosition, options: [])
            let decoded = String(data: jsonData, encoding: .utf8)!
            
            print(decoded)
            let requestBody = "'userCurrentPosition', " + "'" + decoded + "'";
            
            print(requestBody)
            
            let sendData = "javascript:callMethodFromDevice(" + requestBody + ")"
            
            print(sendData)
            
            webView.evaluateJavaScript(sendData, completionHandler: nil)
            
            
        } else if message.name == "saveUserCredentials", let dict = message.body as? NSDictionary {
            
            let username = dict["username"] as? String ?? ""
            let password = dict["password"] as? String ?? ""
            let language = dict["language"] as? String ?? "es"
            
            print("---------------------------")
            print(username)
            print(password)
            print(language)
            print("---------------------------")
            
            preferences.set(username, forKey: PREFERENCES_U)
            preferences.set(password, forKey: PREFERENCES_P)
            preferences.set(language, forKey: PREFERENCES_L)
            preferences.synchronize()
            
            
        } else if(message.name == "deleteUserCredentials"){
            
            preferences.set("", forKey: PREFERENCES_U)
            preferences.set("", forKey: PREFERENCES_P)
            preferences.set("", forKey: PREFERENCES_L)
            preferences.synchronize()
            
            
            // facebook logout()
            
            if (AccessToken.isCurrentAccessTokenActive) {
                let loginManager = LoginManager()
                loginManager.logOut()
            }
                
                // google logout()
                
            else if(GIDSignIn.sharedInstance()?.currentUser != nil){
                GIDSignIn.sharedInstance().signOut()
            }
        } else if message.name == "saveWebSocketURL", let dict = message.body as? NSDictionary {
            
            let socket = dict["socket"] as? String ?? ""
            let id_usuario = dict["id_usuario"] as? String ?? ""
            let nombre_usuario = dict["nombre_usuario"] as? String ?? ""
            
            print("saveWebSocketURL1122212121")
            print(socket)
            print(id_usuario)
            
            print("saveWebSocketURL1122212121")
            
            preferences.set(socket, forKey: PREFERENCES_S)
            preferences.set(id_usuario, forKey: PREFERENCES_UID)
            preferences.set(nombre_usuario, forKey: PREFERENCES_NU)
            preferences.synchronize()
            
            //            connectToWebSocket()
            
        } else if(message.name == "hideLoadingDialog"){
            self.hideLoadingDialog()
        
        } else if(message.name == "facebookLogin"){
            self.facebookLogin()
        } else if(message.name == "googleLogin"){
            self.googleLogin()
        }
    }
    
    func connectToWebSocket(){
        let socketUrl = preferences.string(forKey: PREFERENCES_S)
        print("123123")
        print(socketUrl!)
        print("123123")
        var request = URLRequest(url: URL(string: socketUrl!)!)
        request.timeoutInterval = 5
        socket = WebSocket(request: request)
        socket.delegate = self
        socket.connect()
    }
    
    func sendDataToSocket(){
        
        let idUsuario = self.preferences.string(forKey: self.PREFERENCES_UID)!
        let nombreUsuario = self.preferences.string(forKey: self.PREFERENCES_NU)!
        
        print("***********************")
        print(idUsuario)
        print(nombreUsuario)
        print("***********************")
        
        let uniqueId = UUID().uuidString
        
        let sendUserId = [
            "data" : ["idUsuario": Int(idUsuario)],
            "tipo": "registrarUsuarioSocket"
            ] as [String : Any]
        
        let jsonUserData = try! JSONSerialization.data(withJSONObject: sendUserId, options: [])
        let decodedUserData = String(data: jsonUserData, encoding: .utf8)!
        
        print("---decoded")
        print(decodedUserData)
        print("---decoded")
        
        let sessionData = [
            "data": [
                "evento": "user_notifications__" + idUsuario,
                "id_contenedor": uniqueId,
                "id_usuario": Int(idUsuario)!,
                "metodo": "obj.handle",
                "nombre_usuario": nombreUsuario
            ],
            "tipo": "escucharEvento"
            ] as [String : Any]
        
        let jsonSessionData = try! JSONSerialization.data(withJSONObject: sessionData, options: [])
        let decodedSessionData = String(data: jsonSessionData, encoding: .utf8)!
        
        print("---decoded")
        print(decodedSessionData)
        print("---decoded")
        
        
        self.socket.write(string: decodedUserData)
        self.socket.write(string: decodedSessionData)
        
    }
    
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected(let headers):
            print("connected \(headers)")
            
            sendDataToSocket()
        case .disconnected(let reason, let closeCode):
            print("disconnected \(reason) \(closeCode)")
        case .text(let text):
            print("received text: \(text)")
            
            
            
            showNotification(message: text)
        case .binary(let data):
            print("received data: \(data)")
        case .pong(let pongData):
            print("received pong: \(String(describing: pongData))")
        case .ping(let pingData):
            print("received ping: \(String(describing: pingData))")
        case .error(let error):
            print("error \(String(describing: error))")
        case .viabilityChanged:
            print("viabilityChanged")
        case .reconnectSuggested:
            print("reconnectSuggested")
        case .cancelled:
            print("cancelled")
        }
    }
    
    //    SOCIAL =================
    func facebookLogin(){
        print("-----facebookLogin")
        let loginManager = LoginManager()
        
        if let accessToken = AccessToken.current {
            
            //             private String name;
            //                       private String surname;
            //                       private String email;
            //                       private String token;
            //                       private String userId;
            //                       private String url_photo;
            //                       private String type;
            //                       private String device;
            //                       private String language;
            
            let facebookUserSigned = [
                "userId": accessToken.userID,
                "token": accessToken.tokenString,
                "name": self.preferences.string(forKey: self.PREFERENCES_FN) ?? "",
                "surname": self.preferences.string(forKey: self.PREFERENCES_FN) ?? "",
                "email": "",
                "url_photo": "",
                "type": "facebook",
                "device": "ios",
                "language": Locale.current.languageCode
            ]
            
            let jsonData = try! JSONSerialization.data(withJSONObject: facebookUserSigned, options: [])
            let decoded = String(data: jsonData, encoding: .utf8)!
            
            print(decoded)
            let requestBody = "'facebookSignIn', " + "'" + decoded + "'";
            
            print(requestBody)
            
            let sendData = "javascript:callMethodFromDevice(" + requestBody + ")"
            
            print(sendData)
            
            webView.evaluateJavaScript(sendData, completionHandler: nil)
            
            
            //            print(accessToken.)
            
            // Access token available -- user already logged in
            // Perform log out
            
            // 2
            //            loginManager.logOut()
            
            
        } else {
            // Access token not available -- user already logged out
            // Perform log in
            
            // 3
            loginManager.logIn(permissions: [], from: self) { [weak self] (result, error) in
                
                // 4
                // Check for error
                guard error == nil else {
                    // Error occurred
                    print(error!.localizedDescription)
                    return
                }
                
                // 5
                // Check for cancel
                guard let result = result, !result.isCancelled else {
                    print("User cancelled login")
                    return
                }
                
                // Successfully logged in
                // 6
                //                self?.updateButton(isLoggedIn: true)
                
                // 7
                Profile.loadCurrentProfile { (profile, error) in
                    print("success")
                    
                    self!.preferences.set(Profile.current?.name ?? "", forKey: self!.PREFERENCES_FN)
                    
                    print(Profile.current?.name ?? "")
                    
                    print("------------------")
                    
                    print("------------------")
                    
                }
            }
        }
    }
    
    func googleLogin(){
        GIDSignIn.sharedInstance()?.presentingViewController = self
        GIDSignIn.sharedInstance()?.signIn()
    }
    
    //    GOOGLE
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if let error = error {
            if (error as NSError).code == GIDSignInErrorCode.hasNoAuthInKeychain.rawValue {
                print("The user has not signed in before or they have since signed out.")
            } else {
                print("\(error.localizedDescription)")
            }
            return
        }
        
        let userId = user.userID
        let idToken = user.authentication.idToken
        let fullName = user.profile.name
        let givenName = user.profile.givenName
        let familyName = user.profile.familyName
        let email = user.profile.email
        
        
        let googleUserSigned = [
            "userId": userId,
            "token": idToken,
            "name": givenName,
            "surname": familyName,
            "email": email,
            "url_photo": "",
            "type": "google",
            "device": "ios",
            "language": Locale.current.languageCode
        ]
        
        
        let jsonData = try! JSONSerialization.data(withJSONObject: googleUserSigned, options: [])
        let decoded = String(data: jsonData, encoding: .utf8)!
        
        print(decoded)
        let requestBody = "'googleSignIn', " + "'" + decoded + "'";
        
        print(requestBody)
        
        let sendData = "javascript:callMethodFromDevice(" + requestBody + ")"
        
        print(sendData)
        
        webView.evaluateJavaScript(sendData, completionHandler: nil)
    }
}

extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]){
        guard let coordinate = locations.last?.coordinate else { return }
        
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
    }
}

extension ViewController: UNUserNotificationCenterDelegate {
    
    //for displaying notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        //If you don't want to show notification when app is open, do something here else and make a return here.
        //Even you you don't implement this delegate method, you will not see the notification on the specified controller. So, you have to implement this delegate and make sure the below line execute. i.e. completionHandler.
        
        completionHandler([.alert, .badge, .sound])
    }
    
    // For handling tap and user actions
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        switch response.actionIdentifier {
        case "action1":
            print("Action First Tapped")
        case "action2":
            print("Action Second Tapped")
        default:
            break
        }
        completionHandler()
    }
    
}
