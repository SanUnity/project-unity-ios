# PROJECT UNITY

Project Unity es un proyecto abierto con el que se pretende ayudar en la lucha contra el COVID-19. Dentro del proyecto, desde iOS se pretende dar a los usuarios finales una herramienta para iPhone, iPad y iPod. La parte nativa de la aplicación muestra en un WKWebView la webapp del front, gestionando los permisos e intercomunicación del front y la parte nativa.

### Lenguaje de desarrollo

Swift 5

### Librerías utilizadas

La app implementa las siguientes liberías

* [Firebase](https://github.com/firebase/firebase-ios-sdk)
* [AWS SDK](https://github.com/aws-amplify/aws-sdk-ios/tree/main/AWSAuthSDK/Sources/AWSMobileClient)
* [OpenTrace](https://github.com/opentrace-community/opentrace-ios)
* [DP-3T](https://github.com/DP-3T/dp3t-sdk-ios)
* [SwiftKeychainWrapper](https://github.com/jrendel/SwiftKeychainWrapper)
* [TrustKit](https://github.com/datatheorem/TrustKit)
* [ReachabilitySwift](https://github.com/ashleymills/Reachability.swift)
* [SQLite](https://github.com/stephencelis/SQLite.swift)
* [SwiftProtobuf](https://github.com/apple/swift-protobuf)
* [SwiftJWT](https://github.com/IBM-Swift/Swift-JWT)

### Permisos requeridos

La app puede requerir algunos de estos permisos

* Bluetooth
* Localización
* Cámara
* Fotos
* Contactos
* Notificaciones Push

En función de los módulos que se activen en la webapp, deberán introducirse unos y/u otros en el Info.plist de la app

### Capacidades requeridas:

La app puede necesitar las capacidades de Push Notificationes y algunos Background Modes, en función de los módulos que se activen en la webapp: Uses BT LE accesories, Acts as a BT LE acessory, Background fetch y Remote notifications

### Vistas nativas:

La app implenta estas tres vistas nativas

* Onboarding
* Webview
* Lector QR

### Configuración:

La app tiene una clase de configuración para la app: AppConfig donde configurar:

* **OrgID**: código compuesto por "<COUNTRY_CODE>_<INDENFITIER>", por ejemplo "ES_CA", para indentificar la app en el modelo centralizado de contact tracing
* **CONTACT_TRACING_MODEL**, definición del modelo de contact tracing: centralizado, descentralizado, exposure notification API, ninguno
* **BUSINESS_DAYS_TRACING**, define si el CT se realiza en días laborables, o todos los días
* **HAS_ONBOARDING**, define si se muestra un onboarding en la app
* **PASSPORT_NEEDED**, define si se necesita de pasaporte vigente para activar el contact tracing
* **URL_SCHEME**, define el URL scheme para el deep link (habrá que definirlo además en en el Info.plist del target)
* **HOST**, el domain en el que se aloja la webapp
* **HOSTS**, los domains que se permiten abrir dentro de la app
* **PUBLIC_KEY_HASHES**
* **URL**: URL que se compartiría con otros usuarios desde la app

### Conexión webapp/nativa:

El envío de información desde el JS a la parte nativa se realiza mediante el **WKScriptMessageHandler**, definido en la clase ViewController.

El envío de información desde la parte nativa a la webapp se realiza mediante llamadas al JS del WKWebView

### Exposure Notification API:

Para implementar la Exposure Notifications API la app necesitará los permisos de Apple y añadir los entitlements necesarios. Además será necesario eliminar del target de la app los archivos de la raiz COVID 19 CORE:

* AppDelegate.swift
* AppSettings.swift
* ViewController.swift
* ContactTracingManager.swift

También habrá que desactivar del target de la app los archivos en la capeta DP3T

Por último habrá que activar todos los archivos en la carpeta ExposureNotification