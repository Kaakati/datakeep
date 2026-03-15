import { Controller } from "@hotwired/stimulus";

// Updates default port, URL placeholder, field visibility, and descriptions based on selected database type
export default class extends Controller {
  static targets = [
    "select",
    "sslField",
    "descriptionText",
    "databaseNameHelp",
    "databaseNameField",
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
    // Apply initial visibility based on current selection
    if (this.hasSelectTarget) {
      this.updateSslVisibility(this.selectTarget.value);
    }
  }

  changed() {
    const type = this.selectTarget.value;
    this.updatePort(type);
    this.updateUrlPlaceholder(type);
    this.updateSslVisibility(type);
    this.updateDescription(type);
    this.updateDatabaseNameHelp(type);
  }

  updatePort(type) {
    const portField = document.getElementById("database_config_port");
    if (!portField) return;

    const defaultPort = this.constructor.defaultPorts[type];
    // Only auto-fill if port is empty or is a known default
    const knownDefaults = Object.values(this.constructor.defaultPorts);
    if (
      !portField.value ||
      knownDefaults.includes(parseInt(portField.value))
    ) {
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

    // SSL mode is relevant for PostgreSQL and MySQL, hidden for MongoDB
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
}
