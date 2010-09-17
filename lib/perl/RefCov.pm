package RefCov;

use strict;
use warnings;
use Carp;
use version; my $VERSION = qv( '0.0.1' );
use RefCov::Reference;

# AUTHOR:   Todd Wylie <twylie@wustl.edu>
# CREATED:  Fri Dec  7 11:33:29 CST 2007

# -----------------------------------------------------------------------------
# FACADE CLASS:
# All interfacing with underlying RefCov suite components should be done through
# this class. In general, this class delegates to other RefCov modules. Only
# make PUBLIC methods available through this class. Currently, we only interface
# with the RefCov::Reference class--however, this may change with future
# expansion.
# -----------------------------------------------------------------------------



# NEW
# The Class Constructor for reference coverage objects. Holds underlying
# information for RefCov classes. To instantiate a new reference coverage
# object, here are the legal arguments to pass to the new() method:
#    name
#    start
#    stop
#    thaw
#    thaw_compose
#    glue
# The thaw, thaw_compose, and glue arguments work on pre-existing, frozen refcov
# objects--these arguments should be called by themselves. Example usage:
#   my $myRef = RefCov->new( thaw => 'FROZEN1.rc' );
#   my $myRef = RefCov->new( thaw_compose => ['FROZEN1.rc', 'FROZEN2.rc'] );
#   my $myRef = RefCov->new( glue => ['FRAG1.rc', 'FRAG2.rc'] );
# A brand new reference coverage object must have name, start, and stop
# passed. The START/STOP positions are in terms of the reference (self)... but
# does not necessarily have to start at 1. Example usage:
#   my $myRef = RefCov->new( name => 'gene1', start => 3_000, stop => 4_500 );
# Must pass:
# (brand new)      name; start; stop
# (thaw)           <frozen file name>
# (thaw_compose)  @<frozen file names>
# (glue)          @<frozen file names>
sub new {
    my ($class, %arg) = @_;
    my $self  = { _reference => RefCov::Reference->new( %arg ) };
    return bless ($self, $class);
}



# BASE CONSENSUS
# Returns a consensus-called scalar value for a given position along a reference
# object.  The string field is de-limited by ":" characters. The first field
# always corresponds to the numerical depth of coverage for the position, while
# following fields indicate nucleotides called in the consensus. Majority vote
# returns the most prevalent nucleotide in the consensus, unless there is a tie
# between 2 or more nucleotides, in which case the string will contain the depth
# and all nucleotides that are tied. Must pass: pos
# EXAMPLES:
#    0       =  no base (coverage)
#    255:A   =  A is the dominant base (255 count)
#    55:A:C  =  A,C tied (55 count)
#    5:A:C:T =  A,C,T tied (5 count)
sub base_consensus {
    my ($self, %arg) = @_;
    return $self->{_reference}->base_consensus( %arg );
}



# BASE HETEROZYGOSITY CONSENSUS
# This function determines the top 2 dominant base frequencies per position and
# return a consensus call to the user along with the winning ratios. Returns a
# pipe-delimited string of the following values: 1) depth of coverage for all
# base frequencies at the ref position; 2) top 2 bases based on frequency,
# seperated by a '/' character; 3) ratio of the top 2 bases by base frequency.
#
# EXAMPLES:
#         28|A/T|20:8|0.400
#         2000|A/A|100|-
#         100|G/C|50:50|1
#         0|./.|0|0
sub base_heterozygosity_consensus {
    my ($self, %arg) = @_;
    return $self->{_reference}->base_heterozygosity_consensus( %arg );
}



# BASE HETEROZYGOSITY CONSENSUS SPAN
# Returns a hash reference to a span of base heterozygosity consensus calls;
# each value in the hash represents the most prevalent top 2 base
# frequencies. The values are strings of the format provided by the
# base_heterozygosity_consensus() method. Must pass: start; stop
sub base_heterozygosity_consensus_span {
    my ($self, %arg) = @_;
    return $self->{_reference}->base_heterozygosity_consensus_span( %arg );
}



# BASE CONSENSUS SPAN
# Returns a hash reference to a span of base consensus calls; each value in the
# hash represents the most prevalent base based on coverage depth, tied bases,
# or no coverage. Key values are unordered base positions and values are strings
# of the format provided by the base_consensus() method. Must pass: start; stop
sub base_consensus_span {
    my ($self, %arg) = @_;
    return $self->{_reference}->base_consensus_span( %arg );
}



