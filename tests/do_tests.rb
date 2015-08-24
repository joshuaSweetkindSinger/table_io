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
      tests = [Test1.new, Test2.new, Test3.new]
      tests.each {|test| test.run}
    end


    # Test that we can read in a csv file and write it back out unaltered.
    class Test1 < Test
      include Helpers

      def run
        input_filename  = "#{THIS_DIR}/tables/events.csv"
        output_filename = "#{THIS_DIR}/tables/unaltered_events.csv"
        canonical_output_filename = "#{THIS_DIR}/tables/unaltered_events_correct_output.csv"

        with_test_scaffold do
          Pipe.source(input_filename)              # Read the input file
          .pipe(TableIo::Delimited::Reader.new)    # convert it from csv file format to records
          .pipe(TableIo::Delimited::Writer.new)    # convert records back to csv file format.
          .pipe(Pipe.sink(output_filename))        # write the tab-delimited file to disk.

          files_identical?(canonical_output_filename, output_filename)
        end
      end
    end



    # Test that we can read in a csv file and write it back out as a tab-delimited file
    class Test2 < Test
      include Helpers

      def run
        input_filename  = "#{THIS_DIR}/tables/events.csv"
        output_filename = "#{THIS_DIR}/tables/tabbed_events.txt"
        canonical_output_filename = "#{THIS_DIR}/tables/tabbed_events_correct_output.txt"

        with_test_scaffold do


          Pipe.source(input_filename)              # Read the input file
          .pipe(TableIo::Delimited::Reader.new)    # convert it from csv file format to records
          .pipe(TableIo::Delimited::Writer.new("\t"))  # convert records to tab-delimited file format.
          .pipe(Pipe.sink(output_filename))        # write the tab-delimited file to disk.

          files_identical?(canonical_output_filename, output_filename)
        end
      end
    end



    # Test that we can read in a csv file and write it back out as a filtered, tab-delimited file.
    # Filter out all records except those whose event is "shopping". Strip the "extra notes" field out.
    class Test3 < Test
      include Helpers

      def run
        input_filename  = "#{THIS_DIR}/tables/events.csv"
        output_filename = "#{THIS_DIR}/tables/filtered_events.txt"
        canonical_output_filename = "#{THIS_DIR}/tables/filtered_events_correct_output.txt"

        with_test_scaffold do


          Pipe.source(input_filename)              # Read the input file
          .pipe(TableIo::Delimited::Reader.new)    # convert it from csv file format to records
          .pipe(FilterToShopping.new)              # filter and massage the records to just those containing the "shopping" event
          .pipe(StripNotes.new)                    # Strip off the "extra notes" column
          .pipe(TableIo::Delimited::Writer.new("\t"))  # convert records to tab-delimited file format.
          .pipe(Pipe.sink(output_filename))        # write the tab-delimited file to disk.

          files_identical?(canonical_output_filename, output_filename)
        end
      end


      # This class filters the source records to just those whose "event" column matches the string "shopping"
      class FilterToShopping < Pipe::StreamProcessor
        def each
          self.input_stream.each do |record|
            if record.event == 'shopping'
              yield record
            end
          end
        end
      end


      # This class removes the "extra notes" column from each record
      class StripNotes < Pipe::StreamProcessor
        def each
          self.input_stream.each do |record|
            record.hash.delete('extra notes')
            record.columns[extra_notes_column_index(record), 1] = [] # delete this column
            yield record
          end
        end

        # Return the index of the 'extra notes' column
        def extra_notes_column_index (record)
          @extra_notes_column_index ||= find_column_index(record, 'extra notes')
        end

        def find_column_index (record, column_to_find)
          record.columns.each_with_index do |column_name, index|
            return index if column_name == column_to_find
          end
        end
      end
    end
  end
end




# This file is invokable via the Command-line: Test the functionality in the TableIo module.
TableIoTests::Suite.do_tests