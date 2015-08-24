# Table Io
This module knows how to read and write records/rows stored as table-data (like a spreadsheet)
in a number of different formats, such as csv.
The architecture is extensible so that new readers and writers can be defined for different file formats.

The functionality of this module can be used to process records one at a time from a table file,
such as a csv spreadsheet, before writing them back out, possibly in a new format. It can be used
to filter records, alter records, or simply to convert a table from one format to another.


## Instantiable Classes
The top-level instantiable classes are `DelimitedReader`, `DelimitedWriter`,
`JsonReader`, `JsonWriter`, `XmlReader`, and `XmlWriter`.


Currently this project only implements readers and writers for delimited files, such as csv or tab-delimited
files.


## Installation
There is no installation script needed. Just copy the table_io directory and all its contents as-is
into your code-base. To use one of its classes in your code, simply ensure that your ruby $LOAD_PATH
can find table_io. For example, to use the delimited table reader and write classes, you would do

    require 'table_io/delimited_table_io'
    my_reader = TableIo::Delimited::Reader
    my_writer = TableIo::Delimited:Writer


## Examples
See the file `examples/example.rb`.


## Pipes
All file processing is done with pipes. See `pipe.rb'. Readers, writers, and other stream processors
are chained together in order to transform
an initial input file into an altered, filtered version of the file in another format, with each processor
in the chain performing a single task. Such a chain is called a "pipe", and the readers and writers defined
in this project support piping via the pipe() method, and the synonymous >> operator.
See the examples in `examples/examples.rb`.

All pipes must begin with a SourceFile object at their "left edge" and must end with a SinkFile object
at their "right edge". The SinkFile object is what commands the action. It has a run() method that
triggers the pipe and begins pulling elements through it to be written to the SinkFile's output file.

Every StreamProcessor object in a pipe, except for the final SinkFile object, must define an each() method
that produces the elements of its enumeration as a function of its input stream.


## Architecture Details

There are three main types of objects: Reader, Writer, and Record.

### Record
A Record object is a generic representation of a record in a table: it maps column names to their values.

### Reader
A Reader object is initialized from a character stream (opened from a table) and turns it into
an iterator of Record objects, also called a "record stream". A particular Reader class knows how
to parse the character stream from a particular table format. For example, a Delimited::Reader knows
how to parse the records of a delimited table, such as a csv table.

If r is a Reader receiving input from the character stream of a table t,
then r is an iterator of the records of t, and r.each is an enumeration of the same.
Also, r.columns is an array of strings representing the names of t's columns, in column-order.
Note that the first element of the enumeration is *not* the column header.
You only get that via r.columns.

### Writer
A Writer object is initialized from a record stream and turns it back into
an iterator of characters representing a table. A particular Writer class knows how to write
a character stream in a particular table format. For example, a Delimited::Writer knows how
to write the records of a delimited table, such as a csv table.

If w is a Writer receiving input from a Reader r, which in turn receives input from a table t,
then w is an iterator of the character sequence that represents t translated into w's format,
and w.each is an enumeration of the same.
   Since this is a text representation of the table, the initial characters in the sequence *will*
be the table's column header, which defines the column names and column order of the table.

