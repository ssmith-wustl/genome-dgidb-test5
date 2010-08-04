package Genome::Model::Build::DeNovoAssembly;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';
require List::Util;
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

	#TODO - best place for this??
	processed_reads_count => { is => 'Integer', is_optional => 1, is_mutable => 1, doc => 'Number of reads processed for assembling',
	},

        (
            map { 
                join('_', split(m#\s#)) => {
                    is => 'Number',
                    is_optional => 1,
                    is_mutable => 1,
                    via => 'metrics',
                    where => [ name => $_ ],
                    to => 'value',
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
    my $self = shift;

    my $kb_usage;

    if (defined $self->model->processing_profile->coverage) {
	#estimate usage by 0.025kb per base and 5GB for logs/error output
	my $bases;
	unless ($bases = $self->calculate_base_limit_from_coverage()) {
	    $self->error_message("Failed to get calculated base limit from coverage");
	    return;
	}

	$kb_usage = 0.025 * $bases + 5_000_000;
    }
    else {
	#estimate usage = reads attempted * 2KB
	my $reads_attempted;

	unless ($reads_attempted = $self->calculate_reads_attempted()) {
	    $self->error_message("Failed to get reads attempted");
	    return;
	}

	$kb_usage = $reads_attempted * 2 + 5_000_000;
    } 

    #limit disk reserve to 50G .. 
    return 60_000_000 if $kb_usage > 60_000_000;

    return $kb_usage;
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

sub calculate_base_limit_from_coverage {
    my $self = shift;

    my $coverage = $self->processing_profile->coverage;
    return unless defined $coverage; # ok
    
    my $genome_size = $self->genome_size; # dies on error
    
    return $genome_size * $coverage;
}

#< Metrics >#
sub interesting_metric_names {
    return (
        'assembly length',
        'contigs', 'median contig length', 'average contig length',
        'average contig length gt 500', 'median_contig_length_gt_500',
        'supercontigs', 'median supercontig length', 'average supercontig length',
        'average supercontig length gt 500', 'median_supercontig_length_gt_500',
        'average read length',
        'reads attempted', 
        'reads processed', 'reads processed success',
        'reads assembled', 'reads assembled success', 'reads not assembled pct',
        'read_depths_ge_5x',
    );
}

sub set_metrics {
    my $self = shift;

    my %metrics = $self->calculate_metrics
        or return;

    for my $name ( keys %metrics ) {
        $self->$name( $metrics{$name} );
    }
    
    return %metrics;
}

#< Inst Data Info >#
sub calculate_reads_attempted {
    my $self = shift;

    my @instrument_data = $self->instrument_data;
    unless ( @instrument_data ) {
        $self->error_message("Can't calculate reads attempted, because no instrument data found for ".$self->description);
        return;
    }

    my $reads_attempted = 0;
    if ( $self->processing_profile->sequencing_platform eq 'solexa' ) {
        for my $inst_data ( @instrument_data ) { 
            $reads_attempted += $inst_data->fwd_clusters;
            $reads_attempted += $inst_data->rev_clusters;
        }
    }
    else {
        Carp::confess( 
            $self->error_message("Unsupported sequencing platform (".$self->sequencing_platform."). Can't calculate reads attempted.")
        );
    }

    return $reads_attempted;
}

sub calculate_average_insert_size {
    my $self = shift;

    my @instrument_data = $self->instrument_data;
    unless ( @instrument_data ) {
        Carp::confess(
            $self->error_message("No instrument data found for ".$self->description.". Can't calculate insert size and standard deviation.")
        );
        return;
    }

    my @insert_sizes;
    for my $inst_data ( @instrument_data ) { 
        if ( $inst_data->sequencing_platform eq 'solexa' ) {
            my $median_insert_size = $inst_data->median_insert_size;
            next unless defined $median_insert_size;
            push @insert_sizes, $median_insert_size;
        }
        else {
            Carp::confess( 
                $self->error_message("Unsupported sequencing platform (".$self->sequencing_platform."). Can't calculate insert size and standard deviation.")
            );
        }
    }

    unless ( @insert_sizes ) {
        $self->status_message("No insert sizes found in instrument data for ".$self->description);
        return;
    }

    my $sum = List::Util::sum(@insert_sizes);

    return $sum / scalar(@insert_sizes);
}
#<>#

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Build/DeNovoAssembly.pm $
#$Id: DeNovoAssembly.pm 47126 2009-05-21 21:59:11Z ebelter $
