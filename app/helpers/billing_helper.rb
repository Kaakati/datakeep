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
end
