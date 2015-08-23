require_relative '../delimited_table_io/delimited_table_io'

# Process the delimited file events.csv and filter it for just those event records
# titled "shopping". Also strip the "extra notes" column from the records. Write them back
# out to shopping_days.csv
module Example
  class RecordFilter
    # This class filters
  end

  def self.run
    input_filename  = "#{THIS_DIR}/events.csv"
    output_filename = "#{THIS_DIR}/events3.csv"

    TableIo::source(input_filename) # Read the events file
    .pipe(Delimited::Reader.new)    # convert it from delimited file format to records
    .pipe(TableIo::StreamProcessor.new)                         # filter and massage the records
    .pipe(Delimited::Writer.new)    # convert records back to delimited file format.
    .pipe(TableIo::sink(output_filename)) # write the delimited file to disk.
  end
end
