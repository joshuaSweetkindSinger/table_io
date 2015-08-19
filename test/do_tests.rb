#!/usr/bin/env ruby
require '~/Documents/personal/dev/table_io/table_io'
require '~/Documents/personal/dev/table_io/delimited_table_io/delimited_reader'
require '~/Documents/personal/dev/table_io/delimited_table_io/delimited_writer'

module TableIo
  module Test
    def self.do_tests
      test_same_format
    end


    # Test that we can read in a file and write it back out in the same format without problem.
    def self.test_same_format
      File.open ('test1.csv') do |input_stream|
        reader = DelimitedReader.new(input_stream)
        File.open('test2.csv', 'w') do |output_stream|
          writer = DelimitedWriter.new(output_stream, reader.columns)
          writer.convert(reader)
        end
      end
    end
  end
end

# Invoked via the Command-line: do record formatting from the file specified as the first command line arg.
TableIo::Test::do_tests