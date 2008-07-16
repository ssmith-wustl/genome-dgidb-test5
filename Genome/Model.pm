
package Genome::Model;

use strict;
use warnings;

use above "Genome";
use Term::ANSIColor;
use Genome::Model::EqualColumnWidthTableizer;
use File::Path;
use File::Basename;
use IO::File;
use Sort::Naturally;

class Genome::Model {
    type_name => 'genome model',
    table_name => 'GENOME_MODEL',
    is_abstract => 1,
    sub_classification_method_name => '_resolve_subclass_name',
    id_by => [
        genome_model_id => { is => 'NUMBER', len => 11 },
    ],
    has => [
        processing_profile           => { is => 'Genome::ProcessingProfile::ShortRead', id_by => 'processing_profile_id' },
        #processing_profile           => { is => 'Genome::ProcessingProfile', id_by => 'processing_profile_id' },
        processing_profile_name      => { via => 'processing_profile', to => 'name'},
        sequencing_platform          => { via => 'processing_profile'},
        type_name                    => { via => 'processing_profile'},
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
                                          where => [ "event_type like" => 'genome-model add-reads assign-run %'],
                                          doc => 'each case of a read set being assigned to the model',
                                        },
                                        #this is to get some basic statistics..                         
        alignment_events             => { is => 'Genome::Model::Command::AddReads::AlignReads',
                                          is_many => 1,
                                          reverse_id_by => 'model',
                                          doc => 'each case of a read set being aligned to the model\'s reference sequence(s), possibly including multiple actual aligner executions',
                                     },
       #this is to get the SNP statistics...
       filter_variation_events             => { is => 'Genome::Model::Command::AddReads::FilterVariations',
                                                is_many => 1,
                                                reverse_id_by => 'model',
                                                doc => 'each case of variations filtered per chromosome',
                                           },

        alignment_file_paths         => { via => 'alignment_events' },
        has_all_alignment_metrics    => { via => 'alignment_events', to => 'has_all_metrics' },
        has_all_filter_variation_metrics    => { via => 'filter_variation_events', to => 'has_all_metrics' },
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
    my %libraries = map {$_->library_name => 1} $self->read_sets;
    my @distinct_libraries = keys %libraries;
    if ($self->name =~ /v0b/) {
        warn "removing any *d libraries from v0b models.  temp hack for AML v0b models.";
        @distinct_libraries = grep { $_ !~ /d$/ } @distinct_libraries;
    }
    return @distinct_libraries;
}

sub _calculate_library_count {
    my $self = shift;
    return scalar($self->libraries);
}

sub run_names {
    my $self = shift;
    my %distinct_run_names = map { $_->run_name => 1}  $self->read_sets;
    my @distinct_run_names = keys %distinct_run_names;
    return @distinct_run_names;
}

sub _calculate_run_count {
    my $self = shift;
    return scalar($self->run_names);
}

sub read_sets {
    my $self = shift;
    my %distinct_ids = map { $_->run_id => 1}  $self->read_set_assignment_events;
    my @distinct_ids = keys %distinct_ids;
    my @sets = Genome::RunChunk->get(\@distinct_ids);
    return unless @sets;
    if (my $dw_class = $sets[0]->_dw_class) {
        # cache the equivalent dw data in bulk
        my @tmp = $dw_class->get(id => [ map { $_->id } @sets]);
    }
    return @sets;
}

sub metric_to_class_hash {
    my $class = shift;
    my %metrics = (
                   library_count => 'Genome::Model',
                   run_count => 'Genome::Model',
                   total_read_count => 'Genome::Model::Command::AddReads::AlignReads',
                   total_reads_passed_quality_filter_count => 'Genome::Model::Command::AddReads::AlignReads',
                   total_bases_passed_quality_filter_count => 'Genome::Model::Command::AddReads::AlignReads',
                   aligned_read_count => 'Genome::Model::Command::AddReads::AlignReads',
                   unaligned_read_count => 'Genome::Model::Command::AddReads::AlignReads',
                   SNV_count => 'Genome::Model::Command::AddReads::AnnotateVariations',
                   SNV_in_dbSNP_count => 'Genome::Model::Command::AddReads::AnnotateVariations',
                   SNV_in_venter_count => 'Genome::Model::Command::AddReads::AnnotateVariations',
                   SNV_in_watson_count => 'Genome::Model::Command::AddReads::AnnotateVariations',
                   SNV_distinct_count => 'Genome::Model::Command::AddReads::AnnotateVariations',
                   HQ_SNP_count => 'Genome::Model::Command::AddReads::AnnotateVariations',
                   HQ_SNP_reference_allele_count => 'Genome::Model::Command::AddReads::AnnotateVariations',
                   HQ_SNP_variant_allele_count => 'Genome::Model::Command::AddReads::AnnotateVariations',
                   HQ_SNP_both_allele_count => 'Genome::Model::Command::AddReads::AnnotateVariations',
                   somatic_variants_in_d_v_w => 'Genome::Model::Command::AddReads::FilterVariations',
                   non_coding_variants => 'Genome::Model::Command::AddReads::FilterVariations',
                   novel_tumor_variants => 'Genome::Model::Command::AddReads::FilterVariations',
                   silent_variants => 'Genome::Model::Command::AddReads::FilterVariations',
                   nonsynonymous_variants => 'Genome::Model::Command::AddReads::FilterVariations',
                   var_pass_manreview => 'Genome::Model::Command::AddReads::FilterVariations',
                   var_fail_manreview => 'Genome::Model::Command::AddReads::FilterVariations',
                   var_fail_valid_assay => 'Genome::Model::Command::AddReads::FilterVariations',
                   var_complete_validation=> 'Genome::Model::Command::AddReads::FilterVariations',
                   validated_snps => 'Genome::Model::Command::AddReads::FilterVariations',
                   false_positives=> 'Genome::Model::Command::AddReads::FilterVariations',
                   validated_somatic_variants=> 'Genome::Model::Command::AddReads::FilterVariations',
                   skin_variants=> 'Genome::Model::Command::AddReads::FilterVariations' ,
                   tumor_only_variants=> 'Genome::Model::Command::AddReads::FilterVariations' ,
                   well_supported_variants=> 'Genome::Model::Command::AddReads::FilterVariations' ,
               );
    return %metrics;
}

