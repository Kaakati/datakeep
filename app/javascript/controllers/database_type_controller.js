import { Controller } from "@hotwired/stimulus";

// Updates default port, URL placeholder, field visibility, and descriptions based on selected database type
export default class extends Controller {
  static targets = [
    "select",
    "sslField",
    "descriptionText",
    "databaseNameHelp",
    "databaseNameField",
    "pageSubtitle",
    "submitButton",
    "engineCard",
    "urlHelpText",
    "engineWarning",
  ];

  static defaultPorts = {
    postgresql: 5432,
    mysql: 3306,
    mongodb: 27017,
  };

  static urlSchemes = {
    postgresql: "postgresql://user:pass@host:5432/db",
    mysql: "mysql://user:pass@host:3306/db",
    mongodb: "mongodb://user:pass@host:27017/db",
  };

  static engineLabels = {
    postgresql: "PostgreSQL",
    mysql: "MySQL",
    mongodb: "MongoDB",
  };

  static databaseNameExamples = {
    postgresql: "e.g. myapp_production",
    mysql: "e.g. myapp",
    mongodb: "e.g. mydb",
  };

  static databaseNamePlaceholders = {
    postgresql: "myapp_production",
    mysql: "myapp",
    mongodb: "mydb",
  };

  connect() {
    if (this.hasSelectTarget) {
      // Listen for external changes to the hidden select (e.g. from URL parser)
      this.selectTarget.addEventListener("change", () => {
        this.syncFromSelect();
      });

      // Apply initial state
      const type = this.selectTarget.value;
      this.updateSslVisibility(type);
      this.updateEngineCards(type);
      this.updatePageSubtitle(type);
      this.updateSubmitButton(type);
      this.updateUrlHelpText(type);
    }

    // Set up keyboard navigation for engine cards
    if (this.hasEngineCardTarget) {
      this.element.addEventListener("keydown", (e) =>
        this.handleCardKeydown(e),
      );
    }
  }

  // Called when user clicks an engine card
  selectEngine(event) {
    const card =
      event.currentTarget.closest("[data-engine]") || event.currentTarget;
    const type = card.dataset.engine;
    if (!type) return;

    // Show warning if editing an existing record and changing engine
    const isEdit = this.element.querySelector(
      'input[name="_method"][value="patch"]',
    );
    if (isEdit && this.hasSelectTarget && this.selectTarget.value !== type) {
      if (this.hasEngineWarningTarget) {
        this.engineWarningTarget.classList.remove("hidden");
        clearTimeout(this._warningTimeout);
        this._warningTimeout = setTimeout(() => {
          this.engineWarningTarget.classList.add("hidden");
        }, 5000);
      }
    }

    // Update hidden select
    if (this.hasSelectTarget) {
      this.selectTarget.value = type;
    }

    // Trigger full update
    this.changed();
  }

  // Sync UI when the hidden select changes externally (e.g. URL parser)
  syncFromSelect() {
    const type = this.selectTarget.value;
    this.updateEngineCards(type);
    this.updatePageSubtitle(type);
    this.updateSubmitButton(type);
    this.updateUrlHelpText(type);
  }

  changed() {
    const type = this.selectTarget.value;
    this.updatePort(type);
    this.updateUrlPlaceholder(type);
    this.updateSslVisibility(type);
    this.updateDescription(type);
    this.updateDatabaseNameHelp(type);
    this.updateEngineCards(type);
    this.updatePageSubtitle(type);
    this.updateSubmitButton(type);
    this.updateUrlHelpText(type);
  }

  updatePort(type) {
    const portField = document.getElementById("database_config_port");
    if (!portField) return;

    const defaultPort = this.constructor.defaultPorts[type];
    const knownDefaults = Object.values(this.constructor.defaultPorts);
    if (!portField.value || knownDefaults.includes(parseInt(portField.value))) {
      portField.value = defaultPort;
      portField.dispatchEvent(new Event("change", { bubbles: true }));
    }
  }

  updateUrlPlaceholder(type) {
    const urlField = document.getElementById("connection_url");
    if (!urlField) return;

    urlField.placeholder = this.constructor.urlSchemes[type] || "";
  }

  updateSslVisibility(type) {
    if (!this.hasSslFieldTarget) return;

    this.sslFieldTarget.style.display = type === "mongodb" ? "none" : "";
  }