# PRINT CONSENSUS FASTA
# This function will call the consensus sequence across the length of a given
# reference coverage object and display the FASTA representation to the
# screen. The consensus call is similar to base_consensus() method--however,
# only the highest depth base will be called per position; ties are indicated
# parenthetically; no coverage will produce a '.' character. The call is
# performed from beginning to end (length) of the reference coverage
# object. Descriptor data in the header is derived from the generate_stats()
# function.
# SEE ALSO:
#    generate_stats()
sub print_consensus_FASTA {
    return shift->{_reference}->print_consensus_FASTA();
}



# BASE FREQUENCY
# Returns an array reference of nucleotide base frequencies for a given position
# along a reference object. The order and format of the array is uniform, having
# the following representations: [A, C, G, T, N, -]
# Each field in the array will indicate a numerical value for depth of coverage
# of the corresponding nucleotide base. Must pass: pos
sub base_frequency {
    my ($self, %arg) = @_;
    return $self->{_reference}->base_frequency( %arg );
}



# BASE FREQUENCY SPAN
# Returns a hash reference of base frequency array items from START to STOP
# position. Keys are unordered positions along a reference object and values are
# anonymous arrays of base frequency data as supplied by the base_consensus()
# method, format: [A, C, G, T, N, -]. Must pass: start; stop
sub base_frequency_span {
    my ($self, %arg) = @_;
    return $self->{_frequency}->base_frequency_span( %arg );
}



# DEPTH BINS
# Accessor method for array reference of binned depth information. This is the
# total length of the footprint, position-by-position broken into bins of depth
# of coverage (depth bin:read number). So, a value pair of 0,64 would indicate
# the reference coverage object had 64 base positions with 0 coverage. This
# information is useful for getting a coverage distriubution plot in external
# graphing software. Example:
# -----------------------------------------------------------------------------
# 0       64
# 1       27
# 2       9
# -----------------------------------------------------------------------------
sub depth_bins { return shift->{_reference}->depth_bins() }



# SAVE DEPTH BINS FILE
# Saves a depth_bins() method format file to the file system. Must pass: <output file>
# -----------------------------------------------------------------------------
# 0       64
# 1       27
# 2       9
# -----------------------------------------------------------------------------
sub save_depth_bins_file {
    my ($self, $out) = @_;
    return $self->{_reference}->save_depth_bins_file( $out );
}



# PRINT DEPTH BINS
# Prints a depth_bins() method format file to the screen. Example:
# -----------------------------------------------------------------------------
# 0       64
# 1       27
# 2       9
# -----------------------------------------------------------------------------
sub print_depth_bins {
    return shift->{_reference}->print_depth_bins();
}


# BIT
# Accessor method which returns a scalar bit value (0 or 1) for a given position
# along a reference object. The binary format indicates 0 for not covered and 1
# for covered. The bit values does not indicate depth of coverage but rather if
# the position was covered or not. Must pass: pos
sub bit {
    my ($self, %arg) = @_;
    return $self->{_reference}->bit( %arg );
}



# SPAN BITS
# Accessor method which returns a array reference of a bit values (0 or 1) from
# START to STOP along a given reference covered object. The binary format
# indicates 0 for not covered and 1 for covered. The bit values does not
# indicate depth of coverage but rather if the position was covered or not. Must
# pass: start; stop
sub span_bits {
    my ($self, %arg) = @_;
    return $self->{_reference}->span_bits( %arg );
}



# DEPTH
# Accessor method which returns a scalar numeric value for depth-of-coverage for
# a given position along a reference object. Depth is determined by the number
# of layer sequences stacked at that position in the reference sequence. Must
# pass: pos
sub depth {
    my ($self, %arg) = @_;
    return $self->{_reference}->depth( %arg );
}



# DEPTH SPAN
# Accessor method which returns an array reference to a list of scalar numeric
# values for depth-of-coverage for a START-STOP span along a given reference
# coverage object. Depth is determined by the number of layer sequences stacked
# at that position in the reference sequence. Must pass: start; stop
sub depth_span {
    my ($self, %arg) = @_;
    return $self->{_reference}->depth_span( %arg );
}



# DEPTH BINS (re-visit)



