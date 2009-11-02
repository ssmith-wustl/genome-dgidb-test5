package Genome::InstrumentData::Alignment;

use strict;
use warnings;

use Genome;
use Digest::MD5 qw(md5_hex);

class Genome::InstrumentData::Alignment {
    is => ['Genome::Utility::FileSystem'],
    is_abstract => 1,
    sub_classification_method_name => '_resolve_subclass_name',   
    has => [
        instrument_data                 => {
                                            is => 'Genome::InstrumentData',
                                            id_by => 'instrument_data_id'
                                        },
        instrument_data_id              => {
                                            is => 'Number',
                                            doc => 'the local database id of the instrument data (reads) to align'
                                        },
        aligner_name                    => {
                                            is => 'Text', default_value => 'maq',
                                            doc => 'the name of the aligner to use, maq, blat, newbler etc.'
                                        },
        arch_os                         => {
                                            calculate => q|
                                                my $arch_os = `uname -m`;
                                                chomp($arch_os);
                                                return $arch_os;
                                            |
                                        },
    ],
    has_optional => [
         filter_name        => {
                                is => 'Text',
                                valid_values => ['forward-only','reverse-only', undef],
                                doc => 'apply a standard filter to the instrument data',
                            },
         trimmer_name       => {
                                is => 'Text',
                                doc => 'the name of the trimmer to use: fastx_clipper, etc.'
                            },
         trimmer_version    => {
                                is => 'Text',
                                doc => 'the version of read trimmer to use, i.e. 0.6.8, 0.7.1, etc.'
                            },
         trimmer_params     => {
                                is => 'Text',
                                doc => 'any additional params for the trimmer in a single string'
                            },
         aligner_version    => {
                                is => 'Text',
                                doc => 'the version of maq to use, i.e. 0.6.8, 0.7.1, etc.'
                            },
         aligner_params     => {
                                is => 'Text',
                                doc => 'any additional params for the aligner in a single string'
                            },
         reference_build    => {
                                is => 'Genome::Model::Build::ReferencePlaceholder',
                                id_by => 'reference_name',
                            },
         reference_name     => {
                                doc => 'the reference to use by EXACT name, defaults to NCBI-human-build36',
                                default_value => 'NCBI-human-build36'
                            },
         alignment_directory => {
                                 is => 'Text',
                                 doc => 'A directory to output aligment data. NOTE: this bypasses the disk allocation system',
                             },
         force_fragment     => {
                                is => 'Boolean',
                                default_value => 0,
                            },
         picard_version     => {
                                is => 'String',
                                doc => 'The version of Picard to use for merging files, etc',
                            },
         samtools_version     => {
                                is => 'String',
                                doc => 'The version of Samtools to use for sam-to-bam, etc',
                            },
         _fragment_seq_id => { is => 'Number' },
         _resource_lock   => {  is => 'Text'},
    ],

};


sub _resolve_subclass_name {
    my $class = shift;

    if (ref($_[0]) and $_[0]->isa(__PACKAGE__)) {
        my $aligner_name = $_[0]->aligner_name;
        return $class->_resolve_subclass_name_for_aligner_name($aligner_name);
    }
    elsif (my $aligner_name = $class->get_rule_for_params(@_)->specified_value_for_property_name('aligner_name')) {
        return $class->_resolve_subclass_name_for_aligner_name($aligner_name);
    }
    return;
}

sub _resolve_subclass_name_for_aligner_name {
    my ($class,$aligner_name) = @_;
    my @type_parts = split(' ',$aligner_name);

    my @sub_parts = map { ucfirst } @type_parts;
    my $subclass = join('',@sub_parts);

    my $class_name = join('::', 'Genome::InstrumentData::Alignment' , $subclass);
    return $class_name;
}

