# pxp_ui_ios

[![Build Status](https://travis-ci.org/joemccann/dillinger.svg?branch=master)](https://travis-ci.org/joemccann/dillinger)
# Requerimientos 
##### XCode 11.3 o superior
##### Cocoa Pods
- ##### Instalacion
- sudo gem install cocoapods
- export GEM_HOME=$HOME/.gem
- export PATH=$GEM_HOME/bin:$PATH
- ##### Referencias
- https://guides.cocoapods.org/using/getting-started.html

### Instalación
```sh
$ cd carpeta_del_proyecto
$ pod install
```
 
### Personalización
- cambiar el logo en la raiz del proyeto logo.png
- cambiar los colores del tema en los archivos LaunchScreen.storyboard y Main.storyboard 
- Cambiar la URL base en Constants.swift

### FireBase
- reemplazar el arvhivo GoogleService-Info.plist con los datos de configuracion firebease adecuado para el proyecto usando el Bundle Identifier correspondiente.

### Google
- En el archivo AppDelegate.swift reemplazar el GIDSignIn.sharedInstance().clientID por el nuevo Id generado para el proyecyo.

### Facebook
- Reemplazar el identificador FacebookAppID en el archivo info.plist de la carpeta raiz por el generado para el proyecto.
