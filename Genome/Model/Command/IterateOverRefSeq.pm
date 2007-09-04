
package Genome::Model::Command::IterateOverRefSeq;

use strict;
use warnings;

use UR;
use Command;

use Fcntl;
use Carp;


use constant MATCH => 0;
use constant MISMATCH => 1;
use constant QUERY_INSERT => 3;
use constant REFERENCE_INSERT => 2;


UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    is_abstract => 1,
    has => [
        file    =>  {   type => 'Filename', 
                        is_optional => 1, 
                        doc => "<path_to_alignment_file>  The prefix of the alignment index and data files, without the '_aln.dat'" 
                    },
        aln     =>  {   type => 'Genome::Model::RefSeqAlignmentCollection', 
                        is_optional => 1,
                        doc => "The alignment collection to iterate over." 
                    },    
        chrom   =>  { 
                        type => 'String',  
                        is_optional => 1, 
                        doc => "<name> The single-character name of the chromosome this alignment file covers, to determine the last alignment position to check" 
                    },
        length  =>  { 
                        type => 'Integer', 
                        is_optional => 1, 
                        doc => "<count>   In the absence of --chrom, specify how many positions to calculate coverage for"
                    },
        start   =>  { 
                        type => 'Integer', 
                        is_optional => 1, 
                        doc => "<position> The first alignment position to check, default is 1" 
                    },
        result  =>  { 
                        type => 'Integer', 
                        is_optional => 1, 
                        doc => "" 
                    },
        iterator_method  =>  { 
                        type => 'String', 
                        is_optional => 1, 
                        doc => "<name> The name of the iterator method in Genome::Model::RefSeqAlignmentCollection to use" 
                    },
    ], 
);

sub help_brief {
    "print out the coverage depth for the given alignment file" 
}

sub help_synopsis {
    return <<EOS

Write a sub-classs of this for any commands which iterate over an alignment collection.

The subclass must implement _examine_position() and _print_result().

It's usually easiest to copy one of the existing modules, and modify it's name and replace its guts. 

EOS
}

sub help_options {                     
    my $self = shift;  
    return $self->SUPER::help_options() . <<"EOS"

If neither --chrom or --length are specified, it uses the last position in the alignment file as
the length

EOS
}

sub create {                           
    my $class = shift;
    my %params = @_;

    my($aln,$result,$iterator_method);

    if ($params{'aln'}) {
        $aln = delete $params{'aln'};
    }
    if ($params{'result'}) {
        $result = delete $params{'result'};
    }
    if ($params{'iterator_method'}){
        $iterator_method = delete $params{iterator_method};
    }

    my $self = $class->SUPER::create(%params);

    $self->aln($aln) if ($aln);
    $self->result($result) if ($result);
    if($iterator_method){
        $self->iterator_method($iterator_method)
    }else{
        $self->iterator_method('foreach_reference_position');
    }

    return $self;
}

#sub validate_params {                    
#    my $self = shift;
#    return unless $self->SUPER::validate_params(@_);
#    # ..do real checks here
#    return 1;
#}

# FIXME how can we determine these from the data?
our %CHROM_LEN = (
    1   =>      247249720,
    2   =>      242951150,
    3   =>      199501828,
    4   =>      191273064,
    5   =>      180857867,
    6   =>      170899993,
    7   =>      158821425,
    8   =>      146274827,
    9   =>      140273253,
    10  =>      135374738,
    11  =>      134452385,
    12  =>      132349535,
    13  =>      114142981,
    14  =>      106368586,
    15  =>      100338916,
    16  =>      88827255,
    17  =>      78774743,
    18  =>      76117154,
    19  =>      63811652,
    20  =>      62435965,
    21  =>      46944324,
    22  =>      49691433,
    X   =>      154913755,
    Y   =>      57772955,
);

sub execute {
    my $self = shift;
    my %params = @_;
    
    my $iterator_method = $self->iterator_method;
    if($params{iterator_method}){
        $iterator_method = delete $params{iterator_method};
    }

    require Genome::Model::RefSeqAlignmentCollection;

    my $alignment;
    if ($self->file) {
        $alignment = Genome::Model::RefSeqAlignmentCollection->new(file_prefix  => $self->file,
                                                                   mode         => O_RDONLY,
                                                                   bases_fh     => $params{bases_fh});
        unless ($alignment) {
            $self->error_message("Can't access the alignment data: $!");
            return;
        }
    } elsif ($self->aln) {
        $alignment = $self->aln();
    } else {
        $self->error_message("Either the file or aln arguments are required to execute");
        return;
    }

    my $start_position = $self->start() || 1;
    my $end_position;
    if ($self->length) {
        $end_position = $start_position + $self->length - 1;
    } elsif ($self->chrom) {
        unless ($CHROM_LEN{$self->chrom}) {
            $self->error_message("Can't determine chromosome length for '".$self->chrom."'");
            return;
        }
        $end_position = $CHROM_LEN{$self->chrom};
    } else {
        $end_position = $alignment->max_alignment_pos();
    }

    my $pos_coderef = $self->can('_examine_position');
    unless ($pos_coderef) {
        $self->error_message("Class does not define an _examine_position method!");
        return;
    }

    my $result_coderef;
    if ($self->result) {
        my $coverage_result = $self->result;
        unless (ref($coverage_result) eq 'ARRAY') {
            $self->error_message("result parameter to ",ref($self)," must be an array ref");
            return;
        }
        $result_coderef = sub {  
                                my($pos,$coverage) = @_;
                                push @$coverage_result,$coverage;
                             };
    }
    elsif ($result_coderef = $self->can('_print_result')) {
        print "Result for ",$self->aln," from position $start_position to $end_position\n";
    } 
    else {
        $self->error_message($self->class . " does not implement _print_result, and no result parameter was supplied to capture it!");
        return;
    }

    unless ($alignment->$iterator_method( $pos_coderef, $result_coderef, $start_position, $end_position)) {
        $self->error_message("Error iterating over alignments!: ");
    }

    return 1;
}

1;

