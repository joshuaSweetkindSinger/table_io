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

      super stream
      @delimiter = delimiter
      @columns   = get_row
    end


    # Return the next row from the delimited stream as a Record object, or nil if
    # we are end-of-file.
    def read
      row = get_row
      Record.new(row, @columns) if row
    end


    private

    # Return the next row of data from the delimited stream as an array of strings, or nil
    # if there are no more rows.
    def get_row
      return nil if @stream.eof?

      row = []
      while true
        value, end_of_row = get_value
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
    def get_value
      c = @stream.getc
      quote_mode = (c == '"')
      @stream.ungetc(c) unless quote_mode

      value = ''
      num_quotes = 0 # The number of double-quotes in a row we have encountered. (This does not apply to a leading double-quote, which determines the mode.)
      while true
        if !quote_mode && @stream.eof?
          return value, true
        end

        if quote_mode && num_quotes == 0 && @stream.eof?
          raise "End of file encountered while searching for terminating double quote"
        end

        # We found a closing double-quote for our quote-mode value, and we're at end of file.
        if quote_mode && num_quotes == 1 && @stream.eof?
          return value, true
        end

        c = @stream.getc

        if !quote_mode && (c == "\n")
          return value, true
        end

        if !quote_mode && (c == @delimiter)
          return value, false
        end

        if !quote_mode && (c == '"')
          raise "Values with embedded double-quotes must be surrounded by double-quotes"
        end

        # We are in quote mode and encountered a double-quote.
        # On the next char read, we'll figure out what to do with it.
        if quote_mode && c == '"' && num_quotes == 0
          num_quotes = 1
          next
        end

        # We found an escaped double-quote. We'll add it to the value string.
        if num_quotes == 1 && c == '"'
          num_quotes = 0
        end

        # We found a closing double-quote for our quote-mode value, and we're at end of row.
        if num_quotes == 1 && c == "\n"
          return value, true
        end

        # We found a closing double-quote for our quote-mode value, and we're not at end of row.
        if num_quotes == 1 && c == @delimiter
          return value, false
        end

        if quote_mode && num_quotes == 1
          raise "The only valid character that can follow a double quote is a delimiter or another double quote"
        end

        value << c
      end
    end
  end
end
