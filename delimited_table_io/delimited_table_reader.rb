require '~/Documents/personal/dev/table_io/table_io'

# A DelimitedReader object is initialized from a stream that is opened to the table in question.
# It knows how to read and return the next record from the spreadsheet. Use a delimited reader
# for csv files (the default), and for any other kind of delimited file, such as tab delimited.
# If the delimiter is not a comma, you must specify the delimiter when you initialize the Reader.
# The reader is capable of handling values that contain the delimiter itself. These values must be surrounded
# in double-quotes. The reader is also capable of reading values that include double-quotes. These must be
# escaped by using double-double-quotes, i.e., "" is used to represent a single double-quote.
#
# The DelimitedReader's public methods are already defined by its parent class. This file just defines
# the internal functionality necessary to realize the class.
module TableIo
  class DelimitedTableReader < Reader
    DEFAULT_DELIMITER = ','

    def initialize (stream, delimiter = DEFAULT_DELIMITER)
      @row_reader = RowReader.new(stream, delimiter)
      super()
    end


    private

    # This helper class knows how to read and return the next row from the table as an array of strings.
    # It raises StopIteration if there is no row to read. This behavior is part of our contract with
    # the parent class IoTable::Reader.
    class RowReader
      def initialize(stream, delimiter)
        @value_reader = ValueReader.new(stream, delimiter)
      end


      # Iterate over rows in the table, representing each row as an array of strings, allowing
      # the associated block to process each value.
      def each
        loop {yield self.next}
      end


      # Return the next row of data from the delimited stream as an array of strings, or return
      # nil if there are no more rows.
      def next
        row = @value_reader.each.inject([]) {|row, v| row << v}
        raise StopIteration if row.empty?
        row
      end
    end




    # This is a helper class used only by DelimitedReader. It knows how to read and
    # return the next string value from stream, and raises StopIteration at end-of-row
    class ValueReader
      def initialize (stream, delimiter)
        if (delimiter == '"')
          raise 'Cannot use the double-quote character as a delimiter'
        end

        @stream                     = stream
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
        c = @stream.getc
        raise StopIteration if c.nil? || c == "\n"

        char_stream = (c == '"') ? @quoted_value_char_stream : @unquoted_value_char_stream
        @stream.ungetc(c) if char_stream == @unquoted_value_char_stream # We just read a character this reader needs--put it back
        char_stream.each.inject {|value, c| value << c}
      end



      # This is helper class for DelimitedValueReader. It knows how to read characters
      # from stream in the context of finding an unquoted value, until an end-of-value marker is reached.
      # An unquoted value is a value that does not begin with a double-quote.
      class UnquotedValueCharStream
        def initialize (stream, delimiter)
          @stream    = stream
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

        # Get the next character in stream, raising StopIteration when an end-of-value marker is reached.
        def next
          c = @stream.getc
          @stream.ungetc(c) if c == "\n" # Let the caller read this on the next attempt, in order to signal end-of-row

          raise 'Values with embedded double-quotes must be surrounded by double-quotes' if c == '"'
          raise StopIteration if c == "\n" || c == @delimiter || c.nil?

          c
        end
      end



      # This is helper class for DelimitedValueReader. It knows how to read characters
      # from stream in the context of finding a quoted value, until an end-of-value marker is reached.
      # A quoted value is a value that begins with a double-quote.
      class QuotedValueCharStream
        def initialize (stream, delimiter)
          @stream    = stream
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


        # Get the next logical character in stream, raising StopIteration when an end-of-value marker is reached.
        #   All chars evaluate to themselves except the double double-quote,
        # which is two double quotes in a row, i.e., "". These two chars evaluate to a single logical char,
        # which is returned as the string '""'
        def next
          c = @stream.getc

          raise "End of file encountered while searching for terminating double quote" if c.nil?

          return c if c != '"'

          # We just read a double-quote. Examine the next character to figure out what logical char to return.
          c = @stream.getc

          @stream.ungetc(c) if c == "\n" # push this back on the stream to signal end-of-row next time.

          return '"' if c == '"'  # We found an escaped double-quote

          raise StopIteration if c == @delimiter || c.nil? || c == "\n"
          raise "The only valid character that can follow a double quote is a delimiter or another double quote. Instead got: [#{cc}]"
        end
      end
    end
  end
end
