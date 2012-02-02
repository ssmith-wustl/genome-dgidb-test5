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
        subclass_name => { 
            is => 'String', len => 255, is_mutable => 0,
            calculate_from => ['model_id'],
            calculate => sub {
                my($model_id) = @_;
                return unless $model_id;
                my $model = Genome::Model->get($model_id);
                Carp::croak("Cannot subclass build: no model ($model_id)") if not  $model;
                my $processing_profile_id = $model->processing_profile_id;
                my $processing_profile = $model->processing_profile;
                Carp::croak("Cannot subclass build: processing profile ($processing_profile_id) does not exist for model ($model_id)") if not $processing_profile;
                my $assembler_base_name = $processing_profile->assembler_base_name;
                Carp::croak("Can't subclass build: processing profile ($processing_profile_id)  has no assembler base name") unless $assembler_base_name;
                return __PACKAGE__ . '::' . Genome::Utility::Text::string_to_camel_case($assembler_base_name);
            },
        },
    ],
    has_optional => [
        (
            map { 
                join('_', split(m#\s#)) => {
                    is => 'Number',
                    is_optional => 1,
                    is_metric => 1,
                }
            } __PACKAGE__->metric_names
        ),
    ],
};

sub description {
    my $self = shift;

    return sprintf(
        '%sde novo %s build (%s) for model (%s %s)',
        ( $self->is_imported ? 'imported ' : '' ),
        $self->processing_profile->assembler_name,
        $self->id,
        $self->model->name,
        $self->model->id,
    );
}

sub is_imported {
    my $self = shift;
    if ( $self->processing_profile->assembler_name =~ /import/ ) {
        return 1;
    }
    return;
}

sub validate_for_start_methods {
    my $self = shift;
    my @methods = $self->SUPER::validate_for_start_methods;
    push @methods, 'validate_instrument_data_and_insert_size';
    return @methods;
}

sub validate_instrument_data_and_insert_size {
    my $self = shift;

    return if $self->is_imported;

    # Check that inst data is assigned
    my @instrument_data = $self->instrument_data;
    unless (@instrument_data) {
        return UR::Object::Tag->create(
            properties => ['instrument_data'],
            desc => 'No instrument for build',
        );
    }

    # Check insert size
    my %assembler_params = $self->processing_profile->assembler_params_as_hash; # DEPRECATED!
    return if defined $assembler_params{insert_size};

    my @tags;
    for my $instrument_data ( @instrument_data ) {
        my $library = $instrument_data->library;
        my $insert_size = $library->fragment_size_range;
        next if defined $insert_size;
        $insert_size = eval{ $instrument_data->median_insert_size; };
        next if defined $insert_size;
        push @tags, UR::Object::Tag->create(
            properties => [ 'instrument_data' ],
            desc => 'No insert size for instrument data ('.$instrument_data->id.') or library ('.$library->id.'). Please correct.',
        );
    }

    return @tags if @tags;
    return;
}

sub calculate_estimated_kb_usage {
    my $self = shift;

    my $kb_usage;

    if ( $self->is_imported ) {
        $self->status_message("Kb usage for imported assembly: 5GiB");
        return 5_000_000;
    }

    if (defined $self->model->processing_profile->coverage) {
        #estimate usage by 0.025kb per base and 5GB for logs/error output
        my $bases;
        unless ($bases = $self->calculate_base_limit_from_coverage()) {
            $self->error_message("Failed to get calculated base limit from coverage");
            return;
        }

        $kb_usage = int (0.025 * $bases + 5_000_000);
    }
    else {
        #estimate usage = reads attempted * 2KB
        my $reads_attempted;

        unless ($reads_attempted = $self->calculate_reads_attempted()) {
            $self->error_message("Failed to get reads attempted");
            return;
        }

        $kb_usage = int ($reads_attempted * 2 + 5_000_000);
    } 

    #limit disk reserve to 50G .. 
    return 60_000_000 if $kb_usage > 60_000_000;

    return $kb_usage;
}

sub input_metrics_file_for_instrument_data {
    my $self = shift;
    my $instrument_data = shift;
    my %params = $self->read_processor_params_for_instrument_data($instrument_data);
    my $result = Genome::InstrumentData::SxResult->get(%params);
    return $self->data_directory.'/'.$result->read_processor_input_metric_file;
}
 
