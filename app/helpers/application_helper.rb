module ApplicationHelper
  def nav_link_class(path)
    base_classes = "rounded-md px-3 py-2 text-sm font-medium"
    if current_page?(path)
      "#{base_classes} bg-primary-700 text-white"
    else
      "#{base_classes} text-primary-200 hover:bg-primary-600 hover:text-white"
    end
  end

  def mobile_nav_link_class(path)
    base_classes = "block rounded-md px-3 py-2 text-base font-medium"
    if current_page?(path)
      "#{base_classes} bg-primary-700 text-white"
    else
      "#{base_classes} text-primary-200 hover:bg-primary-600 hover:text-white"
    end
  end

  def sidebar_link_class(path)
    base_classes = "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors"
    if current_page?(path)
      "#{base_classes} bg-primary-50 text-primary-600 dark:bg-primary-900/50 dark:text-primary-400"
    else
      "#{base_classes} text-gray-700 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-800"
    end
  end

  def sidebar_group_heading_class
    "px-3 mb-2 text-xs font-semibold text-gray-400 uppercase tracking-wider"
  end

  def status_badge(status)
    classes = case status.to_s
    when "healthy", "completed", "idle", "enabled"
      "bg-green-100 text-green-800"
    when "unhealthy", "failed", "disabled"
      "bg-red-100 text-red-800"
    when "running", "pending"
      "bg-yellow-100 text-yellow-800"
    when "unknown"
      "bg-gray-100 text-gray-800"
    else
      "bg-gray-100 text-gray-800"
    end

    content_tag(:span, status.to_s.titleize, class: "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium #{classes}")
  end

  def format_bytes(bytes)
    return "N/A" unless bytes

    if bytes < 1024
      "#{bytes} B"
    elsif bytes < 1024 * 1024
      "#{(bytes / 1024.0).round(2)} KB"
    elsif bytes < 1024 * 1024 * 1024
      "#{(bytes / (1024.0 * 1024)).round(2)} MB"
    else
      "#{(bytes / (1024.0 * 1024 * 1024)).round(2)} GB"
    end
  end

  def time_ago_or_never(time)
    time ? time_ago_in_words(time) + " ago" : "Never"
  end

  def sidebar_partial
    current_user&.admin? && controller.class.module_parent_name&.start_with?("Admin") ? "layouts/admin_sidebar" : "layouts/sidebar"
  end

  def billing_status_badge(status)
    classes = case status.to_s
    when "draft"
      "bg-gray-100 text-gray-800"
    when "sent"
      "bg-blue-100 text-blue-800"
    when "paid"
      "bg-green-100 text-green-800"
    when "cancelled", "expired"
      "bg-red-100 text-red-800"
    else
      "bg-gray-100 text-gray-800"
    end

    content_tag(:span, status.to_s.titleize, class: "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium #{classes}")
  end

  def action_badge_class(action)
    case action.to_s
    when "backup_started", "restore_started"
      "bg-blue-100 text-blue-800"
    when "backup_completed", "restore_completed"
      "bg-green-100 text-green-800"
    when "backup_failed", "restore_failed"
      "bg-red-100 text-red-800"
    when "health_check_passed"
      "bg-green-100 text-green-800"
    when "health_check_failed"
      "bg-red-100 text-red-800"
    when "cleanup_completed"
      "bg-purple-100 text-purple-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end
end
