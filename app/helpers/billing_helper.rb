# frozen_string_literal: true

module BillingHelper
  # Renders a usage bar row: label, "used/limit" counter, and optional progress bar.
  #
  #   usage_bar("Databases", used: 2, limit: 5)
  #   usage_bar("Sync Jobs", used: 0, limit: 0)   # 0 limit = fully consumed
  #   usage_bar("Backup Jobs", used: 12, limit: nil) # nil = unlimited
  #
  def usage_bar(label, used:, limit:)
    counter = limit ? "#{used}/#{limit}" : "#{used}/&infin;".html_safe

    bar_html = if limit && limit > 0
                 pct = [(used.to_f / limit * 100), 100].min
                 color = pct >= 100 ? "bg-amber-500" : "bg-primary-500"
                 tag.div(class: "h-2 w-full rounded-full bg-gray-100 dark:bg-gray-800") do
                   tag.div("", class: "h-2 rounded-full #{color}", style: "width: #{pct}%")
                 end
               elsif limit == 0
                 tag.div(class: "h-2 w-full rounded-full bg-gray-100 dark:bg-gray-800") do
                   tag.div("", class: "h-2 rounded-full bg-amber-500", style: "width: 100%")
                 end
               end

    tag.div do
      safe_join([
        tag.div(class: "flex justify-between mb-1.5") do
          safe_join([
            tag.span(label, class: "text-sm font-medium text-gray-700 dark:text-gray-300"),
            tag.span(counter, class: "text-sm text-gray-500 dark:text-gray-400")
          ])
        end,
        bar_html
      ].compact)
    end
  end

  def usage_health(used, limit)
    return :unlimited if limit.nil?
    return :critical if limit == 0 || (limit > 0 && used >= limit)
    return :warning if limit > 0 && used.to_f / limit >= 0.7
    :healthy
  end

  def plan_accent_class(tier_key)
    case tier_key.to_sym
    when :free then "border-l-gray-400"
    when :starter then "border-l-amber-500"
    when :professional then "border-l-emerald-500"
    when :business then "border-l-blue-600"
    when :enterprise then "border-l-purple-600"
    else "border-l-gray-400"
    end
  end

  def format_plan_price(cents, interval = :monthly)
    return "Free" if cents.nil? || cents == 0
    "$#{cents / 100}/mo"
  end

  # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize
  def usage_pulse_card(label, icon_name:, used:, limit:)
    health = usage_health(used, limit)

    # Special cases: retention and s3
    if icon_name == :retention
      return render_retention_card(label, used)
    end

    if icon_name == :s3
      return render_s3_card(label, used)
    end

    bar_color = case health
                when :healthy then "bg-emerald-500"
                when :warning then "bg-amber-500"
                when :critical then "bg-red-500"
                else "bg-gray-300"
                end

    unit = icon_name == :storage ? " GB" : ""
    counter_text = limit ? "#{used}#{unit} / #{limit}#{unit}" : "#{used}#{unit}"
    icon_svg = pulse_icon_svg(icon_name)

    content_tag(:div, class: "rounded-xl border border-gray-200 bg-white dark:border-gray-700 dark:bg-white/[0.03] p-4 flex flex-col gap-2") do
      parts = []

      # Icon + label row
      parts << content_tag(:div, class: "flex items-center gap-2") do
        safe_join([
          icon_svg,
          content_tag(:span, label, class: "text-sm font-medium text-gray-700 dark:text-gray-300")
        ])
      end

      if health == :unlimited
        # Unlimited display
        parts << content_tag(:div, class: "flex items-center gap-1.5") do
          safe_join([
            content_tag(:span, used.to_s, class: "text-2xl font-semibold text-gray-900 dark:text-white"),
            content_tag(:span, raw("&infin;"), class: "text-lg text-gray-400 dark:text-gray-500")
          ])
        end
      else
        # Counter
        parts << content_tag(:span, counter_text, class: "text-2xl font-semibold text-gray-900 dark:text-white")

        # Progress bar
        pct = limit && limit > 0 ? [(used.to_f / limit * 100), 100].min : 100
        parts << content_tag(:div, class: "h-2 w-full rounded-full bg-gray-100 dark:bg-gray-800") do
          content_tag(:div, "", class: "h-2 rounded-full #{bar_color}", style: "width: #{pct}%")
        end

        # Status micro-label
        if health == :warning
          parts << render_status_dot("Almost full", "bg-amber-500", "text-amber-600 dark:text-amber-400")
        elsif health == :critical
          parts << render_status_dot("At limit", "bg-red-500", "text-red-600 dark:text-red-400")
        end
      end

      safe_join(parts)
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize

  private

  def render_status_dot(text, dot_class, text_class)
    content_tag(:div, class: "flex items-center gap-1.5 mt-1") do
      safe_join([
        content_tag(:span, "", class: "inline-block h-2 w-2 rounded-full #{dot_class}"),
        content_tag(:span, text, class: "text-xs font-medium #{text_class}")
      ])
    end
  end

  def render_retention_card(label, days)
    icon_svg = pulse_icon_svg(:retention)
    display = days ? "#{days} days" : "Unlimited"

    content_tag(:div, class: "rounded-xl border border-gray-200 bg-white dark:border-gray-700 dark:bg-white/[0.03] p-4 flex flex-col gap-2") do
      safe_join([
        content_tag(:div, class: "flex items-center gap-2") do
          safe_join([
            icon_svg,
            content_tag(:span, label, class: "text-sm font-medium text-gray-700 dark:text-gray-300")
          ])
        end,
        content_tag(:span, display, class: "text-2xl font-semibold text-gray-900 dark:text-white")
      ])
    end
  end

  def render_s3_card(label, allowed_flag)
    allowed = allowed_flag.present? && allowed_flag != false && allowed_flag != 0

    icon_svg = if allowed
                 # Checkmark icon
                 content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24",
                   stroke_width: "1.5", stroke: "currentColor", class: "h-5 w-5 text-emerald-500") do
                   tag.path(stroke_linecap: "round", stroke_linejoin: "round",
                     d: "M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z")
                 end
               else
                 # Lock icon
                 content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24",
                   stroke_width: "1.5", stroke: "currentColor", class: "h-5 w-5 text-gray-400") do
                   tag.path(stroke_linecap: "round", stroke_linejoin: "round",
                     d: "M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z")
                 end
               end

    status_text = allowed ? "Enabled" : "Locked"
    status_class = allowed ? "text-emerald-600 dark:text-emerald-400" : "text-gray-500 dark:text-gray-400"

    content_tag(:div, class: "rounded-xl border border-gray-200 bg-white dark:border-gray-700 dark:bg-white/[0.03] p-4 flex flex-col gap-2") do
      safe_join([
        content_tag(:div, class: "flex items-center gap-2") do
          safe_join([
            icon_svg,
            content_tag(:span, label, class: "text-sm font-medium text-gray-700 dark:text-gray-300")
          ])
        end,
        content_tag(:span, status_text, class: "text-2xl font-semibold #{status_class}")
      ])
    end
  end

  # rubocop:disable Metrics/MethodLength
  def pulse_icon_svg(icon_name)
    case icon_name
    when :database
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24",
        stroke_width: "1.5", stroke: "currentColor", class: "h-5 w-5 text-gray-500 dark:text-gray-400") do
        safe_join([
          tag.path(stroke_linecap: "round", stroke_linejoin: "round",
            d: "M20.25 6.375c0 2.278-3.694 4.125-8.25 4.125S3.75 8.653 3.75 6.375m16.5 0c0-2.278-3.694-4.125-8.25-4.125S3.75 4.097 3.75 6.375m16.5 0v11.25c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125V6.375"),
          tag.path(stroke_linecap: "round", stroke_linejoin: "round",
            d: "M3.75 6.375c0 2.278 3.694 4.125 8.25 4.125s8.25-1.847 8.25-4.125")
        ])
      end
    when :backup
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24",
        stroke_width: "1.5", stroke: "currentColor", class: "h-5 w-5 text-gray-500 dark:text-gray-400") do
        tag.path(stroke_linecap: "round", stroke_linejoin: "round",
          d: "M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5m8.25 3v6.75m0 0l-3-3m3 3l3-3M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z")
      end
    when :sync
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24",
        stroke_width: "1.5", stroke: "currentColor", class: "h-5 w-5 text-gray-500 dark:text-gray-400") do
        tag.path(stroke_linecap: "round", stroke_linejoin: "round",
          d: "M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182")
      end
    when :restore
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24",
        stroke_width: "1.5", stroke: "currentColor", class: "h-5 w-5 text-gray-500 dark:text-gray-400") do
        tag.path(stroke_linecap: "round", stroke_linejoin: "round",
          d: "M12 9.75v6.75m0 0l-3-3m3 3l3-3m-8.25 6a4.5 4.5 0 01-1.41-8.775 5.25 5.25 0 0110.233-2.33 3 3 0 013.758 3.848A3.752 3.752 0 0118 19.5H6.75z")
      end
    when :retention
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24",
        stroke_width: "1.5", stroke: "currentColor", class: "h-5 w-5 text-gray-500 dark:text-gray-400") do
        tag.path(stroke_linecap: "round", stroke_linejoin: "round",
          d: "M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z")
      end
    when :storage
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24",
        stroke_width: "1.5", stroke: "currentColor", class: "h-5 w-5 text-gray-500 dark:text-gray-400") do
        tag.path(stroke_linecap: "round", stroke_linejoin: "round",
          d: "M5.25 14.25h13.5m-13.5 0a3 3 0 01-3-3m3 3a3 3 0 100 6h13.5a3 3 0 100-6m-16.5-3a3 3 0 013-3h13.5a3 3 0 013 3m-19.5 0a4.5 4.5 0 01.9-2.7L5.737 5.1a3.375 3.375 0 012.7-1.35h7.126c1.062 0 2.062.5 2.7 1.35l2.587 3.45a4.5 4.5 0 01.9 2.7m0 0a3 3 0 01-3 3m0 3h.008v.008h-.008v-.008zm0-6h.008v.008h-.008v-.008zm-3 6h.008v.008h-.008v-.008zm0-6h.008v.008h-.008v-.008z")
      end
    when :s3
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24",
        stroke_width: "1.5", stroke: "currentColor", class: "h-5 w-5 text-gray-500 dark:text-gray-400") do
        tag.path(stroke_linecap: "round", stroke_linejoin: "round",
          d: "M2.25 15a4.5 4.5 0 004.5 4.5H18a3.75 3.75 0 001.332-7.257 3 3 0 00-3.758-3.848 5.25 5.25 0 00-10.233 2.33A4.502 4.502 0 002.25 15z")
      end
    else
      content_tag(:span, "", class: "h-5 w-5")
    end
  end
  # rubocop:enable Metrics/MethodLength
end
