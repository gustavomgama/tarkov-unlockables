# frozen_string_literal: true

module Jev
  # The scorecard dimensions. Every dimension is a Score question: four levels
  # describing concrete situations, so a 2 always means the same thing across
  # files and a mean across files is meaningful.
  #
  # The instructions point Jev at the state fields it may use (path, content,
  # tests, dependencies) and, for security, say explicitly that a weakness
  # prevented by a file outside the state is not a weakness in this file. That
  # is what stops a dev-only default from scoring as a hardcoded secret.
  module Rubrics
    DIMENSIONS = {
      security: {
        instructions: "How much security risk does `path` carry, judging only the code in " \
                      "`content` and the files in `dependencies`? Do not assume a weakness " \
                      "that a guard in a file you cannot see would prevent, and do not count a " \
                      "development-only default that a visible guard refuses to boot " \
                      "production without.",
        criteria: [
          "No security-relevant surface: formatting, constants, or config with no secrets, " \
          "inputs, or authorization decisions.",
          "Handles input or configuration through safe framework defaults; no injection, " \
          "authorization gap, or secret exposure is visible.",
          "A plausible weakness is visible in this file: unsanitized interpolation, a missing " \
          "authorization check, permissive parameter handling, or secret-adjacent code that no " \
          "visible guard neutralizes.",
          "A clear, exploitable vulnerability is visible: SQL/command/template injection, " \
          "missing authorization, a hardcoded secret reachable in production, unsafe " \
          "deserialization, or mass assignment of privileged attributes."
        ]
      },
      performance: {
        instructions: "How much runtime performance risk does `path` carry at this application's " \
                      "scale (a read-mostly dataset of a few thousand rows)?",
        criteria: [
          "No runtime cost of note.",
          "Straightforward queries and loops; fine at this application's scale.",
          "Likely inefficiency at scale: an N+1 query, an unbounded collection load, repeated " \
          "work inside a loop, or a missing index use.",
          "Severe: loads entire tables into memory, queries per record in a hot path, or has " \
          "pathological complexity."
        ]
      },
      code_quality: {
        instructions: "How maintainable and clearly written is `path`?",
        criteria: [
          "Clear, cohesive, well named; easy to change.",
          "Readable with minor smells; slightly long or duplicated.",
          "Tangled: mixed responsibilities, deep conditionals, unclear naming, or hidden coupling.",
          "Very hard to change safely: a god object or function, pervasive duplication, or logic " \
          "that resists tests."
        ]
      },
      correctness_risk: {
        instructions: "How likely is `path` to behave incorrectly or break on real inputs? Use " \
                      "`tests` and `dependencies` as context.",
        criteria: [
          "Trivial or fully guarded; little room to be wrong.",
          "Ordinary logic; errors handled and edge cases plausible.",
          "Fragile: relies on unstated assumptions, swallows errors, or mishandles nil, empty, " \
          "or boundary inputs.",
          "Likely wrong: an incorrect algorithm, inverted condition, unhandled failure path, or " \
          "data-corrupting behavior."
        ]
      },
      test_adequacy: {
        instructions: "How adequate is the test coverage for the behavior in `path`? `tests` " \
                      "holds the test files found for this path; an empty `tests` means none " \
                      "were found.",
        criteria: [
          "No meaningful behavior to test, or the behavior is simple and clearly exercised.",
          "Core behavior is covered, or is the kind that obviously should be; edge cases are thin.",
          "Partially covered: only the happy path, or tests exist but assert little.",
          "Untested behavior with real branching and failure modes, and no test file was found."
        ]
      },
      over_engineering: {
        instructions: "How much unnecessary complexity does `path` carry: speculative " \
                      "abstraction, reinvented standard library, unneeded indirection or " \
                      "dependencies?",
        criteria: [
          "Nothing to cut; uses the standard library and framework directly.",
          "Mild: a little indirection or configuration that could be inlined.",
          "Speculative abstraction, needless indirection, or a reinvented standard library.",
          "Heavy: a framework within a framework, dead flexibility, or a dependency for what one " \
          "line would do."
        ]
      },
      error_handling: {
        instructions: "How well does `path` handle failure: external calls, bad input, missing " \
                      "records, and partial writes? A top-level entry point (a seed, a rake task, " \
                      "a script) that lets an exception propagate so the operation aborts loudly is " \
                      "handling failure correctly when the work is atomic — do not score it as " \
                      "unhandled. Judge what the code itself does with a failure: a rescue that " \
                      "swallows it, a failure path that continues, or a write that can leave " \
                      "partial state.",
        criteria: [
          "No failure modes to handle, or every failure is explicitly handled.",
          "Failures are handled with reasonable defaults or user-facing errors.",
          "Incomplete: a bare rescue, a swallowed exception, or a failure path that silently " \
          "continues.",
          "Missing or wrong: an unhandled exception on an expected failure, or a rescue that " \
          "hides a data-corrupting outcome."
        ]
      },
      data_integrity: {
        instructions: "How well does `path` protect the integrity of the stored data: " \
                      "validations, database constraints, referential integrity, and safe writes?",
        criteria: [
          "No data writes or schema surface.",
          "Writes are validated and constrained in the ordinary Rails way.",
          "Gaps: a write path without validation, a missing uniqueness or foreign-key constraint, " \
          "or a destructive migration that is not reversible.",
          "Dangerous: a write that can corrupt or orphan data, a non-reversible destructive " \
          "migration, or a mass update with no guard."
        ]
      }
    }.freeze

    def self.keys
      DIMENSIONS.keys
    end

    # Files with a test convention get the whole scorecard. Infrastructure and
    # config files have no tests to judge and no runtime hot path, so asking
    # about them only produces noise: a Dockerfile scored 1.5 on test adequacy
    # at confidence 0.0, and the CI workflow scored 2.3 at 0.26. A `.rb` file
    # under config/, db/ or bin/ is still infrastructure whatever its
    # extension, so it is exempt for the same reason.
    CODE_EXTENSIONS = %w[.rb .erb .js .rake].freeze
    INFRA_ONLY = %i[test_adequacy performance].freeze
    INFRA_PATHS = %r{\A(?:config|db|bin|lib/tasks)/}.freeze

    def self.applicable(path)
      return keys - INFRA_ONLY if INFRA_PATHS.match?(path)
      return keys if CODE_EXTENSIONS.include?(File.extname(path))

      keys - INFRA_ONLY
    end

    # The questions map sent to the API, one Score question per applicable
    # dimension for this path.
    def self.questions_for(path)
      applicable = applicable(path)
      DIMENSIONS.filter_map { |id, rubric| question(id, rubric) if applicable.include?(id) }
    end

    def self.questions
      DIMENSIONS.map { |id, rubric| question(id, rubric) }
    end

    def self.question(id, rubric)
      { id: id, type: "score", instructions: rubric[:instructions], criteria: rubric[:criteria] }
    end
    private_class_method :question
  end
end
