require 'table_io'

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
    end


    private

    def write_record (record)
      delimiter = ''
      @columns.each do |column_name|
        @stream.put delimiter
        @stream.put escape_value(record.hash[column_name])
        delimiter = @delimiter
      end
      @stream.puts # write a carriage return at the end of the row
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
      value = '"' + value + '"' if value.include?(@delimiter) # surround it with double quotes if it contains the delimiter.
      value
    end
  end
end
