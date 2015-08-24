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
  # The raw record information is stored in the member variable @hash, with @hash[column_name.to_sym] being
  # the record's value for column_name. The record knows the original order of its columns
  # in the table. These are stored in @columns.
  # ATTENTION: Since hash keys are turned into symbols, you cannot access the value of the 'foo'
  # column of a record r via r.hash['foo']. Instead you would use r.hash[:foo]. Better still,
  # just use r.foo.
  class Record
    attr_accessor :hash, :columns

    # Create a Record object from row, which should be an array of string values,
    # and from columns, which should be an array of corresponding column names.
    def initialize (row, columns)
      @hash = {}
      @columns = columns
      columns.each_with_index do |column_name, index|
        @hash[column_name.to_sym] = row[index]
      end
    end


    def to_s
      "#{@hash}"
    end


    # This is how we provide Record objects with accessors named after their columns.
    def method_missing (column_name)
      column_name = column_name.to_sym

      if @hash.has_key? (column_name)
        @hash[column_name]
      end
    end
  end



  # ===========================================================================
  #                           Reader (Base Class)
  # ===========================================================================
  # A Reader object's input stream is a SourceFile stream (see pipe.rb) that is opened to a file representing a table.
  # If r is a reader, with input from the stream my_table, then r.each
  # is an enumeration of that table's records.
  #   This is a base class. It is not instantiable. For an example of an instantiable class, see DelimitedReader.
  #   Derived classes must define the each() method and yield a sequence of Record objects.
  #
  class Reader < StreamProcessor
    # Enumerate the table as a sequence of Record objects.
    def each
      raise "This method must be defined by a derived class."
    end
  end


  # ===========================================================================
  #
  #                    Writer (Base Class)
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
    end

    # Return the next character in the string representation of the table
    # represented by the record stream from which we were initialized, or raise StopIteration
    # if there are no more records.
    def each
      header_written = false
      self.input_stream.each do |record|
        buffer = ''

        if !header_written
          buffer << header(record.columns)
          header_written = true
        end

        buffer << record_to_string(record)

        buffer.each_char do |c|
          yield c
        end
      end
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