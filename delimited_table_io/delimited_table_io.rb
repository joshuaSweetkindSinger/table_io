require '~/Documents/personal/dev/table_io/table_io'
require '~/Documents/personal/dev/table_io/delimited_table_io/reader'
require '~/Documents/personal/dev/table_io/delimited_table_io/writer'

# This is the top level file for the definition of Delimited reader and writer classes.
# These classes know how to read and write tables represented in delimited format, such as csv files.

module TableIo
  module Delimited
    DEFAULT_DELIMITER = ','
    QUOTE = '"'         # This is the character that can be used to wrap a value containing the delimiter.
    ROW_END_CHAR = "\n" # This is the character that terminates rows of a table.
  end
end