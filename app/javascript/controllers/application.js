import { Application } from "@hotwired/stimulus"
import Dropdown from "@stimulus-components/dropdown"
import Notification from "@stimulus-components/notification"
import Clipboard from "@stimulus-components/clipboard"

const application = Application.start()

// Vendored Stimulus components. Local controllers are eager-loaded
// from controllers/*_controller.js by controllers/index.js.
application.register("dropdown", Dropdown)
application.register("notification", Notification)
application.register("clipboard", Clipboard)

application.debug = false
window.Stimulus = application

export { application }
