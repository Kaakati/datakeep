# frozen_string_literal: true

Turnstiled.site_key = ENV.fetch("TURNSTILE_SITE_KEY", "0x4AAAAAACq7hxqMz72ZXBlL")
Turnstiled.site_secret = ENV.fetch("TURNSTILE_SECRET_KEY", "0x4AAAAAACq7h8d26IrWEpsQeTY6T88MOtY")
