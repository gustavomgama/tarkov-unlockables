# frozen_string_literal: true

require "pathname"

module Jev
  # Builds the state Jev judges for one file. The source alone cannot decide
  # test adequacy (a test file elsewhere decides it) or security (a guard in a
  # concern decides it), so the state carries the tests that cover the file and
  # the local files the source itself includes.
  class StateBuilder
    MAX_CONTEXT_BYTES = 24_000

    def initialize(root: Dir.pwd)
      @root = Pathname.new(root)
    end

    def call(path)
      {
        project: PROJECT,
        path: path,
        content: truncate(read(path)),
        tests: tests_for(path),
        dependencies: dependencies_for(path)
      }
    end

    private

    # Test files are matched by the conventional mirror path first
    # (app/models/item.rb -> test/models/item_test.rb), then by basename
    # anywhere under test/ for the files that live outside the mirror, then by
    # the controller test that renders a view. Only when none of those finds a
    # test is the slower content scan run: it covers a class whose test is named
    # after something else (seeds_test.rb covers
    # Importers::ItemTaskRewardResolver) without dragging every test that
    # mentions a common controller into the state.
    def tests_for(path)
      stem = path.sub(/\.[^.]+\z/, "")
      mirrored = stem.sub(%r{\A(?:app|lib)/}, "")
      candidates = [ @root.join("test", "#{mirrored}_test.rb") ]
      candidates.concat(@root.glob("test/**/#{File.basename(stem)}_test.rb"))
      # A nested source file's test is named after the path below its root:
      # app/models/item/ammo.rb -> test/models/item_ammo_test.rb.
      nested = stem.sub(%r{\A(?:app|lib)/[^/]+/}, "").tr("/", "_")
      candidates.concat(@root.glob("test/**/#{nested}_test.rb"))
      conventional = collect(candidates)
      return conventional if conventional.any?

      rendered_by = view_controller_tests(path)
      return rendered_by if rendered_by.any?

      collect(tests_naming(path))
    end

    # A view is exercised by the integration test of the controller that renders
    # it, so that test is the evidence of adequacy. The mapping is by path, not
    # by scanning, so it cannot claim an unrelated test.
    def view_controller_tests(path)
      return [] unless path.start_with?("app/views/")

      segments = path.split("/")[2..-2]
      return [] if segments.nil? || segments.empty?

      collect([ @root.join("test/controllers/#{segments.join('/')}_controller_test.rb") ])
    end

    # Only a specific constant is searched for: a generic basename ("show",
    # "table") would otherwise match every test file in the suite and report a
    # view as covered when nothing exercises it. The word boundary keeps
    # ApplicationHelper from matching Admin::ApplicationHelperTest.
    def tests_naming(path)
      name = subject_constant(path)
      return [] if name.nil?

      pattern = /\b#{Regexp.escape(name)}\b/
      test_files.select { |_file, content| pattern.match?(content) }.keys
    end

    def subject_constant(path)
      # Every extension, not just the last: group_component.html.erb is
      # GroupComponent, not GroupComponentHtml. A partial's leading underscore
      # is not part of the constant either.
      base = File.basename(path).split(".").first.sub(/\A_+/, "")
      return nil unless base.include?("_") || base.length >= 8

      base.camelize
    end

    def test_files
      @test_files ||= @root.glob("test/**/*_test.rb").to_h { |file| [ file, file.read ] }
    end

    # Only what the source itself names. An `include`d concern is exactly the
    # context that was missing when a controller's mass assignment looked
    # unsafe: the concern defines resource_params, so it decides the risk.
    def dependencies_for(path)
      collect(include_candidates(path) + env_guard_candidates(path))
    end

    def include_candidates(path)
      names = read(path).scan(/^\s*(?:include|extend|prepend)\s+([A-Z][A-Za-z0-9_:]*)/).flatten
      names.flat_map { |name| @root.glob("{app,lib}/**/#{name.underscore}.rb") }
    end

    # Config files are read together: an environment default is often guarded
    # in an initializer that names the same ENV key. Including those is what
    # stops `ENV["ADMIN_PASSWORD"] ||= "admin"` in development.rb from being
    # judged a hardcoded secret when production refuses to boot without one.
    def env_guard_candidates(path)
      return [] unless path.start_with?("config/")

      keys = read(path).scan(/ENV\[["']([A-Z0-9_]+)["']\]/).flatten.uniq
      return [] if keys.empty?

      @root.glob("config/initializers/*.rb").select do |file|
        keys.any? { |key| file.read.include?(key) }
      end
    end

    def collect(candidates)
      candidates.select(&:file?).uniq.to_h do |candidate|
        [ candidate.relative_path_from(@root).to_s, truncate(candidate.read) ]
      end
    end

    def read(path)
      file = @root.join(path)
      file.file? ? file.read : ""
    end

    def truncate(text)
      return text if text.bytesize <= MAX_CONTEXT_BYTES

      "#{text.byteslice(0, MAX_CONTEXT_BYTES)}\n... (truncated)"
    end
  end
end
