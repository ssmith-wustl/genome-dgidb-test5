package Genome::Model::Command::Build::ReferenceAlignment::PostprocessVariations::Maq;

use strict;
use warnings;

use Genome::Model;
use IO::File;
use Genome::Model::Command::Report::MetricsBatchToLsf;
use IO::File;
use File::Basename;

class Genome::Model::Command::Build::ReferenceAlignment::PostprocessVariations::Maq {
    is => ['Genome::Model::Command::Build::ReferenceAlignment::PostprocessVariations', 'Genome::Model::Command::MaqSubclasser'],
};

sub help_brief {
    "Create the input file required for the annotation report generators"
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads postprocess-variations maq --model-id 5 --ref-seq-id 10
EOS
}

sub help_detail {                           
    return <<EOS 
EOS
}

sub _snp_resource_name {
    my $self = shift;
    return sprintf("snps%s", defined $self->ref_seq_id ? "_".$self->ref_seq_id : "");
}

sub _pileup_resource_name {
    my $self = shift;
    return sprintf("pileup%s", defined $self->ref_seq_id ? "_".$self->ref_seq_id : "");
}

sub _variation_metrics_name {
    my $self = shift;
    return sprintf("variation_metrics%s", defined $self->ref_seq_id ? "_".$self->ref_seq_id : "");
}

sub snp_output_file {
    my $self = shift;
    return sprintf("%s/%s", $self->model->maq_snp_related_metric_directory,$self->_snp_resource_name);
}

sub pileup_output_file {
    my $self = shift;
    return sprintf("%s/%s", $self->model->maq_snp_related_metric_directory,$self->_pileup_resource_name);
}

sub variation_metrics_file {
    my $self = shift;
    return sprintf("%s/%s", $self->model->other_snp_related_metric_directory,$self->_variation_metrics_name);
}
sub variation_metrics_file_for_model {
    my $self = shift;
    my $model = shift;
    my $metrics_for_other_snps_directory = $self->model->other_snp_related_metric_directory . "/metrics_for_$model" . "_snps/";

    unless (-d $metrics_for_other_snps_directory) {
        unless(mkdir $metrics_for_other_snps_directory) {
            $self->error_message("Cannot create $metrics_for_other_snps_directory");
            return;
        }
        chmod 02775, $metrics_for_other_snps_directory;
    }
    return $metrics_for_other_snps_directory . $self->_variation_metrics_name;
}


sub experimental_variation_metrics_file_basename {
    my $self = shift;
    return sprintf("%s/%s", $self->model->maq_snp_related_metric_directory, 'experimental_' . $self->_variation_metrics_name);
}

sub execute {
    my $self = shift;
    my $model = $self->model;

    unless(-d $self->model->other_snp_related_metric_directory) {
        unless(mkdir $self->model->other_snp_related_metric_directory) {
            $self->error_message("Cannot create " . $self->model->other_snp_related_metric_directory);
            return;
        }
        chmod 02775, $self->model->other_snp_related_metric_directory;
    }
    
    $self->revert;


    #unless ($self->generate_variation_metrics_files_v1) {        
    #    $self->error_message("Error generating variation metrics file (used downstream at filtering time)!");
    #    return;
    #}
    unless ($self->generate_variation_metrics_files_v2) {        
        $self->error_message("Error generating variation metrics file (used downstream at filtering time)!");
        return;
    }
    
    #hey, this regex could probably be replaced with a formal model comparison lookup system!
    #PS FIXME
    if($model =~ m/tumor/) {
        my $map_file = $self->skin_sample_map_file;
        unless ($self->generate_variation_metrics_files_v2($map_file)) {        
            $self->error_message("Error generating variation metrics file (used downstream at filtering time)!");
            return;
        }
    }

    unless ($self->verify_successful_completion) {
        $self->error_message("Error validating results!");
        # cleanup...
        return;
    }
    
    return 1;
}

