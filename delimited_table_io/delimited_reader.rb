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
  class DelimitedReader < Reader
    DEFAULT_DELIMITER = ','

    def initialize (stream, delimiter = DEFAULT_DELIMITER)
      @value_reader  = DelimitedValueReader.new(stream, delimiter)
      super
    end


    private

    # Return the next row of data from the delimited stream as an array of strings, or raise
    # StopIteration if there are no more rows. Note the careful handling of the StopIteration
    # exception.
    #   StopIteration can be caught here in either of two cases:
    # 1) We just successfully read the last row in the file and now we are being called again on an empty file.
    # 2) We have not yet returned the last row of the file, but we encountered EOF anyway because the row
    #    is not terminated by a carriage return.
    def read_row
      row = []
      @value_reader.each {|v| row << v}
    rescue EndOfRow
      row.empty? ? raise StopIteration : row
    end


    # This is a helper class used only by DelimitedReader. It knows how to read and
    # return the next string value from stream, and raises StopIteration at EOF
    # and EndOfRow at end-of-row
    class DelimitedValueReader
      def initialize (stream, delimiter)
        if (delimiter == '"')
          raise 'Cannot use the double-quote character as a delimiter'
        end

        @stream    = stream
        @delimiter = delimiter
      end


      # Return the next value from within the current row, or raise EndOfRow if we are at the end of the row.
      #
      # PROGRAMMER NOTES: There are two different parsing modes: quote_mode and !quote_mode. If the value
      # begins with a double-quote, then we are in quote mode, and we don't terminate the value until we find
      # its match. If the value does not begin with a double-quote, then we are in !quote_mode, and the value
      # terminates when we find the delimiter, or \n, or EOF.
      #    We don't distinguish EOF from EndOfRow because the final row may not be terminated with a carriage-return.
      # This would raise an ambiguity as to whether we should return EOF or EndOfRow. So we just return EndOfRow
      # in all cases. The caller has enough context to figure out which is which.
      def next
        c = @stream.getc

        if c.nil? || c == '\n'
          raise EndOfRow
        elsif c == '"'
          read_quoted_value
        else
          @stream.ungetc(c)
          read_unquoted_value
        end
      end


      def each
        if block_given?
          yield next
        else
          to_enum
        end
      end


      # This is a helper method and should only be called by read_value() above.
      # Return the next value from within the current row.
      #   This method may only legitimately be called if the value to be read from the stream is an unquoted value,
      # which is to say that it does not begin with a double-quote character.
      def read_unquoted_value
        value = ''
        @stream.chars do |c|
          if c == "\n"
            @stream.ungetc(c) # Let the caller read this on the next attempt, in order to single EndOfRow.
            return value
          end

          if c == @delimiter
            return value
          end

          if c == '"'
            raise "Values with embedded double-quotes must be surrounded by double-quotes"
          end

          value << c
        end
      end

      # This is a helper method and should only be called by read_value() above.
      # Return the next value from within the current row.
      #   This method may only legitimately be called when the value to be read is a quoted value, which
      # is to say that it begins with a double-quote character, AND that double-quote character
      # has already been removed from the stream by the caller.
      def read_quoted_value
        value = ''
        @stream.chars do |c|
          c = get_next_logical_char

          # We found a closing double-quote for our string value
          if c == '"'
            return value
          end

          # We found an escaped double-quote. We'll add it to the value string.
          if c == '""'
            c = '"'
          end

          value << c
        end
      end

      # This is a helper method and should only be called by read_quoted_value() above.
      # Return the next logical character from within the current value.
      # All chars evaluate to themselves except the double double-quote,
      # which is two double quotes in a row, i.e., "", and these two chars evaluate to a single logical char,
      # which is returned as the string '""'
      def get_next_logical_char
        c = @stream.getc

        if c.nil?
          raise "End of file encountered while searching for terminating double quote"
        end

        return c if c != '"'

        # We are reading a double-quote. Examine the next character to figure out what logical char to return.
        cc = @stream.getc
        case cc
          when '"'             # We found an escaped double-quote
            '""'
          when @delimiter       # We found a string-value-terminating double-quote.
            '"'
          when cc.nil?          # We found a string-value-terminating double-quote at EOF
            '"'
          when "\n"            # We found a string-value-terminating double-quote at end-of-row.
            @stream.ungetc(cc) # push this back on the stream to signal EndOfRow next time.
            '"'
          else
            raise "The only valid character that can follow a double quote is a delimiter or another double quote. Instead got: [#{cc}]"
        end
      end
    end
  end

  # We raise an exception of this class to indicate that an end-of-row condition has been encountered.
  class EndOfRow < Exception
  end
end
