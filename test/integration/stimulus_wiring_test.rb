require "test_helper"

# Static check across the JavaScript/markup boundary, which no other test sees:
# a Stimulus controller that nothing mounts ships dead JS to every visitor, and
# a declared target that no markup provides fails at runtime with "Missing
# target element" — the bug class that already hit the view toggle on
# empty-result pages.
#
# The assertions are deliberately about *declarations*, not about behaviour:
# whether a target is guarded per page is up to the controller (view-toggle
# checks `hasGridTarget` before using it).
class StimulusWiringTest < ActiveSupport::TestCase
  CONTROLLERS_DIR = Rails.root.join("app/javascript/controllers")
  MARKUP_DIRS = %w[app/views app/components].freeze

  # Methods that Stimulus calls itself; they are never wired in markup.
  LIFECYCLE = %w[connect disconnect initialize].freeze

  def markup
    @markup ||= MARKUP_DIRS.flat_map { |dir| Rails.root.glob("#{dir}/**/*.erb") }
                           .map(&:read)
                           .join("\n")
  end

  # Yields [name, kebab-name, source] for every Stimulus controller.
  def each_controller
    Rails.root.glob("app/javascript/controllers/*_controller.js").sort.each do |path|
      name = path.basename(".js").to_s.sub(/_controller\z/, "")
      yield name, name.tr("_", "-"), path.read
    end
  end

  test "every Stimulus controller is mounted in the markup" do
    each_controller do |name, kebab, _source|
      # Three spellings the app uses: the literal attribute, the same attribute
      # built with ERB inside the value (filter-options is conditional), and the
      # Rails `data: { controller: ... }` hash.
      mounted = markup.match?(/data-controller=".*\b#{Regexp.escape(kebab)}\b/) ||
                markup.include?("controller: \"#{kebab}\"") ||
                markup.include?("controller: '#{kebab}'")

      assert mounted, "#{name}_controller.js is never mounted (no data-controller=\"#{kebab}\")"
    end
  end

  test "every declared target and action method is wired in the markup" do
    each_controller do |name, kebab, source|
      targets = source[/static targets = \[(.*?)\]/m, 1].to_s.scan(/"(\w+)"/).flatten
      targets.each do |target|
        # Literal attribute or the Rails hash (`search_target: "input"`).
        declared = markup.include?("data-#{kebab}-target=\"#{target}\"") ||
                   markup.include?("#{name}_target: \"#{target}\"")

        assert declared,
               "#{name}_controller.js declares target \"#{target}\" but no element declares " \
               "data-#{kebab}-target=\"#{target}\""
      end

      (source.scan(/^\s{2}(\w+)\(/).flatten - LIFECYCLE).each do |method|
        # `->name#action` or the `name#action` shorthand; a method called only
        # from another method in the same file is internal, not dead wiring
        # (the definition line does not count as a call).
        wired = markup.match?(/->\s*#{Regexp.escape(kebab)}##{method}\b/) ||
                markup.match?(/#{Regexp.escape(kebab)}##{method}\b/)
        internal = source.match?(/this\.#{method}\(/) ||
                   source.scan(/^\s+#{method}\(/).size > 1

        assert(wired || internal, "#{name}_controller.js defines ##{method} but nothing wires or calls it")
      end
    end
  end
end
