
package Genome::Model;

use strict;
use warnings;

use above "Genome";
use Term::ANSIColor;
use Genome::Model::EqualColumnWidthTableizer;
use File::Path;
use File::Basename;
use IO::File;

class Genome::Model {
    type_name => 'genome model',
    table_name => 'GENOME_MODEL',
    id_by => [
        genome_model_id => { is => 'NUMBER', len => 11 },
    ],
    has => [
        processing_profile 		     => { is => 'Genome::ProcessingProfile::ShortRead', id_by => 'processing_profile_id' },
        align_dist_threshold         => { via => 'processing_profile'},
        dna_type                     => { via => 'processing_profile'},
        genotyper_name               => { via => 'processing_profile'},
        genotyper_params             => { via => 'processing_profile'},
        indel_finder_name            => { via => 'processing_profile'},
        indel_finder_params          => { via => 'processing_profile'},
        multi_read_fragment_strategy => { via => 'processing_profile'},
        name                         => { is => 'VARCHAR2', len => 255 },
        prior                        => { via => 'processing_profile'},
        read_aligner_name            => { via => 'processing_profile'},
        read_aligner_params          => { via => 'processing_profile'},
        read_calibrator_name         => { via => 'processing_profile'},
        read_calibrator_params       => { via => 'processing_profile'},
        reference_sequence_name      => { via => 'processing_profile'},
		sample_name                  => { is => 'VARCHAR2', len => 255 },
        
        events                       => { is => 'Genome::Model::Event', is_many => 1, reverse_id_by => 'model', 
                                          doc => 'all events which have occurred for this model',
                                        },
        read_set_assignment_events   => { is => 'Genome::Model::Command::AddReads::AssignRun',
                                          is_many => 1,
                                          reverse_id_by => 'model',
                                          doc => 'each case of a read set being assigned to the model',
                                        },
                                        #this is to get some basic statistics..                         
        alignment_events             => { is => 'Genome::Model::Command::AddReads::AlignReads',
                                          is_many => 1,
                                          reverse_id_by => 'model',
                                          doc => 'each case of a read set being aligned to the model\'s reference sequence(s), possibly including multiple actual aligner executions',
                                     },
       #this is to get the SNP statistics...
       variation_events             => { is => 'Genome::Model::Command::AddReads::FindVariations::Maq',
                                          is_many => 1,
                                          reverse_id_by => 'model',
                                          doc => 'each case of a read set being aligned to the model\'s reference sequence(s), possibly including multiple actual aligner executions',
                                     },

        alignment_file_paths         => { via => 'alignment_events' },
        has_all_alignment_metrics    => { via => 'alignment_events', to => 'has_all_metrics' },
        has_all_variation_metrics    => { via => 'variation_events', to => 'has_all_metrics' },
        variant_count                => {
                                         doc => 'the differences between the genome and the reference',
                                         calculate => q|
                                                my @f = $self->_variant_list_files();
                                                my $c = 0;
                                                for (@f) {
                                                    my $fh = IO::File->new($_);
                                                    while ($fh->getline) {
                                                        $c++
                                                    }
                                                }
                                                return $c;
                                            |,
                                     },
        test                     => {
                                         is => 'Boolean',
                                         doc => 'testing flag',
                                         is_optional => 1,
                                         is_transient => 1,
                                  },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'The GENOME_MODEL table represents a particular attempt to model knowledge about a genome with a particular type of evidence, and a specific processing plan. Individual assemblies will reference the model for which they are assembling reads.',
};



sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    if ($^P) {
        $self->test(1);
    }
    return $self;
}

sub libraries {
    my $self = shift;
    my %libraries = map {$_->library_name => 1} $self->get_read_sets;
    my @distinct_libraries = keys %libraries;
    return @distinct_libraries;
}

sub _calculate_library_count {
    my $self = shift;
    return scalar($self->libraries);
}

sub run_names {
    my $self = shift;

    my %distinct_run_names = map { $_->run_name => 1}  $self->get_read_sets;
    my @distinct_run_names = keys %distinct_run_names;
    return @distinct_run_names;
}

sub _calculate_run_count {
    my $self = shift;
    return scalar($self->run_names);
}