# START
# Accessor method to return a scalar numeric value for the START position of a
# given reference coverage object. This is the very first position in the
# reference sequence.
sub start { return shift->{_reference}->start() }



# STOP
# Accessor method to return a scalar numeric value for the STOP position of a
# given reference coverage object. This is the very last position in the
# reference sequence.
sub stop { return shift->{_reference}->stop() }



# FREEZER
# This method will "freeze" the state of a reference object and save its
# representation to disk as a Storable file. Freezing objects to disk allows for
# future "thawing" of refrence data, composition of multiple like reference
# objects, and "gluing" of reference fragments together. Many of the ancillary
# scripts provided with the RefCov distribution work directly on frozen
# reference coverage objects. By convention, frozen coverage objects are saved
# to files with .rc suffixes. Must pass: <output file name>
# SEE ALSO:
#    new( thaw         => '' )
#    new( thaw_compose => [] )
#    new( glue         => [] )
sub freezer {
    my ($self, $out) = @_;
    return $self->{_reference}->freezer( $out );
}



# GENERATE STATS
# Returns an array reference of coverage statistics for a given coverage
# reference object. This method accepts the optional "min_depth" argument; any
# depth-of-coverage below the passed value will be set to zero and ignored in
# the corresponding stat report. Passing min_depth is a NON-PERSISTENT way to
# ignore per base coverage--i.e., underlying Reference class data is not
# altered. Fields in the array correspond to the following metrics:
# --------------------------------------------------------------------------
#    [0]  Percent of Reference Bases Covered
#    [1]  Total Number of Reference Bases
#    [2]  Total Number of Covered Bases
#    [3]  Number of Missing Bases
#    [4]  Average Coverage Depth
#    [5]  Standard Deviation Average Coverage Depth
#    [6]  Median Coverage Depth
#    [7]  Number of Gaps
#    [8]  Average Gap Length
#    [9]  Standard Deviation Average Gap Length
#    [10] Median Gap Length
#    [11] Min. Depth Filter
#    [12] Discarded Bases (Min. Depth Filter)
#    [13] Max. Unique Filter
#    [14] Total Number of Reads Layered
#    [15] Total Number of Unique Start Site Reads Layered
#    [16] Percent Redundancy of Read Layers
# --------------------------------------------------------------------------
sub generate_stats {
    my ($self, %arg) = @_;
    return shift->{_reference}->generate_stats( %arg );
}



# LAYER NAMES
# Accessor returning an array reference of sequence layer names for a given
# reference coverage object. This method returns a unique list of _all_ layer
# names associated with the coverage of the reference.
# SEE ALSO:
#    layer_names_span( start => '', stop => '' );
sub layer_names { return shift->{_reference}->layer_names() }



# LAYER NAMES SPAN
# Accessor returning an array reference of sequence layer names for a given
# reference coverage object. This method returns a unique list of layer names
# associated with the coverage of the reference between a START and STOP
# position--useful for interrogating membership for specific ranges in a
# reference coverage object.
# SEE ALSO:
#    layer_names()
sub layer_names_span {
    my ($self, %arg) = @_;
    return $self->{_reference}->layer_names_span( %arg );
}



# LAYER READ
# This is the method for layering reads onto a given reference coverage
# object. Each read will be layered onto the reference based on provided START
# and STOP positions. Both START/STOP positions should be in terms of the
# REFERENCE sequence coordinate system--as provided by an external alignment
# application. START and STOP may exceed the reference sequence's boundaries,
# provided that the START/STOP values are in terms of the reference; refcov
# internals will truncate layering automatically. START/STOP are required
# arguments. The layer_read() method scales based upon two other _optional_
# arguments: sequence & layer_name. Supplying one or both of these options
# facilitates refcov functionality at the cost of "heavier" objects (i.e., more
# memory consumption and processing time). Providing "sequence" allows for using
# the base frequency related functions in refcov. Providing "layer_name" allows
# for querying constituent layer membership in a reference coverage object--or a
# specific span of the object.
# Must pass: start; stop Optional: sequence; layer_name
sub layer_read {
    my ($self, %arg) = @_;
    return $self->{_reference}->layer_read( %arg );
}



# LAYERS TOTAL
# This method will return the total number of layers placed upon a given
# reference. To access this information, the object must have the "redundancy"
# argument passed when layering a read using the "layer_read()" method.
sub layers_total {
    my $self = shift;
    return $self->{_reference}->{_redundancy}->layers_total();
}



