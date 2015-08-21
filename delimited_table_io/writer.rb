require '~/Documents/personal/dev/table_io/table_io'

# This file defines the class TableIo::Delimited::Writer.
# A Delimited::Writer object knows how to write records from a record stream into a delimited
# file format. It is initialized from a record stream whose next() method returns successive Record
# objects (see table.rb for the definition of Record).
#    It turns the record stream into a character stream. If delim_writer is a Delimited::Writer object,
# initialized from the record stream my_stream, then delim_writer is an iterator of the characters
# representing my_stream, and delim_writer.each is an enumeration of the same.
#   Use a delimited writer to write csv files (the default), as well as for any other kind of delimited file,
# such as a tab delimited file.
#    If the table's delimiter is not a comma, you must specify the delimiter when you initialize the Writer.
# The writer is capable of handling values that contain the delimiter itself. These values will be surrounded
# in double-quotes. The writer is also capable of writing values that include double-quotes. These will be
# escaped by using double-double-quotes, i.e., "" is used to represent a single double-quote within a value.
#
# The Delimited::Writer's public methods are already defined by its parent class. This file just defines
# the internal functionality necessary to realize the class.
module TableIo
  module Delimited
    class Writer < TableIo::Writer
      DEFAULT_DELIMITER = ','
      QUOTE = '"'         # This is the character that can be used to wrap a value containing the delimiter.
      ROW_END_CHAR = "\n" # This is the character that terminates rows of a table.

      def initialize (stream = nil, delimiter = DEFAULT_DELIMITER)
        if (@delimiter == QUOTE)
          raise 'Cannot use the double-quote character as a delimiter'
        end

        @delimiter = delimiter
        @row = '' # Used to build up a string representing a row before returning it.

        super(stream)
      end


      private

      def header (columns)
        columns.each do |column_name|
          add_to_row column_name
        end
        write_row
      end

      def record_to_string (record)
        record.columns.each do |column_name|
          add_to_row record.hash[column_name]
        end
        write_row
      end


      # Put the value v into the next cell in the spreadsheet, performing any necessary
      # escape modifications so that it is acceptable for output, e.g.,
      # making sure it is a string, that delimiter chars are escaped, etc.
      def add_to_row (v)
        @row << @delimiter unless @row.empty? # Write a cell separator if this is not the first cell in the row
        @row << escape_value(v)               # Write the escaped value.
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

        if value.include?(@delimiter)  || value.include?('"')   # surround it with double quotes if it contains the delimiter or double quotes.
          value = '"' + value + '"'
        end

        value
      end


      # Return the row we've been building up and reset it to the empty string.
      def write_row
        result = @row + ROW_END_CHAR
        @row = ''
        result
      end
    end
  end
end

