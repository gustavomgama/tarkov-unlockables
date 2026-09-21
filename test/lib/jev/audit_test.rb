# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class Jev::AuditTest < ActiveSupport::TestCase
  setup do
    @env = ENV.to_h.slice("JEV_BASE", "GITHUB_BASE_REF")
    ENV.delete("JEV_BASE")
    ENV.delete("GITHUB_BASE_REF")
  end

  teardown do
    ENV.delete("JEV_BASE")
    ENV.delete("GITHUB_BASE_REF")
    @env.each { |key, value| ENV[key] = value }
  end

  def ok_result(path, confidence: 0.9, **scores)
    answers = scores.to_h do |dimension, score|
      [ dimension.to_s, { "score" => score, "confidence" => confidence } ]
    end
    Jev::Scorecard::Result.new(path: path, answers: answers, model: "m",
                               usage: { "input_tokens" => 10, "output_tokens" => 5 })
  end

  def error_result(path)
    Jev::Scorecard::Result.new(path: path, error: "boom")
  end

  def scorecard_returning(results)
    Object.new.tap do |card|
      card.define_singleton_method(:judge) { |_paths| results }
    end
  end

  def audit_for(results)
    Jev::Audit.new(files: results.map(&:path), scorecard: scorecard_returning(results)).run
  end

  # ── gate ───────────────────────────────────────────────────────────────

  test "gates only on severe dimensions with enough confidence" do
    results = [
      ok_result("a.rb", security: 2.6, code_quality: 3.0, correctness_risk: 1.0),
      ok_result("b.rb", security: 2.9, confidence: 0.4),
      ok_result("c.rb", error_handling: 2.5),
      error_result("d.rb")
    ]

    audit = audit_for(results)

    assert_equal [ [ "a.rb", :security ], [ "c.rb", :error_handling ] ],
                 audit.violations.map { |violation| [ violation[:path], violation[:dimension] ] }
    refute audit.pass?
  end

  test "a clean scorecard passes" do
    audit = audit_for([ ok_result("a.rb", security: 1.0, code_quality: 3.0) ])

    assert audit.pass?
    assert_empty audit.violations
  end

  test "an audit where every judgment failed is blind, not passing" do
    audit = audit_for([ error_result("a.rb"), error_result("b.rb") ])

    assert audit.blind?
    refute audit.pass?
    assert_equal 2, audit.failed.length
  end

  test "an audit with no files to judge is not blind" do
    audit = audit_for([])

    refute audit.blind?
    assert audit.pass?
  end

  test "a partial failure still passes but is reported" do
    audit = audit_for([ ok_result("a.rb", security: 1.0), error_result("b.rb") ])

    refute audit.blind?
    assert audit.pass?
    assert_includes audit.summary, "1 judgment(s) failed"
  end

  # ── aggregation ────────────────────────────────────────────────────────

  test "stats average each dimension and count flags" do
    results = [ ok_result("a.rb", security: 1.0, code_quality: 2.0), ok_result("b.rb", security: 3.0) ]

    stats = audit_for(results).stats

    assert_equal 2, stats[:security][:judged]
    assert_equal 2.0, stats[:security][:mean]
    assert_equal 1, stats[:security][:flagged]
    assert_equal 0.9, stats[:security][:confidence]
    assert_equal 0, stats[:performance][:judged]
    assert_equal 0.0, stats[:performance][:mean]
  end

  test "worst ranks files by the sum of their scores" do
    results = [ ok_result("a.rb", security: 1.0), ok_result("b.rb", security: 2.0) ]

    assert_equal [ "b.rb", "a.rb" ], audit_for(results).worst.map(&:path)
  end

  test "usage totals sum both counters across results" do
    audit = audit_for([ ok_result("a.rb", security: 1.0), error_result("b.rb") ])

    assert_equal({ input: 10, output: 5 }, audit.usage_totals)
  end

  test "model falls back to the configured model when nothing was judged" do
    assert_equal Jev::MODEL, audit_for([]).model
    assert_equal "m", audit_for([ ok_result("a.rb", security: 1.0) ]).model
  end

  # ── report ─────────────────────────────────────────────────────────────

  test "the markdown report lists dimensions, worst files, violations and failures" do
    audit = audit_for([ ok_result("a.rb", security: 2.9), error_result("b.rb") ])

    markdown = audit.to_markdown

    assert_includes markdown, "# Jev scorecard"
    assert_includes markdown, "| security |"
    assert_includes markdown, "| a.rb |"
    assert_includes markdown, "## Gate violations"
    assert_includes markdown, "`b.rb` — boom"
  end

  test "a clean report says there is nothing to gate or report" do
    markdown = audit_for([ ok_result("a.rb", security: 1.0) ]).to_markdown

    assert_includes markdown, "## Gate violations\n\nNone."
    assert_includes markdown, "## Failed judgments\n\nNone."
  end

  test "the summary prints a line per judged dimension and a total" do
    summary = audit_for([ ok_result("a.rb", security: 1.0) ]).summary

    assert_includes summary, "security"
    assert_includes summary, "total"
    assert_includes summary, "1 files"
    refute_includes summary, "data_integrity"
  end

  test "write puts both artifacts under the report directory" do
    Dir.mktmpdir do |dir|
      audit = audit_for([ ok_result("a.rb", security: 1.0) ])

      assert_equal dir, audit.write(dir: dir)
      assert File.exist?(File.join(dir, "scorecard.md"))
      assert_equal 1, JSON.parse(File.read(File.join(dir, "scorecard.json")))["files"].length
    end
  end

  # ── selection ──────────────────────────────────────────────────────────

  test "glob returns the source files that exist, sorted" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "app/models"))
      FileUtils.mkdir_p(File.join(dir, "config"))
      File.write(File.join(dir, "app/models/item.rb"), "")
      File.write(File.join(dir, "app/models/barter.rb"), "")
      File.write(File.join(dir, "config/puma.rb"), "")
      # A directory whose name matches a glob is not a source file.
      FileUtils.mkdir_p(File.join(dir, "app/models/directory.rb"))

      assert_equal [ "app/models/barter.rb", "app/models/item.rb", "config/puma.rb" ],
                   Jev::Audit.glob(dir)
    end
  end

  test "glob includes the python data pipeline" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "datastore/scripts"))
      FileUtils.mkdir_p(File.join(dir, "lib/wiki_parser"))
      FileUtils.mkdir_p(File.join(dir, "lib/tasks"))
      File.write(File.join(dir, "datastore/scripts/20_build_canonical.py"), "")
      File.write(File.join(dir, "lib/wiki_parser/parse_itembatches.py"), "")
      File.write(File.join(dir, "lib/tasks/ci.rake"), "")

      assert_equal [ "datastore/scripts/20_build_canonical.py",
                     "lib/tasks/ci.rake",
                     "lib/wiki_parser/parse_itembatches.py" ],
                   Jev::Audit.glob(dir)
    end
  end

  test "changed builds an audit from the first ref that produces a diff" do
    calls = []
    git = lambda do |args|
      calls << args
      [ "app/models/item.rb\n", true ]
    end

    audit = Jev::Audit.changed(root: "/repo", base: "base", git: git)

    assert_equal [ "app/models/item.rb" ], audit.files
    assert_equal "/repo", audit.root
    assert_includes calls, [ "diff", "--name-only", "--diff-filter=ACMR", "base...HEAD" ]
  end

  test "changed excludes files outside the audit globs" do
    git = ->(_args) { [ "progress-jev.md\ntest/models/item_test.rb\napp/models/item.rb\n", true ] }

    assert_equal [ "app/models/item.rb" ], Jev::Audit.changed(root: "/repo", git: git).files
  end

  test "select unions staged, unstaged and untracked files onto the ref diff" do
    git = lambda do |args|
      case args.last
      when "base...HEAD" then [ "committed.rb\n", true ]
      when "--diff-filter=ACMR" then [ "unstaged.rb\n", true ]
      when "--cached" then [ "staged.rb\n", true ]
      when "--exclude-standard" then [ "untracked.rb\n", true ]
      else [ "", false ]
      end
    end

    assert_equal %w[committed.rb unstaged.rb staged.rb untracked.rb],
                 Jev::Audit.select("/repo", "base", git)
  end

  test "select falls back to HEAD~1 when no ref produces a diff" do
    git = lambda do |args|
      args.last == "HEAD~1...HEAD" ? [ "lib/jev.rb\n", true ] : [ "fatal: no repo", false ]
    end

    assert_equal [ "lib/jev.rb" ], Jev::Audit.select("/repo", nil, git)
  end

  test "select returns nothing when no diff can be taken at all" do
    git = ->(_args) { [ "fatal: no repo", false ] }

    assert_equal [], Jev::Audit.select("/repo", nil, git)
  end

  test "JEV_BASE is used when no base is passed" do
    ENV["JEV_BASE"] = "upstream/master"
    seen = []
    git = lambda do |args|
      seen << args
      [ "", true ]
    end

    assert_equal [], Jev::Audit.select("/repo", nil, git)
    assert_includes seen, [ "diff", "--name-only", "--diff-filter=ACMR", "upstream/master...HEAD" ]
  end

  test "pr_base prefixes the GitHub base branch" do
    ENV["GITHUB_BASE_REF"] = "master"

    assert_equal "origin/master", Jev::Audit.pr_base
  end

  test "pr_base is nil without a GitHub base branch" do
    assert_nil Jev::Audit.pr_base
  end

  test "diff reads a real repository when no git runner is injected" do
    Dir.mktmpdir do |dir|
      init_repo(dir)

      assert_equal [ "b.rb" ], Jev::Audit.diff(dir, "HEAD~1", nil)
    end
  end

  test "diff returns nil when git cannot run" do
    assert_nil Jev::Audit.diff("/nonexistent-jev-repo", "HEAD~1", nil)
  end

  test "select picks up an untracked file in a real repository" do
    Dir.mktmpdir do |dir|
      init_repo(dir)
      File.write(File.join(dir, "new.rb"), "x")
      File.write(File.join(dir, "b.rb"), "changed")

      files = Jev::Audit.select(dir, "HEAD~1", nil)

      assert_includes files, "new.rb"
      assert_includes files, "b.rb"
    end
  end

  test "all builds an audit from the whole tree" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "app/models"))
      File.write(File.join(dir, "app/models/item.rb"), "")

      assert_equal [ "app/models/item.rb" ], Jev::Audit.all(root: dir).files
    end
  end

  test "run judges the selected files and returns itself" do
    results = [ ok_result("a.rb", security: 1.0) ]
    audit = Jev::Audit.new(files: [ "a.rb" ], scorecard: scorecard_returning(results))

    assert_equal audit, audit.run
    assert_equal [ "a.rb" ], audit.results.map(&:path)
    assert_equal 1, audit.ok.length
    assert_empty audit.failed
  end

  private

  def init_repo(dir)
    quiet = { out: File::NULL, err: File::NULL }
    system("git", "init", "-q", dir, **quiet)
    commit(dir, "a.rb", "one")
    commit(dir, "b.rb", "two")
  end

  def commit(dir, file, message)
    File.write(File.join(dir, file), file)
    system("git", "-C", dir, "add", file, out: File::NULL, err: File::NULL)
    system("git", "-C", dir, "-c", "user.email=ci@example.com", "-c", "user.name=CI",
           "commit", "-qm", message, out: File::NULL, err: File::NULL)
  end
end
