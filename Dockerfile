# syntax=docker/dockerfile:1
# check=error=true

# Database-Ops: PostgreSQL Backup and Restore Platform
#
# This Dockerfile includes PostgreSQL client tools (pg_dump, pg_restore) for
# database backup and restore operations. Build and run:
#
# docker build -t database_ops .
# docker run -d -p 80:80 \
#   -e RAILS_MASTER_KEY=<value from config/master.key> \
#   -e DATABASE_URL=postgresql://user:pass@host:5432/dbname \
#   -v database_ops_storage:/rails/storage \
#   -v database_ops_backups:/rails/backups \
#   --name database_ops database_ops

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages including PostgreSQL client tools for backup/restore
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libjemalloc2 \
      libvips \
      # PostgreSQL client tools (pg_dump, pg_restore, psql)
      postgresql-client-16 \
      # Required for pg gem native extension
      libpq5 \
      # Compression utilities for backup compression
      gzip \
      bzip2 \
      xz-utils \
      # For file system operations
      coreutils && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment variables and enable jemalloc for reduced memory usage and latency.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems (including pg native extension)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libyaml-dev \
      pkg-config \
      # Required for building pg gem
      libpq-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock vendor ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times.
# -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Final stage for app image
FROM base

# Create directories for backups and storage with proper permissions
RUN mkdir -p /rails/storage /rails/backups /rails/tmp && \
    chmod 755 /rails/storage /rails/backups /rails/tmp

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails /rails

USER 1000:1000

# Copy built artifacts: gems, application
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# Declare volumes for persistent storage
VOLUME ["/rails/storage", "/rails/backups"]

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