  updateDescription(type) {
    if (!this.hasDescriptionTextTarget) return;

    const label = this.constructor.engineLabels[type] || type;
    this.descriptionTextTarget.innerHTML = `Configure your <strong>${label}</strong> connection details`;
  }

  updateDatabaseNameHelp(type) {
    if (!this.hasDatabaseNameHelpTarget) return;

    this.databaseNameHelpTarget.textContent =
      this.constructor.databaseNameExamples[type] || "e.g. myapp_production";

    if (this.hasDatabaseNameFieldTarget) {
      this.databaseNameFieldTarget.placeholder =
        this.constructor.databaseNamePlaceholders[type] || "myapp_production";
    }
  }

  static selectedClasses = {
    postgresql:
      "border-blue-500 bg-blue-50 ring-2 ring-blue-500/20 dark:border-blue-400 dark:bg-blue-900/20",
    mysql:
      "border-orange-500 bg-orange-50 ring-2 ring-orange-500/20 dark:border-orange-400 dark:bg-orange-900/20",
    mongodb:
      "border-green-500 bg-green-50 ring-2 ring-green-500/20 dark:border-green-400 dark:bg-green-900/20",
  };

  static unselectedClasses =
    "border-gray-200 hover:border-gray-300 dark:border-gray-700 dark:hover:border-gray-600";

  updateEngineCards(type) {
    if (!this.hasEngineCardTarget) return;

    // Collect all possible classes for removal
    const allSelectedClasses = Object.values(
      this.constructor.selectedClasses,
    ).flatMap((c) => c.split(" "));
    const allUnselectedClasses = this.constructor.unselectedClasses.split(" ");

    this.engineCardTargets.forEach((card) => {
      const cardType = card.dataset.engine;
      const radio = card.querySelector('input[type="radio"]');
      const checkIcon = card.querySelector("[data-check-icon]");
      const isSelected = cardType === type;

      // Update radio
      if (radio) radio.checked = isSelected;

      // Remove all dynamic classes
      card.classList.remove(...allSelectedClasses, ...allUnselectedClasses);

      if (isSelected) {
        card.setAttribute("aria-checked", "true");
        card.dataset.selected = "true";
        card.tabIndex = 0;
        card.classList.add(
          ...(this.constructor.selectedClasses[cardType] || "").split(" "),
        );
      } else {
        card.setAttribute("aria-checked", "false");
        card.dataset.selected = "false";
        card.tabIndex = -1;
        card.classList.add(...allUnselectedClasses);
      }

      // Toggle check icon visibility
      if (checkIcon) {
        checkIcon.style.display = isSelected ? "" : "none";
      }
    });
  }

  updatePageSubtitle(type) {
    if (!this.hasPageSubtitleTarget) return;

    const label = this.constructor.engineLabels[type] || type;
    this.pageSubtitleTarget.innerHTML = `Configure a new <strong>${label}</strong> database connection`;
  }

  updateSubmitButton(type) {
    if (!this.hasSubmitButtonTarget) return;

    const label = this.constructor.engineLabels[type] || type;
    const isEdit = this.element.querySelector(
      'input[name="_method"][value="patch"]',
    );
    this.submitButtonTarget.value = isEdit
      ? `Update ${label} Database`
      : `Create ${label} Database`;
  }

  updateUrlHelpText(type) {
    if (!this.hasUrlHelpTextTarget) return;

    const label = this.constructor.engineLabels[type] || type;
    this.urlHelpTextTarget.innerHTML = `Paste a <strong>${label}</strong> connection URL to auto-fill all fields below`;
  }

  handleCardKeydown(event) {
    const cards = this.engineCardTargets;
    if (!cards.length) return;

    const current = cards.findIndex(
      (c) => c === document.activeElement || c.contains(document.activeElement),
    );
    if (current === -1) return;

    let next = -1;
    if (event.key === "ArrowRight" || event.key === "ArrowDown") {
      event.preventDefault();
      next = (current + 1) % cards.length;
    } else if (event.key === "ArrowLeft" || event.key === "ArrowUp") {
      event.preventDefault();
      next = (current - 1 + cards.length) % cards.length;
    } else if (event.key === " " || event.key === "Enter") {
      event.preventDefault();
      cards[current].click();
      return;
    }

    if (next >= 0) {
      cards[next].focus();
      cards[next].click();
    }
  }
}
