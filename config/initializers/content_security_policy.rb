# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data, :https
    policy.object_src  :none
    policy.script_src  :self, "https://static.cloudflareinsights.com", "https://challenges.cloudflare.com"
    policy.style_src   :self, "'unsafe-inline'"
    policy.connect_src :self, "https://static.cloudflareinsights.com", "https://challenges.cloudflare.com", "wss://cable.datakeep.ai"
    policy.frame_src   :self, "https://challenges.cloudflare.com"
    policy.child_src   :self, "https://challenges.cloudflare.com"
  end

  # Generate session nonces for permitted importmap and inline scripts.
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src]

  # Report violations without enforcing the policy.
  # Switch to false once verified in production.
  config.content_security_policy_report_only = true
end
