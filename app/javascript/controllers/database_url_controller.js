import { Controller } from "@hotwired/stimulus";

// Parses database connection URLs and populates form fields
// Supports PostgreSQL, MySQL, and MongoDB URLs
export default class extends Controller {
  static targets = [
    "url",
    "host",
    "port",
    "database",
    "username",
    "password",
    "sslMode",
  ];

  static schemes = {
    postgresql: { defaultPort: "5432", type: "postgresql" },
    postgres: { defaultPort: "5432", type: "postgresql" },
    mysql: { defaultPort: "3306", type: "mysql" },
    mysql2: { defaultPort: "3306", type: "mysql" },
    mongodb: { defaultPort: "27017", type: "mongodb" },
    "mongodb+srv": { defaultPort: "27017", type: "mongodb" },
  };

  connect() {
    // Initialize - if URL is filled but fields are empty, parse on load
    if (this.hasUrlTarget && this.urlTarget.value) {
      this.parse();
    }
  }

  parse() {
    const url = this.urlTarget.value.trim();

    if (!url) {
      return;
    }

    try {
      const parsed = this.parseConnectionUrl(url);

      if (parsed) {
        this.populateFields(parsed);
        this.showSuccess();
      }
    } catch (error) {
      this.showError(error.message);
    }
  }

  parseConnectionUrl(url) {
    // Detect scheme
    const schemeMatch = url.match(/^(\w+(?:\+\w+)?):\/\//);
    if (!schemeMatch) {
      throw new Error(
        "URL must start with a scheme (postgresql://, mysql://, mongodb://)",
      );
    }

    const scheme = schemeMatch[1].toLowerCase();
    const schemeInfo = this.constructor.schemes[scheme];
    if (!schemeInfo) {
      throw new Error(
        `Unsupported scheme: ${scheme}. Use postgresql://, mysql://, or mongodb://`,
      );
    }

    try {
      // Use URL API for parsing (swap scheme for http:// to leverage standard parsing)
      const tempUrl = url.replace(/^\w+(\+\w+)?:\/\//, "http://");
      const parsedUrl = new URL(tempUrl);

      const result = {
        host: parsedUrl.hostname || "",
        port: parsedUrl.port || schemeInfo.defaultPort,
        database: parsedUrl.pathname.slice(1) || "", // Remove leading /
        username: parsedUrl.username
          ? decodeURIComponent(parsedUrl.username)
          : "",
        password: parsedUrl.password
          ? decodeURIComponent(parsedUrl.password)
          : "",
        sslMode: "",
        databaseType: schemeInfo.type,
      };

      // Parse query params for sslmode
      const sslMode =
        parsedUrl.searchParams.get("sslmode") ||
        parsedUrl.searchParams.get("ssl_mode");
      if (sslMode) {
        result.sslMode = sslMode;
      }

      return result;
    } catch (e) {
      throw new Error(
        "Invalid URL format. Example: postgresql://user:password@host:port/database",
      );
    }
  }

  populateFields(parsed) {
    if (this.hasHostTarget && parsed.host) {
      this.hostTarget.value = parsed.host;
      this.triggerChange(this.hostTarget);
    }

    if (this.hasPortTarget && parsed.port) {
      this.portTarget.value = parsed.port;
      this.triggerChange(this.portTarget);
    }

    if (this.hasDatabaseTarget && parsed.database) {
      this.databaseTarget.value = parsed.database;
      this.triggerChange(this.databaseTarget);
    }

    if (this.hasUsernameTarget && parsed.username) {
      this.usernameTarget.value = parsed.username;
      this.triggerChange(this.usernameTarget);
    }

    if (this.hasPasswordTarget && parsed.password) {
      this.passwordTarget.value = parsed.password;
      this.triggerChange(this.passwordTarget);
    }

    if (this.hasSslModeTarget && parsed.sslMode) {
      this.sslModeTarget.value = parsed.sslMode;
      this.triggerChange(this.sslModeTarget);
    }

    // Update database type selector if present
    if (parsed.databaseType) {
      const typeSelect = document.getElementById(
        "database_config_database_type",
      );
      if (typeSelect) {
        typeSelect.value = parsed.databaseType;
        this.triggerChange(typeSelect);
      }
    }
  }

  triggerChange(element) {
    element.dispatchEvent(new Event("change", { bubbles: true }));
  }

  showSuccess() {
    // Brief visual feedback
    this.urlTarget.classList.remove("border-red-500", "dark:border-red-500");
    this.urlTarget.classList.add("border-green-500", "dark:border-green-500");

    setTimeout(() => {
      this.urlTarget.classList.remove(
        "border-green-500",
        "dark:border-green-500",
      );
    }, 2000);
  }

  showError(message) {
    this.urlTarget.classList.remove(
      "border-green-500",
      "dark:border-green-500",
    );
    this.urlTarget.classList.add("border-red-500", "dark:border-red-500");

    // Could also show a toast or inline error message
    console.warn("Database URL parse error:", message);
  }

  clear() {
    this.urlTarget.value = "";
    this.urlTarget.classList.remove(
      "border-green-500",
      "dark:border-green-500",
      "border-red-500",
      "dark:border-red-500",
    );
  }
}
