import qs.services
import qs.common.widgets as CommonWidgets

CommonWidgets.VolumeWidget {
  openMixerOnClick: true
  onMixerRequested: Niri.openFloatingTui("wiremix")
}
