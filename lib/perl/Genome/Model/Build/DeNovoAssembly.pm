package Genome::Model::Build::DeNovoAssembly;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';
use Regexp::Common;

class Genome::Model::Build::DeNovoAssembly {
    is => 'Genome::Model::Build',
    is_abstract => 1,
    subclassify_by => 'subclass_name',
    has => [
        subclass_name => { is => 'String', len => 255, is_mutable => 0, column_name => 'SUBCLASS_NAME',
                           calculate_from => ['model_id'],
                           calculate => sub {
                                            my($model_id) = @_;
                                            return unless $model_id;
                                            my $model = Genome::Model->get($model_id);
                                            Carp::croak("Can't find Genome::Model with ID $model_id while resolving subclass for Build") unless $model;
                                            my $assembler_name = $model->assembler_name;
                                            Carp::croak("Can't subclass Build: Genome::Model id $model_id has no assembler_name") unless $assembler_name;
                                            return __PACKAGE__ . '::' . Genome::Utility::Text::string_to_camel_case($assembler_name);
                                          },
                         },
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

sub _X_resolve_subclass_name {
    my $class = shift;
    return __PACKAGE__->_resolve_subclass_name_by_assembler_name(@_);
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

    my $avg_read_length = $read_length / $instrument_data_cnt;
    if ( defined $self->processing_profile->read_trimmer_name ) {
        return int($avg_read_length * .9);
    }

    return $avg_read_length;
}

sub calculate_read_limit_from_read_coverage {
    my $self = shift;

    my $read_coverage = $self->processing_profile->read_coverage;
    return unless defined $read_coverage;
    
    my $estimated_read_length = $self->estimate_average_read_length; # dies
    my $genome_size = $self->genome_size;
    
    my $read_max = int($genome_size * $read_coverage / $estimated_read_length);

    unless ( $read_max % 2 == 0 ) {
        # make it an even number
        $read_max++;
    }

    return $read_max;
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

sub meaningful_metric_names {
    return {
	# contig
	'total_contig_number' => 'contigs',
	'n50_contig_length' => 'median_contig_length',
	# supercontig
	'total_supercontig_number' => 'supercontigs',
	'n50_supercontig_length' => 'median_supercontig_length',
	# reads
	'total_input_reads' => 'reads_processed',
	'placed_reads' => 'reads_assembled',
	# bases
	'total_contig_bases' => 'assembly_length',
	};
}

#<>#


1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Build/DeNovoAssembly.pm $
#$Id: DeNovoAssembly.pm 47126 2009-05-21 21:59:11Z ebelter $
