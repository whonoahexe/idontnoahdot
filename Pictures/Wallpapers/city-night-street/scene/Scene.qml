import QtQuick

// Animated layer for city-night-street.jpg, loaded by the shell's background when the
// wallpaper's folder has a scene/Scene.qml. Draws the full wallpaper with its effects,
// so it can sit directly on top of the static image.
Item {
    id: root

    property real fps: 30
    readonly property real sceneWidth: 3840
    readonly property real sceneHeight: 2160
    readonly property real startMs: Date.now()

    function texture(name) {
        return Qt.resolvedUrl(name)
    }

    Image { id: baseImage; source: root.texture("../city-night-street.jpg"); visible: false; smooth: true; mipmap: true }
    Image { id: foliageImage; source: root.texture("mask-foliage.png"); visible: false; smooth: true }
    Image { id: pulseImage; source: root.texture("mask-pulse.png"); visible: false; smooth: true }
    Image { id: noiseImage; source: root.texture("noise.png"); visible: false; smooth: true }
    Image { id: haloImage; source: root.texture("halo.png"); visible: false; smooth: true }
    Image { id: glowImage; source: root.texture("halo_4.png"); visible: false; smooth: true }

    ShaderEffect {
        id: effect
        anchors.fill: parent
        visible: baseImage.status === Image.Ready

        property var baseTex: baseImage
        property var foliageMask: foliageImage
        property var pulseMask: pulseImage
        property var noiseTex: noiseImage
        property var haloTex: haloImage
        property var glowTex: glowImage
        property real time: 0

        // Same crop as Image.PreserveAspectCrop, in scene UV
        property vector4d crop: {
            const s = Math.max(width / root.sceneWidth, height / root.sceneHeight)
            const w = root.sceneWidth * s
            const h = root.sceneHeight * s
            return Qt.vector4d((w - width) / 2 / w, (h - height) / 2 / h, width / w, height / h)
        }

        fragmentShader: Qt.resolvedUrl("scene.frag.qsb")
    }

    Timer {
        interval: 1000 / root.fps
        repeat: true
        running: root.visible && root.enabled
        onTriggered: effect.time = (Date.now() - root.startMs) / 1000
    }
}
