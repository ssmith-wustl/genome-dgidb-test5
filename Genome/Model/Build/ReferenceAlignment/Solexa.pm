package Genome::Model::Build::ReferenceAlignment::Solexa;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::ReferenceAlignment::Solexa {
    is => 'Genome::Model::Build::ReferenceAlignment',
    has => [],

};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    unless ($self) {
        return;
    }

    my $model = $self->model;

    my @idas = $model->instrument_data_assignments;

    unless (scalar(@idas) && ref($idas[0])  &&  $idas[0]->isa('Genome::Model::InstrumentDataAssignment')) {
        $self->error_message('No instrument data have been added to model: '. $model->name);
        $self->error_message("The following command will add all available instrument data:\ngenome model instrument-data assign  --model-id=".
        $model->id .' --all');
        return;
    }

    return $self;
}

sub calculate_estimated_kb_usage {
    my $self = shift;
    my $model = $self->model;
    my $reference_build = $model->reference_build;
    my $reference_file_path = $reference_build->full_consensus_path;

    my $du_output = `du -sk $reference_file_path`;
    my @fields = split(/\s+/,$du_output);
    my $reference_kb = $fields[0];
    my $estimate_from_reference = $reference_kb * 30;

    my @idas = $model->instrument_data_assignments;
    my $estimate_from_instrument_data = scalar(@idas) * 10000;

    #return ($estimate_from_reference + $estimate_from_instrument_data);
    my $temporary_value = 629145600; #600GB

    my $processing_profile_name = $model->processing_profile_name;

    if ($processing_profile_name =~ /alignments only/i) {
        $temporary_value = 102400; #10 MB
    }
    
    return $temporary_value; 
}

sub consensus_directory {
    my $self = shift;
    return $self->data_directory .'/consensus';

}
sub _consensus_files {
    return shift->_files_for_pattern_and_optional_ref_seq_id('%s/consensus/%s.cns',@_);
}

#sub bam_pileup_file {
#    my $self = shift;
#    my $ref_seq_id = shift;

#    my ($pileup_file) = $self->_consensus_files($self->ref_seq_id);
#    $pileup_file .= '.samtools_pileup';
#    return $pileup_file;
#}

sub bam_pileup_file_path {
    my $self = shift; 
    my $filename = $self->consensus_directory . "/all_sequences.cns.samtools_pileup";
    return $filename; 
}

sub bam_pileup_bzip_file_path {
    my $self = shift; 
    my $filename = $self->bam_pileup_file_path.".bz2";
    return $filename; 
}

sub bam_pileup_file {

    my $self = shift;
    my $file = $self->bam_pileup_file_path;
    my $bzip_file = $file.".bz2";
    if (-s $file) {
        return $file;
    } elsif (-s $bzip_file) {
        #see if the bzip version exists
        my $pileup_file = Genome::Utility::FileSystem->bunzip($bzip_file);
        if (-s $pileup_file) {
            return $pileup_file;
        } else {
            $self->error_message("Could not bunzip pileup file: $pileup_file.");
            die "Could not bunzip pileup file: $pileup_file.";
        }
    } else {
        $self->error_message("No bam pileup file could be found at: $file.");
        die "No bam pileup file could be found at: $file."; 
    }

return;

}

# TODO: we should abstract the genotyper the way we do the aligner
# for now these are hard-coded maq-ish values.


sub _snv_file_unfiltered {
    my $self = shift;
    my $build_id = $self->build_id;

    #Note:  This switch is used to ensure backwards compatibility with 'old' per chromosome data.  
    #Eventually will be removed.
 
    #The 'new' whole genome way 
    if ( $build_id < 0 || $build_id > 96763806 ) {
        my $unfiltered = $self->snp_related_metric_directory .'/snps_all_sequences';
        unless (-e $unfiltered) {
            die 'No variant snps files were found.';
        }
        return $unfiltered;
    } else {
    #The 'old' per chromosome way
        $self->X_snv_file_unfiltered();
    }

}


