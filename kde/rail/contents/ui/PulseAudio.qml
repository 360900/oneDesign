/*
    Audio streams per app, from KDE's task manager (plasma-desktop applets/taskmanager/qml/PulseAudio.qml).
    SPDX-FileCopyrightText: 2017 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.private.volume as PlasmaPa

QtObject {
    id: pulseAudio

    signal streamsChanged()

    function findStreamsFn(fn) {
        const streams = [];
        for (let i = 0, count = instantiator.count; i < count; ++i) {
            const stream = instantiator.objectAt(i);
            if (stream && fn(stream)) streams.push(stream);
        }
        return streams;
    }
    // Same matching order as KDE: sandboxed app id, then process id, then application name
    function streamsFor(appId, pid, appName) {
        let s = appId ? findStreamsFn(st => st.portalAppId === appId) : [];
        if (!s.length && pid > 0) s = findStreamsFn(st => st.pid === pid && !st.portalAppId);
        if (!s.length && appName) s = findStreamsFn(st => st.appName === appName);
        return s;
    }

    readonly property Instantiator instantiator: Instantiator {
        model: PlasmaPa.PulseObjectFilterModel {
            filters: [ { role: "VirtualStream", value: false } ]
            sourceModel: PlasmaPa.SinkInputModel {}
        }
        delegate: QtObject {
            required property var model
            readonly property int pid: model.Client?.properties["application.process.id"] ?? 0
            readonly property string appName: model.Client?.properties["application.name"] ?? ""
            readonly property string portalAppId: model.Client?.properties["pipewire.access.portal.app_id"] ?? ""
            readonly property bool muted: model.Muted
            readonly property bool corked: model.Corked
            readonly property int volume: model.Volume
            function setMuted(m) { model.Muted = m; }
            function setVolume(v) { model.Volume = v; }
        }
        onObjectAdded: pulseAudio.streamsChanged()
        onObjectRemoved: pulseAudio.streamsChanged()
    }

    readonly property int normalVolume: 65536 // PA_VOLUME_NORM
}
