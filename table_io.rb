# This file implements the TableIO module, which knows how to read and write
# records/rows stored as table-data (like a spreadsheet) in a number of different formats, such as csv.
# The architecture is extensible so that new readers and writers can be defined for different formats.
#
# The functionality of this module can be used to read records from a table one at a time,
# possibly altering them, or filtering them, and then writing them back out to a file using a possibly
# different table format. It can also be used to generate new tables by generating their records/rows
# one at a time and then writing them out in the desired format. Or it can be used simply to to convert
# a table from one format to another.
#
# There are three main types of objects: Reader, Writer, and Record.
#
# RECORD
# A Record object is a generic representation of a record in a table: it maps column names to their values.
#
# READER
# A Reader object is initialized from a character stream (opened from a table) and turns it into
# an iterator of Record objects, also called a "record stream". A particular Reader class knows how
# to parse the character stream from a particular table format. For example, a Delimited::Reader knows
# how to parse the records of a delimited table, such as a csv table.
#
# If r is a Reader receiving input from the character stream of a table t,
# then r is an iterator of the records of t, and r.each is an enumeration of the same.
# Also, r.columns is an array of strings representing the names of t's columns, in column-order.
# Note that the first element of the enumeration is *not* the column header.
# You only get that via r.columns.
#
# WRITER
# A Writer object is initialized from a record stream and turns it back into
# an iterator of characters representing a table. A particular Writer class knows how to write
# a character stream in a particular table format. For example, a Delimited::Writer knows how
# to write the records of a delimited table, such as a csv table.
#
# # If w is a Writer receiving input from a Reader r, which in turn receives input from a table t,
# then w is an iterator of the character sequence that represents t translated into w's format,
# and w.each is an enumeration of the same.
#    Since this is a text representation of the table, the initial characters in the sequence *will*
# be the table's column header, which defines the column names and column order of the table.
#
# * * *
#
# PIPES
# It can be useful to chain together readers, writers, and other stream processors in order to transform
# an initial input file into an altered, filtered version of the file in another format, with each processor
# in the chain performing a single task. Such a chain is called a "pipe", and the readers and writers defined
# in this project support piping via the >> operator. See TestSameFormatUsingPipe in do_tests.rb for an example.

# Currently this project implements readers and writers for delimited files, such as csv or tab-delimited, as well
# as readers and writers for JSON and XML formats. These latter two are mainly for show, to prove that the architecture
# is extensible. It is unlikely one would really want to use these formats in real life.
#
# The top-level instantiable classes are DelimitedReader, DelimitedWriter,
# JsonReader, JsonWriter, XmlReader, and XmlWriter.
#
# This file just implements the base classes that create the infrastructure. The instantiable classes
# are in their own sub-directories