# PERCENT REDUNDANCY START SITES
# This method will return the percent redundancy of start sites placed upon a
# given reference. To access this information, the object must have the
# "redundancy" argument passed when layering a read using the "layer_read()"
# method.
sub percent_redundancy_start_sites {
    my ($self, %arg) = @_;
    return $self->{_reference}->{_redundancy}->percent_redundancy_start_sites( %arg );
}



# PERCENT REDUNDANCY LAYERS
# This method will return the percent redundancy of layers placed upon a given
# reference. To access this information, the object must have the "redundancy"
# argument passed when layering a read using the "layer_read()" method.
sub percent_redundancy_layers {
    my ($self, %arg) = @_;
    return $self->{_reference}->{_redundancy}->percent_redundancy_layers( %arg );
}



# REDUNDANCY TOPOLOGY
# This method will return the topology of redundancy of layers placed upon a
# given reference. To access this information, the object must have the
# "redundancy" argument passed when layering a read using the "layer_read()"
# method.
sub redundancy_topology {
    my ($self, %arg) = @_;
    return $self->{_reference}->{_redundancy}->redundancy_topology( %arg );  # hash ref
}



# REDUNDANCY STATS
# Simple way to return all of the related "redundancy" statistics. To access
# this information, the object must have the "redundancy" argument passed when
# layering a read using the "layer_read()" method.
sub redundancy_stats {
    my ($self, %arg) = @_;
    return $self->{_reference}->{_redundancy}->redundancy_stats( %arg );  # array ref
}



# START SITES UNIQUE
# This method will return the unique number of start sites placed upon a given
# reference. To access this information, the object must have the "redundancy"
# argument passed when layering a read using the "layer_read()" method. This
# method accepts the "max_depth" argument for including only members of a
# certain depth or lower in the calculation; default is 1.
sub start_sites_unique {
    my ($self, %arg) = @_;
    return $self->{_reference}->{_redundancy}->start_sites_unique( %arg );
}



# PRINT BASE HETEROZYGOSITY TOPOLOGY
# This function will print to the screen a tab-delimited version of the
# base_heterozygosity_consensus() method output per position along a reference
# coverage object. Columns are as follows:
#    [1] position in reference
#    [2] total depth of coverage for reference object at position
#    [3] most covered allele / second most covered allele
#    [4] ratio of depth of coverage for top/second allelles
#    [5] ratio of depth of coverage for top/second allelles (percent form)
#
# Optionally, a user may pass three arguments for filtering the results
# returned: 1) min_depth; 2) min_ratio; 3)pad. These values are the minimum
# threshold for reporting results. When filtering is invoked, both arguments
# must be provided. The min_ratio value should be supplied in the percent form
# of the ratio (col. 5). The pad switch will pad the filtered positions in the
# reference topology when printing results when non-nil in value; by default,
# padding is turned off for brevity.
# -----------------------------------------------------------------------------
# 621     90     (AT)/G     90:1     0.0111
# 622     275       G/A     275:2    0.0073
# 623     281       A/T     281:1    0.0036
# 624     282       T/G     282:4    0.0142
# -----------------------------------------------------------------------------
sub print_base_heterozygosity_topology {
    my ($self, %arg) = @_;
    return $self->{_reference}->print_base_heterozygosity_topology(
                                                                   min_depth => $arg{min_depth},
                                                                   min_ratio => $arg{min_ratio},
                                                                   pad       => $arg{pad},
                                                                  );
}



# NAME
# Accessor method for returning the identifying name of a given reference
# coverage object; this reflects the name given to the object in the original
# new() method instantiation.
sub name { return shift->{_reference}->name() }



# NUMBER COVERED
# Method to calculate how many bases in a given START/STOP span have bit value
# coverage (i.e., covered or not). A single numeric scalar is return for the
# number of bases in the span that have coverage depth of 1 or greater. Must
# pass: start; stop
sub number_covered {
    my ($self, %arg) = @_;
    return $self->{_reference}->number_covered( %arg );
}



# SAVE DEPTH BINS FILE (re-visit)



# SAVE TOPOLOGY FILE
# Save a print_topology() method format file to the file system.
# Must pass: <output file>
# SEE ALSO:
#    print_topology()
sub save_topology_file {
    my ($self, $out) = @_;
    return $self->{_reference}->save_topology_file( $out );
}