sub _resolve_aligner_name_for_subclass_name {
    my ($class,$subclass_name) = @_;
    my ($ext) = ($subclass_name =~ /Genome::InstrumentData::Alignment::(.*)/);
    return unless ($ext);
    my @words = $ext =~ /[a-z]+|[A-Z](?:[A-Z]+|[a-z]*)(?=$|[A-Z])/g;
    my $aligner_name = lc(join(" ", @words));
    print "\n**********************************$aligner_name*******************\n";
    return $aligner_name;
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return unless $self;

    if ($self->instrument_data) {
        if ($self->force_fragment && !defined($self->_fragment_seq_id)) {
            $self->_fragment_seq_id($self->instrument_data_id);
        }
    } else {
        unless ($self->force_fragment) {
            $self->error_message('No instrument data found for instrument data id '. $self->instrument_data_id);
            die($self->error_message);
        }
        my $reverse_instrument_data = Genome::InstrumentData::Solexa->get(fwd_seq_id => $self->instrument_data_id);
        unless ($reverse_instrument_data) {
            $self->error_message('Failed to find reverse instrument data by forward id: '. $self->instrument_data_id);
            die($self->error_message);
        }
        $self->_fragment_seq_id($self->instrument_data_id);
        $self->instrument_data_id($reverse_instrument_data->id);
    }

    unless ($self->reference_build) {
        unless ($self->reference_name) {
            $self->error_message('No way to resolve reference build without reference_name or refrence_build');
            die($self->error_message);
        }
        my $ref_build = Genome::Model::Build::ReferencePlaceholder->get($self->reference_name);
        unless ($ref_build) {
            my $sample_type = $self->instrument_data->sample_type;
            if ( defined($sample_type) ) {
                $self->status_message("Creating ReferencePlaceholder with sample type: $sample_type");
                $ref_build = Genome::Model::Build::ReferencePlaceholder->create(
                                                                            name => $self->reference_name,
                                                                            sample_type => $self->instrument_data->sample_type,
                                                                        );
            } else {
                $self->status_message("No sample type is defined.  Creating ReferencePlaceholder without a sample type parameter.");
                $ref_build = Genome::Model::Build::ReferencePlaceholder->create(
                                                                            name => $self->reference_name,
                                                                        );
            }
        }
        $self->reference_build($ref_build);
    }

    unless ($self->alignment_directory) {
        $self->resolve_alignment_directory;
    }
    unless (-d $self->alignment_directory) {
        unless ($self->create_directory($self->alignment_directory)) {
            $self->error_message('Failed to create alignment directory '. $self->alignment_directory .":  $!");
            die($self->error_message);
        }
    }

    return $self;
}

sub estimated_kb_usage {
    my $self = shift;
    my $instrument_data = $self->instrument_data;
    return $instrument_data->calculate_alignment_estimated_kb_usage;
}

sub create_allocation {
    my $self = shift;
    unless ($self->estimated_kb_usage) {
        return;
    }
    my $instrument_data = $self->instrument_data;
    my %params = (
                  disk_group_name => 'info_alignments',
                  allocation_path => $self->resolve_alignment_subdirectory,
                  kilobytes_requested => $self->estimated_kb_usage,
                  owner_class_name => $instrument_data->class,
                  owner_id => $instrument_data->id,
              );
    my $disk_allocation = Genome::Disk::Allocation->allocate(%params);
    unless ($disk_allocation) {
        $self->error_message("Failed to get disk allocation with params:\n". Data::Dumper::Dumper(%params));
        die($self->error_message);
    }
    return $disk_allocation;
}

sub get_or_create_allocation {
    my $self = shift;

    my $allocation = $self->get_allocation;
    if ($allocation) {
        return $allocation;
    }
    return $self->create_allocation;
}

sub get_allocation {
    my $self = shift;

    my $reference_sequence_name = $self->reference_name;
    my $instrument_data = $self->instrument_data;

    my $allocation_path = $self->resolve_alignment_subdirectory;

    my @instrument_data_allocations = $instrument_data->allocations;
    my @matches = grep { $_->allocation_path eq $allocation_path } @instrument_data_allocations;
    if (@matches) {
        if (scalar(@matches) > 1) {
            die('More than one allocation found for allocation_path: '. $allocation_path);
        }
        return $matches[0];
    }
    return;
}

