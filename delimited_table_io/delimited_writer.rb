require '~/Documents/personal/dev/table_io/table_io'

# Write records to @stream using a delimited format such as csv (the default).
module TableIo
  class DelimitedWriter < Writer
    DEFAULT_DELIMITER = ','
    QUOTE = '"'         # This is the character that can be used to wrap a value containing the delimiter.
    ROW_END_CHAR = "\n" # This is the character that terminates rows of a table.

    def initialize (record_stream, delimiter = DEFAULT_DELIMITER)
      if (@delimiter == QUOTE)
        raise 'Cannot use the double-quote character as a delimiter'
      end

      super(record_stream)
      @delimiter = delimiter
      @row = '' # Used to build up a string representing a row before returning it.
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