# SAVE BASE FREQUENCY TOPOLOGY FILE
# Saves a save_base_frequency_topology_file() method format file to the file
# system.
# Must pass: <output file>
# SEE ALSO:
#    print_base_frequency_topology()
sub save_base_frequency_topology_file {
    my ($self, $out) = @_;
    return $self->{_reference}->save_base_frequency_topology_file( $out );
}



# SAVE FASTCcon FILE
# Saves a save_FASTCcon_file() method format file to the file system.
# Must pass: <output file>
# SEE ALSO:
#    save_FASTCcon_file()
sub save_FASTCcon_file {
    my ($self, $out) = @_;
    return $self->{_reference}->save_FASTCcon_file( $out );
}



# SAVE FASTC FILE
# Saves a print_FASTC() method format file to the file system.
# Must pass: <output file>
# SEE ALSO:
#    print_FASTC()
sub save_FASTC_file {
    my ($self, $out) = @_;
    return $self->{_reference}->save_FASTC_file( $out );
}



# REFLEN
# Accessor method to return a scalar numeric value for total length of a given
# reference coverage object.
sub reflen { return shift->{_reference}->reflen() }



# RANGE INDEX
# Accessor method to return a hash reference to an index of covered ranges. Keys
# in the data structure are un-ordered positions along a given reference covered
# object and values are included for START and STOP of range. Example:
# -----------------------------------------------------------------------------
# $href = {
#          1 => {
#                start => 1,
#                stop  => 25,
#               },
#          2 => {
#                start => 30,
#                stop  => 100,
#               },
#         };
# -----------------------------------------------------------------------------
sub range_index { return shift->{_reference}->range_index() }



# PRINT TOPOLOGY
# This method will print to the screen a tab-delimited, 2 column file of
# coordinates (pos:depth) for every position in a given reference coverage
# object in position order. The output is useful for plotting the coverage
# topology across the length of the reference footprint in external graphing
# software. Example:
# -----------------------------------------------------------------------------
# 1	5
# 2	5
# 3	5
# 4	5
# 5	5
# 6	5
# -----------------------------------------------------------------------------
sub print_topology { shift->{_reference}->print_topology() }



# PRINT STATS
# Prints to screen generate_stats() method statistical information in general
# YAML document format. The YAML format makes for ease in parsing range
# information for downstream analysis. Example:
# -----------------------------------------------------------------------------
#
# ---
# TestFootprint:
#  Percent of Reference Bases Covered: 36
#  Total Number of Reference Bases: 100
#  Total Number of Covered Bases: 36
#  Number of Missing Bases: 64
#  Average Coverage Depth: 0.45
#  Standard Deviation Average Coverage Depth: 0.65
#  Median Coverage Depth: 0
#  Number of Gaps: 1
#  Average Gap Length: 64
#  Standard Deviation Average Gap Length: nan
#  Median Gap Length: 64
#  Min. Depth Filter: 0x
#  Discarded Bases (Min. Depth Filter): 0
#
# -----------------------------------------------------------------------------
# SEE ALSO:
#    generate_stats()
sub print_stats {
    my ($self, %arg) = @_;
    return shift->{_reference}->print_stats( %arg );
}



# PRINT RANGES YAML
# This method will print a comprehensive YAML document of range/gap information
# for a given reference coverage object. The YAML format makes for ease in
# parsing range information for downstream analysis. Example:
# -----------------------------------------------------------------------------
#
# ---
# REF: TestFootprint
# REF START: 1
# REF STOP: 100
# RANGES:
#
#   # (range 1/2)
#   1:
#     START: 1
#     STOP: 25
#     LENGTH: 25
#     MEMBERS:
#         1:
#           NAME: layer1
#           LENGTH: 25
#           START: 1
#           STOP: 25
#         2:
#           NAME: layer2
#           LENGTH: 9
#           START: 12
#           STOP: 20
#
#   # (range 2/2)
#   2:
#     START: 90
#     STOP: 100
#     LENGTH: 11
#     MEMBERS:
#         1:
#           NAME: layer3
#           LENGTH: 11
#           START: 90
#           STOP: 100
# ...
#
# -----------------------------------------------------------------------------
sub print_ranges_YAML {
    return shift->{_reference}->print_ranges_YAML() ;
}

