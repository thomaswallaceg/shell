import QtQuick
import Quickshell.Services.Pipewire
import qs.common.theme

IconTextBarPill {
  id: pill

  // Bar sets this and handles mixerRequested (opens a TUI mixer). Lockscreen /
  // greeter leave it false so click toggles mute instead — no session TUI.
  property bool openMixerOnClick: false
  signal mixerRequested()

  PwObjectTracker {
    objects: [Pipewire.defaultAudioSink]
  }

  icon: {
    const sink = Pipewire.defaultAudioSink;
    if (!sink || !sink.audio || sink.audio.muted || sink.audio.volume <= 0) return "󰖁";
    if (sink.audio.volume < 0.33) return "󰕿";
    if (sink.audio.volume < 0.66) return "󰖀";
    return "󰕾";
  }
  iconColor: {
    const sink = Pipewire.defaultAudioSink;
    if (!sink || !sink.audio || sink.audio.muted) return Theme.textMuted;
    return Theme.accentPrimary;
  }
  label: {
    const sink = Pipewire.defaultAudioSink;
    if (!sink || !sink.audio) return "–";
    if (sink.audio.muted) return "Mute";
    return Math.round(sink.audio.volume * 100) + "%";
  }

  Accessible.role: Accessible.Button
  Accessible.name: {
    const sink = Pipewire.defaultAudioSink;
    if (!sink || !sink.audio) return "Volume";
    if (sink.audio.muted) return "Volume: muted";
    return "Volume: " + Math.round(sink.audio.volume * 100) + "%";
  }

  WheelStepMouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    onClicked: {
      if (pill.openMixerOnClick) {
        pill.mixerRequested();
        return;
      }
      const sink = Pipewire.defaultAudioSink;
      if (sink && sink.audio)
        sink.audio.muted = !sink.audio.muted;
    }
    onStepped: up => {
      const sink = Pipewire.defaultAudioSink;
      if (!sink || !sink.audio) return;
      sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + (up ? 0.05 : -0.05)));
    }
  }
}
