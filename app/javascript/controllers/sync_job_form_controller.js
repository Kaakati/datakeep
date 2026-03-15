import { Controller } from "@hotwired/stimulus";

// Hides the source database from the list of target checkboxes
// and disables targets with a different engine type than the source.
export default class extends Controller {
  static targets = ["sourceSelect", "targetItem", "targetsContainer"];
  static values = { engineMap: Object };

  connect() {
    this.updateTargets();
  }

  get engineMap() {
    // Engine map is stored on the targetsContainer as a data attribute
    if (this.hasTargetsContainerTarget) {
      try {
        return JSON.parse(
          this.targetsContainerTarget.dataset.syncJobFormEngineMapValue || "{}"
        );
      } catch {
        return {};
      }
    }
    return {};
  }

  updateTargets() {
    const sourceId = this.sourceSelectTarget.value;
    const sourceEngine = this.engineMap[sourceId];

    this.targetItemTargets.forEach((item) => {
      const dbId = item.dataset.dbId;
      const dbEngine = item.dataset.databaseType;
      const input = item.querySelector("input[type='checkbox']");

      if (dbId === sourceId) {
        // Hide source from targets
        item.classList.add("hidden");
        if (input) {
          input.checked = false;
          input.disabled = true;
        }
      } else if (sourceEngine && dbEngine && dbEngine !== sourceEngine) {
        // Different engine — disable and dim
        item.classList.remove("hidden");
        item.classList.add("opacity-40");
        if (input) {
          input.checked = false;
          input.disabled = true;
        }
        // Show engine mismatch message if not already present
        if (!item.querySelector(".engine-mismatch-msg")) {
          const msg = document.createElement("p");
          msg.className =
            "engine-mismatch-msg text-xs text-orange-600 dark:text-orange-400 mt-1 ml-8";
          const engineLabels = {
            postgresql: "PostgreSQL",
            mysql: "MySQL",
            mongodb: "MongoDB",
          };
          const sourceLabel = engineLabels[sourceEngine] || sourceEngine;
          msg.textContent = `Only ${sourceLabel} databases can sync with a ${sourceLabel} source`;
          item.appendChild(msg);
        }
      } else {
        // Same engine or no source selected — enable
        item.classList.remove("hidden", "opacity-40");
        if (input) {
          input.disabled = false;
        }
        // Remove mismatch message if present
        const msg = item.querySelector(".engine-mismatch-msg");
        if (msg) msg.remove();
      }
    });
  }
}