sub X_snv_file_unfiltered {
    my $self = shift;
    my $unfiltered = $self->snp_related_metric_directory .'/all.snps';
    unless (-e $unfiltered) {
        # make a combined snp file
        my @old = $self->_variant_list_files();
        if (@old) {
            warn "building $unfiltered\n";
            my $tmp = Genome::Utility::FileSystem->create_temp_file_path("snpfilter");
            Genome::Utility::FileSystem->cat(
                                             input_files => \@old,
                                             output_file => $tmp,
                                         );
            unless (Genome::Model::Tools::Snp::Sort->execute(
                                                             snp_file => $tmp,
                                                             output_file => $unfiltered,
                                                         )) {
                $self->error_message('Failed to execute snp sort command for snv file unfiltered'. $unfiltered);
            }
        }
    }
    return $unfiltered;
}

sub _unsorted_indel_file {
    my $self = shift;
    my $map_snp_dir = $self->snp_related_metric_directory;
    my $unsorted_indel_file = $map_snp_dir .'/indelpe.out';
    unless (-e $unsorted_indel_file) {
        my @unsorted_indel_files = grep {$_ !~ /sorted/} grep { -e $_ } glob("$map_snp_dir/indelpe*out");
        unless (@unsorted_indel_files) {
            my $model = $self->model;
            my $aligner_path = $self->path_for_maq_version('genotyper_version');
            my $ref_seq = $model->reference_build->full_consensus_path;

            #my $accumulated_alignments_file = $self->accumulate_maps;
            my $accumulated_alignments_file = $self->whole_rmdup_map_file;
            
            unless ($accumulated_alignments_file) {
                $self->error_message('Failed to get accumulated map file');
                return;
            }
            my $indelpe_cmd = "$aligner_path indelpe $ref_seq $accumulated_alignments_file > $unsorted_indel_file";
            Genome::Utility::FileSystem->shellcmd(
                                                  cmd => $indelpe_cmd,
                                                  input_files => [$aligner_path, $ref_seq, $accumulated_alignments_file],
                                                  allow_zero_size_output_files => 1,
                                                  output_files => [$unsorted_indel_file],
                                              );
            #my $rm_cmd = "rm $accumulated_alignments_file";
            #Genome::Utility::FileSystem->shellcmd(cmd => $rm_cmd);
            return $unsorted_indel_file;
        }
        if (scalar(@unsorted_indel_files) > 1) {
            $self->error_message('Found '. scalar(@unsorted_indel_files) .' unsorted indel files but only expecting one for build '. $self->id);
            die($self->error_message);
        }
        return $unsorted_indel_files[0];
    }
    return $unsorted_indel_file;
}

sub _indel_file {
    my $self = shift;

    my $maq_snp_dir = $self->snp_related_metric_directory;
    my $sorted_indelpe = $maq_snp_dir .'/indelpe.sorted.out';
    unless (-e $sorted_indelpe) {
        # lookup or make a sorted indelpe file
        my $unsorted_indel_file = $self->_unsorted_indel_file;
        if (-s $unsorted_indel_file) {
            unless (Genome::Model::Tools::Snp::Sort->execute(
                                                             snp_file => $unsorted_indel_file,
                                                             output_file => $sorted_indelpe,
                                                         )) {
                $self->error_message('Failed to execute snp sort command for indelpe file '. $unsorted_indel_file);
            }
        } else {
            my $fh = Genome::Utility::FileSystem->open_file_for_writing($sorted_indelpe);
            unless ($fh) {
                die "failed to open $sorted_indelpe!: $!";
            }
            $fh->close;
        }
    }
    return $sorted_indelpe;
}

sub _snv_file_filtered {
    my $self = shift;

    my $filtered;
    my $unfiltered = $self->_snv_file_unfiltered;

    my $build_id = $self->build_id;
 
    #Note:  This switch is to insure backward compatibility while generating reports.  
    #Builds before the id below generated files on a per chromosome basis.
    #Test builds and current production builds generate data on a whole genome basis.

    #'new', whole genome 
    if ( $build_id < 0 || $build_id > 96763806 ) {
        $filtered = $self->filtered_snp_file();
        $self->status_message("********************Path for filtered indelpe file: $filtered");
    } else {
    #'old', per chromosme
       $filtered = $unfiltered; 
       $filtered =~ s/all/filtered.indelpe/g;
    }

    if (-e $unfiltered and not -e $filtered) {
        # run SNPfilter w/ indelpe data
        my $indelpe = $self->_indel_file;
        my $bin = $self->path_for_maq_version('genotyper_version');
        my $script = $bin . '.pl';

        my $indelpe_param;
	my @inputs = ($script, $unfiltered);
        if (-s $indelpe) {
            $indelpe_param = "-F '$indelpe'";
	    push @inputs, $indelpe;
        }
        else {
            warn "omitting indelpe data from the SNPfilter results because no indels were found...";
            $indelpe_param = '';
        }
        Genome::Utility::FileSystem->shellcmd(
            cmd => "$script SNPfilter $indelpe_param $unfiltered > $filtered",
            input_files => \@inputs,
            allow_zero_size_output_files => 1,
            output_files => [$filtered],
        );
    }
    return $filtered;
}

