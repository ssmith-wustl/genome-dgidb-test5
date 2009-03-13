package Genome::Model::Command::Build::ReferenceAlignment::RunReports;

use strict;
use warnings;

use above "Genome";

use Genome;
#use Data::Dumper;
#use Genome::Model::Command::Report::VariationsBatchToLsf;
#use Genome::Model::EventWithRefSeq;
#use Genome::Utility::Parser;
use IO::File;

class Genome::Model::Command::Build::ReferenceAlignment::RunReports {
    is => [ 'Genome::Model::EventWithRefSeq' ],
    #is => [ 'Genome::Model::Event' ],
    has => [
    ],
};

#########################################################

#sub sub_command_sort_position { 90 } # TODO needed?

# TODO Add doc
sub help_brief {
    "Automates report generation."
}

sub help_synopsis {
    return;
}

sub help_detail {
    return <<"EOS"
Generates GoldSnp report, etc
EOS
}

#sub bsub_rusage { return "-R 'span[hosts=1]'"; } 

#- EXECUTE -#
sub execute {
    my $self = shift;
    
    my $model = $self->model;
    my $id = $model->genome_model_id;  
    #my $log_dir = $self->resolve_log_directory;
    #print ("Log dir: ".$log_dir);
    
    my $report_dir = $self->build->maq_snp_related_metric_directory;
 
    $self->status_message('Report dir: '.$report_dir);

    my $ts = time();
    my $accumulated_alignments_file;

    my $build_id = $self->build_id;
  
    ###############################################
    $self->status_message('Starting MapCheck report.');
    my $MapCheck_report_name = 'Ref Seq Maq';
    #model id for previous test:  2733662090
    my $MapCheck_report = Genome::Model::ReferenceAlignment::Report::RefSeqMaq->create(build_id =>$build_id, name=>$MapCheck_report_name, version=>$self->model->read_aligner_name);
    #my $MapCheck_report = Genome::Model::Report::RefSeqMaq->create(build_id =>$build_id, name=>$MapCheck_report_name, version=>$self->model->read_aligner_name);
    $accumulated_alignments_file = $self->accumulate_maps(); 
    $self->status_message('The accumulated alignments file is: '.$accumulated_alignments_file);
    $MapCheck_report->accumulated_alignments_file($accumulated_alignments_file);
    #$MapCheck_report->generate_report_detail();
    $MapCheck_report->generate_data();
    $MapCheck_report->save();
    $self->status_message('Finished MapCheck report.');
  
    ###############################################
    #cleaning up accumulated file
    my $rm_cmd = "rm $accumulated_alignments_file";
    $self->status_message("Removing accumlated file with command: $rm_cmd");
    my $rv = `$rm_cmd`;
    $self->status_message("Result of remove: $rv");
   
    ###############################################
    ###Generate the big snp file

    my @snp_list = $self->build->_variant_list_files;
    my $file_list = join(" ", @snp_list);
    $self->status_message("Variant list files: $file_list");
    my $snp_file = "$report_dir/snpfile_$id"."_$ts.snp";
    my $snp_file_cmd = "cat $file_list > $snp_file";
    $self->status_message('Snp file concatenation command: '.$snp_file_cmd);
    my $snp_file_result = `$snp_file_cmd`;
   
    #Note:  maq_snp_related_metric_directory in Solex.pm
     
    ###SNP Filter############################################
    $self->status_message('Starting SNP Filter report.');
    
    #maq.pl SNPfilter [snpfile] > [outputfile]
    my $snp_filter_path = "$report_dir/snpfilter_report_$id"."_$ts.out";
    $self->status_message('Dumping SNPfilter output to: '.$snp_filter_path);
    my $snp_filter_cmd = "maq.pl SNPfilter $snp_file > $snp_filter_path";
    $self->status_message("SNPfilter command: $snp_filter_cmd");
    my $snp_filter_result = `$snp_filter_cmd`;
    $self->status_message('Completed SNP Filter report.');
    
    ###############################################
    $self->status_message('Starting GoldSnp report.');
    my $name = 'Gold Snp';
    $DB::single=1; 
    
    #my $report = Genome::Model::Report::GoldSnp->create(build_id =>$build_id, name=>$name);
    my $report = Genome::Model::ReferenceAlignment::Report::GoldSnp->create(build_id =>$build_id, name=>$name);

    #$self->status_message("GoldSnp temp file is: ".$tmp_file_path);

    #$tmp_file_handle->print($snp_file);
    #$tmp_file_handle->close(); 

    $report->snp_file($snp_file); 
    #$report->generate_report_detail;
    $report->generate_data;
    $report->save;
    $self->status_message('Finished GoldSnp report. '); 
    #Indelpe##############################################
    
    #cd /gscmnt/sata810/info/medseq/GBM_71_maps/
    #maq indelpe /gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.bfa bigmap.map > normal.indelpe

    $self->status_message('Starting Indelpe report.');
    my $aligner_path = $self->aligner_path('read_aligner_name'); 
    my $ref_seq = $model->reference_sequence_path."/all_sequences.bfa"; 
    my $indelpe_output_path = "$report_dir/indelpe_report_$id"."_$ts.out";
    $accumulated_alignments_file = $self->accumulate_maps(); 
    $self->status_message('The accumulated alignments file is: '.$accumulated_alignments_file);
    my $indelpe_cmd = "$aligner_path indelpe $ref_seq $accumulated_alignments_file > $indelpe_output_path";
    $self->status_message('Indelpe report command: '.$indelpe_cmd);
    my $indelpe_result = `$indelpe_cmd`;
    $self->status_message('Completed Indelpe report.');
   
    ###############################################
    $rm_cmd = "rm $accumulated_alignments_file";
    $self->status_message("Removing accumlated file with command: $rm_cmd");
    $rv = `$rm_cmd`;
    $self->status_message("Result of remove: $rv");
    ###############################################
    $self->status_message('Starting DbSnp report.');
    my ($tmp_file_handle, $tmp_file_path) = File::Temp::tempfile( DIR => "/tmp");
    $self->status_message("DbSnp temp file is: ".$tmp_file_path);
    
    my $DbSnp_report_name = 'Db Snp';
    #my $DbSnp_report = Genome::Model::Report::DbSnp->create(build_id =>$build_id, name=>$DbSnp_report_name);
    my $DbSnp_report = Genome::Model::ReferenceAlignment::Report::DbSnp->create(build_id =>$build_id, name=>$DbSnp_report_name);

    $self->status_message("DbSnp model id: ".$DbSnp_report->model->id );
    #$self->status_message("DbSnp build id: ".$DbSnp_report->build->id );
    
    #$DbSnp_report->override_model_snp_file($tmp_file_path);
    $DbSnp_report->override_model_snp_file($snp_file);
    #$DbSnp_report->generate_report_detail;
    $DbSnp_report->generate_data;
    $DbSnp_report->save;
    $self->status_message('Finished DbSnp report.');
   
    ############################################### 
        my $success = 1;
 
    if ( $success )
    { 
        $self->event_status("Succeeded");
    }
    else 
    {
        $self->event_status("Failed");
    }

    $self->date_completed( UR::Time->now );

    return $success;
}

1;

#$HeadURL$
#$Id$
