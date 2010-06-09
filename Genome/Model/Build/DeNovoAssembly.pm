package Genome::Model::Build::DeNovoAssembly;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';
use Regexp::Common;

class Genome::Model::Build::DeNovoAssembly {
    is => 'Genome::Model::Build',
    has => [
        (
            map { 
                join('_', split(m#\s#)) => {
                    is => 'Integer',
                    is_mutable => 1,
                    is_optional => 1,
                }
            } __PACKAGE__->interesting_metric_names
        )
    ],
};

sub description {
    my $self = shift;

    return sprintf(
        'de novo assembly %s build (%s) for model (%s %s)',
        $self->processing_profile->sequencing_platform,
        $self->id,
        $self->model->name,
        $self->model->id,
    );
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( $self->model->type_name eq 'de novo assembly' ) {
        $self->error_message( 
            sprintf(
                'Incompatible model type (%s) to build as an de novo assembly',
                $self->model->type_name,
            )
        );
        $self->delete;
        return;
    }

    mkdir $self->data_directory unless -d $self->data_directory;
    
    return $self;
}

sub calculate_estimated_kb_usage {
    return 51_200_000; # 50 Gb
}

sub genome_size {
    my $self = shift;

    my $model = $self->model;
    my $subject = $model->subject;
    unless ( $subject ) { # Should not happen
        Carp::confess('De Novo Assembly model ('.$model->id.' '.$model->name.') does not have a subject.');
    }

    my $taxon;
    if ( $subject->isa('Genome::Taxon') ) { 
        $taxon = $subject;
    }
    elsif ( $subject->isa('Genome::Sample') ) { 
        $taxon = $subject->taxon;
    }
    # TODO add more...

    unless ( $taxon ) {
        Carp::confess('De Novo Assembly model ('.$self->model->id.' '.$self->model->name.') does not have a taxon associated with it\'s subject ('.$subject->id.' '.$subject->name.').');
    }

    if ( defined $taxon->estimated_genome_size ) {
        return $taxon->estimated_genome_size;
    }
    elsif ( $taxon->domain =~ /bacteria/i ) {
        return 4500000;
    }
    # TODO add more
    print Dumper($taxon);
    
    Carp::confess('Cannot determine genom size for De Novo Assembly model\'s ('.$self->model->id.' '.$self->model->name.') associated taxon ('.$taxon->id.')');
}

sub estimate_average_read_length {
    my $self = shift;

    my @instrument_data = $self->instrument_data;
    unless ( @instrument_data ) {
        Carp::confess("No instruemnt data found for ".$self->description);
    }
    
    my $read_length = 0;
    my $instrument_data_cnt = 0;
    for my $instrument_data ( $self->instrument_data ) {
        $read_length += $instrument_data->read_length;
        $instrument_data_cnt++;
    }

    unless ( $read_length ) {
        Carp::confess("No read length found in instrument data (".join(', ', map { $_->id } @instrument_data).')');
    }

    if ( defined $self->processing_profile->read_trimmer_name ) {
        return int($read_length / $instrument_data_cnt * .9);
    }

    return $read_length;
}

sub calculate_read_limit_from_read_coverage {
    my $self = shift;

    my $read_coverage = $self->processing_profile->read_coverage;
    return unless defined $read_coverage;
    
    my $estimated_read_length = $self->estimate_average_read_length; # dies
    my $genome_size = $self->genome_size;
    
    return int($genome_size * $read_coverage / $estimated_read_length);

}

#< Metrics >#
sub interesting_metric_names {
    return (
        # contig
        'total contig number',
        'average contig length',
        'n50 contig length',
        # supercontig
        'total supercontig number',
        'average supercontig length',
        'n50 supercontig length',
        # reads
        'total input reads',
        'average read length',
        'placed reads',
        'chaff rate',
        # bases
        'total contig bases',
    );
}
#<>#

#< FIXME  subclass for velvet specific file names >#
sub collated_fastq_file {
    return $_[0]->data_directory.'/collated.fastq';
}

sub assembly_afg_file {
    return $_[0]->data_directory.'/velvet_asm.afg';
}

sub contigs_fasta_file {
    return $_[0]->data_directory.'/contigs.fa';
}

sub sequences_file {
    return $_[0]->data_directory.'/Sequences';
}

sub velvet_fastq_file {
    return $_[0]->data_directory.'/velvet.fastq';
}

sub velvet_ace_file {
    return $_[0]->data_directory.'/edit_dir/velvet_asm.ace';
}

sub stats_file { 
    return $_[0]->edit_dir.'/stats.txt';
}

#<>#

#< FIXME subclass for newbler specific file names >#
sub assembly_directory {
    return $_[0]->data_directory.'/assembly';
}

sub sff_directory {
    return $_[0]->data_directory.'/sff';
}

#ASSEMBLY OUTPUT FILES
sub edit_dir {
    return $_[0]->data_directory.'/edit_dir';
}

sub ace_file {
    return $_[0]->edit_dir.'/velvet_asm.ace';
}

sub gap_file {
    return $_[0]->edit_dir.'/gap.txt';
}

sub contigs_bases_file {
    return $_[0]->edit_dir.'/contigs.bases';
}

sub contigs_quals_file {
    return $_[0]->edit_dir.'/contigs.quals';
}

sub read_info_file {
    return $_[0]->edit_dir.'/readinfo.txt';
}

sub reads_placed_file {
    return $_[0]->edit_dir.'/reads.placed';
}

sub supercontigs_agp_file {
    return $_[0]->edit_dir.'/supercontigs.agp';
}

sub supercontigs_fasta_file {
    return $_[0]->edit_dir.'/supercontigs.fasta';
}

sub input_fastas {
    my $self = shift;
    my @files;
    foreach (glob($self->data_directory."/*fasta.gz")) {
	#make sure qual file exists for the fasta
	my ($qual_file) = $_ =~ s/\.gz$/\.qual\.gz/;
	next unless -s $qual_file;
	push @files, $_;
    }
    
    return @files;
}

#NEWBLER SPECIFIC
sub fasta_file {
    my $self = shift;
    my @instrument_data = $self->model->instrument_data;
    #SINGULAR FOR NOW .. NEED TO GET IT TO WORK FOR MULTIPLE INPUTS
    my $fasta = $instrument_data[0]->fasta_file;
    unless ($fasta) {
	$self->error_message("Instrument data does not have a fasta file");
	return;
    }
    #COPY THIS FASTA TO BUILD INPUT_DATA_DIRECTORY
    File::Copy::copy ($fasta, $self->input_data_directory);
    #RENAME THIS FASTA TO SFF_NAME.FA ??
    #RETURN TO PREPARE-INSTRUMENT DATA FOR CLEANING
    return 1;
}

sub input_data_directory {
    my $self = shift;
    mkdir $self->data_directory.'/input_data' unless
	-d $self->data_directory.'/input_data';
    return $self->data_directory.'/input_data';
}
#<>#

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Build/DeNovoAssembly.pm $
#$Id: DeNovoAssembly.pm 47126 2009-05-21 21:59:11Z ebelter $
