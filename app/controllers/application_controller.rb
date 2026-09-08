class ApplicationController < ActionController::Base
  include LooseSearchable

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, CSS :has.
  allow_browser versions: :modern
end