sub get_read_sets {
    my $self = shift;

    my %distinct_run_ids = map { $_->run_id => 1}  $self->read_set_assignment_events;
    my @distinct_run_ids = keys %distinct_run_ids;
    return Genome::RunChunk->get(\@distinct_run_ids);
}

sub metrics_for_class {
    my $class = shift;
    my @metrics = qw(
                     library_count
                     run_count
                     total_read_count
                     total_reads_passed_quality_filter_count
                     total_bases_passed_quality_filter_count
                     aligned_read_count
                     unaligned_read_count
                     SNV_count
                     SNV_in_dbSNP_count
                     SNV_in_venter_count
                     SNV_in_watson_count
                     SNV_distinct_count
                     HQ_SNP_count
                     HQ_SNP_reference_allele_count
                     HQ_SNP_variant_allele_count
                     HQ_SNP_both_allele_count
                    );
    return @metrics;
}

sub generate_metrics_hash_ref {
    my $self = shift;
    #we get model metric names one way or another:
    my @model_metrics = $self->metrics_for_class;
    my %metric_name_value_hash;

    for my $metric (@model_metrics) {
        my $value;
        my $calculate_method = "_calculate_" . $metric;
        if ($self->can($calculate_method)) {
            $value = $self->$calculate_method;
        }
        else{
            $self->error_message("No _calculate_" . $calculate_method . " method has been defined for " . __PACKAGE__ . "\n");
            return;
        }
        $metric_name_value_hash{$metric} = $value;
    }
    return \%metric_name_value_hash;
}

#define calculate methods required


sub _calculate_total_read_count {
    my $self = shift;
    my @events = $self->alignment_events;
    return $self->_get_sum_of_metric_values_from_events('total_read_count',@events);
}

sub _calculate_total_reads_passed_quality_filter_count {
    my $self = shift;
    my @events = $self->alignment_events;
    return $self->_get_sum_of_metric_values_from_events('total_reads_passed_quality_filter_count',@events);
}

sub _calculate_total_bases_passed_quality_filter_count {
    my $self = shift;
    my @events = $self->alignment_events;
    return $self->_get_sum_of_metric_values_from_events('total_bases_passed_quality_filter_count',@events);
}

sub _calculate_aligned_read_count {
    my $self = shift;
    my @events = $self->alignment_events;
    return $self->_get_sum_of_metric_values_from_events('aligned_read_count',@events);
}

sub _calculate_aligned_base_pair_count {
    my $self = shift;
    my @events = $self->alignment_events;
    return $self->_get_sum_of_metric_values_from_events('aligned_base_pair_count',@events);
}

sub _calculate_unaligned_read_count {
    my $self = shift;
    my @events = $self->alignment_events;
    return $self->_get_sum_of_metric_values_from_events('unaligned_read_count',@events);
}

sub _calculate_unaligned_base_pair_count {
    my $self = shift;
    my @events = $self->alignment_events;
    return $self->_get_sum_of_metric_values_from_events('unaligned_base_pair_count',@events);
}

sub _calculate_SNV_count {
    my $self = shift;
    my @events = $self->variation_events;
    return $self->_get_sum_of_metric_values_from_events('SNV_count',@events);
}

sub _calculate_SNV_in_dbSNP_count {
    my $self = shift;
    my @events = $self->variation_events;
    return $self->_get_sum_of_metric_values_from_events('SNV_in_dbSNP_count',@events);
}

sub _calculate_SNV_in_venter_count {
    my $self = shift;
    my @events = $self->variation_events;
    return $self->_get_sum_of_metric_values_from_events('SNV_in_venter_count',@events);
}

sub _calculate_SNV_in_watson_count {
    my $self = shift;
    my @events = $self->variation_events;
    return $self->_get_sum_of_metric_values_from_events('SNV_in_watson_count',@events);
}

sub _calculate_SNV_distinct_count {
    my $self = shift;
    my @events = $self->variation_events;
    return $self->_get_sum_of_metric_values_from_events('SNV_distinct_count',@events);
}

sub _calculate_HQ_SNP_count {
    my $self = shift;
    my @events = $self->variation_events;
    return $self->_get_sum_of_metric_values_from_events('HQ_SNP_count',@events);
}

