import "../../services"
import "../../common/widgets" as CommonWidgets

CommonWidgets.VolumeWidget {
  openMixerOnClick: true
  onMixerRequested: Niri.openFloatingTui("wiremix")
}
