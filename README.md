CocoaPodUI
----------

Xcode plugin that implements CocoaPods GUI.

Installation Guide
------------------

Open and build CocoaPodUI project, it will be installed automatically.

Uninstall
---------
Just remove CocoaPodUI.xcplugin from ~/Library/Application Support/Developer/Shared/Xcode/Plug-ins

Version History
---------------
- **v.1.2**
    * New podspec format support.
    * Checking for outdated Pods and it’s updating.
    * Badge on Xcode Dock icon with outdated Pods count
- **v.1.1**
    * Added multi-target support.
    * Adding pods to the «Installed»-table by drag’n’drop.
    * Extended editing capabilities of pods.
- **v.1.0.4 hotfix 2**
    * Fixed crash when Cocoapods gem file path is not defined and equals nil.
    * Fixed forming of incorrect text for Podfile.
- **v.1.0.4 hotfix 1**
    * «must provide a launch path» crash fix.
- **v.1.0.4**
    * Avoid complete overwriting an existing Podfile.
- **v.1.0.3**
    * Added console output for during pods install.
- **v.1.0.2 hotfix 2**
    * Small bug-fix.
- **v.1.0.2 hotfix 1**
    * Cocoapod gem search optimization.
- **v.1.0.2**
    * Added mechanism that allows user manually define location of Cocoapods
gem file.
- **v.1.0.1**
    * Critical bug fixes.
        * Fixed crash when Cocoapod gem placed in non-default folder.
        * Fixed crash when Podfile contains additional pre- or post-install
scenarios.
    * Global improvements.
- **v.1.0**
    * Basic capabilities: «Podfile» creation and pods installation. Cleaning up project from pods.

<img src="http://i1199.photobucket.com/albums/aa470/Akki-87/readme.png">

Special thanks to [kodlian (JMModalOverlay)](https://github.com/kodlian/JMModalOverlay)
