# This file establishes the Pipe module, which provides classes for creating a pipe of chained
# StreamProcessor objects.

module Pipe
  # This is a base class establishing the stream processing protocol.
  #    A StreamProcessor has an input stream and produces an output stream. The input
  # stream is assigned to it via a call to pipe(input_stream). The output stream is produced
  # via a call to each(), which yields its elements one at a time to a block.
  #   The stream processor's input stream must also be an object that has an each() method,
  # yielding its elements one at a time to a block.
  #   Derived classes based on StreamProcessor must define their own each() method, which
  # defines how they process their input stream.
  class StreamProcessor
    attr_accessor :input_stream

    # Enumerate the elements of our output by processing our input stream, yielding
    # each successive element to the block.
    #    This default method just returns the elements of the input stream unchanged.
    def each
      self.input_stream.each do |x|
        yield x
      end
    end

    # The pipe method allows one to establish a chain of stream processors, known as a pipe.
    #    Tell downstream_processor, which should be a stream processor, to take input from our output.
    # This effectively establishes a pipe from ourselves to downstream_processor.
    # Return downstream_processor as the value of the pipe operation.
    #    If downstream_processor is a sink, then it will drive the pipe and pull everything from its
    # input, writing to its output file. See the SinkFile class below.
    def pipe (downstream_processor)
      downstream_processor.input_stream = self
      downstream_processor
    end

    # This is an operator synonym for pipe().
    def >> (downstream_processor)
      pipe(downstream_processor)
    end
  end

# Return a source acceptable as the left edge of a pipe. The specified filename
# will be used to generate an iterator on its characters.
  def self.source(filename)
    SourceFile.new filename
  end


  # This is a thin wrapper around an input stream.
  # All it really does it guarantee that its stream is closed when it is done reading from it.
  # It also provides a slightly smoother syntax for pipes, because it makes its each() method explicit.
  # Really, we could do without this, and use File.open('my_file.txt').each_char in place of
  # SourceFile.new('my_file.txt')
  class SourceFile < StreamProcessor
    def initialize (filename)
      self.input_stream = File.open(filename)
    end

    # Return the next char from @file, raising StopIteration when EOF.
    def each
      self.input_stream.each_char do |c|
        yield c
      end
      close
    end

    def method_missing (m, *args)
      self.input_stream.send(m, *args)
    end
  end



  # Return a sink acceptable as the right edge of a pipe. The characters received from
  # the pipe's input will be written to filename.
  def self.sink(filename)
    SinkFile.new filename
  end

  # This is a thin wrapper around an output stream. It hooks up its run() method to the input_stream=()
  # assigment, so that assigning an input to a SinkFile gets the ball rolling and begins processing
  # of the entire pipe.
  class SinkFile < StreamProcessor
    # filename is the file to write to. When we are hooked up to a pipe, we will automatically
    # process the input and write to filename, unless dont_run is true. In that case, the pipe
    # operator will merely return self without running, and the caller must explicitly call run()
    # on the SinkFile object to process the pipe.
    def initialize (filename, dont_run = false)
      @output_stream = File.open(filename, 'w')
      @dont_run      = dont_run
    end

    def each
      raise 'Programmer error: each() shoud not be called on a SinkFile object.'
    end

    # Run the pipe: pull characters from @input_stream and write them to @output_stream, closing it when
    # we are done.
    def run
      self.input_stream.each do |c|
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

