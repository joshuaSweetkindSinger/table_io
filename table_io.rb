require_relative 'pipe'

# This file just implements the base classes that create the infrastructure. The instantiable classes
# are in their own sub-directories

module TableIo
  include Pipe
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
  # A Reader object's input stream is a SourceFile stream (see pipe.rb) that is opened to the table in question.
  # If r is a reader, with input from the stream my_table, then r is an iterator of that table's records, and r.each
  # is an enumeration of the same.
  #   This is a base class. It is not instantiable. For an example of an instantiable class, see DelimitedReader.
  #   Derived classes must define a @row_reader member variable: an object with a next() method that returns the next
  # row of the table from the stream as an array of strings, or raises StopIteration if there are no more rows to read.
  # Derived classes must also define a header() method that reads and returns the table's column definitions as an array of strings.
  # It is assumed that the column definitions will be the first row or rows of the table.
  class Reader < StreamProcessor
    attr_reader :columns

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
  class Writer < StreamProcessor
    # Inputs: record_stream is a record iterator, an instance of one of the Reader subclasses.
    def initialize
      @record_writer  = nil     # This needs to be initialized by the derived class.
      @header_written = false
      @buffer = '' # This buffer holds the characters in the table representation as we decode them from successive records.
                   # Characters are returned from the buffer when next() is called.
    end

    # Return the next character in the string representation of the table
    # represented by the record stream from which we were initialized, or raise StopIteration
    # if there are no more records.
    def next
      write_record(input_stream.next) if @buffer.empty?
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
end