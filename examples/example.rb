#!/usr/bin/env ruby
require_relative '../delimited_table_io/delimited_table_io'


# This simple example reads in a csv file and writes it back out as a tab-delimited file.
# It uses the >> operator, which is a synonym for the pipe() method.
module Example1
  THIS_DIR = File.dirname(__FILE__)

  def self.run
    input_filename  = "#{THIS_DIR}/tables/events.csv"
    output_filename = "#{THIS_DIR}/tables/events.txt"

    Pipe.source(input_filename)          >> # Read the input file
    TableIo::Delimited::Reader.new       >> # convert it from delimited file format to records
    TableIo::Delimited::Writer.new("\t") >> # convert records tab-delimited file format.
    Pipe.sink(output_filename)              # write the delimited file to disk.
  end
end



# This example processes the delimited file "events.csv" and filters it for just those event records
# titled "shopping". It also strips the "extra notes" column from the records. Then it writes them back
# out to "shopping_days.txt" in tab-delimited format. The top-level method is self.run().
module Example2
  THIS_DIR = File.dirname(__FILE__)

  def self.run
    input_filename  = "#{THIS_DIR}/tables/events.csv"
    output_filename = "#{THIS_DIR}/tables/filtered_events.txt"

    Pipe.source(input_filename)                 # Read the input file
    .pipe(TableIo::Delimited::Reader.new)       # convert it from delimited file format to records
    .pipe(FilterToShopping.new)                 # filter and massage the records to just those contianing the "shopping" event
    .pipe(StripNotes.new)                       # Strip of the "extra notes" column
    .pipe(TableIo::Delimited::Writer.new("\t")) # convert records to tab-delimited format.
    .pipe(Pipe.sink(output_filename))           # write the delimited file to disk.
  end



  # This class filters the source records to just those whose "event" column matches the string "shopping"
  class FilterToShopping < Pipe::StreamProcessor
    def each
      self.input_stream.each do |record|
        if record.event == 'shopping'
          yield record
        end
      end
    end
  end

  # This class removes the "extra notes" column from each record
  class StripNotes < Pipe::StreamProcessor
    def each
      self.input_stream.each do |record|
        record.hash.delete('extra notes')
        record.columns[extra_notes_column_index(record), 1] = [] # delete this column
        yield record
      end
    end

    # Return the index of the 'extra notes' column
    def extra_notes_column_index (record)
      @extra_notes_column_index ||= find_column_index(record, 'extra notes')
    end

    def find_column_index (record, column_to_find)
      record.columns.each_with_index do |column_name, index|
        return index if column_name == column_to_find
      end
    end
  end
end

Example1.run
Example2.run