sub resolve_alignment_subdirectory {
    my $self = shift;
    
    my $reference_sequence_name = $self->reference_name;
    my $instrument_data         = $self->instrument_data;

    return sprintf('alignment_data/imported/%s/%s',$reference_sequence_name,$instrument_data->id)
        if $self->aligner_name =~ /^Imported$/i;

    unless ($instrument_data->subset_name) {
        die ($instrument_data->class .'('. $instrument_data->id .') is missing the subset_name or lane!');
    }
    my $directory;
    
    # TODO: there should be no conditional logic here, because the aligner_label should
    # encapsulate all of the variation in a single text string.

    if ($instrument_data->is_external) {
        $directory = sprintf('alignment_data/%s/%s/%s/%s_%s',
                             $self->aligner_label,
                             $reference_sequence_name,
                             $instrument_data->id,
                             $instrument_data->subset_name,
                             $instrument_data->id
                         );
    } 
    elsif ($self->force_fragment) {
        if ($self->trimmer_name) {
            $directory = sprintf('alignment_data/%s/%s/%s/fragment/%s/%s_%s',
                                 $self->aligner_label,
                                 $reference_sequence_name,
                                 $instrument_data->run_name,
                                 $self->trimmer_label,
                                 $instrument_data->subset_name,
                                 $self->_fragment_seq_id,
                             );
        } 
        else {
            $directory = sprintf('alignment_data/%s/%s/%s/fragment/%s_%s',
                                 $self->aligner_label,
                                 $reference_sequence_name,
                                 $instrument_data->run_name,
                                 $instrument_data->subset_name,
                                 $self->_fragment_seq_id,
                             );
        }
    } 
    else {
        unless ($instrument_data->run_name) {
            die ($instrument_data->class .'('. $instrument_data->id .') is missing the run_name!');
        }
        if ($self->trimmer_name) {
            $directory = sprintf('alignment_data/%s/%s/%s/%s/%s_%s',
                                 $self->aligner_label,
                                 $reference_sequence_name,
                                 $instrument_data->run_name,
                                 $self->trimmer_label,
                                 $instrument_data->subset_name,
                                 $instrument_data->id
                             );
        } 
        else {
            $directory = sprintf('alignment_data/%s/%s/%s/%s_%s',
                                 $self->aligner_label,
                                 $reference_sequence_name,
                                 $instrument_data->run_name,
                                 $instrument_data->subset_name,
                                 $instrument_data->id
                             );
        }
    }
    return $directory;
}

sub aligner_label {
    my $self = shift;

    # alignerV_V_V
    # alignerV_V_V/md5

    my $aligner_name    = $self->aligner_name;
    my $aligner_version = $self->aligner_version;
    my $aligner_params  = $self->aligner_params;

    my $aligner_label = $aligner_name;
    if (defined($aligner_version)) {
        $aligner_version =~ s/\./_/g;
        $aligner_label .= $aligner_version;
    }
    
    if ($self->filter_name) {
        $aligner_label .= '.filter_name~' . $self->filter_name;
        # EX: bwa1_2_3.filter_name~forward-only
    }
    
    # TODO: make this NOT an MD5 since that is not reversible,
    # A heuristic which, by default, makes '-a 1 -b foo -c 2 -d bar' into '-a1-bfoo-c2-dbar'?
    # This DOESNT have to be complex b/c each aligner could subclass this method for its case.
    # Maybe: bwa1_2_3.filter_name~forward-only.-t4

    # Also, stop using a sub-directory since it makes the directory 
    # tree have an uneven structure.    
    if ($aligner_params and $aligner_params ne '') {
        my $params_md5 = md5_hex($aligner_params);
        $aligner_label .= '/'. $params_md5;
    }

    return $aligner_label;
}

sub trimmer_label {
    my $self = shift;

    my $trimmer_name    = $self->trimmer_name;
    my $trimmer_version = $self->trimmer_version;
    my $trimmer_params  = $self->trimmer_params;

    my $trimmer_label = $trimmer_name;
    if (defined($trimmer_version)) {
        $trimmer_version =~ s/\./_/g;
        $trimmer_label .= $trimmer_version;
    }
    if ($trimmer_params and $trimmer_params ne '') {
        my $params_md5 = md5_hex($trimmer_params);
        $trimmer_label .= '/'. $params_md5;
    }
    return $trimmer_label;
}


sub resolve_alignment_directory {
    my $self = shift;

    unless ($self->alignment_directory) {
        my $allocation = $self->get_or_create_allocation;
        unless ($allocation) {
            $self->error_message('Failed to get or create alignment allocation.');
            die($self->error_message);
        }
        $self->alignment_directory($allocation->absolute_path);
    }
    return $self->alignment_directory;
}

