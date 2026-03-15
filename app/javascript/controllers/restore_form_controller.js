import { Controller } from "@hotwired/stimulus";

// Dynamically updates file accept attributes and help text based on the selected database engine
export default class extends Controller {
  static targets = ["databaseSelect", "fileInput", "fileHelp"];
  static values = { engineMap: Object };

  static fileAccepts = {
    postgresql: ".sql,.dump,.gz,.sql.gz",
    mysql: ".sql,.gz,.sql.gz",
    mongodb: ".archive,.gz,.bson",
  };

  static fileHelpTexts = {
    postgresql: "Accepts .sql, .dump, .gz, or .sql.gz files",
    mysql: "Accepts .sql, .gz, or .sql.gz files",
    mongodb: "Accepts .archive, .gz, or .bson files",
  };

  updateFileAccept() {
    const dbId = this.databaseSelectTarget.value;
    if (!dbId) return;

    const engine = this.engineMapValue[dbId];
    if (!engine) return;

    const accept =
      this.constructor.fileAccepts[engine] || ".sql,.dump,.gz,.sql.gz";
    const helpText =
      this.constructor.fileHelpTexts[engine] ||
      "Accepts .sql, .dump, .gz, or .sql.gz files";

    if (this.hasFileInputTarget) {
      this.fileInputTarget.accept = accept;
    }

    if (this.hasFileHelpTarget) {
      this.fileHelpTarget.textContent = helpText;
    }
  }
}
