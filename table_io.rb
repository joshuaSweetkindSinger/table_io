#!/usr/bin/env ruby

# This file implements the TableIO module, which knows how to read and write
# records/rows stored as table-data in a number of different formats, such as csv.
# The architecture is extensible so that new readers and writers
# can be defined for different formats.
#
# The functionality of this module can be used to read records from a spreadsheet one at a time,
# possibly altering them, or filtering them, and then writing back out to a file using a possibly
# different table format. It can also be used to generate new spreadsheets by generating their records/rows
# one at a time and then writing them out in the desired format. Or it can be used simply to to convert
# a spreadsheet from one format to another. (See Writer.convert())
#
# A Reader object has a read() method that reads a new record/row from a spreadsheet and returns a Record object.
# A Writer object has a write() method that accepts a Record object and writes a new row to a spreadsheet.
#
# Currently this file implements readers and writers for delimited files, such as csv or tab-delimited, as well
# as readers and writers for JSON and XML formats. These latter two are mainly for show, to prove that the architecture
# is extensible. It is unlikely one would really want to use these formats in real life.
#
# The top-level instantiable classes are DelimitedReader, DelimitedWriter, JsonReader, JsonWriter, XmlReader, and XmlWriter.

module TableIO

  # ===========================================================================
  #                           Helper Module
  # ===========================================================================
  # This module contains helper functions for the TableIO module
  module Helper
    # Read the next value from our stream. Stream is comma-separated, and lines are terminated with a carriage return,
    # except if the value begins with a double quote, then read through commas and carriage returns until
    # the closing double quote.
    def get_next_value
      char = @stream.readchar
      stop_chars = (char == '"') ? '"' : ",\n"
      @stream.ungetc(char) if (char != '"')
      result = read_to_char(stop_chars)
      @stream.readchar if char == '"' # chomp the comma that will follow the closing double quote.
      result
    end


    # Read characters from our stream until one of the stop_chars is encountered.
    # Return a string of the characters read up to but not including the stop char.
    def read_to_char (stop_chars)
      result = ''
      while !@stream.eof? && !stop_chars.include?(c = @stream.readchar)
        result << c
      end
      result
    end
  end

  # ===========================================================================
  #                           Record
  # ===========================================================================
  # A Record object represents a single row from the spreadsheet.
  # The record has accessor methods for each column name. Thus, if the spreadsheet
  # has a column called 'foo', and r is a record, then r.foo is its 'foo' value.
  # The raw record information is stored in the member variable @hash, with @hash[column_name] being
  # the record's value for column_name.
  class Record
    attr_accessor :hash


    def initialize (row, columns)
      @hash = {}
      columns.each_with_index do |column_name, index|
        @hash[column_name] = row[index]
      end
    end


    # This is how we provide Record objects with accessors named after their columns.
    def method_missing (column_name)
      if @hash.has_key? (column_name)
        @hash[column_name]
      else
        raise "Unknown column name: #{column_name}"
      end
    end
  end

  # ===========================================================================
  #                           Reader (Base Class)
  # ===========================================================================
  # A Reader object is initialized from a stream that is opened to the spreadsheet in question.
  # It knows how to read and return the next record from the spreadsheet.
  # This is a base class. It is not instantiable.
  class Reader
    def initialize(stream)
      @stream = stream
    end

    # Read the next row from the stream and return it as a Record object.
    def read
      raise "The read() method must be defined by a subclass of Reader. You can't instantiate a Reader object directly."
    end

  end


  # ===========================================================================
  #                           Writer (Base Class)
  # ===========================================================================
  # A Writer object is initialized from a stream that is opened for writing, with the
  # intent of writing rows in a particular spreadsheet format, such as csv, or tab-delimited, etc.
  # It is told the stream to write to, the columns that should be written, and whether or not a
  # header row should be written. It then responds to write(record) commands, where record is taken
  # to be a record that contains the columns of interest. Note that the writer need not write all
  # the columns in record--just those it is asked to write.
  #  This is a base class. It is not instantiable. See, for example, DelimitedWriter
  class Writer
    def initialize (stream, columns, write_header)
      @stream       = stream
      @columns      = columns
      @write_header = write_header # Flag to tell us we need to write a header row.
    end


    # Write record to @stream using our format.
    def write (record)
      raise "The write() method must be defined by a subclass of Write. You can't instantiate a Writer object directly."
    end


    # Read the entire spreadsheet represented by reader and convert it to our format.
    def convert (reader)
      while r = reader.read
        write r
      end
    end
  end


  # ===========================================================================
  #                           Delimited Reader and Writer
  # ===========================================================================
  # A DelimitedReader object is initialized from a stream that is opened to the spreadsheet in question.
  # It knows how to read and return the next record from the spreadsheet. Use a delimited reader
  # for csv files (the default), and for any other kind of delimited file, such as tab delimited.
  # If the delimiter is not a comma, you must specify the delimiter when you initialize the Reader.
  class DelimitedReader < Reader
    DEFAULT_DELIMITER = ','

    def initialize (stream, delimiter = DEFAULT_DELIMITER)
      if (delimiter = '"')
        raise 'Cannot use the double-quote character as a delimiter'
      end

      super stream
      @delimiter = delimiter
      @columns   = get_row
    end


    # Return the next row from the delimited stream as a Record object.
    def read
      Record.new(get_row, @columns)
    end


    private

    # Return the next row of data from the delimited stream as an array of strings.
    def get_row
      @stream.readline().split(@delimiter)
    end
  end



  # Write records to @stream using a delimited format such as csv (the default).
  class DelimitedWriter < Writer
    DEFAULT_DELIMITER = ','


    def initialize (stream, columns, write_header, delimiter = DEFAULT_DELIMITER)
      if (delimiter = '"')
        raise 'Cannot use the double-quote character as a delimiter'
      end

      super stream, columns, write_header
      @delimiter = delimiter
    end


    def write (record)
      write_header if @write_header

      delimiter = ''
      @columns.each do |column_name|
        @stream.put delimiter
        @stream.put escape_value(record.hash[column_name])
        delimiter = @delimiter
      end
      @stream.puts # write a carriage return at the end of the row
    end


    # Handle proper escaping for csv values.
    # - If the value to be written is not a string, we need to turn it into one.
    # - If the string value to be written contains double quotes, we need to turn them into
    #   double double-quotes, e.g., 'the movie "Star Wars"' becomes 'the movie ""Star Wars""'
    # - If the string value to be written contains embedded delimiter characters,
    #   we need to surround it with double quotes, e.g.,
    #  'I like cookies, ice cream, cake' becomes '"I like cookies, ice cream, cake"'
    def escape_value (value)
      value = value.to_s                                      # turn it into a string
      value = value.gsub('"', '""')                           # turn all embedded double quotes into double double-quotes
      value = '"' + value + '"' if value.include?(@delimiter) # surround it with double quotes if it contains the delimiter.
      value
    end
  end

  # ===========================================================================
  #                           Test Routine
  # ===========================================================================

  # Do record formatting from filename.
  def self.test_it
    File.open ('test1.csv') do |input_stream|
      reader = DelimitedReader.new(input_stream)
      File.open('test1.xml', 'w') do |output_stream|
        writer = XmlWriter.new(output_stream)
        writer.convert(reader)
      end
    end
  end
end

# Invoked via the Command-line: do record formatting from the file specified as the first command line arg.
TableIO::test_it