sub remove_alignment_directory {
    my $self = shift;

    my $allocation = $self->get_allocation;
    unless ($allocation) {
        die('No alignment allocation found for instrument data '. $self->instrument_data_id
            .' with aligner '. $self->aligner_name .' and refseq '. $self->reference_name);
    }
    my $allocation_path = $allocation->absolute_path;
    unless (File::Path::rmtree($allocation_path)) {
        $self->error_message('Failed to remove alignment data directory: '. $allocation_path .":  $!");
        die $self->error_message;
    }
    unless ($allocation->deallocate) {
        $self->error_message('Failed to deallocate alignment data directory disk space for allocator id '. $allocation->allocator_id);
        die $self->error_message;
    }
    return 1;
}

#Abstract methods to be implemented in subclass

sub find_or_generate_alignment_data {
    die('Please implement find_or_generate_alignment_data in '. __PACKAGE__);
}

sub verify_alignment_data {
    die('Please implement verify_alignment_data in '. __PACKAGE__);
}

sub verify_aligner_successful_completion {
    die('Please implement verify_aligner_successful_completion in '. __PACKAGE__);
}

sub get_alignment_statistics {
    die('Please implement get_alignment_statistics in '. __PACKAGE__);
}

sub run_aligner {
    die('Please implement run_aligner in '. __PACKAGE__);
}
sub process_low_quality_alignments {
    die('Please implement process_low_quality_alignments in '. __PACKAGE__);
}

#Method for locking and unlocking

sub lock_alignment_resource {
    my $self = shift;
    my $alignment_directory = $self->alignment_directory;
    my $resource_lock_name = $alignment_directory . '.generate';
    my $lock = $self->lock_resource(resource_lock => $resource_lock_name, max_try => 2);
    unless ($lock) {
        $self->status_message("This data set is still being processed by its creator.  Waiting for existing data lock...");
        $lock = $self->lock_resource(resource_lock => $resource_lock_name);
        unless ($lock) {
            $self->error_message("Failed to get existing data lock!");
            die($self->error_message);
        }
    }
    $self->_resource_lock($lock);
    return $lock;
}

sub unlock_alignment_resource {
    my $self = shift;
    unless ($self->unlock_resource(resource_lock => $self->_resource_lock)) {
        $self->error_message('Failed to unlock alignment resource '. $self->_resource_lock);
        return;
    }
    return 1;
}