sub filtered_snp_file {

    my ($self) = @_;
    return join('/', $self->snp_related_metric_directory(), '/filtered.indelpe.snps');
}


#clearly if multiple aligners/programs becomes common practice, we should be delegating to the appropriate module to construct this directory
sub _variant_list_files {
    return shift->_variant_files('snps', @_);
}

sub _variant_filtered_list_files {
    my ($self, $ref_seq) = @_;
    my $caller_type = $self->_snp_caller_type;
    my $pattern = '%s/'.$caller_type.'_snp_related_metrics/snps_%s.filtered';
    return $self->_files_for_pattern_and_optional_ref_seq_id($pattern, $ref_seq);
}

sub _variant_pileup_files {
    return shift->_variant_files('pileup', @_);
}

sub _variant_detail_files {
    return shift->_variant_files('report_input', @_);
}

sub _variation_metrics_files {
    return shift->_files_for_pattern_and_optional_ref_seq_id('%s/other_snp_related_metrics/variation_metrics_%s.csv',@_);
}

sub _variant_files {
    my ($self, $file_type, $ref_seq) = @_;
    my $caller_type = $self->_snp_caller_type;
    my $pattern = '%s/'.$caller_type.'_snp_related_metrics/'.$file_type.'_%s';
    return $self->_files_for_pattern_and_optional_ref_seq_id($pattern, $ref_seq);
}

sub _transcript_annotation_files {
    return shift->_files_for_pattern_and_optional_ref_seq_id('%s/annotation/%s_snp.transcript',@_);
}

sub other_snp_related_metric_directory {
    my $self = shift;
    return $self->data_directory . "/other_snp_related_metrics/";
}

sub snp_related_metric_directory {
    my $self = shift;
    return $self->data_directory . '/' . $self->_snp_caller_type . '_snp_related_metrics/';
}

sub _snp_caller_type {
    return shift->model->_snp_caller_type;
}
    
sub _filtered_variants_dir {
    my $self = shift;
    return sprintf('%s/filtered_variations/',$self->data_directory);
}

sub _reports_dir {
    my $self = shift;
    return sprintf('%s/annotation/',$self->data_directory);
}

sub _files_for_pattern_and_optional_ref_seq_id {
    my ($self, $pattern, $ref_seq) = @_;

    if ((defined $ref_seq and $ref_seq eq 'all_sequences') or !defined $ref_seq) {
        return sprintf($pattern, $self->data_directory, 'all_sequences');
    }

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
    $self->model->get_subreference_names;

    return @files;
}

sub whole_map_file {
    my $self = shift;
    return $self->accumulated_alignments_directory .'/whole.map';
}

sub whole_rmdup_map_file {
    my $self = shift;
    return $self->accumulated_alignments_directory .'/whole_rmdup.map';
}

sub whole_rmdup_bam_file {
    my $self = shift;
    my $model = $self->model;
    my $subject = $model->subject_name;
    my $resolved_file = $subject . '_merged_rmdup.bam';
    return $self->accumulated_alignments_directory .'/'.$resolved_file;
}


sub reference_coverage_directory {
    my $self = shift;
    return $self->data_directory .'/reference_coverage';
}

sub layers_file {
    my $self = shift;
    return $self->reference_coverage_directory .'/whole.layers';
}

sub genes_file {
    my $self = shift;

    my $model = $self->model;
    my $reference_build = $model->reference_build;
    return $reference_build->data_directory .'/BACKBONE.tsv';
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
    my @map_lists = grep { -e $_ } glob($self->accumulated_alignments_directory .'/*_'. $ref_seq_id .'.maplist');
    unless (@map_lists) {
        $self->error_message("No map lists found for ref seq $ref_seq_id in " . $self->accumulated_alignments_directory);
    }
    return @map_lists;
}

sub duplicates_map_file {
    my $self = shift;
    return $self->accumulated_alignments_directory .'/all_sequences.duplicates.map';
}


