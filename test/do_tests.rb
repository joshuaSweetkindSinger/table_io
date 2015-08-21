#!/usr/bin/env ruby
require '~/Documents/personal/dev/table_io/delimited_table_io/delimited_table_io'


module TableIo
  module Test
    def self.files_identical? (file1, file2)
      File.open(file1) do |stream1|
        File.open(file2) do |stream2|
          while (!stream1.eof? || !stream2.eof?) && (stream1.getc == stream2.getc)
          end
          stream1.eof? && stream2.eof?
        end
      end
    end


    def self.do_tests
      print 'testing same format . . . '
      if test_same_format
        print 'passed'
      else
        print 'failed'
      end
      puts
    end


    # Test that we can read in a file and write it back out in the same format without problem.
    def self.test_same_format
      File.open('test1.csv') do |input_stream|
        reader = Delimited::Reader.new(input_stream)
        File.open('test2.csv', 'w') do |output_stream|
          writer = Delimited::Writer.new(reader.each)
          writer.each {|c| output_stream.print(c)}
        end
      end
      files_identical?('test2.csv', 'test1_correct_output.csv')
    end

    def self.test_same_format_using_pipe
      Pipe.new('test1.csv') >> DelimitedTableReader >> DelimitedTableWriter >> 'test2.csv'
    end
  end
end

# Invoked via the Command-line: do record formatting from the file specified as the first command line arg.
TableIo::Test::do_tests