sub save_ranges_YAML {
    my ($self, $out) = @_;
    return $self->{_reference}->save_ranges_YAML( $out );
}


# PRINT RANGES
# Calling this method results in the printing of tab-delimited, 3 column
# information regarding covered ranges in a given coverage reference
# object. Ranges are ordered by position in the reference coverage
# object. Example:
# -----------------------------------------------------------------------------
# TestFootprint	  1       25
# TestFootprint   90      113
# TestFootprint   130     151
# TestFootprint   156     254
# -----------------------------------------------------------------------------
# SEE ALSO:
#    print_ranges_YAML()
sub print_ranges { return shift->{_reference}->print_ranges() }



# PRINT GAPS
# Calling this method results in the printing of tab-delimited, 4 column
# information regarding the gaps in a given coverage reference object. Gaps are
# ordered by position in the reference coverage object. Example:
# -----------------------------------------------------------------------------
# GAP	TestFootprint	26	89
# GAP	TestFootprint	114	129
# GAP	TestFootprint	152	155
# GAP	TestFootprint	255	299
# -----------------------------------------------------------------------------
# SEE ALSO:
#    print_ranges_YAML()
sub print_gaps { return shift->{_reference}->print_gaps() }



# PRINT BASE FREQUENCY TOPOLOGY
# This method will print to the screen a tab-delimited, 7 column file of
# coordinates (depth:A:C:G:T:N:-) for every position in a given reference
# coverage object. The output is useful for plotting the coverage topology
# across the length of the reference footprint in external graphing software.
# -----------------------------------------------------------------------------
# 1	5	0	0	0	0	0
# 2	0	5	0	0	0	0
# 3	0	0	5	0	0	0
# 4	0	5	0	0	0	0
# 5	2	0	0	3	0	0
# 6	0	5	0	0	0	0
# 7	0	0	5	0	0	0
# -----------------------------------------------------------------------------
sub print_base_frequency_topology {
    return shift->{_reference}->print_base_frequency_topology();
}



# PRINT FASTC
# This method prints a FASTC format file to the screen when called. The FASTC
# (FAST Coverage) format is similar to FASTA--having a header tag followed by
# positional values--however, FASTC values represent depth of coverage per
# position and not nucleotide or protein sequence. FASTC consists of a header
# line (with new line return) followd by a single string of depth values,
# delimited by spaces. Example:
# -----------------------------------------------------------------------------
# >TestFootprint
# 1 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 2 2 2 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0
# 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
# 0 0 0 0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 1 1 1 1
# -----------------------------------------------------------------------------
sub print_FASTC { return shift->{_reference}->print_FASTC() }



# PRINT FASTCcon
# This method prints a FASTCcon format file to the screen when called. The
# FASTCcon (FAST Coverage consensus) format is similar to FASTA--having a header
# tag followed by positional values--however, FASTCcon values represent depth of
# coverage per position (not nucleotide or protein sequence) plus the consensus
# call bases for the position. FASTC consists of a header line (with new line
# return) followd by a single string of depth values, delimited by
# spaces. Values are in base_consensus() format.
# -----------------------------------------------------------------------------
# >TestFootprint
# 5:A 5:C 5:G 5:C 3:T 5:C 5:G 5:T 5:A 5:T 5:A 5:T 5:C 5:T 5:C 5:G 5:C 5:G 5:G
# 5:C 5:G 5:G 5:C 5:C 5:C 0 1:A 1:A 1:A 1:A 1:A 1:A 1:A 1:A 1:A 1:A 0 0 0 0 0 0
# 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
# 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
# -----------------------------------------------------------------------------
sub print_FASTCcon { return shift->{_reference}->print_FASTCcon() }



1;  # end of package


__END__


=head1 NAME

RefCov - [One line description of module's purpose here]


=head1 VERSION

This document describes RefCov version 0.0.1


=head1 SYNOPSIS

    use RefCov;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.


=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.

RefCov requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-refcov@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Todd Wylie

C<< <todd@monkeybytes.org> >>

L<< http://www.monkeybytes.org >>


=head1 LICENSE AND COPYRIGHT

Copyright (c) 2007, Todd Wylie C<< <todd@monkeybytes.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See perlartistic.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENSE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=head1 NOTE

This software was written using the latest version of GNU Emacs, the
extensible, real-time text editor. Please see
L<http://www.gnu.org/software/emacs> for more information and download
sources.