sub _calculate_HQ_SNP_reference_allele_count {
    my $self = shift;
    my @events = $self->variation_events;
    return $self->_get_sum_of_metric_values_from_events('HQ_SNP_reference_allele_count',@events);
}

sub _calculate_HQ_SNP_variant_allele_count {
    my $self = shift;
    my @events = $self->variation_events;
    return $self->_get_sum_of_metric_values_from_events('HQ_SNP_variant_allele_count',@events);
}

sub _calculate_HQ_SNP_both_allele_count {
    my $self = shift;
    my @events = $self->variation_events;
    return $self->_get_sum_of_metric_values_from_events('HQ_SNP_both_allele_count',@events);
}

sub _get_sum_of_metric_values_from_events {
    my $self = shift;
    my $metric_to_sum = shift;
    my @events = @_;

    my $metric_method = $metric_to_sum;
    my @values;
    for my $event (@events) {
        unless($event->can($metric_method)) {
            #do something;
            $self-error_message("The event you're trying to call " . $metric_method
                                . "on doesn't have that method.");
            return;
        }
        return "Not Found" if ($event->$metric_method !~ /^\d+$/);
     push @values, $event->$metric_method;
    }
    my $sum;
    $sum += $_ foreach @values;
    return $sum;
}

sub has_all_metrics {
    my $self = shift;
    my @metrics = $self->has_all_alignment_metrics;
    push @metrics, $self->has_all_variation_metrics;
    for my $metric (@metrics) {
        unless ($metric) {
            $self->error_message("Not all metrics were found for model ". $self->id);
            return 0;
        }
    }
    return 1;
}

# Operating directories

sub base_parent_directory {
    "/gscmnt/839/info/medseq"
}

sub data_parent_directory {
    my $self = shift;
    return $self->base_parent_directory . "/model_links"
}

sub sample_path {
    my $self = shift;
    return $self->data_parent_directory . $self->sample_name;
}

sub data_directory {
    my $self = shift;
    my $name = $self->name;
    return $self->data_parent_directory . '/' . $self->sample_name . "_" . $name;
}

sub lock_directory {
    my $self = shift;
    my $data_directory = $self->data_directory;
    my $lock_directory = $data_directory . '/locks/';
    if (-d $data_directory and not -d $lock_directory) {
        mkdir $lock_directory;
        chmod 02775, $lock_directory;
    }
    return $lock_directory;
}

sub directory_for_run {
    my ($self, $run) = @_;
    return sprintf('%s/runs/%s/%s', 
        $self->data_directory,
        $run->sequencing_platform,
        $run->name
    );
}
sub directory_for_log {
    my ($self, $run) = @_;
    return sprintf('%s/logs/%s/%s', 
        $self->data_directory,
        $run->sequencing_platform,
        $run->name
    );
}


# Refseq directories and names

sub reference_sequence_path {
    my $self = shift;
    my $path = sprintf('%s/reference_sequences/%s', $self->base_parent_directory,
						$self->reference_sequence_name);

    my $dna_type = $self->dna_type;
    $dna_type =~ tr/ /_/;

    if (-d $path . '.' . $dna_type) {
        $path .= '.' . $dna_type
    }

    return $path;
}

sub get_subreference_paths {
    my $self = shift;
    my %p = @_;
    
    my $ext = $p{reference_extension};
    
    return glob(sprintf("%s/*.%s",
                        $self->reference_sequence_path,
                        $ext));
    
}

sub get_subreference_names {
    my $self = shift;
    my %p = @_;
    
    my $ext = $p{reference_extension} || 'fasta';

    my @paths = $self->get_subreference_paths(reference_extension=>$ext);
    
    my @basenames = map {basename($_)} @paths;
    for (@basenames) {
        s/\.$ext$//;
    }
    
    return @basenames;    
}


# Results data
# TODO: refactor to not be directly in the model

# TODO: this consensus doesn't have the alignments, so assembly is not a good name
*assembly_file_for_refseq = \&_consensus_files;

sub _consensus_files {
    return shift->_files_for_pattern_and_optional_ref_seq_id('%s/consensus/%s.cns',@_);
}

