import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import qs.wallpaper

Scope {
  id: root

  readonly property var _ctrl: WallpaperController

  IpcHandler {
    target: "wallpaper"
    function set(path: string): void {
      WallpaperController.setSource(path);
    }
    function clear(): void {
      WallpaperController.clear();
    }
    function pick(): void {
      WallpaperController.pick();
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData

      visible: WallpaperController.source !== ""
      focusable: false
      color: "transparent"

      WlrLayershell.layer: WlrLayer.Background
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      WlrLayershell.namespace: "quickshell/wallpaper"

      exclusionMode: ExclusionMode.Ignore
      mask: Region {}

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      Item {
        id: content
        anchors.fill: parent

        property bool useA: true
        property int loadGeneration: 0

        // Decode at screen size instead of the file's full resolution
        readonly property size decodeSize: {
          const edge = Math.max(content.width, content.height);
          return Qt.size(edge, edge);
        }

        function pathToUrl(path) {
          if (path.startsWith("file:") || path.startsWith("http:") || path.startsWith("https:"))
            return path;
          return "file://" + path;
        }

        function applySource(path) {
          if (!path) {
            imageA.source = "";
            imageB.source = "";
            return;
          }
          const url = pathToUrl(path);
          if (!imageA.source.toString() && !imageB.source.toString()) {
            imageA.source = url;
            useA = true;
            return;
          }
          const target = useA ? imageB : imageA;
          target.loadGen = ++loadGeneration;
          target.source = url;
        }

        Image {
          id: imageA
          property int loadGen: 0
          anchors.fill: parent
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          sourceSize: content.decodeSize
          cache: false
          opacity: content.useA ? 1 : 0
          Behavior on opacity {
            NumberAnimation {
              duration: 350
              easing.type: Easing.InOutQuad
              onFinished: {
                if (imageA.opacity === 0)
                  imageA.source = "";
              }
            }
          }
          onStatusChanged: {
            if (status === Image.Ready && loadGen === content.loadGeneration && loadGen > 0)
              content.useA = true;
          }
        }

        Image {
          id: imageB
          property int loadGen: 0
          anchors.fill: parent
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          sourceSize: content.decodeSize
          cache: false
          opacity: content.useA ? 0 : 1
          Behavior on opacity {
            NumberAnimation {
              duration: 350
              easing.type: Easing.InOutQuad
              onFinished: {
                if (imageB.opacity === 0)
                  imageB.source = "";
              }
            }
          }
          onStatusChanged: {
            if (status === Image.Ready && loadGen === content.loadGeneration && loadGen > 0)
              content.useA = false;
          }
        }

        Connections {
          target: WallpaperController
          function onSourceChanged() {
            content.applySource(WallpaperController.source);
          }
        }

        Component.onCompleted: content.applySource(WallpaperController.source)
      }
    }
  }
}
