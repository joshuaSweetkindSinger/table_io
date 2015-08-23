#!/usr/bin/env ruby
require_relative '../delimited_table_io/delimited_table_io'

# This file is invokable via the Command-line: Test the functionality in the TableIo module.
# On command line: > ./do_tests.rb

# This module defines all the tests in the test suite for validating the TableIo module.
module TableIoTests
  # This module defines helper functions for testing
  module Helpers
    # Return true if file1 and file2 are identical; otherwise, return false.
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

  # This defines the testing framework we will use. The actual tests are defined
  # beneath this module definition.
  module Framework
    # This is a base class that provides a with_run_scaffold method that realizes the test framework.
    # It should be invoked inside the run() method of the derived class.
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
      # scaffold with a block that returns true if and only if the test passes. This framework
      # records whether the test has passed and whether it has run and prints out information to that effect.
      def with_test_scaffold
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
  end



  # This module defines the test suite for testing the TableIo module.
  module Suite
    include Framework

    THIS_DIR = File.dirname(__FILE__)

    # This is the top-level function. Right now it only has one test.
    def self.do_tests
      tests = [TestSameFormat.new]
      tests.each {|test| test.run}
    end


    # Test that we can read in a csv file and write it back out unaltered from the original.
    class TestSameFormat < Test
      include Helpers

      def run
        input_filename            = "#{THIS_DIR}/events.csv"
        output_filename           = "#{THIS_DIR}/events.out.csv"
        canonical_output_filename = "#{THIS_DIR}/events_correct_output.csv"

        with_test_scaffold do
          Pipe.source(input_filename)
          .pipe(TableIo::Delimited::Reader.new)
          .pipe(TableIo::Delimited::Writer.new)
          .pipe(Pipe.sink(output_filename))

          files_identical?(canonical_output_filename, output_filename)
        end
      end
    end
  end
end



# This file is invokable via the Command-line: Test the functionality in the TableIo module.
TableIoTests::Suite.do_tests