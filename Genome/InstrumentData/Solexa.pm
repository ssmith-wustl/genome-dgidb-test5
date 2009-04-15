package Genome::InstrumentData::Solexa;

use strict;
use warnings;

use Genome;

use File::Basename;

class Genome::InstrumentData::Solexa {
    is => ['Genome::InstrumentData', 'Genome::Utility::FileSystem'],
    table_name => <<EOS
        (
            select to_char(seq_id) id, 
                seq_id genome_model_run_id, 
                lane limit_regions,
                
                flow_cell_id, 
                lane,
                unique_reads_across_library,
                duplicate_reads_across_library,
                read_length,
                run_type,
                gerald_directory,
                median_insert_size,
                sd_above_insert_size,
                is_external,
                FILT_CLUSTERS,
                analysis_software_version,
                sample.dna_id sample_id,
                library.dna_id library_id 
            from solexa_lane_summary\@dw s
            left join dna\@oltp sample on sample.dna_name = s.sample_name
            left join dna\@oltp library on library.dna_name = s.library_name
        ) 
        solexa_detail
EOS
    ,
    has_optional => [
        flow_cell_id                    => { }, # = short name
        lane                            => { }, # = subset_name
        read_length                     => { },
        unique_reads_across_library     => { },
        duplicate_reads_across_library  => { },
        run_type                        => { },
        gerald_directory                => { },
        median_insert_size              => { },
        sd_above_insert_size            => { },
        is_external                     => { },
        analysis_software_version       => { },             
        clusters                        => { column_name => 'FILT_CLUSTERS' },
        
        short_name => {
            doc => 'The essential portion of the run name which identifies the run.  The rest is redundent information about the instrument, date, etc.',
            is => 'Text', 
            calculate_from => ['run_name'],
            calculate => q|($run_name =~ /_([^_]+)$/)[0]|
        },

        is_paired_end                   => {
                                            calculate_from => ['run_type'],
                                            calculate => q| if (defined($run_type) and $run_type =~ m/Paired End Read (\d)/) {
                                                                return $1;
                                                             }
                                                             else {
                                                                 return 0;
                                                             } |
                                        },
        _run_lane_solexa => {
            doc => 'Solexa Lane Summary from LIMS.',
            is => 'GSC::RunLaneSolexa',
            calculate => q| GSC::RunLaneSolexa->get($id); |,
            calculate_from => ['id']
        },

        # deprecated, compatible with Genome::RunChunk::Solexa
        genome_model_run_id => {},
        limit_regions       => {},

        # basic relationship to the "source" of the lane
        library         => { is => 'Genome::Library', id_by => ['library_id'] },
        library_id      => { is => 'Number', },
    
        # these are indirect via library, but must be set directly for lanes missing library info
        sample              => { is => 'Genome::Sample', id_by => ['sample_id'] },
        sample_id           => { is => 'Number', },
        
        sample_source       => { via => 'sample', to => 'source' },
        sample_source_name  => { via => 'sample_source', to => 'name' },
        
        # indirect via the sample source, but we let the sample manage that
        # since we sometimes don't know the source, it also tracks taxon directly
        taxon               => { via => 'sample', to => 'taxon' },
        species_name        => { via => 'taxon' },
    ],
};

sub calculate_alignment_estimated_kb_usage {
    my $self = shift;
    # These default values should be replaced with an equation that takes into account:
    # 1.) read_length
    # 2.) reference sequence size
    # 3.) clusters
    # 4.) paired end
    if ($self->is_paired_end) {
        return 2000000;
    } else {
        return 1000000;
    }
}

sub resolve_full_path {
    my $self = shift;

    my @fs_path = GSC::SeqFPath->get(
        seq_id => $self->genome_model_run_id,
        data_type => [qw/ duplicate fastq path unique fastq path /],
    )
        or return; # no longer required, we make this ourselves at alignment time as needed

    my %dirs = map { File::Basename::dirname($_->path) => 1 } @fs_path;

    if ( keys %dirs > 1) {
        $self->error_message(
            sprintf(
                'Multiple directories for run %s %s (%s) not supported!',
                $self->run_name,
                $self->lane,
                $self->genome_model_run_id,
            )
        );
        return;
    }
    elsif ( keys %dirs == 0 ) {
        $self->error_message(
            sprintf(
                'No directories for run %s %s (%s)',
                $self->run_name,
                $self->lane,
                $self->id,
            )
        );
        return;
    }

    my ($full_path) = keys %dirs;
    $full_path .= '/' unless $full_path =~ m|\/$|;

    return $full_path;
}

#< Dump to File System >#
sub dump_to_file_system {
    #$self->warning_message("Method 'dump_data_to_file_system' not implemented");
    return 1;
}

sub fastq_filenames {
    my $self = shift;
    my @fastqs;
    if ($self->is_external) {
        @fastqs = $self->resolve_external_fastq_filenames;
    } else {
        @fastqs = $self->resolve_fastq_filenames;
    }
    return @fastqs;
}

sub desc {
    my $self = shift;
    return $self->full_name .'('. $self->id .')';
}

