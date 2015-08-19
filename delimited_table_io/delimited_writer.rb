require '~/Documents/personal/dev/table_io/table_io'

# Write records to @stream using a delimited format such as csv (the default).
module TableIo
  class DelimitedWriter < Writer
    DEFAULT_DELIMITER = ','


    def initialize (stream, columns, options = {})
      super stream, columns, options

      @delimiter = options[:delimiter] || DEFAULT_DELIMITER

      if (@delimiter == '"')
        raise 'Cannot use the double-quote character as a delimiter'
      end

      @row = '' # Used to build up a string representing a row before writing it to the stream.
    end


    private

    def write_header
      @columns.each do |column_name|
        add_to_row column_name
      end
      write_row
    end

    def write_record (record)
      @columns.each do |column_name|
        add_to_row record.hash[column_name]
      end
      write_row
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


    # Put the value v into the next cell in the spreadsheet, performing any necessary
    # escape modifications so that it is acceptable for output, e.g.,
    # making sure it is a string, that delimiter chars are escaped, etc.
    def add_to_row (v)
      puts "add_to_row: [#{v}]"
      @row << @delimiter unless @row.empty? # Write a cell separator if this is not the first cell in the row
      @row << escape_value(v)               # Write the escaped value.
    end


    # Write out to the stream the row we have been building up, and start a new row.
    def write_row
      puts "write_row"
      @stream.puts(@row)
      @row = ''
    end
  end
end
