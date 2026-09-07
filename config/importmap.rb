# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "controllers/filter_group_controller", to: "controllers/filter_group_controller.js"
pin "controllers/view_toggle_controller", to: "controllers/view_toggle_controller.js"