module TableIo
  # This module contains helper methods common to many of the classes used in the project.
  module Helpers
    # Iterate through each of the items in our iterator, passing them in turn to the block for processing,
    # or return an Enumeration if no block is given.
    def each
      if block_given?
        loop {yield self.next}
      else
        to_enum
      end
    end

    # It can be convenient to pipe readers and writers together for the purpose
    # of translating and/or filtering tables. The pipe method allows one to establish a chain
    # of stream processors, known as a pipe.
    #    Tell output, which should be a stream processor, such as a reader or writer,
    # to take input from ourselves.
    #    This effectively establishes a pipe from ourselves to output, which itself will
    # be an iterator, unless output is a sink. Return output as the value of the pipe operation.
    #    If output is a sink, then it will drive the pipe and pull everything from its
    # input, writing to its output file. See the SinkFile class below.
    def pipe (output)
      output.input_stream = self
      output
    end

    # This is an operator synonym for pipe().
    def >> (output)
      pipe(output)
    end
  end



  # ===========================================================================
  #                           Record
  # ===========================================================================
  # A Record object represents a single row from the table.
  # The record has accessor methods for each column name. Thus, if the table
  # has a column called 'foo', and r is a record, then r.foo is its 'foo' value.
  # The raw record information is stored in the member variable @hash, with @hash[column_name] being
  # the record's value for column_name. The record knows the original order of its columns
  # in the table. These are stored in @columns.
  class Record
    attr_accessor :hash, :columns

    def initialize (row, columns)
      @hash = {}
      @columns = columns
      columns.each_with_index do |column_name, index|
        @hash[column_name] = row[index]
      end
    end


    def to_s
      "#{@hash}"
    end


    # This is how we provide Record objects with accessors named after their columns.
    def method_missing (column_name)
      if @hash.has_key? (column_name)
        @hash[column_name]
      else
        raise "Unknown column name: #{column_name}"
      end
    end
  end

  # ===========================================================================
  #                           Base (Base class for Reader and Writer)
  # ===========================================================================
  # This is a base class containing methods common to all readers and writers
  class StreamProcessor
    include Helpers
    attr_accessor :input_stream

    # NOTE: If we are being used as part of a pipe, stream will be nil at initialize time.
    # We must define the input_stream=() method to handle
    # initializing the input stream at a possibly later time. See the >> operator above.
    def initialize (stream = nil)
      self.input_stream = stream if stream # Initialize stream only if it was specified.
    end
  end

  # ===========================================================================
  #                           Reader (Base Class)
  # ===========================================================================
  # A Reader object is initialized from a file stream that is opened to the table in question.
  # If r is a reader, initialized to the stream my_table, then r is an iterator of that table's records, and r.each
  # is an enumeration of the same.
  #   This is a base class. It is not instantiable. For an example of an instantiable class, see DelimitedReader.
  #   Derived classes must define a @row_reader member variable: an object with a next() method that returns the next
  # row of the table from the stream as an array of strings, or raises StopIteration if there are no more rows to read.
  # Derived classes must also define a header() method that reads and returns the table's column definitions as an array of strings.
  # It is assumed that the column definitions will be the first row or rows of the table.
  class Reader < StreamProcessor
    attr_reader :columns

    def initialize (stream = nil)
      @columns      = nil
      @row_reader   = nil # This needs to be initialized by the derived class.
      super(stream)
    end

    # Return the next row from the stream as a Record object, or raise StopIteration if
    # we are end-of-file.
    def next
      @columns = header if !@columns
      Record.new(@row_reader.next, @columns)
    end
  end


  # ===========================================================================
  #                           Writer (Base Class)
  # ===========================================================================
  # A Writer object is initialized from a record iterator of the successive records
  # of the table to be written. The Reader sub-classes
  # in this project provide objects that are suitable record iterators.
  #   If w is a Writer object, initialized from a record iterator belonging to my_table,
  # then w is an iterator of the character sequence that represents my_table according to w's format,
  # and w.each is an enumeration of the same.
  #    This is a base class. It is not instantiable. For an example of an instantiable class,
  # see DelimitedWriter.
  #    Derived classes must define a record_to_string(record) method that converts record
  # into its string representation, including any row-termination character.
  #    Derived classes must also define a header(columns) method that returns the string representation
  # of columns to be the column header for the table. It is assumed that this should occupy the initial characters of the table's
  # text representation.
  class Writer < StreamProcessor
    # Inputs: record_stream is a record iterator, an instance of one of the Reader subclasses.
    def initialize (record_stream = nil)
      @record_writer  = nil     # This needs to be initialized by the derived class.
      @header_written = false
      @buffer = '' # This buffer holds the characters in the table representation as we decode them from successive records.
                   # Characters are returned from the buffer when next() is called.
      super(record_stream)
    end

    # Return the next character in the string representation of the table
    # represented by the record stream from which we were initialized, or raise StopIteration
    # if there are no more records.
    def next
      write_record(@input_stream.next) if @buffer.empty?
      pop_buffer
    end

    private

    # Write out record to our internal buffer so that its characters can be returned
    # via successive calls to next(). If the header has not yet been written, write
    # that out first.
    def write_record (record)
      write_header(record) if !@header_written
      @buffer << record_to_string(record)
    end

    # Write out the header to our internal buffer so that its characters can be returned
    # via successive calls to next()
    def write_header (record)
      @buffer << header(record.columns)
      @header_written = true
    end

    # pop the first character off of our internal buffer.
    def pop_buffer
      c = @buffer[0]
      @buffer[0] = ''
      c
    end


    # Write record to @stream using our format. The public method is write(). See above.
    def record_to_string (record)
      raise "The record_to_string() method must be defined by a subclass of Writer. You can't instantiate a Writer object directly."
    end

    # Write a column header to the stream.
    def header (columns)
      raise "The header() method must be defined by a subclass of Writer. You can't instantiate a Writer object directly."
    end
  end

  # ===========================================================================
  #                           Odds And Ends Related to Pipes
  # ===========================================================================
  # Return a source acceptable as the left edge of a pipe. The specified filename
  # will be used to generate an iterator on its characters.
  def self.source(filename)
    SourceFile.new filename
  end


  # This class facilitates the use of pipes. No need to instantiate it directly. See the function source() above.
  # It is a thin wrapper on an IO stream that understands the >> operator, provides each() and next() methods,
  # and passes all other messages on to the underlying input stream.
  class SourceFile < StreamProcessor
    def initialize (filename)
      super(File.open(filename))
    end

    # Return the next char from @file, raising StopIteration when EOF.
    def next
      @input_stream.readchar
    rescue EOFError
      @input_stream.close
      raise StopIteration
    end

    def method_missing (m, *args)
      @input_stream.send(m, *args)
    end
  end





  # Return a sink acceptable as the right edge of a pipe. The characters received from
  # the pipe's input will be written to filename.
  def self.sink(filename)
    SinkFile.new filename
  end

  # This class facilitates the use of pipes. No need to instantiate it directly. See the function sink() above.
  class SinkFile < StreamProcessor
    # filename is the file to write to. When we are hooked up to a pipe, we will automatically
    # process the input and write to filename, unless dont_run is true. In that case, the pipe
    # operator will merely return us without running, and the caller must explicitly call run() to
    # run the pipe.
    def initialize (filename, dont_run = false)
      @output_stream = File.open(filename, 'w')
      @dont_run      = dont_run
      super(nil)
    end

    # Run the pipe: pull characters from @input_stream and write them to @output_stream, closing it when
    # we are done.
    def run
      @input_stream.each do |c|
        @output_stream.putc(c)
      end
      @output_stream.close
    end


    # Hook ourselves up to the character iterator <stream>
    # and then run the pipe, unless our init options tell us not to. Return ourselves in any event.
    def input_stream= (stream)
      super(stream)
      run unless @dont_run
      self
    end
  end
end