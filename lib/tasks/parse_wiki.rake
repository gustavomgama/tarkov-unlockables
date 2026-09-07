# frozen_string_literal: true

namespace :wiki do
  desc "Parse officialwiki itembatches into parsed_items.json"
  task parse: :environment do
    py = File.expand_path("~/.pyvenv-tarkov/bin/python")
    script = Rails.root.join("lib/wiki_parser/parse_itembatches.py")
    system(py, script.to_s) or abort "wiki parse failed"
  end
end
