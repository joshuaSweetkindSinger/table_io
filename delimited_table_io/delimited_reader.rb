require 'table_io'

# A DelimitedReader object is initialized from a stream that is opened to the spreadsheet in question.
# It knows how to read and return the next record from the spreadsheet. Use a delimited reader
# for csv files (the default), and for any other kind of delimited file, such as tab delimited.
# If the delimiter is not a comma, you must specify the delimiter when you initialize the Reader.
module TableIo
  class DelimitedReader < Reader
    attr_reader :columns, :delimiter

    DEFAULT_DELIMITER = ','

    def initialize (stream, delimiter = DEFAULT_DELIMITER)
      if (delimiter = '"')
        raise 'Cannot use the double-quote character as a delimiter'
      end

      super stream
      @delimiter = delimiter
      @columns   = get_row
    end


    # Return the next row from the delimited stream as a Record object.
    def read
      Record.new(get_row, @columns)
    end


    private

    # Return the next row of data from the delimited stream as an array of strings.
    def get_row
      @stream.readline().split(@delimiter)
    end

    # Read the next value from our stream. Usually that means reading up to the delimiter,
    # but we need to take double-quotes into account, as well as embedded ines are terminated with a carriage return,
    # except if the value begins with a double quote, then read through commas and carriage returns until
    # the closing double quote.
    def get_next_value
      char = @stream.readchar
      stop_chars = (char == '"') ? '"' : ",\n"
      @stream.ungetc(char) if (char != '"')
      result = read_to_char(stop_chars)
      @stream.readchar if char == '"' # chomp the comma that will follow the closing double quote.
      result
    end


    # Read characters from our stream until one of the stop_chars is encountered.
    # Return a string of the characters read up to but not including the stop char.
    def read_to_char (stop_chars)
      result = ''
      while !@stream.eof? && !stop_chars.include?(c = @stream.readchar)
        result << c
      end
      result
    end
  end
end
