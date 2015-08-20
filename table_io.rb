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

module TableIo
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
  # A Reader object is initialized from a source object--typically a stream, that is opened
  # to the table in question.
  #   It knows how to read and return the next record from the table. It is an external
  # iterator, and calling to_enum() on it will return an Enumerable.
  #   This is a base class. It is not instantiable. See, for example, DelimitedReader.
  # Derived classes must define the read_row() method.
  #  Note that this class does not define a stream argument as input to initialize, because
  # the base class does not make use of it. In principle, a subclass of Reader could be initialized
  # from a source other than a stream. All the reader needs to be able to do is implement read_row().
  # In practice, subclasses will have initialize() methods that accept a stream arg.
  class Reader
    attr_reader :columns

    def initialize
      @columns = read_row # grab the header row that describes the table's columns
    end



    # Read and return the next row from the stream as a Record object, or raise StopIteration if
    # we are end-of-file.
    def next
      row = read_row
      if row
        Record.new(row, @columns)
      else
        raise StopIteration
      end
    end


    def each
      loop {yield self.next}
    end


    private

    # Read the next row from the source object and return it as an array of string values, or
    # return nil if there are no more rows.
    def read_row
      raise "The read_row() method must be defined by a subclass of Reader. You can't instantiate a Reader object directly."
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
  #  This is a base class. It is not instantiable. See, for example, DelimitedWriter. Derived classes
  # must define write_record() and write_header() methods.
  class Writer
    def initialize (stream, columns, options = {})
      @stream         = stream
      @columns        = columns
      @options        = {write_header: true}.merge(options)
      @header_written = false
    end

    # Write record to @stream, possibly writing a header first if necessary.
    def write (record)
      if !@header_written && @options[:write_header]
        write_header
        @header_written = true
      end

      write_record record
    end

    private

    # Write record to @stream using our format. The public method is write(). See above.
    def write_record (record)
      raise "The write_record() method must be defined by a subclass of Writer. You can't instantiate a Writer object directly."
    end

    # Write a column header to the stream.
    def write_header
      raise "The write_header() method must be defined by a subclass of Writer. You can't instantiate a Writer object directly."
    end
  end
end