#!/usr/bin/env ruby
require_relative '../delimited_table_io/delimited_table_io'


module TableIo
  module Tests
    THIS_DIR = File.dirname(__FILE__)

    def self.do_tests
      tests = [TestSameFormatUsingPipe.new]
      tests.each {|test| test.run}
    end

    module Helpers
      module_function

      def files_identical? (file1, file2)
        stream1 = File.open(file1)
        stream2 = File.open(file2)
        i = 0
        while stream1.each_char.next == stream2.each_char.next
          i += 1
        end
        raise StopIteration
      rescue StopIteration
        identical = stream1.eof? && stream2.eof?
        puts "Files differ. Stopped at char #{i}" if !identical
        stream1.close
        stream2.close
        identical
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

        if passed?
          print 'passed'
        else
          print 'failed'
        end
        puts
      end
    end



    # Test that we can read in a file and write it back out in the same format without problem.
    class TestSameFormat < Test
      include Helpers

      def run
        input_filename            = "#{THIS_DIR}/events.csv"
        output_filename           = "#{THIS_DIR}/events2.csv"
        canonical_output_filename = "#{THIS_DIR}/events_correct_output.csv"

        with_run_scaffold do
          File.open(input_filename) do |input_stream|
            reader = Delimited::Reader.new(input_stream)
            File.open(output_filename, 'w') do |output_stream|
              writer = Delimited::Writer.new(reader.each)
              writer.each {|c| output_stream.print(c)}
            end
          end

          files_identical?(canonical_output_filename, output_filename)
        end
      end
    end



    class TestSameFormatUsingPipe < Test
      include Helpers

      def run
        input_filename            = "#{THIS_DIR}/events.csv"
        output_filename           = "#{THIS_DIR}/events3.csv"
        canonical_output_filename = "#{THIS_DIR}/events_correct_output.csv"

        with_run_scaffold do
          Pipe::source(input_filename)
            .pipe(Delimited::Reader.new)
            .pipe(Delimited::Writer.new)
            .pipe(Pipe::sink(output_filename))

          files_identical?(canonical_output_filename, output_filename)
        end
      end
    end
  end
end


# Invoked via the Command-line: do record formatting from the file specified as the first command line arg.
TableIo::Tests::do_tests