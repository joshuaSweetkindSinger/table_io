require '~/Documents/personal/dev/table_io/table_io'

# A DelimitedReader object is initialized from a stream that is opened to the spreadsheet in question.
# It knows how to read and return the next record from the spreadsheet. Use a delimited reader
# for csv files (the default), and for any other kind of delimited file, such as tab delimited.
# If the delimiter is not a comma, you must specify the delimiter when you initialize the Reader.
# The reader is capable of handling values that contain the delimiter itself. These values must be surrounded
# in double-quotes. The reader is also capable of reading values that include double-quotes. These must be
# escaped by using double-double-quotes, i.e., "" is used to represent a single double-quote.
module TableIo
  class DelimitedReader < Reader
    attr_reader :columns, :delimiter

    DEFAULT_DELIMITER = ','

    def initialize (stream, delimiter = DEFAULT_DELIMITER)
      if (delimiter == '"')
        raise 'Cannot use the double-quote character as a delimiter'
      end

      @delimiter = delimiter

      super stream
    end


    private

    # Return the next row of data from the delimited stream as an array of strings, or nil
    # if there are no more rows.
    def read_row
      return nil if @stream.eof?

      row = []
      while true
        value, end_of_row = read_value
        row << value
        if end_of_row
          return row
        end
      end
    end



    # returns two values: the next value from within the current row, and a boolean indicating end-of-row.
    # This boolean is false until the last value from the row is read, at which time it is true.
    #
    # PROGRAMMER NOTES: There are two different parsing modes: quote_mode and !quote_mode. If the value
    # begins with a double-quote, then we are in quote mode, and we don't terminate the value until we find
    # its match. If the value does not begin with a double-quote, then we are in !quote_mode, and the value
    # terminates when we find the delimiter, or \n, or EOF.
    #
    # The variable num_quotes keeps track of state for the number of quotes in a row we have encountered.
    # This is only utilized in quote_mode. It helps us distinguish the case of a terminating double quote
    # from an escaped double quote.
    def read_value
      c = @stream.getc

      if c == '"'
        read_quoted_value
      else
        @stream.ungetc(c)
        read_unquoted_value
      end
    end


    # This is a helper method and should only be called by read_value() above.
    # returns two values: the next value from within the current row, and a boolean indicating end-of-row.
    # This boolean is false until the last value from the row is read, at which time it is true.
    # This method may only legitimately be called if the value to be read from the stream is an unquoted value,
    # which is to say that it does not begin with a double-quote character.
    def read_unquoted_value
      value = ''
      while true
        c = @stream.getc

        if c.nil?
          return value, true
        end

        if c == "\n"
          return value, true
        end

        if c == @delimiter
          return value, false
        end

        if c == '"'
          raise "Values with embedded double-quotes must be surrounded by double-quotes"
        end

        value << c
      end
    end

    # This is a helper method and should only be called by read_value() above.
    # returns two values: the next value from within the current row, and a boolean indicating end-of-row.
    # This boolean is false until the last value from the row is read, at which time it is true.
    # This method may only legitimately be called when the value to be read is a quoted value, which
    # is to say that it begins with a double-quote character, AND that double-quote character
    # has already been removed from the stream by the caller.
    def read_quoted_value
      value = ''
      while true
        c, end_of_row = get_next_logical_char

        # We found a closing double-quote for our string value
        if c == '"'
          return value, end_of_row
        end

        # We found an escaped double-quote. We'll add it to the value string.
        if c == '""'
          c = '"'
        end

        value << c
      end
    end

    # This is a helper method and should only be called by read_quoted_value() above.
    # returns two values: the next logical character from within the current value, and a boolean indicating end-of-row.
    # The boolean is true when the logical character read is a string-value-terminating double-quote at end-of-row.
    # All chars evaluate to themselves except the double double-quote,
    # which is two double quotes in a row, i.e., "", and these two chars evaluate to a single logical char,
    # which is returned as the string '""'
    def get_next_logical_char
      c = @stream.getc

      if c.nil?
        raise "End of file encountered while searching for terminating double quote"
      end

      return [c, false] if c != '"'

      # We are reading a double-quote. Examine the next character to figure out what logical char to return.
      cc = @stream.getc
      return ['""', false] if cc == '"'        # We found an escaped double-quote
      return ['"',  true]  if cc.nil?          # We found a string-value-terminating double-quote at EOF
      return ['"',  true]  if cc == "\n"       # We found a string-value-terminating double-quote at end-of-row.
      return ['"',  false] if cc == @delimiter # We found a string-value-terminating double-quote.

      raise "The only valid character that can follow a double quote is a delimiter or another double quote. Instead got: [#{cc}]"
    end
  end
end
