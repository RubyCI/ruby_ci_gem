# frozen_string_literal: true

module RubyCI
  class  ExtractDescriptions
    def call(example_group, count: false)
      data = {}

      data[scoped_id(example_group)] = {
        description: description(example_group),
        line_number: line_number(example_group),
      }

      if count
        data[:test_count] ||= 0
        data[:test_count] += RSpec.world.example_count([example_group])
      end

      example_group.examples.each do |ex|
        data[scoped_id(example_group)][scoped_id(ex)] = {
          line_number: line_number(ex),
          description: description(ex),
        }
      end

      example_group.children.each do |child|
        data[scoped_id(example_group)].merge! call(child)
      end

      data
    end

    def scoped_id(example_group)
      example_group.metadata[:scoped_id].split(":").last
    end

    def line_number(example_group)
      example_group.metadata[:line_number]
    end

    def description(example_group)
      example_group.metadata[:description]
    end
  end
end