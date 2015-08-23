# This file establishes the Pipe module, which provides classes for creating a pipe of chained
# StreamProcessor objects.

module Pipe
# This is a base class establishing the stream processing protocol, which relies on
# the methods pipe() and next().
#    A Stream processor has an input stream, which is given to it via a call to pipe(input_stream),
# and emits its own output stream, via a call to next(). There need not be a
# one-to-one correspondence between input and output. When called upon for its
# next() element, the processor may read many elements
# from its own input stream before deciding to emit an element of output.
#  A stream processor's input stream can be any object that has a next() method and that raises StopIteration
# when it is out of elements to return.
  class StreamProcessor
    attr_accessor :input_stream

    # Return the next element from our output stream. The default here just returns the next element
    # from @input_stream without altering it, making it an the "identity" processor. In practice,
    # this method should be overridden.
    def next
      self.input_stream.next
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


    # Iterate through each of the items in our iterator, passing them in turn to the block for processing,
    # or return an Enumeration if no block is given.
    def each
      if block_given?
        loop {yield self.next}
      else
        to_enum
      end
    end
  end

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
      self.input_stream = File.open(filename)
    end

    # Return the next char from @file, raising StopIteration when EOF.
    def next
      self.input_stream.readchar
    rescue EOFError
      self.input_stream.close
      raise StopIteration
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

# This class facilitates the use of pipes. No need to instantiate it directly. See the function sink() above.
  class SinkFile < StreamProcessor
    # filename is the file to write to. When we are hooked up to a pipe, we will automatically
    # process the input and write to filename, unless dont_run is true. In that case, the pipe
    # operator will merely return us without running, and the caller must explicitly call run() to
    # run the pipe.
    def initialize (filename, dont_run = false)
      @output_stream = File.open(filename, 'w')
      @dont_run      = dont_run
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

