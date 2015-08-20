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
      super()
    end


    private

    # Return the next row of data from the delimited stream as an array of strings, or return
    # nil if there are no more rows.
    def read_row
      row = []
      @value_reader.each {|v| row << v}
      row unless row.empty?
    end


    # This is a helper class used only by DelimitedReader. It knows how to read and
    # return the next string value from stream, and raises StopIteration at end-of-row
    class DelimitedValueReader
      def initialize (stream, delimiter)
        if (delimiter == '"')
          raise 'Cannot use the double-quote character as a delimiter'
        end

        @stream                = stream
        @quoted_value_reader   = QuotedValueReader.new(stream, delimiter)
        @unquoted_value_reader = UnquotedValueReader.new(stream, delimiter)
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

        @stream.ungetc(c)
        reader = (c == '"') ? @quoted_value_reader : @unquoted_value_reader
        reader.next
      end


      # Iterate over values in the row, allowing
      # the associated block to process each value.
      def each
        loop {yield self.next}
      end


      # This is helper class for DelimitedValueReader. It knows how to read an unquoted value
      # from stream. An unquoted value is a value that does not begin with a double-quote.
      class UnquotedValueReader
        def initialize (stream, delimiter)
          @stream    = stream
          @delimiter = delimiter
        end

        # Return the next value from within the current row.
        #   This method may only legitimately be called if the value to be read from the stream is an unquoted value,
        # which is to say that it does not begin with a double-quote character.
        def next
          value = ''
          @stream.each_char do |c|
            if c == "\n"
              @stream.ungetc(c) # Let the caller read this on the next attempt, in order to signal end-of-row
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
      end



      # This is helper class for DelimitedValueReader. It knows how to read a quoted value
      # from stream. An quoted value is a value that begins with a double-quote.
      class QuotedValueReader
        def initialize (stream, delimiter)
          @stream              = stream
          @logical_char_stream = LogicalCharStream.new(stream, delimiter)
        end

        # This is a helper method and should only be called by read_value() above.
        # Return the next value from within the current row.
        #   This method may only legitimately be called when the value to be read is a quoted value, which
        # is to say that it begins with a double-quote character.
        def next
          raise "Quoted value must begin with a double quote character!" if @stream.getc != '"'

          value = ''
          @logical_char_stream.each do |c|
            value << (c == '""' ? '"' : c)
          end

          puts "<Q: #{value}>"

          value
        end


        # This is a helper class for QuotedValueReader. It knows how to read the nexts logical
        # character from the stream, in the context of reading a quoted value.
        #   All chars evaluate to themselves except the double double-quote,
        # which is two double quotes in a row, i.e., "". These two chars evaluate to a single logical char,
        # which is returned as the string '""'
        class LogicalCharStream
          def initialize (stream, delimiter)
            @stream = stream
            @delimiter = delimiter
          end


          def each
            loop {yield self.next}
          end


          def next
            c = @stream.getc
            puts c

            if c.nil?
              raise "End of file encountered while searching for terminating double quote"
            end

            if c != '"'
              puts "[#{c}]"
              return c
            end


            # We are reading a double-quote. Examine the next character to figure out what logical char to return.
            cc = @stream.getc

            puts cc

            @stream.ungetc(cc) if cc == "\n" # push this back on the stream to signal end-of-row next time.
            if cc == '"'  # We found an escaped double-quote
              puts '[""]'
              return '""'
            end

            raise StopIteration if cc == @delimiter || cc.nil? || cc == "\n"
            raise "The only valid character that can follow a double quote is a delimiter or another double quote. Instead got: [#{cc}]"
          end
        end
      end
    end
  end
end
