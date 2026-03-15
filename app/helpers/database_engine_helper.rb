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

  def engine_select_options
    [["PostgreSQL", "postgresql"], ["MySQL", "mysql"], ["MongoDB", "mongodb"]]
  end
end