sub _variant_list_files {
    return shift->_files_for_pattern_and_optional_ref_seq_id('%s/identified_variations/snips_%s',@_);
}

sub _variant_pileup_files {
    return shift->_files_for_pattern_and_optional_ref_seq_id('%s/identified_variations/pileup_%s',@_);
}

sub _variant_detail_files {
    return shift->_files_for_pattern_and_optional_ref_seq_id('%s/identified_variations/report_input_%s',@_);
}

sub _filtered_variants_dir {
    my $self = shift;
    return sprintf('%s/filtered_variations/',$self->data_directory);
}

sub _reports_dir {
    my $self = shift;
    return sprintf('%s/reports/',$self->data_directory);
}

sub _files_for_pattern_and_optional_ref_seq_id {
    $DB::single = 1;
    my $self=shift;
    my $pattern = shift;
    my $ref_seq=shift;
    
    my @files = 
        map { 
            sprintf(
                $pattern,
                $self->data_directory,
                $_
            )
        }
        grep { $_ ne 'all_sequences' }
        grep { (!defined($ref_seq)) or ($ref_seq eq $_) }
        $self->get_subreference_names;
        
    return @files;
}

sub _files_for_pattern_and_params {
    my $self = shift;
    my $pattern = shift;
    my %params = @_;
    my $ref_seq_id = delete $params{'ref_seq_id'};
    Carp::confess("unknown params! " . Data::Dumper::Dumper(\%params)) if keys %params;
    return $self->_files_for_pattern_and_optional_ref_seq_id($pattern, $ref_seq_id);
}

sub alignments_maplist_directory {
    my $self = shift;
    return $self->data_directory . '/alignments.maplist'; 
}

sub maplist_file_paths {
    my $self = shift;

    my %p = @_;
    my $ref_seq_id;

    if (%p) {
        $ref_seq_id = $p{ref_seq_id};
    } else {
        $ref_seq_id = 'all_sequences';
    }

    return grep { -e $_ } glob($self->alignments_maplist_directory .'/*_'. $ref_seq_id .'.maplist');
}

##

sub library_names {
    my $self = shift;
    die "TOOD: write me!";    
}


sub _mapmerge_locally {
    my($self,$ref_seq_id,@maplists) = @_;

    $ref_seq_id ||= 'all_sequences';

    my $result_file = '/tmp/mapmerge_' . $self->genome_model_id . '-' . $ref_seq_id;

    my @inputs;
    foreach my $listfile ( @maplists ) {
        my $f = IO::File->new($listfile);
        next unless $f;
        chomp(my @lines = $f->getlines());

        push @inputs, @lines;
    }

    if (-f $result_file && -s $result_file) {
        $self->warning_message("Using mapmerge file left over from previous run: $result_file");
    } else {
        $self->warning_message("Performing a complete mapmerge.  Hold on...");
        my $cmd = Genome::Model::Tools::Maq::MapMerge->create(use_version => '0.6.5', output => $result_file, inputs => \@inputs);
        $cmd->execute();
        $self->warning_message("mapmerge complete.  output filename is $result_file");
    }
    return $result_file;
}


sub resolve_accumulated_alignments_filename {
    my $self = shift;
    my %p = @_;
    my $ref_seq_id = $p{ref_seq_id};
    my $library_name = $p{library_name};

    my @maplists;
    if ($ref_seq_id) {
        @maplists = $self->maplist_file_paths(%p);
    } else {
        @maplists = $self->maplist_file_paths();
    }
    if ($library_name) {
        @maplists = grep { /$library_name/ } @maplists;
    }

    if (!@maplists) {
        $self->error_message("No maplists found");
        return;
    }

    if ($self->test) {
        # If we're running under the debugger, the fork() below will mess things up
        return $self->_mapmerge_locally($ref_seq_id,@maplists);
    }

    my $vmerge = Genome::Model::Tools::Maq::Vmerge->create(
                                                           maplist => \@maplists,
                                                       );
    unless (Genome::DataSource::GMSchema->set_all_dbh_to_inactive_destroy) {
        $self->error_message("Could not set all dbh to inactive destroy");
        exit(1);
    }
    my $pid = fork();
    if (!defined $pid) {
        $self->error_message("No fork available:  $!");
        return;
    } elsif ($pid == 0) {
        $vmerge->execute;
        exit;
    } else {
        sleep(5);
        return $vmerge->pipe;
    }
    $self->error_message("Should never happen:  $!");
    return;
}

