# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"

module Jev
  # Selects the files to judge, runs the scorecard, renders the report, and
  # decides whether the result fails the build.
  #
  # The default scope is what a branch changed, because the scorecard calls a
  # paid API and runs on every push (bin/hooks/pre-push -> bin/ci). JEV_ALL=1
  # judges the whole tree; JEV_MODE=report never fails the build.
  class Audit
    GLOBS = %w[
      app/**/*.rb app/**/*.erb app/**/*.js
      lib/**/*.rb lib/**/*.py lib/**/*.rake config/**/*.rb config/**/*.yml
      datastore/**/*.py
      db/seeds.rb bin/* .github/workflows/*.yml
      Dockerfile render.yaml
    ].freeze

    # Only these dimensions can fail the build, and only at or above the
    # threshold with enough confidence to act on. A probabilistic score on code
    # style is a signal to report, not a verdict to gate on.
    SEVERE = {
      security: 2.5, correctness_risk: 2.5, data_integrity: 2.5, error_handling: 2.5
    }.freeze
    MIN_CONFIDENCE = 0.5
    FLAGGED_AT = 2.0

    attr_reader :files, :results, :root

    class << self
      def changed(root: Dir.pwd, base: nil, git: nil)
        files = select(root, base, git).select { |path| auditable?(path) }
        new(files: files, root: root)
      end

      # The changed scope uses the same globs as the full tree, so a changed
      # test, doc or built asset is not judged by the code rubrics.
      def auditable?(path)
        GLOBS.any? { |pattern| File.fnmatch?(pattern, path, File::FNM_PATHNAME | File::FNM_EXTGLOB) }
      end

      def all(root: Dir.pwd)
        new(files: glob(root), root: root)
      end

      def glob(root)
        Dir.glob(GLOBS, base: root).select { |path| File.file?(File.join(root, path)) }.sort
      end

      # A diff needs a base. JEV_BASE wins, then the PR base GitHub provides,
      # then origin/HEAD. When no ref produces a diff (shallow clone, no
      # remote), HEAD~1 is the last attempt; an empty list is not an error.
      #
      # The ref diff only sees commits. Staged, unstaged and untracked files are
      # unioned in on top, so a local run on a dirty tree judges the new code
      # instead of skipping exactly what most needs review. In CI the tree is
      # clean and the extra commands return nothing.
      def select(root, base, git)
        (committed(root, base, git) + working_tree(root, git)).uniq
      end

      def committed(root, base, git)
        refs = [ base, ENV["JEV_BASE"], pr_base, "origin/HEAD" ].compact.reject(&:empty?)
        refs.each do |ref|
          names = diff(root, ref, git)
          return names unless names.nil?
        end
        diff(root, "HEAD~1", git) || []
      end

      # Deletions are filtered out the same way the ref diff filters them: a
      # deleted file has no content to judge.
      def working_tree(root, git)
        [ [ "diff", "--name-only", "--diff-filter=ACMR" ],
          [ "diff", "--name-only", "--diff-filter=ACMR", "--cached" ],
          [ "ls-files", "--others", "--exclude-standard" ] ].flat_map do |args|
          output, status = git ? git.call(args) : capture(root, args)
          status ? output.split("\n").map(&:strip).reject(&:empty?) : []
        end
      end

      def pr_base
        ref = ENV["GITHUB_BASE_REF"].to_s
        ref.empty? ? nil : "origin/#{ref}"
      end

      # Returns the changed file names, or nil when the diff cannot be taken.
      def diff(root, ref, git)
        args = [ "diff", "--name-only", "--diff-filter=ACMR", "#{ref}...HEAD" ]
        output, status = git ? git.call(args) : capture(root, args)
        return nil unless status

        output.split("\n").map(&:strip).reject(&:empty?)
      end

      def capture(root, args)
        output, status = Open3.capture2e("git", *args, chdir: root)
        [ output, status.success? ]
      rescue SystemCallError
        [ "", false ]
      end
      private :capture
    end

    def initialize(files:, root: Dir.pwd, scorecard: Scorecard.new, dimensions: Rubrics.keys)
      @files = files
      @root = root
      @scorecard = scorecard
      @dimensions = dimensions
      @results = []
    end

    def run
      @results = @scorecard.judge(@files)
      self
    end

    def ok
      @results.select(&:ok?)
    end

    def failed
      @results.reject(&:ok?)
    end

    # Severe dimensions at or above their threshold, with enough confidence to
    # act on. Everything else is reported, never gated.
    def violations
      @results.flat_map { |result| violations_for(result) }
    end

    # No judgment came back at all. The gate is blind, not clean: an expired
    # key, an outage, or an exhausted rate limit must not read as a pass.
    def blind?
      @results.any? && ok.empty?
    end

    def pass?
      !blind? && violations.empty?
    end

    def stats
      @dimensions.to_h { |dimension| [ dimension, dimension_stats(dimension) ] }
    end

    def worst
      ok.sort_by { |result| -total(result) }
    end

    def total(result)
      @dimensions.sum { |dimension| answer_for(result, dimension).to_h.fetch("score") { 0 }.to_f }
    end

    def usage_totals
      @results.each_with_object({ input: 0, output: 0 }) do |result, totals|
        totals[:input] += result.usage.to_h.fetch("input_tokens") { 0 }.to_i
        totals[:output] += result.usage.to_h.fetch("output_tokens") { 0 }.to_i
      end
    end

    def model
      ok.first&.model || MODEL
    end

    def summary
      lines = @dimensions.filter_map do |dimension|
        row = stats[dimension]
        next if row[:judged].zero?

        format("  %-16s mean %.2f  flagged %2d  confidence %.2f",
               dimension, row[:mean], row[:flagged], row[:confidence])
      end
      totals = usage_totals
      lines << format("  %-16s %d files, %d in / %d out tokens",
                      "total", ok.length, totals[:input], totals[:output])
      lines << "  #{failed.length} judgment(s) failed" if failed.any?
      lines.join("\n")
    end

    def to_markdown
      lines = [ "# Jev scorecard", "" ]
      lines << "Model: `#{model}` · files judged: #{ok.length}/#{@files.length} · " \
               "dimensions: #{@dimensions.length}"
      lines << ""
      lines << "Each file is scored 0-3 per dimension (0 = no concern, 3 = severe); " \
               "means are probability-weighted."
      lines.concat(dimension_section)
      lines.concat(worst_section)
      lines.concat(violation_section)
      lines.concat(failure_section)
      "#{lines.join("\n")}\n"
    end

    def to_json_hash
      {
        model: model,
        dimensions: @dimensions,
        stats: stats,
        violations: violations,
        files: @results.map do |result|
          { path: result.path, error: result.error, answers: result.answers }
        end
      }
    end

    def write(dir: File.join(@root, "tmp", "jev"))
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "scorecard.md"), to_markdown)
      File.write(File.join(dir, "scorecard.json"), JSON.pretty_generate(to_json_hash))
      dir
    end

    private

    def dimension_section
      lines = [ "", "## Dimensions", "" ]
      lines << "| dimension | mean | flagged >= #{FLAGGED_AT} | mean confidence | judged |"
      lines << "| --- | --- | --- | --- | --- |"
      @dimensions.each do |dimension|
        row = stats[dimension]
        lines << "| #{dimension} | #{format('%.2f', row[:mean])} | #{row[:flagged]} | " \
                 "#{format('%.2f', row[:confidence])} | #{row[:judged]} |"
      end
      lines
    end

    def worst_section
      lines = [ "", "## Highest-risk files (sum of all dimension scores)", "" ]
      lines << "| file | sum | #{@dimensions.join(' | ')} |"
      lines << "| --- | --- | #{Array.new(@dimensions.length, '---').join(' | ')} |"
      worst.first(25).each do |result|
        scores = @dimensions.map do |dimension|
          format("%.2f", answer_for(result, dimension).to_h.fetch("score") { 0 }.to_f)
        end
        lines << "| #{result.path} | #{format('%.2f', total(result))} | #{scores.join(' | ')} |"
      end
      lines
    end

    def violation_section
      lines = [ "", "## Gate violations", "" ]
      lines << "None." if violations.empty?
      violations.each do |violation|
        lines << "- `#{violation[:path]}` — #{violation[:dimension]} " \
                 "#{format('%.2f', violation[:score])} " \
                 "(confidence #{format('%.2f', violation[:confidence])})"
      end
      lines
    end

    def failure_section
      lines = [ "", "## Failed judgments", "" ]
      lines << "None." if failed.empty?
      failed.each { |result| lines << "- `#{result.path}` — #{result.error}" }
      lines
    end

    def answer_for(result, dimension)
      result.answers.to_h[dimension.to_s]
    end

    # A result that failed to judge is not evidence of a clean file, so it
    # contributes no violations and no stats.
    def violations_for(result)
      return [] unless result.ok?

      SEVERE.filter_map { |dimension, threshold| violation(result, dimension, threshold) }
    end

    def violation(result, dimension, threshold)
      answer = answer_for(result, dimension)
      return if answer.nil?

      score = answer["score"].to_f
      confidence = answer["confidence"].to_f
      return if confidence < MIN_CONFIDENCE || score < threshold

      { path: result.path, dimension: dimension, score: score, confidence: confidence }
    end

    def dimension_stats(dimension)
      scores = ok.filter_map { |result| answer_for(result, dimension)&.dig("score") }
      confidences = ok.filter_map { |result| answer_for(result, dimension)&.dig("confidence") }
      {
        judged: scores.length,
        mean: mean(scores),
        flagged: scores.count { |score| score >= FLAGGED_AT },
        confidence: mean(confidences)
      }
    end

    def mean(values)
      return 0.0 if values.empty?

      values.sum / values.length.to_f
    end
  end
end
