# frozen_string_literal: true

module Importers
  # Shared shape for the importers that read one JSON file: the subclass sets
  # SOURCE and implements `#import!`, this supplies the class-level entry point,
  # the source handling and a memoized parse of the file.
  class JsonImport
    def self.import!(source: self::SOURCE)
      new(source).import!
    end

    def initialize(source)
      @source = source
    end

    private

    def records
      @records ||= JSON.parse(File.read(@source))
    end
  end
end