sub remove_alignment_directory_contents {

    my $self = shift;
    my $alignment_dir = $self->alignment_directory;
    $self->status_message("Attempting to remove files in alignment directory $alignment_dir");  
    my @files = <$alignment_dir/*>;
    for my $file (@files) {
        my $rv = unlink($file);
        unless ($rv) {
            $self->status_message("Warning:  Could not unlink file $file in $alignment_dir.");  
        }
    }

    if (scalar(@files) > 0) {
        $self->status_message("Done removing files."); 
    } else {
        $self->status_message("No files found to remove."); 
    } 

    return 1; 
} 


#Cleanly die and unlock the resource

sub die_and_clean_up {
    my $self = shift;
    my $error_message = shift;

    eval { $self->unlock_alignment_resource };
    if ($@) {
        $error_message .= "\n". $@;
    }
    eval { $self->remove_alignment_directory };
    if ($@) {
        $error_message .= "\n". $@;
    }
    die($error_message);
}

sub sanger_fastq_filenames {
    my $self = shift;

    my $instrument_data = $self->instrument_data;

    my @sanger_fastq_pathnames;
    if ($self->{_sanger_fastq_pathnames}) {
        @sanger_fastq_pathnames = @{$self->{_sanger_fastq_pathnames}};
        my $errors;
        for my $sanger_fastq (@sanger_fastq_pathnames) {
            unless (-e $sanger_fastq && -f $sanger_fastq && -s $sanger_fastq) {
                $self->error_message('Missing or zero size sanger fastq file: '. $sanger_fastq);
                $self->die_and_clean_up($self->error_message);
            }
        }
    } else {
        my %params;
        
        # This was a hack to support fragment alignment by allowing the LIMS id 
        # for the half of the lane in question to stand in as the instrument data id.
        # Remove this later in favor of the filter logic below.
        if ($self->force_fragment) {
            if ($self->instrument_data_id eq $self->_fragment_seq_id) {
                # reverse reads only
                $params{paired_end_as_fragment} = 2;
            } else {
                # forward reads only
                $params{paired_end_as_fragment} = 1;
            }
        }

        if ($self->filter_name eq 'forward-only') {
            # forward reads only
            $self->status_message('forward-only filter applied for this assignment');
            $params{paired_end_as_fragment} = 1;
        }
        elsif ($self->filter_name eq 'reverse-only') {
            # reverse reads only
            $self->status_message('reverse-only filter applied for this assignment');
            $params{paired_end_as_fragment} = 2;
        }
        elsif ($self->filter_name eq undef) {
            $self->status_message('No special filter for this assignment');
        } 
        else {
            die 'Unsupported filter: "' . $self->filter_name . '"!';
        }

        my @illumina_fastq_pathnames = $instrument_data->fastq_filenames(%params);
        my $counter = 0;
        for my $illumina_fastq_pathname (@illumina_fastq_pathnames) {
            my $sanger_fastq_pathname = $self->create_temp_file_path('sanger-fastq-'. $counter);
            if ($instrument_data->resolve_quality_converter eq 'sol2sanger') {
                my $aligner_version;
                if ($self->aligner_name eq 'maq') {
                    $aligner_version = $self->aligner_version;
                } else {
                    $aligner_version = '0.7.1', ### default to most recent
                }
                unless (Genome::Model::Tools::Maq::Sol2sanger->execute(
                                                                       use_version => $aligner_version,
                                                                       solexa_fastq_file => $illumina_fastq_pathname,
                                                                       sanger_fastq_file => $sanger_fastq_pathname,
                                                                   )) {
                    $self->error_message('Failed to execute sol2sanger quality conversion.');
                    $self->die_and_clean_up($self->error_message);
                }
            } elsif ($instrument_data->resolve_quality_converter eq 'sol2phred') {
                unless (Genome::Model::Tools::Fastq::Sol2phred->execute(
                                                                        fastq_file => $illumina_fastq_pathname,
                                                                        phred_fastq_file => $sanger_fastq_pathname,
                                                                    )) {
                    $self->error_message('Failed to execute sol2phred quality conversion.');
                    $self->die_and_clean_up($self->error_message);
                }
            }
            unless (-e $sanger_fastq_pathname && -f $sanger_fastq_pathname && -s $sanger_fastq_pathname) {
                $self->error_message('Failed to validate the conversion of solexa fastq file '. $illumina_fastq_pathname .' to sanger quality scores');
                $self->die_and_clean_up($self->error_message);
            }

            if ($self->trimmer_name) {
                my $trimmed_sanger_fastq_pathname = $self->create_temp_file_path('trimmed-sanger-fastq-'. $counter);
                my $trimmer;
                if ($self->trimmer_name eq 'fastx_clipper') {
                    #THIS DOES NOT EXIST YET
                    $trimmer = Genome::Model::Tools::Fastq::Clipper->create(
                        params => $self->trimmer_params,
                        version => $self->trimmer_version,
                        input => $sanger_fastq_pathname,
                        output => $trimmed_sanger_fastq_pathname,
                    );
                } elsif ($self->trimmer_name eq 'trim5') {
                    $trimmer = Genome::Model::Tools::Fastq::Trim5->create(
                        length => $self->trimmer_params,
                        input => $sanger_fastq_pathname,
                        output => $trimmed_sanger_fastq_pathname,
                    );
                } else {
                    $self->error_message('Unknown read trimmer_name '. $self->trimmer_name);
                    $self->die_and_clean_up($self->error_message);
                }
                unless ($trimmer) {
                    $self->error_message('Failed to create fastq trim command');
                    $self->die_and_clean_up($self->error_message);
                }
                unless ($trimmer->execute) {
                    $self->error_message('Failed to execute fastq trim command '. $trimmer->command_name);
                    $self->die_and_clean_up($self->error_message);
                }
                $sanger_fastq_pathname = $trimmed_sanger_fastq_pathname;
            }
            push @sanger_fastq_pathnames, $sanger_fastq_pathname;
            $counter++;
        }
        $self->{_sanger_fastq_pathnames} = \@sanger_fastq_pathnames;
    }
    return @sanger_fastq_pathnames;
}





1;