sub verify_successful_completion {
    my $self = shift;

    # TODO: re-enable with checks for Dave Larson's new metrics;
    return 1;

    my $model = $self->model; 

    my $snp_output_file             = $self->snp_output_file;
    my $snp_output_file_count       = _wc($snp_output_file);
    
    my $errors = 0;   
 
    my @ck = map { $self->$_ } qw/variation_metrics_file/;
    for my $ck (@ck) {
        unless (-e $ck) {
            $self->error_message("Failed to find $ck!");
            $errors++;
            next;
        }
        my $cnt = _wc($ck);
        unless ($cnt == $snp_output_file_count) {
            $self->error_message("File $ck has size $cnt "
                    . "while the SNP file $snp_output_file has size $snp_output_file_count!");
            $errors++;
        }
    }
    
    return !$errors;
}


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

sub generate_variation_metrics_files_v2 {
    # This generates additional bleeding-edge data.
    # It runs directly out of David Larson's home for now until merged w/ the stuff above.
    # It will be removed when bugs are worked out in the regular metric generator.

    my $self                 = shift;
    my $map_file = shift;
    my $model_comparison_id = shift;
    my $output_basename;
    if($map_file) {
        $output_basename     = $self->variation_metrics_file_for_model($model_comparison_id);
    }
    else {
        $map_file            = $self->resolve_accumulated_alignments_filename(ref_seq_id => $self->ref_seq_id); 
        $output_basename     = $self->variation_metrics_file;
    }
    my $snp_file            = $self->snp_output_file; 
    my $model = $self->model;
    #I hack this hack hackily.  If you wonder why this is here, ask brian and dave for
    #some long/boring explanation
    my $ref_seq             = $self->ref_seq_id;
    my $bfa_file = sprintf("%s/all_sequences.bfa", $model->reference_sequence_path);

    my @f = ($map_file,$bfa_file,$snp_file);
    my $errors = 0;
    for my $f (@f) {
        if ($self->check_for_existence($f)) {
            #$self->status_message("Found file $f");
        }
        else {
            $self->error_message("Failed to find file $f");
            $errors++;
        }
    }
    return if $errors;

    #my $cmd = "perl /gscuser/dlarson/pipeline_mapstat/snp_stats2.pl --mapfile $map_file --ref-bfa $bfa_file --basename '${output_basename}' --locfile $snp_file --minq 1 --chr=$ref_seq";
    #$self->status_message("Running: $cmd");
    #my $result = system($cmd);
    #$result /= 256;
    
    #if ($result) {
        #    $self->error_message("Got exit code $result!: $?");
        # return;
#    }
#    else {
#        $self->status_message("Metrics generation complete.");
#        return 1;
#    }

     my $rv = Genome::Model::Tools::Maq::CreateExperimentalMetricsFile->execute(
         map_file=>$map_file,
         location_file=>$snp_file,
         ref_bfa_file => $bfa_file,
         output_file => $output_basename,
         snpfilter_file => "$snp_file.filtered",
         ref_name => $self->ref_seq_id,
     );
     unless($rv) {
         $self->error_message("CreateExperimentalMetricsFile tool did not return successful");
         return;
     } 
}

# Converts between the 1-letter genotype code into
# its allele constituients
sub _lookup_iub_code {
    my($self,$code) = @_;

    $self->{'_iub_code_table'} ||= {
             A => ['A', 'A'],
             C => ['C', 'C'],
             G => ['G', 'G'],
             T => ['T', 'T'],
             M => ['A', 'C'],
             K => ['G', 'T'],
             Y => ['C', 'T'],
             R => ['A', 'G'],
             W => ['A', 'T'],
             S => ['G', 'C'],
             D => ['A', 'G', 'T'],
             B => ['C', 'G', 'T'],
             H => ['A', 'C', 'T'],
             V => ['A', 'C', 'G'],
             N => ['A', 'C', 'G', 'T'],
          };
    return @{$self->{'_iub_code_table'}->{$code}};
}


#- LOG FILES -#
sub snp_out_log_file {
    my $self = shift;

    return sprintf
    (
        '%s/%s.out', #'%s/%s_snp.out',
        $self->resolve_log_directory,
        ($self->lsf_job_id || $self->ref_seq_id),
    );
}

sub snp_err_log_file {
    my $self = shift;

    return sprintf
    (
        '%s/%s.err', #'%s/%s_snp.err',
        $self->resolve_log_directory,
        ($self->lsf_job_id || $self->ref_seq_id),
    );
}

