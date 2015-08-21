# This file implements the TableIO module, which knows how to read and write
# records/rows stored as table-data in a number of different formats, such as csv.
# The architecture is extensible so that new readers and writers
# can be defined for different formats.
#
# The functionality of this module can be used to read records from a spreadsheet one at a time,
# possibly altering them, or filtering them, and then writing them back out to a file using a possibly
# different table format. It can also be used to generate new spreadsheets by generating their records/rows
# one at a time and then writing them out in the desired format. Or it can be used simply to to convert
# a spreadsheet from one format to another.
#
# There are three main types of objects: Reader, Writer, and Record.
# A Record object is a generic representation of a record in a table: it maps column names to their values.
# A Reader object is initialized from a stream opened to a table and turns it into an iterator of Record objects, also called a "record stream".
# A Writer object is initialized from a record stream and turns it back into an iterator of characters representing the table.
#
# If r is a Reader, then r is an iterator of the records of its source table,
# and r.each is an enumeration of the same. Also, r.columns is an
# array of strings representing the names of the table's columns, in column-order. Note that the first element
# of the enumeration is *not* the column header. You only get that via r.columns.

# If w is a Writer, then w is an iterator of the character sequence that represents the source records,
# and w.each is an enumeration of the same. Since this is a text representation of the table,
# the initial characters in the sequence *will* be the table's
# column header, which defines the column names and column order of the table. If r is a Reader, then both r
# and r.each are suitable initializers for a Writer object. The former is preferred.
#
# Currently this file implements readers and writers for delimited files, such as csv or tab-delimited, as well
# as readers and writers for JSON and XML formats. These latter two are mainly for show, to prove that the architecture
# is extensible. It is unlikely one would really want to use these formats in real life.
#
# The top-level instantiable classes are DelimitedReader, DelimitedWriter, JsonReader, JsonWriter, XmlReader, and XmlWriter.

module TableIo
  # This module contains methods common to all readers and writers
  module Common
    # Iterate through each of the records in the table, passing them in turn to the block for processing,
    # or return an Enumeration if no block is given.
    def each
      if block_given?
        loop {yield self.next}
      else
        to_enum
      end
    end
  end
  # ===========================================================================
  #                           Record
  # ===========================================================================
  # A Record object represents a single row from the table.
  # The record has accessor methods for each column name. Thus, if the table
  # has a column called 'foo', and r is a record, then r.foo is its 'foo' value.
  # The raw record information is stored in the member variable @hash, with @hash[column_name] being
  # the record's value for column_name. The record knows the original order of its columns
  # in the table. These are stored in @columns.
  class Record
    attr_accessor :hash, :columns

    def initialize (row, columns)
      @hash = {}
      @columns = columns
      columns.each_with_index do |column_name, index|
        @hash[column_name] = row[index]
      end
    end


    def to_s
      "#{@hash}"
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
  # A Reader object is initialized from a file stream that is opened to the table in question.
  # If r is a reader, initialized to the stream my_table, then r is an iterator of that table's records, and r.each
  # is an enumeration of the same.
  #   This is a base class. It is not instantiable. For an example of an instantiable class, see DelimitedReader.
  #   Derived classes must define a @row_reader member variable: an object with a next() method that returns the next
  # row of the table from the stream as an array of strings, or raises StopIteration if there are no more rows to read.
  # Derived classes must also define a header() method that reads and returns the table's column definitions as an array of strings.
  # It is assumed that the column definitions will be the first row or rows of the table.
  class Reader
    include Common
    attr_reader :columns

    def initialize (stream)
      @stream     = stream
      @columns    = nil
      @row_reader = nil # This needs to be initialized by the derived class.
    end

    # Return the next row from the stream as a Record object, or raise StopIteration if
    # we are end-of-file.
    def next
      @columns = header if !@columns
      Record.new(@row_reader.next, @columns)
    end
  end


  # ===========================================================================
  #                           Writer (Base Class)
  # ===========================================================================
  # A Writer object is initialized from a record iterator of the successive records
  # of the table to be written. The Reader sub-classes
  # in this project provide objects that are suitable record iterators.
  #   If w is a Writer object, initialized from a record iterator belonging to my_table,
  # then w is an iterator of the character sequence that represents my_table according to w's format,
  # and w.each is an enumeration of the same.
  #    This is a base class. It is not instantiable. For an example of an instantiable class,
  # see DelimitedWriter.
  #    Derived classes must define a record_to_string(record) method that converts record
  # into its string representation, including any row-termination character.
  #    Derived classes must also define a header(columns) method that returns the string representation
  # of columns to be the column header for the table. It is assumed that this should occupy the initial characters of the table's
  # text representation.
  class Writer
    include Common
    
    # Inputs: record_stream is a record iterator, an instance of one of the Reader subclasses.
    def initialize (record_stream)
      @record_stream  = record_stream
      @record_writer  = nil     # This needs to be initialized by the derived class.
      @header_written = false
      @buffer = '' # This buffer holds the characters in the table representation as we decode them from successive records.
                   # Characters are returned from the buffer when next() is called.
    end

    # Return the next character in the string representation of the table
    # represented by the record stream from which we were initialized, or raise StopIteration
    # if there are no more records.
    def next
      write_record(@record_stream.next) if @buffer.empty?
      pop_buffer
    end

    private

    # Write out record to our internal buffer so that its characters can be returned
    # via successive calls to next(). If the header has not yet been written, write
    # that out first.
    def write_record (record)
      write_header(record) if !@header_written
      @buffer << record_to_string(record)
    end

    # Write out the header to our internal buffer so that its characters can be returned
    # via successive calls to next()
    def write_header (record)
      @buffer << header(record.columns)
      @header_written = true
    end

    # pop the first character off of our internal buffer.
    def pop_buffer
      c = @buffer[0]
      @buffer[0] = ''
      c
    end


    # Write record to @stream using our format. The public method is write(). See above.
    def record_to_string (record)
      raise "The record_to_string() method must be defined by a subclass of Writer. You can't instantiate a Writer object directly."
    end

    # Write a column header to the stream.
    def header (columns)
      raise "The header() method must be defined by a subclass of Writer. You can't instantiate a Writer object directly."
    end
  end



  # ===========================================================================
  #                           Useful Functions Facilitating Pipes
  # ===========================================================================
  # It can be convenient to pipe readers and writers together for the purpose
  # of translating and/or filtering tables. These functions facilitate that.

  # Create a new instance of output_class, initialized with input_iterator providing its input.
  # This effectively creates a pipe with input from input_iterator and output from the newly-created
  # instance of output_class, which itself will be an iterator.
  def >> (input_iterator, output_class)
    output_class.new(input_iterator)
  end

  def source(filename)
    SourceFile.new filename
  end

  def sink(filename)
    SinkFile.new filename
  end

  class SourceFile
    def initialize (filename)
      @file = File.open(filename)
    end

    def next
      @file.readchar
    rescue EOFError
      @file.close
      raise StopIteration
    end
  end


  class SinkFile
    def initialize (filename)
      @file = File.open(filename, 'w')
    end

    def next
      @file.readchar
    rescue EOFError
      @file.close
      raise StopIteration
    end
  end

end