sub accumulate_maps {
    my $self=shift;

    my $model = $self->model;
    my $result_file;

    #replace 999999 with the cut off value... 
    #2761337261 is an old AML2 model with newer data
    if ($model->id < 0 || $model->id >= 2766822526 || $model->id == 2761337261) {
        $result_file = $self->resolve_accumulated_alignments_filename;
    } else {
        my @all_map_lists;
        my @chromosomes = $model->reference_build->subreference_names;
        foreach my $c (@chromosomes) {
            my $a_ref_seq = Genome::Model::RefSeq->get(model_id => $model->id, ref_seq_name=>$c);
            my @map_list = $a_ref_seq->combine_maplists;
            push (@all_map_lists, @map_list);
        }

        $result_file = '/tmp/mapmerge_'. $model->genome_model_id;
        $self->warning_message("Performing a complete mapmerge for $result_file \n"); 

        my ($fh,$maplist) = File::Temp::tempfile;
        $fh->print(join("\n",@all_map_lists),"\n");
        $fh->close;

        my $maq_version = $model->read_aligner_version;
        system "gt maq vmerge --maplist $maplist --pipe $result_file --version $maq_version &";

        $self->status_message("gt maq vmerge --maplist $maplist --pipe $result_file --version $maq_version &");
        my $start_time = time;
        until (-p "$result_file" or ( (time - $start_time) > 100) )  {
            $self->status_message("Waiting for pipe...");
            sleep(5);
        }
        unless (-p "$result_file") {
            die "Failed to make pipe? $!";
        }
        $self->status_message("Streaming into file $result_file.");
        $self->warning_message("mapmerge complete.  output filename is $result_file");
        chmod 00664, $result_file;
    }
    return $result_file;
}

sub maq_version_for_pp_parameter {
    my $self = shift;
    my $pp_param = shift;

    $pp_param = 'read_aligner_version' unless defined $pp_param;
    my $pp = $self->model->processing_profile;
    unless ($pp->$pp_param) {
        die("Failed to resolve path for maq version using processing profile parameter '$pp_param'");
    }
    my $version = $pp->$pp_param;
    unless ($version) {
        $pp_param =~ s/version/name/;
        $version = $pp->$pp_param;
        $version =~ s/^\D+//;
        $version =~ s/_/\./g;
    }
    unless ($version) {
        die("Failed to resolve a version for maq using processing profile parameter '$pp_param'");
    }
    return $version;
}

sub path_for_maq_version {
    my $self = shift;
    my $pp_param = shift;

    my $version = $self->maq_version_for_pp_parameter($pp_param);
    return Genome::Model::Tools::Maq->path_for_maq_version($version);
}


sub resolve_accumulated_alignments_filename {
    my $self = shift;

    my $aligner_path = $self->path_for_maq_version('read_aligner_version');

    my %p = @_;
    my $ref_seq_id = $p{ref_seq_id};
    my $library_name = $p{library_name};

    my $alignments_dir = $self->accumulated_alignments_directory;

    if ($library_name && $ref_seq_id) {
        return "$alignments_dir/$library_name/$ref_seq_id.map";
    } elsif ($ref_seq_id) {
        return $alignments_dir . "/mixed_library_submaps/$ref_seq_id.map";
    } else {
        my @files = glob("$alignments_dir/mixed_library_submaps/*.map");
        my $tmp_map_file = Genome::Utility::FileSystem->create_temp_file_path('ACCUMULATED_ALIGNMENTS-'. $self->model_id .'.map');
        if (-e $tmp_map_file) {
            unless (unlink $tmp_map_file) {
                $self->error_message('Could not unlink existing temp file '. $tmp_map_file .": $!");
                die($self->error_message);
            }
        }
        require POSIX;
        unless (POSIX::mkfifo($tmp_map_file, 0700)) {
            $self->error_message("Can not create named pipe ". $tmp_map_file .":  $!");
            die($self->error_message);
        }
        my $cmd = "$aligner_path mapmerge $tmp_map_file " . join(" ", @files) . " &";
        my $rv = Genome::Utility::FileSystem->shellcmd(
                                                       cmd => $cmd,
                                                       input_files => \@files,
                                                       output_files => [$tmp_map_file],
                                                   );
        unless ($rv) {
            $self->error_message('Failed to execute mapmerge command '. $cmd);
            die($self->error_message);
        }
        return $tmp_map_file;
    }
}


1;