sub skin_sample_map_file {
    my $self= shift;
    my $model = $self->model;
    my $model_name = $model->name;
    my $skin_name = $model_name;

    $skin_name =~ s/98tumor/34skin/g;
    my $skin_model = Genome::Model->get('name like' => $skin_name);
    unless ($skin_model) {
        $self->error_message(sprintf("tumor model matching name %s does not exist.  please verify this first.", $skin_name));
        return undef;
    }
    my $skin_map=$self->resolve_accumulated_alignments_filename(ref_seq_id => $self->ref_seq_id);
    return $skin_map, $model->id;
}

sub _wc {
    my $name = shift;
    my $fh = IO::File->new($name);
    my $cnt = 0;
    while (<$fh>) { $cnt++ }
    return $cnt;
}

#### disabled ####

sub generate_variation_metrics_files {
    my $self = shift;

    my %p = @_;
    my $test_extension = $p{test_extension} || '';

    my $model = $self->model;
    my $ref_seq_id = $self->ref_seq_id;

    my $snpfile = $self->snp_output_file;
    my $variation_metrics_file = $self->variation_metrics_file.$test_extension;

    my $parallel_units;
    if ($ref_seq_id == 1 or $ref_seq_id == 8 or $ref_seq_id == 10) {
        $parallel_units = 1;
    }
    elsif ($ref_seq_id < 10) {
        $parallel_units = 1;
    }
    else {
        $parallel_units = 1;
    }

    my @libraries = $model->libraries;

    #TODO: let the filtering module indicate whether it requires per-library metrics.
    my @check_libraries;
    if ($model->filter_ruleset_name eq 'dtr3e' or $model->filter_ruleset_name eq 'dtr2a') {
        @check_libraries = (@libraries,'');
        $self->status_message("\n*** Generating per-library metric breakdown of $variation_metrics_file");
        $self->status_message(join("\n",map { "'$_'" } @libraries));
    }
    else {
        @check_libraries = ('');
    }

    foreach my $library_name (@check_libraries) {
        my $variation_metrics_file = $self->variation_metrics_file;

        my $chromosome_alignment_file;
        if ($library_name) {
            $variation_metrics_file .= '.' . $library_name.$test_extension;
            $self->status_message("\n...generating per-library metrics for $variation_metrics_file");
        }
        else {
            $variation_metrics_file .= $test_extension;
            $self->status_message("\n*** Generating cross-library metrics for $variation_metrics_file");
        }    
    
        my $tries = 0;
        for (1) {
            if ($library_name) {
                $chromosome_alignment_file = $self->resolve_accumulated_alignments_filename(
                    ref_seq_id => $self->ref_seq_id,
                    library_name => $library_name,
                );
            }
            else {
                $chromosome_alignment_file = $self->resolve_accumulated_alignments_filename(
                    ref_seq_id => $self->ref_seq_id,
                );
            }    
            
            unless (
                $chromosome_alignment_file 
                and -e $chromosome_alignment_file 
                and (-p $chromosome_alignment_file or -s $chromosome_alignment_file)
            ) {
                $self->error_message(
                    "Failed to create an accumulated alignments file for"
                    . ($library_name ? " library_name '$library_name' " : '')
                    . " ref_seq_id " . $self->ref_seq_id    
                    . " to generate metrics file $variation_metrics_file"
                );
                if ($tries > 3) {
                    return;
                }
                else {
                    redo;
                }
            }
        }
        
        my $result =
            Genome::Model::Tools::Maq::GenerateVariationMetrics->execute(
                input => $chromosome_alignment_file,
                snpfile => $snpfile,
                qual_cutoff => 1,
                output => $variation_metrics_file,
                parallel_units => $parallel_units,
            );

        unless ($result) {
            $self->error_message("Failed to generate cross-library metrics for $variation_metrics_file");
            return;
        }

        unless (-s ($variation_metrics_file)) {
            $self->error_message("Metrics file not found for library $variation_metrics_file!");
            return;
        }
    }

    return 1;
}



1;

