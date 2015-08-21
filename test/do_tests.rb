#!/usr/bin/env ruby
require '~/Documents/personal/dev/table_io/delimited_table_io/delimited_table_io'


module TableIo
  module Tests
    def self.do_tests
      tests = [TestSameFormat.new, TestSameFormatUsingPipe.new]
      tests.each {|test| test.run}
    end

    def self.files_identical? (file1, file2)
      File.open(file1) do |stream1|
        File.open(file2) do |stream2|
          while (!stream1.eof? || !stream2.eof?) && (stream1.getc == stream2.getc)
          end
          stream1.eof? && stream2.eof?
        end
      end
    end



    class Test
      def initialize
        @passed = false
        @has_run = false
      end

      def name
        self.class.name
      end

      def passed?
        @passed
      end


      def has_run?
        @has_run
      end

      # A small framework for running a test. The actual test
      # is defined by the run method of the derived class, which should invoke this
      # scaffold with a test block that returns true if and only if the test passes. This framework
      # records whether the test has passed and whether it has run and prints out information to that effect.
      def with_run_scaffold
        print "testing #{name} . . . "

        @passed  = yield
        @has_run = true

        if test.passed?
          print 'passed'
        else
          print 'failed'
        end
        puts
      end
    end



    # Test that we can read in a file and write it back out in the same format without problem.
    class TestSameFormat < Test
      def run
        with_run_scaffold do
          File.open('test1.csv') do |input_stream|
            reader = Delimited::Reader.new(input_stream)
            File.open('test2.csv', 'w') do |output_stream|
              writer = Delimited::Writer.new(reader.each)
              writer.each {|c| output_stream.print(c)}
            end
          end

          files_identical?('test1_correct_output.csv', 'test2.csv')
        end
      end
    end



    class TestSameFormatUsingPipe
      def run
        with_run_scaffold do
          source('test1.csv') >> Delimited::Reader.pipe >> Delimited::Writer.pipe >> sink('test2.csv')
          files_identical?('test1_correct_output.csv', 'test2.csv')
        end
      end
    end
  end
end


# Invoked via the Command-line: do record formatting from the file specified as the first command line arg.
TableIo::Tests::do_tests