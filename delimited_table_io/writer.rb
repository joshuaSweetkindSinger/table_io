require_relative '../table_io'

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

      def initialize (delimiter = DEFAULT_DELIMITER)
        super()

        if (@delimiter == QUOTE)
          raise 'Cannot use the double-quote character as a delimiter'
        end

        @delimiter = delimiter
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

      # Return a string representing the column header of the table.
      def header (columns)
        row = Row.new(@delimiter)
        columns.each do |column_name|
          row.add column_name
        end
        row.finalize
      end

      # Return a string representing record.
      def record_to_string (record)
        row = Row.new(@delimiter)
        record.columns.each do |column_name|
          row.add record.send(column_name)
        end
        row.finalize
      end
    end


    # Row is a small helper class. It represents a string object that understands delimited
    # rows and allows values to be added to the row one at a time. It also massages/sanitizes
    # values that are added to the row, escaping them when necessary.
    class Row
      def initialize (delimiter)
        @delimiter = delimiter
        @row = ''
      end

      # Put the value v into the next cell in the row, performing any necessary
      # escape modifications so that it is acceptable for output, e.g.,
      # making sure it is a string, that delimiter chars are escaped, etc.
      def add (v)
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

        # surround it with double quotes if it contains the delimiter or double quotes or a carriage return.
        if value.include?(@delimiter) ||
          value.include?(QUOTE) ||
          value.include?(ROW_END_CHAR)

          value = '"' + value + '"'
        end

        value
      end


      # Return the row we've been building up, and terminate it properly.
      def finalize
        @row << ROW_END_CHAR
      end
    end
  end
end


