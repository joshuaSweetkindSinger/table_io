# Table Io
This module knows how to read and write records stored in a file as tabular data like a spreadsheet.
The architecture is extensible so that new readers and writers can be defined for different file formats,
but at the moment the module only supports the reading and writing of delimited files, such as csv files
or tab-delimited files.

The functionality of this module can be used to process records one at a time from a table file,
such as a csv spreadsheet, before writing them back out, possibly in a new format, such as a tab-delimited
format. It can be used to filter records, alter records, or simply to convert a table from
one format to another.

The single mechanism used to do all processing is the "pipe", which should be familiar to *nix users. It is
described in more detail below. Using pipes allows for a uniform, generic approach to the processing of
records in a table.

## Examples
### Convert from csv to tab-delimited format
This brief example reads in the csv file 'foo.csv' and writes it out as the tab-delimited file
'foo.txt'. The >> operator is the pipe operator, which passes the output of one processor into
the input of the next.

    Pipe.source('foo.csv')               >> # Read the input file
    TableIo::Delimited::Reader.new(",")  >> # Convert it from csv format to records
    TableIo::Delimited::Writer.new("\t") >> # Convert records to tab-delimited file format.
    Pipe.sink('foo.txt')                    # Write the new tab-delimited file to disk.

See the file `examples/example.rb` for more examples.

### Find all dessert recipes with fewer than 300 calories
If you don't want to write out a new file, then you can just use the end of the pipe as an enumeration,
rather than writing to a SinkFile. In this example, we just return an array of Record objects that
represent dessert recipes with fewer than 300 calories.

(Here we prefer to use the pipe() method,
rather than the >> operator above. Although these two are functionally equivalent, the Ruby
parser has different syntactic precedences for them, which makes pipe() more convenient than >> to use in conjunction with to_enum().)

      Pipe.source('desserts.csv')            # Read the input file
      .pipe(TableIo::Delimited::Reader.new)  # Convert it to records
      .to_enum.select do |record|            # Select the low-cal desserts
        record.calories.to_i < 300
      end

See the file `examples/example.rb` for more examples.


## Pipes
All file processing is done with pipes. See `pipe.rb` in this project.
A pipe is a chain of StreamProcessor objects, with the output of one processor
providing the input for the next processor in the chain.
Chaining together StreamProcessor objects into a pipe is how one transforms
an initial input file into an altered, filtered version of the file in another format, with each processor
in the chain ideally performing a single task.

Every StreamProcessor object in a pipe, except for the final SinkFile object, must define an each() method
that produces its output stream as a function of its input stream. The output stream is simply a Ruby enumeration,
which is to say that the each() method must simply yield each element of its output in turn to the block associated
with the call to each().

The Reader and Writer classes defined in this project support piping via the pipe() method,
and via the synonymous >> operator.
See the examples in `examples/examples.rb`.

All pipes must begin with a SourceFile object at their "left edge" and typically end with a SinkFile object
at their "right edge". The SinkFile object is what commands the action. It has a run() method that
triggers the pipe and begins pulling elements through it to be written to the SinkFile's output file.

If you don't end your pipe with a SinkFile, then the return value of the chain of StreamProcessor objects
you have created is just the rightmost StreamProcessor. Its each() method can be invoked to yield the
elements of the pipe.



## Instantiable Classes
The top-level instantiable classes are `DelimitedReader` and `DelimitedWriter`.


## Installation
There is no installation script needed. Just copy the table_io directory and all its contents as-is
into your code-base. To use one of its instantiable classes in your code, simply ensure that your ruby $LOAD_PATH
can find the `table_io` directory and then `require` the class's file. At the moment, the only instantiable
classes are the delimited reader and writer classes, so the only meaningful require statement
is the following: `require 'table_io/delimited_table_io/delimited_table_io'`.


## Usage
### Using Existing Classes
Using existing classes is as simple as chaining them together in a pipe, in the manner of the examples above,
in order to transform a table from one form to another. If your end goal isn't to write out another file,
you can break out of the pipe model and just use the end of the pipe as an enumeration to process the
table's records in any way you see fit. The dessert example above illustrates this case.

### Creating Your Own Classes
If you want to create your own pair of Reader and Writer classes, just have them inherit from Reader
or Writer, respectively, and have them implement the each() method, and you're good to go. You can
use the Delimited::Reader rand Delimited::Writer classes as examples to work from.


## Architecture Details

The infrastructure defines three main types of objects: Reader, Writer, and Record.

### Record
A Record object is a generic representation of a record in a table: it maps column names to their values.
A record is initialized with two arrays of strings: the first representing column names, and the second representing
their associated values.

### Reader
A Reader object receives pipe input from a character stream (opened from a table) and produces
Record objects as its pipe output. A particular Reader class knows how
to parse the incoming character stream from a particular table format. For example, a Delimited::Reader knows
how to parse the records of a delimited table, such as a csv table.

If r is a Reader receiving input from the character stream of a table t,
then r.each is an enumeration of the records in t.
Also, r.columns is an array of strings representing the names of t's columns, in column-order.
Note that the first element of the enumeration is *not* the column header.
You only get that via r.columns.

### Writer
A Writer object receives pipe input from a record stream, such as that produced by the output
of a Reader object, and produces a character stream representing a table as its pipe output.
A particular Writer class knows how to write a character stream in a particular table format.
For example, a Delimited::Writer knows how to write the records of a delimited table, such as a csv table.

If w is a Writer receiving input from a Reader r, which in turn receives input from a table t,
then w.each is an enumeration of the character sequence that represents t translated into w's format.
   Since w's output is a text representation of a table, the initial characters in the sequence *will*
be the table's column header, which defines the column names and column order of the table.