sub Xresolve_accumulated_alignments_filename {
    my $self = shift;
    
    my %p = @_;
    my $refseq = $p{ref_seq_id};
    
    my $model_data_directory = $self->data_directory;
    
    my @subsequences = grep {$_ ne "all_sequences" } $self->get_subreference_names(reference_extension=>'bfa');
    
    if (@subsequences && !$refseq) {
        $self->error_message("there are multiple subsequences available, but you did not specify a refseq");
        return;
    } elsif (!@subsequences) {
        return $model_data_directory . "/alignments.submap/all_sequences.map";
    } else {
        return $model_data_directory . "/alignments.submap/" . $refseq . ".map";   
    }
}

sub is_eliminate_all_duplicates {
    my $self = shift;

    if ($self->multi_read_fragment_strategy and
        $self->multi_read_fragment_strategy eq 'EliminateAllDuplicates') {
        1;
    } else {
        0;
    }
}

# Functional methods

sub lock_resource {
    my($self,%args) = @_;
    my $ret;
    my $resource_id = $self->lock_directory . '/' . $args{'resource_id'} . ".lock";
    my $block_sleep = $args{block_sleep} || 10;
    my $max_try = $args{max_try} || 7200;

    mkdir($self->lock_directory,0777) unless (-d $self->lock_directory);

    while(! ($ret = mkdir $resource_id)) {
        return undef unless $max_try--;
        $self->status_message("waiting on lock for resource $resource_id");
        sleep $block_sleep;
    }

    my $lock_info_pathname = $resource_id . '/info';
    my $lock_info = IO::File->new(">$lock_info_pathname");
    $lock_info->printf("HOST %s\nPID $$\nLSF_JOB_ID %s\nUSER %s\n",
                       $ENV{'HOST'},
                       $ENV{'LSB_JOBID'},
                       $ENV{'USER'},
                     );
    $lock_info->close();

    eval "END { unlink \$lock_info_pathname; rmdir \$resource_id;}";

    return 1;
}

sub unlock_resource {
    my ($self, %args) = @_;
    my $resource_id = delete $args{resource_id};
    Carp::confess("No resource_id specified for unlocking.") unless $resource_id;
    $resource_id = $self->lock_directory . "/" . $resource_id . ".lock";
    unlink $resource_id . '/info';
    rmdir $resource_id;
}


my @printable_property_names;
sub pretty_print_text {
    my $self = shift;
    unless (@printable_property_names) {
        # do this just once...
        my $class_meta = $self->get_class_object;
        for my $name ($class_meta->all_property_names) {
            next if $name eq 'name';
            my $property_meta = $class_meta->get_property_meta_by_name($name);
            unless ($property_meta->is_delegated or $property_meta->is_calculated) {
                push @printable_property_names, $name;
            }
        }
    }
    my @out;
    for my $prop (@printable_property_names) {
        if (my @values = $self->$prop) {
            my $value;
            if (@values > 1) {
                if (grep { ref($_) } @values) {
                    next;
                }
                $value = join(", ", grep { defined $_ } @values);
            }
            else {
                $value = $values[0];
            }
            next if not defined $value;
            next if ref $value;
            next if $value eq '';
            
            push @out, [
                Term::ANSIColor::colored($prop, 'red'),
                Term::ANSIColor::colored($value, "cyan")
            ]
        }
    }
    
    Genome::Model::EqualColumnWidthTableizer->new->convert_table_to_equal_column_widths_in_place( \@out );

    my $out;
    $out .= Term::ANSIColor::colored(sprintf("Model: %s (ID %s)", $self ->name, $self->id), 'bold magenta') . "\n\n";
    $out .= Term::ANSIColor::colored("Configured Properties:", 'red'). "\n";    
    $out .= join("\n", map { " @$_ " } @out);
    $out .= "\n\n";
    return $out;
}


1;