sub output_metrics_file_for_instrument_data {
    my $self = shift;
    my $instrument_data = shift;
    my %params = $self->read_processor_params_for_instrument_data($instrument_data);
    my $result = Genome::InstrumentData::SxResult->get(%params);
    return $self->data_directory.'/'.$result->read_processor_input_metric_file;
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
        $taxon = $subject->source->taxon unless $taxon;
    }

    unless ( $taxon ) {
        Carp::confess('De Novo Assembly model ('.$self->model->id.' '.$self->model->name.') does not have a taxon associated with it\'s subject ('.$subject->id.' '.$subject->name.').');
    }

    if ( defined $taxon->estimated_genome_size ) {
        return $taxon->estimated_genome_size;
    }
    #elsif ( defined $taxon->domain and $taxon->domain =~ /bacteria/i ) {
    else {
        return 4000000;
    }

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
sub metric_names {
    return (qw/
        assembly_length major_contig_threshold
        contigs_count contigs_length contigs_average_length
        contigs_major_count contigs_major_length contigs_major_average_length 
        contigs_n50_count contigs_n50_length
        contigs_major_n50_count contigs_major_n50_length
        genome_size insert_size
        supercontigs_count supercontigs_length supercontigs_average_length
        supercontigs_major_count supercontigs_major_length supercontigs_major_average_length 
        supercontigs_n50_count supercontigs_n50_length
        supercontigs_major_n50_count supercontigs_major_n50_length
        reads_attempted reads_processed reads_processed_success reads_assembled reads_assembled_duplicate reads_assembled_success
        /);
}

#< Inst Data Info >#
sub calculate_reads_attempted {
    my $self = shift;

    my @instrument_data = $self->instrument_data;
    unless ( @instrument_data ) {
        Carp::confess( 
            $self->error_message("Can't calculate reads attempted, because no instrument data found for ".$self->description)
        );
    }

    my $reads_attempted = 0;
    for my $inst_data ( @instrument_data ) { 
        if ($inst_data->class =~ /Solexa/){
            $reads_attempted += $inst_data->fwd_clusters;
            $reads_attempted += $inst_data->rev_clusters;
        }elsif($inst_data->class =~ /Imported/){
            $reads_attempted += $inst_data->read_count;
        } elsif ( $inst_data->class =~ /454/ ) {
            $reads_attempted += $inst_data->total_reads;
        } else {
            Carp::confess( 
                $self->error_message("Unsupported sequencing platform or inst_data class (".$inst_data->class."). Can't calculate reads attempted.")
            );
        }
    }

    return $reads_attempted;
}

sub calculate_average_insert_size {
    my $self = shift;

    #check if insert size is set in processing-profile
    my %assembler_params = $self->processing_profile->assembler_params_as_hash;
    if ( exists $assembler_params{'insert_size'} and $self->processing_profile->assembler_base_name eq 'soap') { #bad
        $self->status_message("Using insert size set in assembler params");
        my $insert_size = $assembler_params{'insert_size'};
        return $insert_size;
    }

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
            my $insert_size = ( $inst_data->median_insert_size ) ? $inst_data->median_insert_size : $inst_data->library->fragment_size_range;
            unless ( defined $insert_size ) {
                Carp::confess(
                    $self->error_message("Failed to get median insert size from inst data nor frag size range from library for inst data")
                );
            }
            unless ( $insert_size =~ /^\d+$/ or $insert_size =~ /^\d+\s+\d+$/ or $insert_size =~ /^\d+-\d+$/ or $insert_size =~ /^\d+\.\d+$/ ) {
                Carp::confess(
                    $self->status_message("Expected a number or two numbers separated by blank space but got: $insert_size")
                );
            }
            my @sizes = split( /\s+|-/, $insert_size );
            @insert_sizes = ( @insert_sizes, @sizes );
        }
        else {
            Carp::confess( 
                $self->error_message("Unsupported sequencing platform (".$inst_data->sequencing_platform."). Can't calculate insert size and standard deviation.")
            );
        }
    }

    unless ( @insert_sizes ) {
        $self->status_message("No insert sizes found in instrument data for ".$self->description);
        return;
    }

    my $sum = List::Util::sum(@insert_sizes);
    my $average_insert_size = $sum / scalar(@insert_sizes);
    $average_insert_size = POSIX::floor($average_insert_size);
    return $average_insert_size;
}

sub is_insert_size_set_by_pp { #remove??
    my $self = shift;

    my %params = $self->processing_profile->assembler_params_as_hash;

    return $params{'insert_size'} if exists $params{'insert_size'};

    return;
}

#< Files / Dirs >#
sub edit_dir {
    return $_[0]->data_directory.'/edit_dir';
}

sub stats_file { 
    return $_[0]->edit_dir.'/stats.txt';
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

sub assembly_fasta_file {
    return contigs_bases_file(@_);
}

#< Misc >#
sub center_name {
    return $_[0]->model->center_name || 'WUGC';
}

#< Assemble >#
sub assembler_rusage { return; }
sub before_assemble { return 1; }
sub after_assemble { return 1; }

1;

