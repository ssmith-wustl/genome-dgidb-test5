package Genome::TranscriptSubStructure;
#:adukes short term: move data directory into id_by, but this has to be done in parallel w/ rewriting all file-based data sources.  It might be better to wait until long term: custom datasource that incorporates data_dir, possibly species/source/version, eliminating the need for these properties in the id, and repeated multiple times in the files

use strict;
use warnings;

use Genome;

class Genome::TranscriptSubStructure {
    type_name => 'genome transcript sub structure',
    table_name => 'TRANSCRIPT_SUB_STRUCTURE',
    id_by => [
        transcript_structure_id => { 
            is => 'NUMBER', 
        },
        species => { is => 'varchar',
            is_optional => 1,
        },
        source => { is => 'VARCHAR',
            is_optional => 1,
        },
        version => { is => 'VARCHAR',
            is_optional => 1,
        },
    ],
    has => [
        transcript_id => {  #TODO changed to text extended length
            is => 'Text', 
        },
        structure_type => { 
            is => 'VARCHAR',    
            is_optional => 1 
        },
        structure_start => { 
            is => 'NUMBER', 
            is_optional => 1 
        },
        structure_stop => { 
            is => 'NUMBER', 
            is_optional => 1 
        },
        ordinal => { 
            is => 'NUMBER', 
            is_optional => 1
        },
        phase => { 
            is => 'NUMBER', 
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
        chrom_name => {
            via => 'transcript',
        },
        gene => {
            via => 'transcript',
        },
        gene_name =>  {
            via => 'gene',
            to => 'name',
        },
        transcript_name => {
            via => 'transcript',
        },
    ],
    schema_name => 'files',
    data_source => 'Genome::DataSource::TranscriptSubStructures',
};

sub rename_to_errors_later {  #TODO not sure what the new valid sub name is
    my $self = shift;
    return if grep  { ! defined $self->$_ } qw/structure_type structure_start structure_stop ordinal/;
    return unless $self->structure_stop >= $self->structure_start;
    unless ($self->structure_type =~ /intron/){
        return unless defined $self->nucleotide_seq;
    }
    return 1;
}

sub length {
    my $self = shift;
    my $length = $self->structure_stop - $self->structure_start + 1;
    return $length;
}

sub strand {
    my $self = shift;
    my $t = $self->transcript;
    my $strand = '.';
    if ($t->strand eq '+1') {
        $strand = '+';
    } elsif ($t->strand eq '-1') {
        $strand = '-';
    }
    return $strand;
}

sub frame {
    my $self = shift;
    if (defined($self->phase)) {
        return $self->phase;
    }
    return '.';
}

sub bed_string {
    my $self = shift;
    my $bed_string = $self->chrom_name ."\t". $self->structure_start ."\t". $self->structure_stop ."\t". $self->gene_name
        .':'. $self->structure_type .":". $self->ordinal ."\t0\t". $self->strand ."\n";
    return $bed_string;
}

sub _base_gff_string {
    my $self = shift;
    return $self->chrom_name ."\t". $self->source .'_'. $self->version ."\t". $self->structure_type ."\t". $self->structure_start ."\t". $self->structure_stop ."\t.\t". $self->strand ."\t". $self->frame;
}

sub gff_string {
    my $self = shift;
    return $self->_base_gff_string ."\t". $self->gene_name ."\n";
}

sub gff3_string {
    my $self = shift;
    return $self->_base_gff_string ."\tID=". $self->transcript_structure_id .'; PARENT='. $self->transcript->transcript_id .';' ."\n";
}

sub gtf_string {
    return undef;
}

1;

#TODO
=pod
=cut