sub class_for_metric {
    my $self = shift;
    my $metric_name = shift;

    my %metric_to_class_hash = $self->metric_to_class_hash;
    return $metric_to_class_hash{$metric_name};
}

sub get_events_for_metric {
    my $self = shift;
    my $metric_name = shift;

    unless ($metric_name) {
        $self->error_message("Must give metric name to get events for");
        return;
    }
    my $class = $self->class_for_metric($metric_name);
    if ($class eq __PACKAGE__) {
        # Should maybe do something else here
        # return $self->$metric_name;
        return $self;
    }

    #if we get here then we need to make sure we only grab events related to one add-reads 
    #or post-process_alignemnts event
    my @parent_addreads_events = Genome::Model::Command::AddReads->get(model_id => $self->id);
    my @parent_pp_alignment_events= Genome::Model::Command::AddReads::PostprocessAlignments->get(model_id => $self->id);

    #nothing has a frickin addreads event yet
    #@parent_addreads_events = sort { $a->date_scheduled cmp $b->date_scheduled } @parent_addreads_events;
    @parent_pp_alignment_events= sort { $b->date_scheduled cmp $a->date_scheduled } @parent_pp_alignment_events;
    my @latest_parent_ids = ($parent_pp_alignment_events[0]->id);
    $DB::single=1;
    my @events = $class->get(model_id => $self->id, parent_event_id => \@latest_parent_ids);
    
    if (!@events) {
        return $class->get(model_id=> $self->id);
   }
   return @events;
}

sub get_metrics_hash_ref {
    my $self = shift;
    #we get model metric names one way or another:
    my %metrics = $self->metric_to_class_hash;
    my %metric_name_value_hash;

    for my $metric (keys %metrics) {
        my $value;
        my $calculate_method = "_calculate_" . $metric;
        if ($self->can($calculate_method)) {
            $value = $self->$calculate_method;
        } else {
            $self->error_message("No _calculate_" . $calculate_method . " method has been defined for " . __PACKAGE__ . "\n");
            return;
        }
        $metric_name_value_hash{$metric} = $value;
    }
    return \%metric_name_value_hash;
}

sub resolve_metrics {
    my $self = shift;
    my %metric_to_class = $self->metric_to_class_hash;
    my @metrics;
    for my $metric_name (keys %metric_to_class) {
        if ($metric_name =~ /^HQ/) { next; }
        my @events = $self->get_events_for_metric($metric_name);
        for my $event (@events) {
            if (ref($event) eq __PACKAGE__) {
                next;
            }
            my $metric = $event->resolve_metric($metric_name);
            if ($metric) {
                push @metrics, $metric;
            }
        }
    }
    return @metrics;
}

sub generate_metrics {
    my $self = shift;
    my %metric_to_class = $self->metric_to_class_hash;
    my @metrics;
    for my $metric_name (keys %metric_to_class) {
        if ($metric_name =~ /^HQ/) { next; }
        my @events = $self->get_events_for_metric($metric_name);
        for my $event (@events) {
            if (ref($event) eq __PACKAGE__) {
                next;
            }
            my $metric = $event->generate_metric($metric_name);
            if ($metric) {
                push @metrics, $metric;
            }
        }
    }
    return @metrics;
}

#define calculate methods required

