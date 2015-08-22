require_relative '../table_io'

# This file defines the class TableIo::Delimited::Reader.
# A Delimited::Reader object knows how to read records from a delimited table.
# It is initialized from a file stream that is opened to the table in question.
# It turns the stream into an enumeration of records. If delim_reader is a Delimited::Reader object,
# initialized to the stream "my_table.csv", then delim_reader is an iterator of the records
# in "my_table.csv" and delim_reader.each is an enumeration of the same.
#   Use a delimited reader to read csv files (the default), as well as for any other kind of delimited file,
# such as a tab delimited file.
#    If the table's delimiter is not a comma, you must specify the delimiter when you initialize the Reader.
# The reader is capable of handling values that contain the delimiter itself. These values must be surrounded
# in double-quotes. The reader is also capable of reading values that include double-quotes. These must be
# escaped by using double-double-quotes, i.e., "" is used to represent a single double-quote within a value.
#
# The Delimited::Reader's primary public methods are already defined by its parent class. This file just defines
# the internal functionality necessary to realize the class.
module TableIo
  module Delimited
    class Reader < TableIo::Reader
      def initialize (stream = nil, delimiter = DEFAULT_DELIMITER)
        @delimiter = delimiter  # We must assign this before calling super, in case input_stream= is called by super.
        super(stream)
      end

      def header
        @row_reader.next
      end

      def input_stream= (stream)
        super(stream)
        @row_reader = RowReader.new(stream, @delimiter)
        stream
      end


      private

      # This helper class knows how to read and return the next row from the table as an array of strings.
      # It raises StopIteration if there is no row to read. This behavior is part of our contract with
      # the parent class IoTable::Reader.
      class RowReader
        def initialize(stream, delimiter)
          @input_stream = stream
          @value_reader = ValueReader.new(stream, delimiter)
        end


        # Iterate over rows in the table, representing each row as an array of strings, allowing
        # the associated block to process each value.
        def each
          loop {yield self.next}
        end


        # Return the next row of data from the delimited stream as an array of strings, or raise
        # StopIteration of their are no more rows, and close the input stream.
        def next
          row = @value_reader.each.inject([]) {|row, v| row << v}

          if row.empty?
            @input_stream.close
            raise StopIteration
          end

          row
        end
      end



      # This is a helper class used only by DelimitedReader. It knows how to read and
      # return the next string value from stream, and raises StopIteration at end-of-row
      class ValueReader
        def initialize (stream, delimiter)
          if (delimiter == QUOTE)
            raise 'Cannot use the double-quote character as a delimiter'
          end

          @input_stream               = stream
          @quoted_value_char_stream   = QuotedValueCharStream.new(stream, delimiter)
          @unquoted_value_char_stream = UnquotedValueCharStream.new(stream, delimiter)
        end


        # Iterate over values in the row, allowing
        # the associated block to process each value.
        def each
          if block_given?
            loop {yield self.next}
          else
            to_enum
          end
        end


        # Return the next value from within the current row, or raise StopIteration if we are at the end of the row.
        #
        # PROGRAMMER NOTES: There are two different parsing modes: quote_mode and !quote_mode. If the value
        # begins with a double-quote, then we are in quote mode, and we don't terminate the value until we find
        # its match. If the value does not begin with a double-quote, then we are in !quote_mode, and the value
        # terminates when we find the delimiter, or \n, or EOF.
        #    We don't distinguish EOF from end-of-row because the final row may not be terminated with a carriage-return.
        # This would raise an ambiguity as to whether we should raise EOF or EndOfRow. So we just raise StopIteration
        # in all cases. The caller has enough context to figure out which is which.
        def next
          c = @input_stream.getc
          raise StopIteration if c.nil? || c == ROW_END_CHAR

          char_stream = (c == QUOTE) ? @quoted_value_char_stream : @unquoted_value_char_stream
          @input_stream.ungetc(c) if char_stream == @unquoted_value_char_stream # We just read a character this reader needs--put it back
          char_stream.each.inject {|value, c| value << c}
        end



        # This is helper class for DelimitedValueReader. It knows how to read characters
        # from stream in the context of finding an unquoted value, until an end-of-value marker is reached.
        # An unquoted value is a value that does not begin with a double-quote.
        class UnquotedValueCharStream
          def initialize (stream, delimiter)
            @input_stream  = stream
            @delimiter     = delimiter
          end

          # Iterate through each character in stream until an end-of-value marker is reached,
          # yielding the characters to the block.
          def each
            if block_given?
              loop {yield self.next}
            else
              to_enum
            end
          end

          # Get the next character in stream, raising StopIteration when an end-of-value marker is reached.
          def next
            c = @input_stream.getc
            @input_stream.ungetc(c) if c == ROW_END_CHAR # Let the caller read this on the next attempt, in order to signal end-of-row

            raise 'Values with embedded double-quotes must be surrounded by double-quotes' if c == QUOTE
            raise StopIteration if c == ROW_END_CHAR || c == @delimiter || c.nil?

            c
          end
        end



        # This is helper class for DelimitedValueReader. It knows how to read characters
        # from stream in the context of finding a quoted value, until an end-of-value marker is reached.
        # A quoted value is a value that begins with a double-quote.
        class QuotedValueCharStream
          def initialize (stream, delimiter)
            @input_stream    = stream
            @delimiter = delimiter
          end


          # Iterate through each character in stream until an end-of-value marker is reached,
          # yielding the characters to the block.
          def each
            if block_given?
              loop {yield self.next}
            else
              to_enum
            end
          end


          # Get the next logical character in stream, raising StopIteration when the closing QUOTE mark is reached.
          # Note that it is possible to encounter a QUOTE char that is NOT the closing QUOTE mark, because quote
          # marks can be escaped by proceeding them with another quote mark. This sequence of two QUOTES one
          # right after the other is called a double-QUOTE, and it is returned as the single char QUOTE,
          # without raising a StopIteration signal.  All other chars evaluate to themselves.
          def next
            c = @input_stream.getc

            raise 'End of file encountered while searching for terminating double quote' if c.nil?

            return c if c != QUOTE

            # We just read a QUOTE. Examine the next character to figure out what logical char to return.
            c = @input_stream.getc
            @input_stream.ungetc(c) if c == ROW_END_CHAR # push this back on the stream to signal end-of-row next time.

            return QUOTE if c == QUOTE  # We found an escaped double-quote
            raise StopIteration if c == @delimiter || c.nil? || c == ROW_END_CHAR
            raise "The only valid character that can follow a double quote is a delimiter or another double quote. Instead got: [#{c}]"
          end
        end
      end
    end
  end
end

