# frozen_string_literal: true

module DatabaseEngineHelper
  ENGINE_LABELS = {
    "postgresql" => "PostgreSQL",
    "mysql" => "MySQL",
    "mongodb" => "MongoDB"
  }.freeze

  ENGINE_BADGE_CLASSES = {
    "postgresql" => "bg-blue-50 text-blue-700 dark:bg-blue-900/20 dark:text-blue-400",
    "mysql" => "bg-orange-50 text-orange-700 dark:bg-orange-900/20 dark:text-orange-400",
    "mongodb" => "bg-green-50 text-green-700 dark:bg-green-900/20 dark:text-green-400"
  }.freeze

  ENGINE_ICON_BG = {
    "postgresql" => "bg-blue-100 text-blue-600 dark:bg-blue-900/30 dark:text-blue-400",
    "mysql" => "bg-orange-100 text-orange-600 dark:bg-orange-900/30 dark:text-orange-400",
    "mongodb" => "bg-green-100 text-green-600 dark:bg-green-900/30 dark:text-green-400"
  }.freeze

  ENGINE_DESCRIPTIONS = {
    "postgresql" => "Relational, ACID-compliant",
    "mysql" => "Relational, widely deployed",
    "mongodb" => "Document store, flexible schema"
  }.freeze

  ENGINE_DEFAULT_PORTS = {
    "postgresql" => "5432",
    "mysql" => "3306",
    "mongodb" => "27017"
  }.freeze

  ENGINE_CARD_COLORS = {
    "postgresql" => {
      selected: "border-blue-500 bg-blue-50 ring-2 ring-blue-500/20 dark:border-blue-400 dark:bg-blue-900/20",
      unselected: "border-gray-200 hover:border-gray-300 dark:border-gray-700 dark:hover:border-gray-600",
      icon: "text-blue-600 dark:text-blue-400",
      dot: "bg-blue-500"
    },
    "mysql" => {
      selected: "border-orange-500 bg-orange-50 ring-2 ring-orange-500/20 dark:border-orange-400 dark:bg-orange-900/20",
      unselected: "border-gray-200 hover:border-gray-300 dark:border-gray-700 dark:hover:border-gray-600",
      icon: "text-orange-600 dark:text-orange-400",
      dot: "bg-orange-500"
    },
    "mongodb" => {
      selected: "border-green-500 bg-green-50 ring-2 ring-green-500/20 dark:border-green-400 dark:bg-green-900/20",
      unselected: "border-gray-200 hover:border-gray-300 dark:border-gray-700 dark:hover:border-gray-600",
      icon: "text-green-600 dark:text-green-400",
      dot: "bg-green-500"
    }
  }.freeze

  ENGINE_CACHE_LABELS = {
    "postgresql" => "Cache Hit Ratio",
    "mysql" => "Buffer Pool Hit Ratio",
    "mongodb" => "Resident Memory"
  }.freeze

  ENGINE_FILE_ACCEPT = {
    "postgresql" => ".sql,.dump,.gz,.sql.gz",
    "mysql" => ".sql,.gz,.sql.gz",
    "mongodb" => ".archive,.gz,.bson"
  }.freeze

  def engine_label(type)
    ENGINE_LABELS[type.to_s] || type.to_s.capitalize
  end

  def engine_badge(type)
    classes = ENGINE_BADGE_CLASSES[type.to_s] || "bg-gray-50 text-gray-700 dark:bg-gray-800 dark:text-gray-400"
    content_tag(:span, engine_label(type), class: "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium #{classes}")
  end

  def engine_icon_bg(type)
    ENGINE_ICON_BG[type.to_s] || "bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400"
  end

  def engine_cache_label(type)
    ENGINE_CACHE_LABELS[type.to_s] || "Cache Hit Ratio"
  end

  def engine_file_accept(type)
    ENGINE_FILE_ACCEPT[type.to_s] || ".sql,.dump,.gz,.sql.gz"
  end

  def database_select_name(db)
    "#{db.name} (#{engine_label(db.database_type)})"
  end

  def engine_description(type)
    ENGINE_DESCRIPTIONS[type.to_s] || ""
  end

  def engine_default_port(type)
    ENGINE_DEFAULT_PORTS[type.to_s] || "5432"
  end

  def engine_card_colors(type)
    ENGINE_CARD_COLORS[type.to_s] || ENGINE_CARD_COLORS["postgresql"]
  end

  def engine_select_options
    [["PostgreSQL", "postgresql"], ["MySQL", "mysql"], ["MongoDB", "mongodb"]]
  end

  # rubocop:disable Metrics/MethodLength
  def connection_method_icon(icon_name)
    icons = {
      "globe" => '<path stroke-linecap="round" stroke-linejoin="round" d="M12 21a9.004 9.004 0 0 0 8.716-6.747M12 21a9.004 9.004 0 0 1-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 0 1 7.843 4.582M12 3a8.997 8.997 0 0 0-7.843 4.582m15.686 0A11.953 11.953 0 0 1 12 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0 1 21 12c0 .778-.099 1.533-.284 2.253m0 0A17.919 17.919 0 0 1 12 16.5a17.92 17.92 0 0 1-8.716-2.247m0 0A9.015 9.015 0 0 1 3 12c0-1.605.42-3.113 1.157-4.418" />',
      "shield" => '<path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75m-3-7.036A11.959 11.959 0 0 1 3.598 6 11.99 11.99 0 0 0 3 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285Z" />',
      "lock" => '<path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 1 0-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 0 0 2.25-2.25v-6.75a2.25 2.25 0 0 0-2.25-2.25H6.75a2.25 2.25 0 0 0-2.25 2.25v6.75a2.25 2.25 0 0 0 2.25 2.25Z" />',
      "zap" => '<path stroke-linecap="round" stroke-linejoin="round" d="m3.75 13.5 10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75Z" />',
      "terminal" => '<path stroke-linecap="round" stroke-linejoin="round" d="m6.75 7.5 3 2.25-3 2.25m4.5 0h3m-9 8.25h13.5A2.25 2.25 0 0 0 21 18V6a2.25 2.25 0 0 0-2.25-2.25H5.25A2.25 2.25 0 0 0 3 6v12a2.25 2.25 0 0 0 2.25 2.25Z" />',
      "arrow-right" => '<path stroke-linecap="round" stroke-linejoin="round" d="M7.5 21 3 16.5m0 0L7.5 12M3 16.5h13.5m0-13.5L21 7.5m0 0L16.5 12M21 7.5H7.5" />'
    }

    svg_path = icons[icon_name] || icons["globe"]
    %(<svg class="h-7 w-7 text-gray-600 dark:text-gray-400" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">#{svg_path}</svg>).html_safe
  end
  # rubocop:enable Metrics/MethodLength
end