sub resolve_fastq_filenames {
    my $self = shift;

    my $fastq_directory = $self->dump_illumina_fastq_archive;
    my $lane = $self->subset_name;

    my @illumina_output_paths;
    my @errors;
    # First check the archive directory and second get the gerald directory
    for my $directory ($fastq_directory, $self->gerald_directory) {
        eval {
            unless ($directory) {
                die('No directory found for '. $self->desc);
            }
            unless (-d $directory) {
                die('No directory on the filesystem for '. $self->desc .' : '. $directory);
            }
            # handle fragment or paired-end data
            if ($self->is_paired_end) {
                if (-e "$directory/s_${lane}_1_sequence.txt") {
                    push @illumina_output_paths, "$directory/s_${lane}_1_sequence.txt";
                } elsif (-e "$directory/Temp/s_${lane}_1_sequence.txt") {
                    push @illumina_output_paths, "$directory/Temp/s_${lane}_1_sequence.txt";
                } else {
                    die "No illumina forward data in directory for lane $lane! $directory";
                }
                if (-e "$directory/s_${lane}_2_sequence.txt") {
                    push @illumina_output_paths, "$directory/s_${lane}_2_sequence.txt";
                } elsif (-e "$directory/Temp/s_${lane}_2_sequence.txt") {
                    push @illumina_output_paths, "$directory/Temp/s_${lane}_2_sequence.txt";
                } else {
                    die "No illumina reverse data in directory for lane $lane! $directory";
                }
            } else {
                if (-e "$directory/s_${lane}_sequence.txt") {
                    push @illumina_output_paths, "$directory/s_${lane}_sequence.txt";
                } elsif (-e "$directory/Temp/s_${lane}_sequence.txt") {
                    push @illumina_output_paths, "$directory/Temp/s_${lane}_sequence.txt";
                } else {
                    die "No illumina data in directory for lane $lane! $directory";
                }
            }
        };
        if ($@) {
            push @errors, $@;
        }
        if (@illumina_output_paths) {
            last;
        }
    }
    unless (@illumina_output_paths) {
        if (@errors) {
            die(join("\n",@errors));
        } else {
            die('Failed to trap error messages!  However, no fastq files were found for '. $self->desc);
        }
    }
    return @illumina_output_paths;
}

sub dump_illumina_fastq_archive {
    my $self = shift;

    my $rls = $self->_run_lane_solexa;
    my $archive = $rls->illumina_fastq_archive_path;
    my $tmp_dir = $self->base_temp_directory;
    my $cmd = "tar -xzf $archive --directory=$tmp_dir";
    unless ($self->shellcmd(
                            cmd => $cmd,
                            input_files => [$archive],
                        ) ) {
        $self->error_message('Failed to run tar command '. $cmd);
        die($self->error_message);
    }
    return $tmp_dir;
}

sub resolve_external_fastq_filenames {
    my $self = shift;

    my @fastq_pathnames;
    my $fastq_pathname = $self->create_temp_file_path('fastq');
    unless ($fastq_pathname) {
        die "Failed to create temp file for fastq!";
    }
    return ($fastq_pathname);
}

sub _calculate_total_read_count {
    my $self = shift;

    if($self->is_external) {
        my $data_path_object = Genome::MiscAttribute->get(entity_id => $self->id, property_name=>'full_path');
        my $data_path = $data_path_object->value;
        my $lines = `wc -l $data_path`;
        return $lines/4;
    }
    if ($self->clusters <= 0) {
        die('Impossible value '. $self->clusters .' for clusters field for solexa lane '. $self->id);
    }

    return $self->clusters;
}

sub resolve_quality_converter {
    my $self = shift;

    my %analysis_software_versions = (
                                     'GAPipeline-0.3.0'       => 'sol2sanger',
                                     'GAPipeline-0.3.0b1'     => 'sol2sanger',
                                     'GAPipeline-0.3.0b2'     => 'sol2sanger',
                                     'GAPipeline-0.3.0b3'     => 'sol2sanger',
                                     'GAPipeline-1.0'         => 'sol2sanger',
                                     'GAPipeline-1.0-64'      => 'sol2sanger',
                                     'GAPipeline-1.0rc4'      => 'sol2sanger',
                                     'GAPipeline-1.1rc1p4'    => 'sol2sanger',
                                     'SolexaPipeline-0.2.2.5' => 'sol2sanger',
                                     'SolexaPipeline-0.2.2.6' => 'sol2sanger',
                                     #Anything newer than GAPipeline-1.3* uses sol2phred
                                     'GAPipeline-1.3.2'       => 'sol2phred',
                                     'GAPipeline-1.3.4'       => 'sol2phred',
                                     'GAPipeline-1.3rc4'      => 'sol2phred',
                                     'GAPipeline-1.3rc6'      => 'sol2phred',
                                 );
    my $analysis_software_version = $self->analysis_software_version;
    unless ($analysis_software_version) {
        die('No analysis_software_version found for instrument data '. $self->id);
    }
    unless ($analysis_software_versions{$analysis_software_version}) {
        die('No quality converter defined for anlaysis_software_version '. $analysis_software_version );
    }
    return $analysis_software_versions{$analysis_software_version};
}

1;

#$HeaderURL$
#$Id$