sub _calculate_total_read_count {
    my $self = shift;
    my $name = 'total_read_count';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_total_reads_passed_quality_filter_count {
    my $self = shift;
    my $name = 'total_reads_passed_quality_filter_count';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_total_bases_passed_quality_filter_count {
    my $self = shift;
    my $name = 'total_bases_passed_quality_filter_count';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_aligned_read_count {
    my $self = shift;
    my $name = 'aligned_read_count';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_aligned_base_pair_count {
    my $self = shift;
    my $name = 'aligned_base_pair_count';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_unaligned_read_count {
    my $self = shift;
    my $name = 'unaligned_read_count';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_unaligned_base_pair_count {
    my $self = shift;
    my $name = 'unaligned_base_pair_count';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_SNV_count {
    my $self = shift;
    my $name = 'SNV_count';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_SNV_in_dbSNP_count {
    my $self = shift;
    my $name = 'SNV_in_dbSNP_count';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_SNV_in_venter_count {
    my $self = shift;
    my $name = 'SNV_in_venter_count';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_SNV_in_watson_count {
    my $self = shift;
    my $name = 'SNV_in_watson_count';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_SNV_distinct_count {
    my $self = shift;
    my $name = 'SNV_distinct_count';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_HQ_SNP_count {
    my $self = shift;
    my $name = 'HQ_SNP_count';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_HQ_SNP_reference_allele_count {
    my $self = shift;
    my $name = 'HQ_SNP_reference_allele_count';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_HQ_SNP_variant_allele_count {
    my $self = shift;
    my $name = 'HQ_SNP_variant_allele_count';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_HQ_SNP_both_allele_count {
    my $self = shift;
    my $name = 'HQ_SNP_both_allele_count';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_somatic_variants_in_d_v_w {
    my $self = shift;
    my $name = 'somatic_variants_in_d_v_w';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_non_coding_variants {
    my $self = shift;
    my $name = 'non_coding_variants';
    return $self->_get_sum_of_metric_values_from_events($name);
}
sub _calculate_novel_tumor_variants {
    my $self = shift;
    my $name = 'novel_tumor_variants';
    return $self->_get_sum_of_metric_values_from_events($name);
}


sub _calculate_silent_variants {
    my $self = shift;
    my $name = 'silent_variants';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_nonsynonymous_variants {
    my $self = shift;
    my $name = 'nonsynonymous_variants';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_var_pass_manreview {
    my $self = shift;
    my $name = 'var_pass_manreview';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_var_fail_manreview {
    my $self = shift;
    my $name = 'var_fail_manreview';
    return $self->_get_sum_of_metric_values_from_events($name);
}


sub _calculate_var_fail_valid_assay {
    my $self = shift;
    my $name = 'var_fail_valid_assay';
    return $self->_get_sum_of_metric_values_from_events($name);
}


sub _calculate_var_complete_validation {
    my $self = shift;
    my $name = 'var_complete_validation';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_validated_snps {
    my $self = shift;
    my $name = 'validated_snps';
    return $self->_get_sum_of_metric_values_from_events($name);
}
sub _calculate_false_positives {
    my $self = shift;
    my $name = 'false_positives';
    return $self->_get_sum_of_metric_values_from_events($name);
}
sub _calculate_validated_somatic_variants {
    my $self = shift;
    my $name = 'validated_somatic_variants';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_well_supported_variants {
    my $self = shift;
    my $name = 'well_supported_variants';
    return $self->_get_sum_of_metric_values_from_events($name);
}


sub _calculate_skin_variants {
    my $self = shift;
    my $name = 'skin_variants';
    return $self->_get_sum_of_metric_values_from_events($name);
}

sub _calculate_tumor_only_variants {
    my $self = shift;
    my $name = 'tumor_only_variants';
    return $self->_get_sum_of_metric_values_from_events($name);
}



sub _get_sum_of_metric_values_from_events {
    my $self = shift;
    my $metric_name = shift;
    my @events = $self->get_events_for_metric($metric_name);

    my $sum;
    for my $event (@events) {
        unless ($event->should_calculate) {
            $self->error_message("The event ". $event->id ." will not calculate ". $metric_name);
            next;
        }
        unless($event->can($metric_name)) {
            #do something;
            $self->error_message("The event you're trying to call " . $metric_name
                                . "on doesn't have that method.");
            return;
        }
        my $value = $event->$metric_name;
        if ($value =~ /^\d+$/) {
            $sum += $value;
        }
    }
    return $sum;
}

# Operating directories

sub base_parent_directory {
    "/gscmnt/839/info/medseq"
}

sub alignment_links_directory {
    my $self = shift;
    return $self->base_parent_directory . "/alignment_links/" .
        $self->read_aligner_name .'/'.
        $self->reference_sequence_name;
}

sub model_links_directory {
    my $self = shift;
    return $self->base_parent_directory . "/model_links"
}

sub data_directory {
    my $self = shift;
    my $name = $self->name;
    return $self->model_links_directory . '/' . $self->sample_name . "_" . $name;
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

sub alignments_directory {
    my $self = shift;
    return $self->data_directory . '/alignments'; 
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

    my @map_lists = grep { -e $_ } glob($self->alignments_directory .'/*_'. $ref_seq_id .'.maplist');
    unless (@map_lists) {
        $self->error_message("No map lists found for ref seq $ref_seq_id in " . $self->alignments_directory);
    }
    return @map_lists;
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
            # an exception to include the processing profile name when listed
            if ($name eq 'processing_profile_name') {
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

# This is called by the infrastructure to appropriately classify abstract processing profiles
# according to their type name because of the "sub_classification_method_name" setting
# in the class definiton...
sub _resolve_subclass_name {
    my $class = shift;
    my $proper_subclass_name;
    if (ref($_[0]) and $_[0]->isa(__PACKAGE__)) {
        my $type_name = $_[0]->type_name;
        $proper_subclass_name = $class->_resolve_subclass_name_for_type_name($type_name);
    }
    # access the type according to the processing profile being used
    elsif (my $processing_profile_id = $class->get_rule_for_params(@_)->specified_value_for_property_name('processing_profile_id')) {
        my $processing_profile = Genome::ProcessingProfile->get(id =>
                                            $processing_profile_id);
        my $type_name = $processing_profile->type_name;    
        $proper_subclass_name = $class->_resolve_subclass_name_for_type_name($type_name);
    }
    # Adding a hack to call class to force autoload
    $proper_subclass_name->class if $proper_subclass_name;
    return $proper_subclass_name;
}

# This is called by both of the above.
sub _resolve_subclass_name_for_type_name {
    my ($class,$type_name) = @_;
    my @type_parts = split(' ',$type_name);
	
    my @sub_parts = map { ucfirst } @type_parts;
    my $subclass = join('',@sub_parts);
	
    my $class_name = join('::', 'Genome::Model' , $subclass);
    return $class_name;
}

sub _resolve_type_name_for_subclass_name {
    my ($class,$subclass_name) = @_;
    my ($ext) = ($subclass_name =~ /Genome::Model::(.*)/);
    return unless ($ext);
    my @words = $ext =~ /[a-z]+|[A-Z](?:[A-Z]+|[a-z]*)(?=$|[A-Z])/g;
    my $type_name = lc(join(" ", @words));
    return $type_name;
}

# Returns the base name of the hq_snp report files
sub hq_snp_base_name {
    my $self = shift;

    return $self->_filtered_variants_dir . "/hq_snp";
}

# Returns the name of the snplist file
sub hq_snp_snplist_name {
    my $self = shift;

    return $self->hq_snp_base_name . '_snplist.csv';
}

# Returns the name of the notfound file
sub hq_snp_notfound_name {
    my $self = shift;

    return $self->hq_snp_base_name . '_notfound.csv';
}

# Returns the name of the detail file
sub hq_snp_detail_name {
    my $self = shift;

    return $self->hq_snp_base_name . '_detail.csv';
}

# Returns the name of the summary file
sub hq_snp_summary_name {
    my $self = shift;

    return $self->hq_snp_base_name . '_summary.csv';
}
    
# Returns the name of the report file
sub hq_snp_report_name {
    my $self = shift;

    return $self->hq_snp_base_name . '_report.csv';
}

# Returns the name of the numbers file
sub hq_snp_numbers_name {
    my $self = shift;

    return $self->hq_snp_base_name . '_numbers.csv';
}

# Returns the name of the gold snp file
# This file is just the intersection of all micro array data on the same sample
sub gold_snp_file {
    my $self = shift;

    return $self->_filtered_variants_dir . "/gold_snp.tsv";
}

sub hq_snp_file_for_chromosome {
    my $self = shift;
    my $chromosome = shift;

    return $self->hq_snp_base_name . "_$chromosome.tsv";
}

# Segments the gold snp file into chromosomes
sub segment_HQ_snp_file {
    my $self = shift;

    my $hq_snplist = $self->hq_snp_snplist_name();
    unless (-e $hq_snplist) {
        $self->error_message("HQ snplist file $hq_snplist doesnt exist!");
        return undef;
    }
    
    my $input_fh;
    unless ($input_fh = IO::File->new("$hq_snplist")) {
        $self->error_message("Could not open file $hq_snplist after determining it exists!");
        return undef;
    }
    my $output_fh = IO::File->new();

    my $last_chr = undef;
    while (my $line = $input_fh->getline) {
        my ($type,$chr,$pos, $cns_sequence,$var_sequence, $quality_score,$depth) = split("\t", $line);

        # if we hit a new chromosome, close the old and open a new outfile
        if ($chr ne $last_chr) {
            $last_chr = $chr;
            $output_fh->close();
            my $filename = $self->hq_snp_file_for_chromosome($chr);
            $output_fh = IO::File->new(">$filename");
        } 

        print $output_fh join("\t",($type,$chr,$pos, $cns_sequence,$var_sequence, $quality_score,$depth));
    }
}

# Gets the hq num stats for a single chromosome file
sub get_hq_snps_for_chrom {
    my $self = shift;
    my $chromosome = shift;

    my $hq_snplist = $self->hq_snp_file_for_chromosome($chromosome);

    # If this file does not exist, must not have done the segment yet. Do it!
    unless (-e $hq_snplist) {
        $self->segment_HQ_snp_file();
        unless (-e $hq_snplist) {
            $self->error_message("HQ snplist file $hq_snplist still doesnt exist after attempting to create!");
            return undef;
        }
    }
    
    my $input_fh = IO::File->new("$hq_snplist");

    my $hq_snp;
    ($hq_snp->{reference} = 0, $hq_snp->{variant} = 0, $hq_snp->{both} = 0, $hq_snp->{total} = 0);
    while (my $line = $input_fh->getline) {
        my ($type,$chr,$pos, $cns_sequence,$var_sequence, $quality_score,$depth) = split("\t", $line);

        $hq_snp->{total}++;
        if ($type eq 'het') {
            $hq_snp->{both}++;
            $hq_snp->{reference}++;
            $hq_snp->{variant}++;
        }
        elsif ($type eq 'hetref') {
            $hq_snp->{reference}++;
        }
        elsif ($type eq 'hetvar') {
            $hq_snp->{variant}++;
        }
    }

    return $hq_snp;
}

# Compare files and output where they agree on chromosome, position, and alleles into a 3rd file
sub make_gold_snp_file {
    my $self = shift;
    $DB::single=1;
    
    my $output_file_name = $self->gold_snp_file();
    my $output_fh;
    unless ($output_fh = IO::File->new(">$output_file_name")) {
        die("Could not open $output_file_name");
    }

    my @related_microarray = Genome::Model::MicroArray->get(sample_name => $self->sample_name);
    if (scalar(@related_microarray) == 0) {
        $self->error_message("No micro array models found with the same sample");
        return 0;
    }
    # if theres only one related micro array... use that as the gold snp list
    elsif (scalar(@related_microarray) == 1) {
        $self->error_message("Only one micro array model found with the same sample... using its data as the gold snp file.");
        my $model = $related_microarray[0];
        while ($model->get_next_line) {
            print $output_fh $model->current_line->{chromosome} . "\t" .
            $model->current_line->{position} . "\t" .
            $model->current_line->{position} . "\t"; 
             
            #TODO : currently very hackish... 4 columns do not make sense... should be 2... check if this is necessary and fix   
            if ($model->current_line->{allele_1} eq $model->current_line->{allele_2}) {
                if ($model->current_line->{allele_1} eq $model->current_line->{reference}) {
                    print $output_fh "ref\tref\tref\tref\n"; 
                } 
                else {
                    print $output_fh "SNP\tSNP\tSNP\tSNP\n";
                }
                # otherwise must be het            
            } else {
                print $output_fh "ref\tSNP\tref\tSNP\n"; 
            }
        }
        return 1;
    }

    # Otherwise we have 2 or more microarray models to compare, compare all of them to find agreement
    my $done = 0;
    while(!$done) {
        my $return = $self->get_next_microarray_input(@related_microarray);

        if ($return == -1) {
            $done = 1;
        }
        elsif ($return == 1) {
            if ((($related_microarray[0]->current_line->{allele_1} eq $related_microarray[1]->current_line->{allele_1}) 
            && ($related_microarray[0]->current_line->{allele_2} eq $related_microarray[1]->current_line->{allele_2})) || 
            (($related_microarray[0]->current_line->{allele_2} eq $related_microarray[1]->current_line->{allele_1}) 
            && ($related_microarray[0]->current_line->{allele_1} eq $related_microarray[1]->current_line->{allele_2}))) {
                my $model = $related_microarray[0];
                print $output_fh $model->current_line->{chromosome} . "\t" .
                $model->current_line->{position} . "\t" .
                $model->current_line->{position} . "\t"; 

                # if reverse match, print reverse...
                if (($related_microarray[0]->current_line->{allele_1} eq $related_microarray[1]->current_line->{allele_1}) && 
                ($related_microarray[0]->current_line->{allele_2} eq $related_microarray[1]->current_line->{allele_2})) {
                    print $output_fh $related_microarray[0]->current_line->{allele_2} . "\t" 
                    . $related_microarray[0]->current_line->{allele_1} . "\t"; 
                } else {
                    print $output_fh $related_microarray[0]->current_line->{allele_1} . "\t" 
                    . $related_microarray[0]->current_line->{allele_2} . "\t"; 
                }

                # if homozygous
                if ($related_microarray[1]->current_line->{allele_1} eq $related_microarray[1]->current_line->{allele_2}) {
                    if ($related_microarray[1]->current_line->{allele_1} eq $related_microarray[1]->current_line->{reference}) {
                        print $output_fh "ref\tref\t"; 
                    } 
                    else {
                        print $output_fh "SNP\tSNP\t";
                    }
                    # otherwise must be het            
                } else {
                    print $output_fh "ref\tSNP\t"; 
                }

                # if homozygous 
                if ($related_microarray[0]->current_line->{allele_1} eq $related_microarray[0]->current_line->{allele_2}) {
                    if ($related_microarray[0]->current_line->{allele_1} eq $related_microarray[0]->current_line->{reference}) {
                        print $output_fh "ref\tref\n"; 
                    } 
                    else {
                        print $output_fh "SNP\tSNP\n";
                    }
                    # otherwise must be het            
                } else {
                    print $output_fh "ref\tSNP\n"; 
                }
            } 
            # If the chrom/pos matches but the alleles dont, just get new lines for each model
            for my $model (@related_microarray) {
                $model->get_next_line();
            }
        }
        # Get the next input if return is 0... means there is no chrom/pos match yet
    }
    $output_fh->close;

    return 1;
}

# Gets the next line for the model that has the least value for chromosome/pos...
# Does nothing and returns 1 if they all match, return 0 if next gotten but no match
# Return undef if one of the models hit the end
sub get_next_microarray_input {
    my $self = shift;

    my @models = @_;
    
    my $lowest_model = undef;
    for my $model (@models) {
        # if a line has not been gotten in this model yet, get one
        if (!$model->{current_line}) {
            # if we still cant get a line successfully, must be at the end
            unless($model->get_next_line) {
                return -1;
            }
        }
        
        # If alleles were not captured (dashes in the file)... get a new line
        if (!$model->current_line->{allele_1} || !$model->current_line->{allele_2}) { 
            $model->get_next_line();
            next;
        }

        # if lowest model has not been set yet, set to current model
        if (!$lowest_model) {
            $lowest_model = $model;
            next;
        }

        #compare chromosomes
        if(ncmp($model->current_line->{chromosome}, $lowest_model->current_line->{chromosome}) > 0) {
            # current lowest stands... do nothing
        }
        elsif(ncmp($model->current_line->{chromosome}, $lowest_model->current_line->{chromosome}) < 0) {
            $lowest_model = $model;
        }
        #same chromosome, compare positions    
        elsif(ncmp($model->current_line->{chromosome}, $lowest_model->current_line->{chromosome}) == 0) {
            if(ncmp($model->current_line->{position}, $lowest_model->current_line->{position}) > 0) {
                # current lowest stands... do nothing
            }
            elsif(ncmp($model->current_line->{position}, $lowest_model->current_line->{position}) < 0) {
                $lowest_model = $model;
            }
            # match position... check alleles... can match or be reversed to be included
            elsif(ncmp($model->current_line->{position}, $lowest_model->current_line->{position}) == 0) {
                # We have found a chromosome and position match
                return 1;
            }
        }
    } # end for

    # Now, get the next line of the model that has the lowest chrom/pos values...
    $lowest_model->get_next_line();

    return 0;
}

# This stuff is hacked out of brian's maq_gold_snp.pl script
# TODO: This maybe doesnt belong here... but where? Filtervariations?
sub find_hq_snps {
    my $self = shift;
    
    # Command line option variables
    my($aii_file, $cns, $basename, $maxsnps, $snplist);
    $maxsnps=10000000;
    $snplist = 0;

    $aii_file = $self->gold_snp_file();

    my ($total_aii, $ref_aii, $het_aii, $hom_aii);
    $total_aii = $ref_aii = $het_aii = $hom_aii = 0;
    my %aii;
    open(AII,$aii_file) || die "Unable to open aii input file: $aii_file $$";
    while(<AII>) {
        chomp;
        my $line = $_;
        my ($chromosome, $start, $end, $allele1, $allele2
            , $rgg1_allele1_type, $rgg1_allele2_type
            , $rgg2_allele1_type, $rgg2_allele2_type
            ) = split("\t");

        my $ref = 0;
        $total_aii += 1;
        if ($rgg1_allele1_type eq 'ref' &&
            $rgg1_allele2_type eq 'ref' &&
            $rgg2_allele1_type eq 'ref' &&
            $rgg2_allele2_type eq 'ref') {
                $ref_aii += 1;
                $ref = 1;
        }
            
        $aii{$chromosome}{$start}{allele1} = $allele1;
        $aii{$chromosome}{$start}{allele2} = $allele2;
        $aii{$chromosome}{$start}{ref} = $ref;
        $aii{$chromosome}{$start}{found} = 0;
        $aii{$chromosome}{$start}{line} = $line;

        if ($rgg1_allele1_type eq 'ref' &&
        $rgg1_allele2_type eq 'ref' &&
        $rgg2_allele1_type eq 'ref' &&
        $rgg2_allele2_type eq 'ref') {
            next;
        }
        if ($allele1 eq $allele2) {
            $hom_aii += 1;
        } else {
            $het_aii += 1;
        }
    } # end while <AII>
    close(AII);

    # get all of the snp files... sort them... use them as input
    my @snp_files = $self->_variant_list_files();
    my $file_list = join(" ", @snp_files);
    my $snp_cmd = "cat $file_list | sort -g -t \$'\t' -k 1 -k 2 |";
    unless (open(DATA,$snp_cmd)) {
        die("Unable to run input command: $snp_cmd");
        exit 0;
    }

    # Begin sort black magic...
    # This essentially will just sort by chromosome and position
    # Sorts chromosomes correctly as 1-22, then x, then y
    my @list= <DATA>;
    my @sorted= @list[
    map { unpack "N", substr($_,-4) }
    sort
    map {
        my $key= $list[$_];
        $key =~ s[(\d+)][ pack "N", $1 ]ge;
        $key . pack "N", $_
    } 0..$#list
    ];
    close (DATA);
    # End black magic
    
    my %IUBcode=(
             A=>'AA',
             C=>'CC',
             G=>'GG',
             T=>'TT',
             M=>'AC',
             K=>'GT',
             Y=>'CT',
             R=>'AG',
             W=>'AT',
             S=>'GC',
             D=>'AGT',
             B=>'CGT',
             H=>'ACT',
             V=>'ACG',
             N=>'ACGT',
             );


    my $max_bin = 40;
    my %qsnp;
    my %qsnp_het;
    my %qsnp_het_match;
    my %qsnp_het_ref_match;
    my %qsnp_het_var_match;
    my %qsnp_het_mismatch;
    my %qsnp_hom;
    my %qsnp_hom_match;
    my %qsnp_hom_mismatch;
    my $total;
    my $output_snplist = $self->hq_snp_snplist_name();
    if ($snplist) {
        open(SNPLIST,">$output_snplist") || die "Unable to create snp list file: $output_snplist $$";
    }
    for my $line (@sorted) {
        chomp($line);
        my ($id, $start, $ref_sequence, $iub_sequence, $quality_score, $depth, $avg_hits, $high_quality, $unknown) = split("\t", $line);
        next if ($depth < 2);
        $total += 1;
        if ($total >= $maxsnps) {
            last;
        }

        my ($chr, $pos, $offset, $c_orient);
        ($chr, $pos) = ($id, $start);

        my $genotype = $IUBcode{$iub_sequence};
        $genotype ||= 'NN';
        my $cns_sequence = substr($genotype,0,1);
        my $var_sequence = (length($genotype) > 2) ? 'X' : substr($genotype,1,1);
        if (exists($aii{$chr}{$pos})) {
            $aii{$chr}{$pos}{found} = 1;
            $qsnp{$quality_score} += 1;
            if ($aii{$chr}{$pos}{allele1} ne $aii{$chr}{$pos}{allele2}) {
                $qsnp_het{$quality_score} += 1;
                if (($aii{$chr}{$pos}{allele1} eq $cns_sequence &&
                     $aii{$chr}{$pos}{allele2} eq $var_sequence) ||
                    ($aii{$chr}{$pos}{allele1} eq $var_sequence &&
                     $aii{$chr}{$pos}{allele2} eq $cns_sequence)) {
                        $qsnp_het_match{$quality_score} += 1;
                        $qsnp_het_ref_match{$quality_score} += 1;
                        $qsnp_het_var_match{$quality_score} += 1;
                        if ($snplist) {
                            print SNPLIST join("\t",('het',$chr,$pos, $cns_sequence,$var_sequence, $quality_score,$depth)) . "\n";
                        }
                } else {
                    if ($aii{$chr}{$pos}{allele1} eq $cns_sequence ||
                        $aii{$chr}{$pos}{allele1} eq $var_sequence) {
                            $qsnp_het_ref_match{$quality_score} += 1;
                            if ($snplist) {
                                print SNPLIST join("\t",('hetref',$chr,$pos, $cns_sequence,$var_sequence, $quality_score,$depth)) . "\n";
                            }
                    } elsif ($aii{$chr}{$pos}{allele2} eq $cns_sequence ||
                             $aii{$chr}{$pos}{allele2} eq $var_sequence) {
                                $qsnp_het_var_match{$quality_score} += 1;
                                if ($snplist) {
                                    print SNPLIST join("\t",('hetvar',$chr,$pos, $cns_sequence,$var_sequence, $quality_score,$depth)) . "\n";
                                }
                    } else {
                        if ($snplist) {
                            print SNPLIST join("\t",('hetmis',$chr,$pos, $cns_sequence,$var_sequence, $quality_score,$depth)) . "\n";
                        }
                    }
                    $qsnp_het_mismatch{$quality_score} += 1;
                }
            } else {
                $qsnp_hom{$quality_score} += 1;
                if (($aii{$chr}{$pos}{allele1} eq $cns_sequence &&
                     $aii{$chr}{$pos}{allele2} eq $var_sequence) ||
                    ($aii{$chr}{$pos}{allele1} eq $var_sequence &&
                     $aii{$chr}{$pos}{allele2} eq $cns_sequence)) {
                        $qsnp_hom_match{$quality_score} += 1;
                        if ($snplist) {
                            my $type = ($aii{$chr}{$pos}{ref}) ? 'ref' : 'hom';
                            print SNPLIST join("\t",($type,$chr,$pos, $cns_sequence,$var_sequence, $quality_score,$depth)) . "\n";
                        }
                 } else {
                    if ($snplist) {
                        print SNPLIST join("\t",('hommis',$chr,$pos, $cns_sequence,$var_sequence, $quality_score,$depth)) . "\n";
                    }
                    $qsnp_hom_mismatch{$quality_score} += 1;
                }
            }
        } # end if (exists($aii{$chr}{$pos}))
    } # end while <SNP>
    close(SNPLIST);

    my $output_notfound = $self->hq_snp_notfound_name();
    open(NOTFOUND,">$output_notfound") || die "Unable to create not found file: $output_notfound $$";
    foreach my $chromosome (sort (keys %aii)) {
        foreach my $location (sort (keys %{$aii{$chromosome}})) {
            unless ($aii{$chromosome}{$location}{found}) {
                print NOTFOUND $aii{$chromosome}{$location}{line} . "\n";
            }
        }
    }

    close(NOTFOUND);

    my $output = $self->hq_snp_detail_name();
    open(OUTPUT,">$output") || die "Unable to open output file: $output";
    print OUTPUT "Total\t$total\n\n";
    print OUTPUT "qval\tall_het\thet_match\thet_mismatch\tall\tall_hom\thom_match\thom_mismatch\thet_ref_match\thet_var_match\n";
    my @qkeys = ( 0, 10, 15, 20, 30 );
    my %all;
    my %het_location;
    my %het_match;
    my %het_ref_match;
    my %het_var_match;
    my %het_mismatch;
    my %hom_location;
    my %hom_match;
    my %hom_mismatch;
    foreach my $qval (sort { $a <=> $b } (keys %qsnp)) {
        # Initialize values to 0 if undef
        my $all = $qsnp{$qval} || 0;
        my $all_het = $qsnp_het{$qval} || 0;
        my $het_match = $qsnp_het_match{$qval} || 0;
        my $het_ref_match = $qsnp_het_ref_match{$qval} || 0;
        my $het_var_match = $qsnp_het_var_match{$qval} || 0;
        my $het_mismatch = $qsnp_het_mismatch{$qval} || 0;
        my $all_hom = $qsnp_hom{$qval} || 0;
        my $hom_match = $qsnp_hom_match{$qval} || 0;
        my $hom_mismatch = $qsnp_hom_mismatch{$qval} || 0;
        print OUTPUT "$qval\t$all_het\t$het_match\t$het_mismatch\t$all\t$all_hom\t$hom_match\t$hom_mismatch\t$het_ref_match\t$het_var_match\n";
        foreach my $qkey (@qkeys) {
            if ($qval >= $qkey) {
                $all{$qkey} += $all;
                $het_location{$qkey} += $all_het;
                $het_match{$qkey} += $het_match;
                $het_ref_match{$qkey} += $het_ref_match;
                $het_var_match{$qkey} += $het_var_match;
                $het_mismatch{$qkey} += $het_mismatch;
                $hom_location{$qkey} += $all_hom;
                $hom_match{$qkey} += $hom_match;
                $hom_mismatch{$qkey} += $hom_mismatch;
            }
        }
    } # end foreach
    close(OUTPUT);

    my $summary = $self->hq_snp_summary_name();
    open(SUMMARY,">$summary") || die "Unable to open output summary file: $summary";
    print SUMMARY "Total\t$total\n\n";
    print SUMMARY "QVAL\tHet_Location\tHet_Match\tHet_Mismatch\tHom_Location\tHom_Match\tHom_Mismatch\tAll\tHet_Ref_Match\tHet_Var_Match\n";
    foreach my $qkey (@qkeys) {
        print SUMMARY "$qkey\t$het_location{$qkey}\t$het_match{$qkey}\t$het_mismatch{$qkey}\t$hom_location{$qkey}\t$hom_match{$qkey}\t$hom_mismatch{$qkey}\t$all{$qkey}\t$het_ref_match{$qkey}\t$het_var_match{$qkey}\n";
    }
    close(SUMMARY);

    my $report = $self->hq_snp_report_name();
    open(REPORT,">$report") || die "Unable to open output report file: $report";
    my ($result) = $self->GetResults($summary);

    print REPORT "all\tref\thet\thom\n";
    print REPORT "$total_aii\t$ref_aii\t$het_aii\t$hom_aii\n";

    print REPORT "\nTotal: " . $result->{total} . "\n\n";

    print REPORT "Heterozygous:\n";
    print REPORT join("\t", ( '', 'Location', 'Match', 'Ref Match', 'Var Match',
    'Mismatch')) . "\n";

    print REPORT "SNP Q0:\t" .  join("\t",@{$result}{ qw( q0_location q0_match q0_ref_match q0_var_match q0_mismatch) }) . "\n";
    print REPORT "SNP Q15:\t" .  join("\t",@{$result}{ qw( q15_location q15_match q15_ref_match q15_var_match q15_mismatch) }) . "\n";
    print REPORT "SNP Q30:\t" .  join("\t",@{$result}{ qw( q30_location q30_match q30_ref_match q30_var_match q30_mismatch) }) . "\n";
    print REPORT "SNP Q0 %:\t" .  join("\t", map { my $p = sprintf "%0.2f%%", (100.0 * $_)/$het_aii; $p; } @{$result}{ qw( q0_location q0_match q0_ref_match q0_var_match q0_mismatch) }) . "\n";
    print REPORT "SNP Q15 %:\t" .  join("\t", map { my $p = sprintf "%0.2f%%", (100.0 * $_)/$het_aii; $p; } @{$result}{ qw( q15_location q15_match q15_ref_match q15_var_match q15_mismatch) }) . "\n";
    print REPORT "SNP Q30 %:\t" .  join("\t", map { my $p = sprintf "%0.2f%%", (100.0 * $_)/$het_aii; $p; } @{$result}{ qw( q30_location q30_match q30_ref_match q30_var_match q30_mismatch) }) . "\n";

    print REPORT "\nHomozygous:\n";
    print REPORT join("\t", ( '', 'Location', 'Match', 'Mismatch')) . "\n";
    print REPORT "SNP Q0:\t" .  join("\t",@{$result}{ qw( q0_location_hom q0_match_hom q0_mismatch_hom) }) . "\n";
    print REPORT "SNP Q15:\t" .  join("\t",@{$result}{ qw( q15_location_hom q15_match_hom q15_mismatch_hom) }) . "\n";
    print REPORT "SNP Q30:\t" .  join("\t",@{$result}{ qw( q30_location_hom q30_match_hom q30_mismatch_hom) }) . "\n";

    print REPORT "SNP Q0 %:\t" .  join("\t", map { my $p = sprintf "%0.2f%%", (100.0 * $_)/$het_aii; $p; } @{$result}{ qw( q0_location_hom q0_match_hom q0_mismatch_hom) }) . "\n";
    print REPORT "SNP Q15 %:\t" .  join("\t", map { my $p = sprintf "%0.2f%%", (100.0 * $_)/$het_aii; $p; } @{$result}{ qw( q15_location_hom q15_match_hom q15_mismatch_hom) }) . "\n";
    print REPORT "SNP Q30 %:\t" .  join("\t", map { my $p = sprintf "%0.2f%%", (100.0 * $_)/$het_aii; $p; } @{$result}{ qw( q30_location_hom q30_match_hom q30_mismatch_hom) }) . "\n";
    
    close(REPORT);

    my $numbers = $self->hq_snp_numbers_name();
    open(NUMBERS,">$numbers") || die "Unable to open output report file: $numbers ";

    my $ref_match = $result->{q15_ref_match};  
    my $var_match = $result->{q15_var_match};  
    my $all_match = $result->{q15_match};  
    print NUMBERS "HQ SNP count (all het snps): $het_aii\n";
    print NUMBERS "HQ SNP reference allele count (agree on ref): $ref_match\n";
    print NUMBERS "HQ SNP variant allele count (agree on var): $var_match\n";
    print NUMBERS "HQ SNP both allele count (total agreement): $all_match\n";
        
    close(NUMBERS);
        
    return 1;
}

# This is also fully pasted from the maq_gold_snp.
sub GetResults {
    my $self = shift;
    
	my ($summary_file) = @_;
	my $filename = basename($summary_file);

	open(SUMMARY,$summary_file) || die "Unable to open summary file: $summary_file $$";
	my %result_best_fit;
	my %new_best_fit;
	my $total;
	while(<SUMMARY>) {
		chomp;
		my ($qkey, $het_location, $het_match, $het_mismatch,
				$hom_location, $hom_match, $hom_mismatch, $all,
				$het_ref_match, $het_var_match) = split("\t");
        $qkey = $qkey || '';
		if ($qkey eq 'Total') {
			$total = $het_location;
			$total ||= '';
			if (!defined($total) || $total eq '') {
				return (\%new_best_fit);
			}
		} elsif ($qkey =~ /^\d+$/x) {
#			print "$_\n";
			$result_best_fit{$qkey}{location} = $het_location;
			$result_best_fit{$qkey}{match} = $het_match;
			$result_best_fit{$qkey}{ref_match} = $het_ref_match;
			$result_best_fit{$qkey}{var_match} = $het_var_match;
			$result_best_fit{$qkey}{mismatch} = $het_mismatch;
			$result_best_fit{$qkey}{location_hom} = $hom_location;
			$result_best_fit{$qkey}{match_hom} = $hom_match;
			$result_best_fit{$qkey}{mismatch_hom} = $hom_mismatch;
		} else {
#			print "$_\n";
		}
	}
	close(SUMMARY);
	$new_best_fit{total} = $total || 0;
	$new_best_fit{q0_location} = $result_best_fit{0}{location} || 0;
	$new_best_fit{q0_match} = $result_best_fit{0}{match} || 0;
	$new_best_fit{q0_ref_match} = $result_best_fit{0}{ref_match} || 0;
	$new_best_fit{q0_var_match} = $result_best_fit{0}{var_match} || 0;
	$new_best_fit{q0_mismatch} = $result_best_fit{0}{mismatch} || 0;
	$new_best_fit{q0_location_hom} = $result_best_fit{0}{location_hom} || 0;
	$new_best_fit{q0_match_hom} = $result_best_fit{0}{match_hom} || 0;
	$new_best_fit{q0_mismatch_hom} = $result_best_fit{0}{mismatch_hom} || 0;

	$new_best_fit{q15_location} = $result_best_fit{15}{location} || 0;
	$new_best_fit{q15_match} = $result_best_fit{15}{match} || 0;
	$new_best_fit{q15_ref_match} = $result_best_fit{15}{ref_match} || 0;
	$new_best_fit{q15_var_match} = $result_best_fit{15}{var_match} || 0;
	$new_best_fit{q15_mismatch} = $result_best_fit{15}{mismatch} || 0;
	$new_best_fit{q15_location_hom} = $result_best_fit{15}{location_hom} || 0;
	$new_best_fit{q15_match_hom} = $result_best_fit{15}{match_hom} || 0;
	$new_best_fit{q15_mismatch_hom} = $result_best_fit{15}{mismatch_hom} || 0;

	$new_best_fit{q30_location} = $result_best_fit{30}{location} || 0;
	$new_best_fit{q30_match} = $result_best_fit{30}{match} || 0;
	$new_best_fit{q30_ref_match} = $result_best_fit{30}{ref_match} || 0;
	$new_best_fit{q30_var_match} = $result_best_fit{30}{var_match} || 0;
	$new_best_fit{q30_mismatch} = $result_best_fit{30}{mismatch} || 0;
	$new_best_fit{q30_location_hom} = $result_best_fit{30}{location_hom} || 0;
	$new_best_fit{q30_match_hom} = $result_best_fit{30}{match_hom} || 0;
	$new_best_fit{q30_mismatch_hom} = $result_best_fit{30}{mismatch_hom} || 0;
	return (\%new_best_fit);
}


1;
