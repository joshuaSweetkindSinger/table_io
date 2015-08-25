require_relative 'pipe'

# This file implements three of the four base classes that provide the infrastructure
# for table processing: Reader, Writer, and Record. The fourth class is StreamProcessor,
# which is defined in pipe.rb.
#    The instantiable classes are in their own sub-directories. See the
# directory delimited_table_io for an example.


module TableIo
  include Pipe


  # ===========================================================================
  #                           Record
  # ===========================================================================
  # A Record object represents a single row from a table. It is implemented as a thin wrapper
  # around a Hash object.
  #    The record has accessor methods for each column name. Thus, if the table
  # has a column called 'foo', and r is a record, then r.foo is its 'foo' value.
  # The raw record information is stored in the member variable @hash, with @hash[column_name.to_sym] being
  # the record's value for column_name. The record knows the original order of its columns
  # in the table. These are stored in @columns.
  # ATTENTION: Since hash keys are turned into symbols, you cannot access the value of the 'foo'
  # column of a record r via r.hash['foo']. Instead you would use r.hash[:foo]. Better still,
  # just use r.foo.
  class Record
    attr_accessor :hash, :columns

    # Create a Record object from row_values, which should be an array of string values,
    # and from row_columns, which should be an array of corresponding column names.
    def initialize (row_columns, row_values)
      @hash = {}
      @columns = row_columns
      row_columns.each_with_index do |column_name, index|
        @hash[column_name.to_sym] = row_values[index]
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
    def each
      raise "This method must be defined by a derived class."
    end
  end
end