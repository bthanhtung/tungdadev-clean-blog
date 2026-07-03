FROM jekyll/builder:latest

# Set the working directory
WORKDIR /srv/jekyll

# Copy dependency files first for layer caching
COPY Gemfile Gemfile.lock ./

# Install Ruby dependencies
RUN bundle config set path 'vendor/bundle' && bundle install

# Copy the rest of the source code
COPY . .

# Expose Jekyll default port
EXPOSE 4000

# Default command to serve the blog
CMD ["bundle", "exec", "jekyll", "serve", "--host", "0.0.0.0"]
