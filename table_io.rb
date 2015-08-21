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
# A Reader object is initialized from a stream opened to a table and turns it into an enumeration of Record objects.
# A Writer object is initialized from a reader object and turns it back into an enumeration of characters representing the table.
#
# If r is a Reader, then r.each is an enumeration of the records of its source table. Also, r.columns is an
# array of strings representing the names of the table's columns, in column-order. Note that the first element
# of the enumeration is *not* the column header. You only get that via r.columns.

# If w is a Writer, then w.each is an enumeration of the character sequence that represents the source records.
# Since this is a text representation of the table, the initial characters in the sequence *will* be the table's
# column header, which defines the column names and column order of the table.
#
# Currently this file implements readers and writers for delimited files, such as csv or tab-delimited, as well
# as readers and writers for JSON and XML formats. These latter two are mainly for show, to prove that the architecture
# is extensible. It is unlikely one would really want to use these formats in real life.
#
# The top-level instantiable classes are DelimitedReader, DelimitedWriter, JsonReader, JsonWriter, XmlReader, and XmlWriter.

module TableIo
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
  # A Reader object is initialized from a stream that is opened to the table in question.
  # It turns the stream into an enumeration of its records. If r is a reader,
  # initialized to stream my_table, then r.each is an enumeration of that table's records.
  #   This is a base class. It is not instantiable. For an example of an instantiable class, see DelimitedReader.
  #   Derived classes must define a @row_reader member variable: an object with a next() method that returns the next
  # row of the table from the stream as an array of strings, or raises StopIteration if there are no more rows to read.
  # Derived classes must also define a header() method that reads and returns the table's column definitions as an array of strings.
  # It is assumed that the column definitions will be the first row or rows of the table.
  class Reader
    attr_reader :columns

    def initialize (stream)
      @stream     = stream
      @columns    = nil
      @row_reader = nil # This needs to be initialized by the derived class.
    end

    # Read and return the next row from the stream as a Record object, or raise StopIteration if
    # we are end-of-file.
    def next
      @columns = header if !@columns
      Record.new(@row_reader.next, @columns)
    end

    def each
      if block_given?
        loop {yield self.next}
      else
        to_enum
      end
    end
  end


  # ===========================================================================
  #                           Writer (Base Class)
  # ===========================================================================
  # A Writer object is initialized from a record stream, which is an enumeration
  # of the successive records of the table to be written. The Reader sub-classes
  # in this project have each() methods that return suitable record streams.
  #    The Writer object turns this into another enumeraton: an enumeration of the character sequence that represents
  # the table, according to the writer's format. If w is a Writer object,
  # initialized from a stream of records belonging to my_table, then w.each is an enumeration of the character
  # sequence that represents my_table according to w's format.
  #    This is a base class. It is not instantiable. For an example of an instantiable class,
  # see DelimitedWriter.
  #    Derived classes must define a record_to_string(record) method that converts record
  # into its string representation, including any row-termination character.
  #    Derived classes must also define a header(columns) method that returns the string representation
  # of columns to be the column header for the table. It is assumed that this should occupy the initial characters of the table's
  # text representation.
  class Writer
    def initialize (record_stream)
      @record_stream  = record_stream
      @record_writer  = nil     # This needs to be initialized by the derived class.
      @header_written = false
      @buffer = '' # This buffer holds the characters in the table representation as we decode them from successive records.
                   # Characters are returned from the buffer when next() is called.
    end

    def each
      if block_given?
        loop {yield self.next}
      else
        to_enum
      end
    end

    # Return the next character in the string representation of the table.
    def next
      if !@header_written
        record = @record_stream.next
        @buffer << header(record.columns)
        @header_written = true
        @buffer << record_to_string(record)
      end

      if @buffer.empty?
        @buffer << record_to_string(@record_stream.next)
      end
      c = @buffer[0]
      @buffer[0] =''
      c
    end

    private

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