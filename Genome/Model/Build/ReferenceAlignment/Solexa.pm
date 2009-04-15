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

    return ($estimate_from_reference + $estimate_from_instrument_data);
}

sub _consensus_files {
    return shift->_files_for_pattern_and_optional_ref_seq_id('%s/consensus/%s.cns',@_);
}

#clearly if multiple aligners/programs becomes common practice, we should be delegating to the appropriate module to construct this directory
sub _variant_list_files {
    return shift->_files_for_pattern_and_optional_ref_seq_id('%s/maq_snp_related_metrics/snps_%s',@_);
}

sub _variant_filtered_list_files {
    return shift->_files_for_pattern_and_optional_ref_seq_id('%s/maq_snp_related_metrics/snps_%s.filtered',@_);
}

# TODO: we should abstract the genotyper the way we do the aligner
# for now these are hard-coded maq-ish values.

sub _snv_file_unfiltered {
    my $self = shift;
    my $dd = $self->data_directory;
    my $unfiltered = "$dd/maq_snp_related_metrics/all.snps";
    unless (-e $unfiltered) {
        # make a combined snp file
        my @old = $self->_variant_list_files();
        if (@old) {
            warn "building $unfiltered\n";
            my $tmp = Genome::Utility::FileSystem->create_temp_file_path("snpfilter");
            Genome::Utility::FileSystem->shellcmd(
                cmd => "cat @old >$tmp; gt snp sort -s $tmp >$unfiltered",
                input_files => \@old,
                output_files => [$unfiltered],
            );
        }
    }
    return $unfiltered;
}


sub _indel_file {
    my $self = shift;
    my $dd = $self->data_directory;
    my $path = $dd . '/maq_snp_related_metrics/indelpe.sorted.out';
    unless (-e $path) {
        # make a sorted indelpe file
        my @indelpe_orig = grep { -e $_ } glob("$dd/maq_snp_related_metrics/indelpe*out");
        die "multiple indelpe results?\n@indelpe_orig" if @indelpe_orig > 1;
        my $indelpe_orig = $indelpe_orig[0];
        if (-e $indelpe_orig) {
            if (-s $indelpe_orig) {
                warn "generating $path from $indelpe_orig";
                # note: not running directly in Perl b/c we want to redirect IO
                Genome::Utility::FileSystem->shellcmd(
                    cmd => "gt snp sort -s $indelpe_orig > $path",
                    input_files => [$indelpe_orig],
                    output_files => [$path],
                );
            }
            else {
                warn "generating empty $path from empty $indelpe_orig";
                my $fh = Genome::Utility::FileSystem->open_file_for_writing($path);
                unless ($fh) {
                    die "failed to open $path!: $!";
                }
                $fh->close;
            }
        }
    }
    return $path;
}

sub _snv_file_filtered {
    my $self = shift;
    my $unfiltered = $self->_snv_file_unfiltered;
    my $filtered = $unfiltered;
    $filtered =~ s/all/filtered.indelpe/g;
    if (-e $unfiltered and not -e $filtered) {
        # run SNPfilter w/ indelpe data
        my $pp = $self->model->processing_profile;
        unless ($pp->genotyper_name =~ /maq/) {
            die "THIS LOGIC IS CURRENTLY HARD-CODED FOR MAQ!!!";
        }
        my $dd = $self->data_directory;
        my $indelpe = $self->_indel_file;
        my $version = $pp->genotyper_version;
        unless ($version) {
            $version = $pp->genotyper_name;
            $version =~ s/^\D+//;
            $version =~ s/_/\./g;
        }
        my $bin = Genome::Model::Tools::Maq->path_for_maq_version($version);
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
            # TODO: add flag to allow zero size output?
            #output_files => [$filtered],
        );
	unless (-s $filtered) {
	    $self->status_message('Zero size or non-existent filtered indel file '. $filtered);
	}
    }
    return $filtered; 
}

sub _variant_pileup_files {
    return shift->_files_for_pattern_and_optional_ref_seq_id('%s/maq_snp_related_metrics/pileup_%s',@_);
}

sub _variant_detail_files {
    return shift->_files_for_pattern_and_optional_ref_seq_id('%s/maq_snp_related_metrics/report_input_%s',@_);
}

sub _variation_metrics_files {
    return shift->_files_for_pattern_and_optional_ref_seq_id('%s/other_snp_related_metrics/variation_metrics_%s.csv',@_);
}

sub _transcript_annotation_files {
    return shift->_files_for_pattern_and_optional_ref_seq_id('%s/annotation/%s_snp.transcript',@_);
}

sub other_snp_related_metric_directory {
    my $self = shift;
    return $self->data_directory . "/other_snp_related_metrics/";
}
sub maq_snp_related_metric_directory {
    my $self = shift;
    return $self->data_directory . "/maq_snp_related_metrics/";
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
    my $self=shift;
    my $pattern = shift;
    my $ref_seq=shift;
    
    if(defined($ref_seq) and $ref_seq eq 'all_sequences') {
        return sprintf($pattern,$self->data_directory,$ref_seq);
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

1;

