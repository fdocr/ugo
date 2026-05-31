import { Controller } from "@hotwired/stimulus";

// Toggles `data-state="active"` on segmented control buttons. Visual styling
// is handled by CSS (.ui-segmented-option) so the design system stays in
// one place.
export default class extends Controller {
  static targets = ["deviceButton", "geoButton"];
  static outlets = ["devices", "geo"];

  connect() {
    this.setActiveDeviceFilter("device_type");
    this.setActiveGeoFilter("country");
  }

  showDevices(event) {
    event.preventDefault();
    const filterType = event.currentTarget.dataset.filter;
    this.setActiveDeviceFilter(filterType);
    this.devicesOutlet.updateChart(filterType);
  }

  showGeo(event) {
    event.preventDefault();
    const filterType = event.currentTarget.dataset.filter;
    this.setActiveGeoFilter(filterType);
    this.geoOutlet.updateChart(filterType);
  }

  setActiveDeviceFilter(activeFilter) {
    this.#applyState(this.deviceButtonTargets, activeFilter);
  }

  setActiveGeoFilter(activeFilter) {
    this.#applyState(this.geoButtonTargets, activeFilter);
  }

  #applyState(buttons, activeFilter) {
    buttons.forEach(button => {
      if (button.dataset.filter === activeFilter) {
        button.dataset.state = "active";
      } else {
        delete button.dataset.state;
      }
    });
  }
}
