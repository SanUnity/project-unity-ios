
# PROJECT UNITY - iOS

<p align="center">
    <a href="https://github.com/SanUnity/project-unity-ios/commits/" title="Last Commit"><img src="https://img.shields.io/github/last-commit/SanUnity/project-unity-front?style=flat"></a>
    <a href="https://github.com/SanUnity/project-unity-ios/issues" title="Open Issues"><img src="https://img.shields.io/github/issues/SanUnity/project-unity-front?style=flat"></a>
    <a href="https://github.com/SanUnity/project-unity-ios/blob/master/LICENSE" title="License"><img src="https://img.shields.io/badge/License-AGPL--3.0-blue?style=flat"></a>
</p>

Project Unity is an open project that aims to help in the fight against COVID-19.

Dentro del proyecto, desde iOS se pretende dar a los usuarios finales una herramienta para iPhone, iPad y iPod. La parte nativa de la aplicación muestra en un WKWebView la webapp del front, gestionando los permisos e intercomunicación del front y la parte nativa.

## Lenguaje de desarrollo

Swift 5

## Librerías utilizadas

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

## Permisos requeridos

La app puede requerir algunos de estos permisos

* Bluetooth
* Localización
* Cámara
* Fotos
* Contactos
* Notificaciones Push

En función de los módulos que se activen en la webapp, deberán introducirse unos y/u otros en el Info.plist de la app

## Capacidades requeridas:

La app puede necesitar las capacidades de Push Notificationes y algunos Background Modes, en función de los módulos que se activen en la webapp: Uses BT LE accesories, Acts as a BT LE acessory, Background fetch y Remote notifications

## Vistas nativas:

La app implenta estas tres vistas nativas

* Onboarding
* Webview
* Lector QR

## Configuración:

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

## Conexión webapp/nativa:

El envío de información desde el JS a la parte nativa se realiza mediante el **WKScriptMessageHandler**, definido en la clase ViewController.

El envío de información desde la parte nativa a la webapp se realiza mediante llamadas al JS del WKWebView

## Contact Tracing

El proyecto permite implementar tres modos de rastreo de contactos:

### Descentralizado: BlueTrace Protocol (Modelo Singaput)
BlueTrace es un protocolo que preserva la privacidad para el rastreo de contactos impulsado por la comunidad mediante dispositivos Bluetooth, que permite la interoperabilidad global.

BlueTrace está diseñado para el registro de proximidad descentralizado y complementa el rastreo de contactos centralizado por parte de las autoridades de salud pública. El registro de proximidad mediante Bluetooth aborda una limitación clave del rastreo manual de contactos: que depende de la memoria de una persona y, por lo tanto, se limita a los contactos que una persona conoce y recuerda haber conocido. Por lo tanto, BlueTrace permite que el rastreo de contactos sea más escalable y requiera menos recursos.

### Centralizado: DP^3T (Modelo Suiza)
El proyecto Decentralized Privacy-Preserving Proximity Tracing (DP-3T) es un protocolo abierto para el rastreo de proximidad COVID-19 que utiliza la funcionalidad Bluetooth Low Energy en dispositivos móviles que garantiza que los datos personales permanezcan completamente en el teléfono de una persona. Fue elaborado por un equipo central de más de 25 científicos e investigadores académicos de toda Europa. También ha sido examinado y mejorado por la comunidad en general.

DP-3T es un esfuerzo independiente iniciado en EPFL y ETHZ que produjo este protocolo y que lo está implementando en una aplicación y un servidor de código abierto.)

### Exposure Notification API: Apple/Google Framework
La API de notificaciones de exposición es un esfuerzo conjunto entre Apple y Google para proporcionar la funcionalidad principal para crear aplicaciones iOS y Android para notificar a los usuarios de una posible exposición a casos confirmados de COVID-19.

## Exposure Notification API:

Para implementar la Exposure Notifications API la app necesitará los permisos de Apple y añadir los entitlements necesarios. Además será necesario eliminar del target de la app los archivos de la raiz COVID 19 CORE:

* AppDelegate.swift
* AppSettings.swift
* ViewController.swift
* ContactTracingManager.swift

También habrá que desactivar del target de la app los archivos en la capeta DP3T y habrá que activar todos los archivos en la carpeta ExposureNotification

Será necesario especificar ENDeveloperRegion en el Info.plist indicando el ISO 3166-1 country code (por ejemplo, “CA” para Canada), o el ISO 3166-1/3166-2 country code con el subdivision code (por ejemplo, “US-CA” para California).

## Support and Feedback

The following channels are available for discussions, feedback, and support requests:

| Type       | Channel                                                |
| ---------- | ------------------------------------------------------ |
| **Issues** | <a href="https://github.com/SanUnity/project-unity-ios//issues" title="Open Issues"><img src="https://img.shields.io/github/issues/SanUnity/project-unity-ios?style=flat"></a> |

## Contribute

If you want to contribute with this exciting project follow the steps in [How to create a Pull Request in GitHub](https://opensource.com/article/19/7/create-pull-request-github).

## License

This Source Code Form is subject to the terms of the [AGPL, v. 3.0](https://www.gnu.org/licenses/agpl-3.0.html).
