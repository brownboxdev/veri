# Veri: Minimal Authentication Framework for Rails

[![Gem Version](https://badge.fury.io/rb/veri.svg)](http://badge.fury.io/rb/veri)
[![Github Actions badge](https://github.com/brownboxdev/veri/actions/workflows/ci.yml/badge.svg)](https://github.com/brownboxdev/veri/actions/workflows/ci.yml)

Veri is a cookie-based authentication library for Ruby on Rails that provides essential authentication building blocks without imposing business logic. Unlike full-featured solutions, Veri gives you complete control over your authentication flow while handling the complex underlying mechanics of secure password storage and session management.

**Key Features:**

- Cookie-based authentication with database-stored sessions
- Multiple password hashing algorithms (argon2, bcrypt, scrypt)
- Granular session management and control
- Return path handling
- User impersonation feature
- Account lockout functionality

> ⚠️ **Development Notice**<br>
> Veri is functional but in early development. Breaking changes may occur in minor releases until v1.0!

## Table of Contents

**Gem Usage:**
  - [Installation](#installation)
  - [Configuration](#configuration)
  - [Password Management](#password-management)
  - [Controller Integration](#controller-integration)
  - [Authentication Sessions](#authentication-sessions)
  - [Account Lockout](#account-lockout)
  - [View Helpers](#view-helpers)
  - [Testing](#testing)

**Community Resources:**
  - [Getting Help and Contributing](#getting-help-and-contributing)
  - [License](#license)
  - [Code of Conduct](#code-of-conduct)

## Installation

Add Veri to your Gemfile:

```rb
gem "veri"
```

Install the gem:

```bash
bundle install
```

Generate the migration for your user model (replace `users` with your user table name if different):

```shell
# For standard integer IDs
rails generate veri:authentication users

# For UUID primary keys
rails generate veri:authentication users --uuid
```

Run the migration:

```shell
rails db:migrate
```

## Configuration

If customization is required, configure Veri in an initializer:

```rb
# These are the default values; you can change them as needed
Veri.configure do |config|
  config.hashing_algorithm = :argon2       # Password hashing algorithm (:argon2, :bcrypt, or :scrypt)
  config.inactive_session_lifetime = nil   # Session inactivity timeout (nil means sessions never expire due to inactivity)
  config.total_session_lifetime = 14.days  # Maximum session duration regardless of activity
  config.user_model_name = "User"          # Your user model name
end
```

## Password Management

Your user model is automatically extended with password management methods:

```rb
# Set or update a password
user.update_password("new_password")

# Verify a password
user.verify_password("submitted_password")
```

## Controller Integration

### Basic Setup

Include the authentication module and configure protection:

```rb
class ApplicationController < ActionController::Base
  include Veri::Authentication

  with_authentication # Require authentication by default
end

class PicturesController < ApplicationController
  skip_authentication only: [:index, :show] # Allow public access to index and show actions
end
```

### Authentication Methods

This is a simplified example of how to use Veri's authentication methods:

```rb
class SessionsController < ApplicationController
  skip_authentication except: [:destroy]

  def create
    user = User.find_by(email: params[:email])

    if user&.verify_password(params[:password])
      log_in(user)
      redirect_to return_path || dashboard_path
    else
      flash.now[:alert] = "Invalid credentials"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    log_out
    redirect_to root_path
  end
end
```

Available methods:

- `current_user` - Returns authenticated user or `nil`
- `logged_in?` - Returns `true` if user is authenticated
- `log_in(user)` - Authenticates user and creates session, returns `true` on success or `false` if account is locked
- `log_out` - Terminates current session
- `return_path` - Returns path user was accessing before authentication
- `current_session` - Returns current authentication session

### User Impersonation (Shapeshifting)

Veri provides user impersonation functionality that allows, for example, administrators to temporarily assume another user's identity:

```rb
module Admin
  class ImpersonationController < ApplicationController
    def create
      user = User.find(params[:user_id])
      current_session.shapeshift(user)
      redirect_to root_path, notice: "Now viewing as #{user.name}"
    end

    def destroy
      original_user = current_session.true_identity
      current_session.revert_to_true_identity
      redirect_to admin_dashboard_path, notice: "Returned to #{original_user.name}"
    end
  end
end
```

Available session methods:

- `shapeshift(user)` - Assume another user's identity (maintains original identity)
- `revert_to_true_identity` - Return to original identity
- `shapeshifted?` - Returns true if currently shapeshifted
- `true_identity` - Returns original user when shapeshifted, otherwise current user

Controller helper:

- `shapeshifter?` - Returns true if the current session is shapeshifted

### When unauthenticated

Override this private method to customize authentication behavior:

```rb
class ApplicationController < ActionController::Base
  include Veri::Authentication

  with_authentication

  # ...

  private

  # Customize unauthenticated user handling
  def when_unauthenticated
    # By default redirects back with a fallback to the root path if the request format is HTML,
    # otherwise responds with 401 Unauthorized
    redirect_to login_path
  end
end
```

## Authentication Sessions

Veri stores authentication sessions in the database, providing session management capabilities:

### Session Access

```rb
# Get all sessions for a user
user.veri_sessions

# Get current session in controller
current_session
```

### Session Information

```rb
session.identity
# => authenticated user
session.info
# => {
#   device: "Desktop",
#   os: "macOS",
#   browser: "Chrome",
#   ip_address: "1.2.3.4",
#   last_seen_at: "2023-10-01 12:00:00"
# }
```

### Session Status

```rb
session.active?     # Session is active (neither expired nor inactive)
session.inactive?   # Session exceeded inactivity timeout
session.expired?    # Session exceeded maximum lifetime
```

### Session Management

```rb
# Terminate a specific session
session.terminate

# Terminate all sessions for a user
Veri::Session.terminate_all(user)

# Clean up expired/inactive sessions
Veri::Session.prune           # All sessions
Veri::Session.prune(user)     # Specific user's sessions
```

## Account Lockout

Veri provides account lockout functionality to temporarily disable user accounts (for example, after too many failed login attempts or for security reasons).

```rb
# Lock a user account
user.lock!

# Unlock a user account
user.unlock!

# Check if account is locked
user.locked?
```

When an account is locked, users cannot log in. If they're already logged in, their sessions will be terminated and they'll be treated as unauthenticated users.

## View Helpers

Access authentication state in your views:

```erb
<% if logged_in? %>
  <p>Welcome, <%= current_user.name %>!</p>
  <% if shapeshifter? %>
    <p><em>Currently viewing as <%= current_user.name %> (Original: <%= current_session.true_identity.name %>)</em></p>
    <%= link_to "Return to Original Identity", revert_path, method: :patch %>
  <% end %>
  <%= link_to "Logout", logout_path, method: :delete %>
<% else %>
  <%= link_to "Login", login_path %>
<% end %>
```

## Testing

Veri doesn't provide test helpers, but you can easily create your own:

### Request Specs (Recommended)

```rb
module AuthenticationHelpers
  def log_in(user)
    password = "test_password"
    user.update_password(password)
    post login_path, params: { email: user.email, password: }
  end

  def log_out
    delete logout_path
  end
end

# In your spec_helper.rb
RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
```

### Controller Specs (Legacy)

```rb
module AuthenticationHelpers
  def log_in(user)
    controller.log_in(user)
  end

  def log_out
    controller.log_out
  end
end

# In your spec_helper.rb
RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :controller
end
```

## Getting Help and Contributing

### Getting Help
Have a question or need assistance? Open a discussion in our [discussions section](https://github.com/brownboxdev/veri/discussions) for:
- Usage questions
- Implementation guidance
- Feature suggestions

### Reporting Issues
Found a bug? Please [create an issue](https://github.com/brownboxdev/veri/issues) with:
- A clear description of the problem
- Steps to reproduce the issue
- Your environment details (Rails version, Ruby version, etc.)

### Contributing Code
Ready to contribute? You can:
- Fix bugs by submitting pull requests
- Improve documentation
- Add new features (please discuss first in our [discussions section](https://github.com/brownboxdev/veri/discussions))

Before contributing, please read the [contributing guidelines](https://github.com/brownboxdev/veri/blob/main/CONTRIBUTING.md)

## License

The gem is available as open source under the terms of the [MIT License](https://github.com/brownboxdev/veri/blob/main/LICENSE.txt).

## Code of Conduct

Everyone interacting in the Veri project is expected to follow the [code of conduct](https://github.com/brownboxdev/veri/blob/main/CODE_OF_CONDUCT.md).
