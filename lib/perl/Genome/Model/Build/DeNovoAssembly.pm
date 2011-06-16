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
                Carp::croak("Cannot subclass build: no model ($model_id)") if not  $model;
                my $processing_profile_id = $model->processing_profile_id;
                my $processing_profile = $model->processing_profile;
                Carp::croak("Cannot subclass build: processing profile ($processing_profile_id) does not exist for model ($model_id)") if not $processing_profile;
                my $assembler_base_name = $processing_profile->assembler_base_name;
                Carp::croak("Can't subclass build: processing profile ($processing_profile_id)  has no assembler base name") unless $assembler_base_name;
                return __PACKAGE__ . '::' . Genome::Utility::Text::string_to_camel_case($assembler_base_name);
            },
        },
        #TODO - best place for this??
        processed_reads_count => {
            is => 'Integer',
            is_optional => 1,
            is_mutable => 1,
            doc => 'Number of reads processed for assembling',
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

sub validate_for_start_methods {
    my $self = shift;
    my @methods = $self->SUPER::validate_for_start_methods;
    push @methods, 'instrument_data_assigned';
    return @methods;
}

sub instrument_data_assigned {
    my $self = shift;
    my @tags;

    my @instrument_data = $self->instrument_data;
    unless (@instrument_data or $self->processing_profile->assembler_name =~ /import/) {
        push @tags, UR::Object::Tag->create(
            properties => ['instrument_data'],
            desc => 'No instrument for build',
        );
    }

    return @tags;
}

sub calculate_estimated_kb_usage {
    my $self = shift;

    my $kb_usage;

    if ( $self->processing_profile->assembler_name =~ /import/ ) {
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

sub genome_size {
    my $self = shift;

    return $self->genome_size_used if $self->genome_size_used;

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
    # TODO add more...

    unless ( $taxon ) {
        Carp::confess('De Novo Assembly model ('.$self->model->id.' '.$self->model->name.') does not have a taxon associated with it\'s subject ('.$subject->id.' '.$subject->name.').');
    }

    if ( defined $taxon->estimated_genome_size ) {
        $self->genome_size_used( $taxon->estimated_genome_size );
        return $taxon->estimated_genome_size;
    }
    elsif ( defined $taxon->domain and $taxon->domain =~ /bacteria/i ) {
        $self->genome_size_used( 4000000 );
        return 4000000;
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
        'major contig length',
        'assembly length',
        'contigs', 'n50 contig length', 'average contig length',
        'average contig length gt 300', 'n50_contig_length_gt_300', #soap
        'average contig length gt 500', 'n50_contig_length_gt_500', #velvet
        'average supercontig length gt 500', 'n50_supercontig_length_gt_500',
        'average supercontig length gt 300', 'n50_supercontig_length_gt_300',
        'supercontigs', 'n50 supercontig length', 'average supercontig length',
        'average read length',
        'reads attempted', 
        'reads processed', 'reads processed success',
        'reads assembled', 'reads assembled success', 'reads not assembled pct',
        'read_depths_ge_5x',
        'genome size used',
        'average insert size used',
    );
}

sub set_metrics {
    my $self = shift;

    my %metrics = $self->calculate_metrics
        or return;

    print Dumper \%metrics;

    for my $name ( keys %metrics ) {
        $self->$name( $metrics{$name} );
    }

    eval{ $self->_additional_metrics(\%metrics); };

    return %metrics;
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
        } else {
            Carp::confess( 
                $self->error_message("Unsupported sequencing platform or inst_data class (".$self->sequencing_platform." ".$inst_data->class."). Can't calculate reads attempted.")
            );
        }
    }

    return $reads_attempted;
}

sub calculate_average_insert_size {
    my $self = shift;

    return $self->average_insert_size_used if $self->average_insert_size_used;

    #check if insert size is set in processing-profile
    my %assembler_params = $self->processing_profile->assembler_params_as_hash;
    if ( exists $assembler_params{'insert_size'} and $self->processing_profile->assembler_base_name eq 'soap') { #bad
        $self->status_message("Using insert size set in assembler params");
        my $insert_size = $assembler_params{'insert_size'};
        $self->average_insert_size_used( $insert_size );
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
            unless ( $insert_size =~ /^\d+$/ or $insert_size =~ /^\d+\s+\d+$/ ) {
                Carp::confess(
                    $self->status_message("Expected a number or two numbers separated by blank space but got: $insert_size")
                );
            }
            my @sizes = split( /\s+/, $insert_size );
            @insert_sizes = ( @insert_sizes, @sizes );
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

    my $average_insert_size = $sum / scalar(@insert_sizes);

    $self->average_insert_size_used( $average_insert_size );

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

#< Metrics >#
sub calculate_metrics {
    my  $self = shift;

    my $stats_file = $self->stats_file;
    my $stats_fh = eval{ Genome::Sys->open_file_for_reading($stats_file); };
    unless ( $stats_fh ) {
        $self->error_message("Can't set metrics because can't open stats file ($stats_file).");
        return;
    }

    my %stat_to_metric_names = ( # old names to new
        'major contig length' => 'major_contig_length',			 
        # contig
        'total contig number' => 'contigs',
        'n50 contig length' => 'n50_contig_length',
        'major_contig n50 contig length' => 'n50_contig_length_gt_MCL',
        'average contig length' => 'average_contig_length',
        'major_contig avg contig length' => 'average_contig_length_gt_MCL',	 
        # supercontig
        'total supercontig number' => 'supercontigs',
        'n50 supercontig length' => 'n50_supercontig_length',
        'major_supercontig n50 contig length' => 'n50_supercontig_length_gt_MCL',
        'average supercontig length' => 'average_supercontig_length',
        'major_supercontig avg contig length' => 'average_supercontig_length_gt_MCL',
        # reads
        'total input reads' => 'reads_processed',
        'placed reads' => 'reads_assembled',
        'chaff rate' => 'reads_not_assembled_pct',
        'average read length' => 'average_read_length',
        # bases
        'total contig bases' => 'assembly_length',
        # read depths
        'depth >= 5' => 'read_depths_ge_5x',
        #add'l metrics .. really not part of stats but is build metrics			 
        'genome size used' => 'genome_size_used',
        'average insert size used' => 'average_insert_size_used',
    );

    my %metrics;
    my $major_contig_length;
    while ( my $line = $stats_fh->getline ) { #reading stats file
        #get metrics
        next unless $line =~ /\:/;
        chomp $line;

        #get major contig length .. slightly different than getting rest of values
        if ($line =~ /^Major\s+Contig\s+\(/) {
            ($major_contig_length) = $line =~ /^Major\s+Contig\s+\(>\s+(\d+)\s+/;
            $metrics{'major_contig_length'} = $major_contig_length; #300 for soap, 500 for velvet
            next;
        }

        my ($stat, $values) = split(/\:\s+/, $line);
        $stat = lc $stat;
        next unless grep { $stat eq $_ } keys %stat_to_metric_names;

        unless ( defined $values ) {
            $self->error_message("Found '$stat' in stats file, but it does not have a value on line ($line)");
            return;
        }

        my @tmp = split (/\s+/, $values);

        #in most value we want is $tmp[0] which in most cases is a number but can be NA
        my $value = $tmp[0];

        # Addl processing of values needed
        if ($stat eq 'depth >= 5') {
            unless (defined $tmp[1]) {
                $self->error_message("Failed to derive >= 5x depth from line: $values\n\t".
                    "Expected line like: 3760	0.0105987146239711");
                return;
            }
            $value = $tmp[1];
        }

        my $metric = delete $stat_to_metric_names{$stat};
        #to account differences in major contig length among assemblers
        $metric =~ s/MCL$/$major_contig_length/ if $metric =~ /length_gt_MCL/;

        $metrics{$metric} = $value;
    }

    #warn about any metrics not defined in stats file
    if ( %stat_to_metric_names ) {
        $self->status_message(
            'Missing these metrics ('.join(', ', keys %stat_to_metric_names).') in stats file ($stats_file)'
        );
        #return;
    }

    #further processing of metric values
    #unused reads .. NA for soap assemblies, a number for others
    unless ($metrics{reads_not_assembled_pct} eq 'NA') {
        $metrics{reads_not_assembled_pct} =~ s/%//;
        $metrics{reads_not_assembled_pct} = sprintf('%0.3f', $metrics{reads_not_assembled_pct} / 100);
    }

    #additional calculations needed to derive metric values

    #reads attempted, total input reads
    $metrics{reads_attempted} = $self->calculate_reads_attempted
        or return; # error in sub

    #reads that pass filtering
    $metrics{reads_processed_success} =  sprintf(
        '%0.3f', $metrics{reads_processed} / $metrics{reads_attempted}
    );

    #assembled reads - NA for soap ..currently don't know now many of input reads actually assemble
    $metrics{reads_assembled_success} = ( $metrics{reads_assembled} eq 'NA' ) ? 'NA' :
    sprintf( '%0.3f', $metrics{reads_assembled} / $metrics{reads_processed} );

    #5x coverage stats - not defined for soap assemblies
    $metrics{read_depths_ge_5x} = ( $metrics{read_depths_ge_5x} ) ? sprintf ('%0.1f', $metrics{read_depths_ge_5x} * 100) : 'NA';

    #genome and average insert size used
    my $genome_size_used;

    eval { $genome_size_used = $self->genome_size; };
    if ( $@ ) { #okay for this to fail for soap assemblies for now .. 
        $genome_size_used = 'NA';
    }

    $metrics{genome_size_used} = $genome_size_used;
    $metrics{average_insert_size_used} = $self->calculate_average_insert_size;

    return %metrics;
}

sub _add_metrics { return 1; }

# Old metrics
sub total_contig_number { return $_[0]->contigs; }
#sub n50_contig_length { return $_[0]->n50_contig_length; }
sub total_supercontig_number { return $_[0]->supercontigs; }
#sub n50_supercontig_length { return $_[0]->n50_supercontig_length; }
sub total_input_reads { return $_[0]->reads_processed; }
sub placed_reads { return $_[0]->reads_assembled; }
sub chaff_rate { return $_[0]->reads_not_assembled_pct; }
sub total_contig_bases { return $_[0]->assembly_length; }
#<>#
#< make soap config file >#

sub create_config_file {
    my $self = shift;

    $self->status_message("Creating soap config file");

    my $config = $self->get_config_for_libraries;
    if ( not $config ) {
        $self->error_message("Failed to get config info for build");
        return;
    }

    my $config_file = $self->soap_config_file;
    unlink $config_file if -e $config_file;

    my $fh;
    eval {
        $fh = Genome::Sys->open_file_for_writing( $config_file );
    };
    if ( not defined $fh ) {
        $self->error_message("Can not open soap config file ($config_file) for writing $@");
        return;
    }
    $fh->print( $config );
    $fh->close;

    $self->status_message("Ok created soap config file");

    #return 1;
    return $config_file;
}

sub get_config_for_libraries {
    my $self = shift;

    my @libraries = $self->libraries_with_existing_assembler_input_files;
    if ( not @libraries ) {
        $self->error_message("No assembler input files were found for libraries");
        return;
    }
    $self->status_message('OK...fastq files for libraires');

    my $config = "max_rd_len=120\n";
    for my $library ( @libraries ) {
        my $insert_size = $library->{insert_size};# || 320;# die if no insert size
        $config .= <<CONFIG;
[LIB]
avg_ins=$insert_size
reverse_seq=0
asm_flags=3
pair_num_cutoff=2
map_len=60
CONFIG
        if ( exists $library->{paired_fastq_files} ) { 
            $config .= 'q1='.$library->{paired_fastq_files}->[0]."\n";
            $config .= 'q2='.$library->{paired_fastq_files}->[1]."\n";
        }

        if ( exists $library->{fragment_fastq_file} ) {
            $config .= 'q='.$library->{fragment_fastq_file}."\n";
        }
    }

    return $config;

}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Build/DeNovoAssembly.pm $
#$Id: DeNovoAssembly.pm 47126 2009-05-21 21:59:11Z ebelter $
