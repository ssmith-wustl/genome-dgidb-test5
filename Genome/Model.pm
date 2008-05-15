
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
        align_dist_threshold         => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        dna_type                     => { is => 'VARCHAR2', len => 64 },
        genotyper_name               => { is => 'VARCHAR2', len => 255 },
        genotyper_params             => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        indel_finder_name            => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        indel_finder_params          => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        multi_read_fragment_strategy => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        name                         => { is => 'VARCHAR2', len => 255 },
        prior                        => { is => 'VARCHAR2', len => 255, is_optional => 1, sql => 'prior_ref_seq' },
        read_aligner_name            => { is => 'VARCHAR2', len => 255 },
        read_aligner_params          => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        read_calibrator_name         => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        read_calibrator_params       => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        reference_sequence_name      => { is => 'VARCHAR2', len => 255 },
        sample_name                  => { is => 'VARCHAR2', len => 255 },
        
        events                       => { is => 'Genome::Model::Event', is_many => 1, reverse_id_by => 'model', 
                                          doc => 'all events which have occurred for this model',
                                        },
        read_set_assignment_events   => { is => 'Genome::Model::Command::AddReads::AssignRun', is_many => 1, reverse_id_by => 'model',
                                          doc => 'each case of a read set being assigned to the model',
                                        },
        alignment_events             => { is => 'Genome::Model::Command::AddReads::AlignReads', is_many => 1, reverse_id_by => 'model',
                                          doc => 'each case of a read set being aligned to the model\'s reference sequence(s), possibly including multiple actual aligner executions',
                                        },
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
        
                                
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'The GENOME_MODEL table represents a particular attempt to model knowledge about a genome with a particular type of evidence, and a specific processing plan. Individual assemblies will reference the model for which they are assembling reads.',
};


# Operating directories

sub base_parent_directory {
    "/gscmnt/sata114/info/medseq"
}

sub data_parent_directory {
    my $self = shift;
    return $self->base_parent_directory . "/model_data"
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

sub _variant_detail_files {
    return shift->_files_for_pattern_and_optional_ref_seq_id('%s/identified_variations/pileup_%s',@_);
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

    return grep { -e $_ } glob($self->alignments_maplist_directory .'/*'. $ref_seq_id .'.maplist');
}

##

sub resolve_accumulated_alignments_filename {
    my $self = shift;
    my %p = @_;
    my $ref_seq_id = $p{ref_seq_id};
    my @maplists;
    if ($ref_seq_id) {
        @maplists = $self->maplist_file_paths(%p);
    } else {
        @maplists = $self->maplist_file_paths();
    }
    if (!@maplists) {
        $self->error_message("No maplists found");
        return;
    }
    my $vmerge = Genome::Model::Tools::Maq::Vmerge->create(
                                                           maplist => \@maplists,
                                                       );
    my $pid = fork();
    if (!defined $pid) {
        $self->error_message("No fork available:  $!");
        return;
    } elsif ($pid == 0) {
        unless (Genome::DataSource::GMSchema->set_all_dbh_to_inactive_destroy) {
            $self->error_message("Could not set all dbh to inactive destroy");
            exit(1);
        }
        $vmerge->execute;
        exit;
    } else {
        sleep(10);
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
    my $resource_id = $self->data_directory . "/" . $args{'resource_id'} . ".lock";
    my $block_sleep = $args{block_sleep} || 10;
    my $max_try = $args{max_try} || 7200;

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
    $resource_id = $self->data_directory . "/" . $resource_id . ".lock";
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
            print $name,"\n";
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
