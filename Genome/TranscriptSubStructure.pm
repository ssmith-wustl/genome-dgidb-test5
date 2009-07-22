package Genome::TranscriptSubStructure;

use strict;
use warnings;

use Genome;

class Genome::TranscriptSubStructure {
    type_name => 'genome transcript sub structure',
    table_name => 'TRANSCRIPT_SUB_STRUCTURE',
    id_by => [
        transcript_structure_id => { 
            is => 'NUMBER', 
            len => 10 
        },
    ],
    has => [
        transcript_id => {  #TODO changed to text extended length
            is => 'Text', 
            len => 35 
        },
        structure_type => { 
            is => 'VARCHAR',    
            len => 10, 
            is_optional => 1 
        },
        structure_start => { 
            is => 'NUMBER', 
            len => 10, 
            is_optional => 1 
        },
        structure_stop => { 
            is => 'NUMBER', 
            len => 10, 
            is_optional => 1 
        },
        ordinal => { 
            is => 'NUMBER', 
            len => 10, 
            is_optional => 1
        },
        phase => { 
            is => 'NUMBER', 
            len => 7, 
            is_optional => 1
        },
        nucleotide_seq => { 
            is => 'CLOB', 
            is_optional => 1
        },
        transcript => { #TODO, straighten out ID stuff w/ Tony
            is => 'Genome::Transcript', 
            id_by => 'transcript_id' 
        },
        data_directory => {
            is => "Path",
        },
    ],
    schema_name => 'files',
    data_source => 'Genome::DataSource::TranscriptSubStructures',
};

sub rename_to_errors_later{  #TODO not sure what the new valid sub name is
    my $self = shift;
    return if grep  { ! defined $self->$_ } qw/structure_type structure_start structure_stop ordinal/;
    return unless $self->structure_stop >= $self->structure_start;
    unless ($self->structure_type =~ /intron/){
        return unless defined $self->nucleotide_seq;
    }
    return 1;
}

sub length{
    my $self = shift;
    my $length = $self->structure_stop - $self->structure_start + 1;
    return $length;
}

1;

#TODO
=pod
=cut
