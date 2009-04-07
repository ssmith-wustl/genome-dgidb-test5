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
    "generate standard reports"
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
    
    my $ts = time();
    my $build_id = $self->build_id;
    my $model = $self->model;
    
    my $id = $model->genome_model_id;
    
    #my $log_dir = $self->resolve_log_directory;
    #print ("Log dir: ".$log_dir);
    
    my $report_dir = $self->build->maq_snp_related_metric_directory;
 
 
    $self->status_message('Report dir: '.$report_dir);

    ###############################################
    # TODO: get the rest of them to fit here, 
    # then put the list in the processing profile,
    # then allow it to be extended arbitrarily with model hang-offs.
    my $failures = 0;
    for my $report_type (qw/
        DbSnpConcordance 
        GoldSnpConcordance
    /) {
        my $report_class = 'Genome::Model::ReferenceAlignment::Report::' . $report_type;
        my $report_name = 'unknown';
        eval {
            
            $self->status_message("Starting $report_type report.");
            
            my $report_def = $report_class->create(build_id =>$build_id);
            unless ($report_def) {
                $self->error_message("Error creating report $report_class!: " . $report_class->error_message());
                $failures++;
                next;
            }
            $report_name = $report_def->name;
            $self->status_message("Defined report with name $report_name");
            
            my $report = $report_def->generate_report;
            unless ($report) {
                $self->error_message("Error generating $report_name ($report_class)!: " . $report_class->error_message());
                $failures++;
                $report_def->delete;
                next;
            }
            
            unless ($self->build->add_report($report)) {
                $self->error_message('Error saving dbSnp Concordance report!: ' . $self->build->error_message);
            }
            $self->status_message('Saved dbSnp Concordance report.');
        };
        if ($@) {
            $self->error_message("Error generationg report named '$report_name' (class: $report_class):\n$@");
            $failures++;
            next;
        }
    }

    my $accumulated_alignments_file;

    ###############################################
    $self->status_message('Starting MapCheck report.');
    my $MapCheck_report_name = 'RefSeqMaq';
    #model id for previous test:  2733662090
    my $MapCheck_report = Genome::Model::ReferenceAlignment::Report::RefSeqMaq->create(
                                                                                       build_id => $build_id,
                                                                                       name => $MapCheck_report_name,
                                                                                       version => $self->model->read_aligner_version
                                                                                   );
    #my $MapCheck_report = Genome::Model::Report::RefSeqMaq->create(build_id =>$build_id, name=>$MapCheck_report_name, version=>$self->model->read_aligner_version);
    $accumulated_alignments_file = $self->accumulate_maps();
    unless ($accumulated_alignments_file) {
        $self->error_message('Failed to get accumulated maps file');
        return;
    }
    $self->status_message('The accumulated alignments file is: '.$accumulated_alignments_file);
    $MapCheck_report->accumulated_alignments_file($accumulated_alignments_file);
    #$MapCheck_report->generate_report_detail();
    $self->build->add_report( $MapCheck_report->generate_report );
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
    
    
    #Indelpe##############################################
    #cd /gscmnt/sata810/info/medseq/GBM_71_maps/
    #maq indelpe /gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.bfa bigmap.map > normal.indelpe
    $self->status_message('Starting Indelpe report.');
    my $aligner_path = $self->aligner_path('read_aligner_version'); 
    my $ref_seq = $model->reference_sequence_path."/all_sequences.bfa"; 
    my $indelpe_output_path = "$report_dir/indelpe_report_$id"."_$ts.out";

    $accumulated_alignments_file = $self->accumulate_maps();

    unless ($accumulated_alignments_file) {
        $self->error_message('Failed to get accumulated map file');
        return;
    }

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
    

    ##############################################
    #Report Summary
    
    $self->status_message('Starting report summary.');
    my $r = Genome::Model::ReferenceAlignment::Report::Summary->create( build_id => $self->build_id );

    my @templates = $r->report_templates;
    $self->status_message("Using report templates: ".join(",",@templates));  

    my $generated_report = $r->generate_report;

    my $result = $generated_report->save($self->build->resolve_reports_directory);

    $self->status_message("Save result return value: $result. Saved report: ".$generated_report->name. " to ". $self->build->resolve_reports_directory);
 
    $self->status_message('Report summary complete.');

    ################################################### 
    $self->status_message('Sending summary e-mail.');
    my $summary_report_dir_name = $r->name;
    $summary_report_dir_name =~ s/ /_/g;
    my $summary_report_path = $self->build->resolve_reports_directory."/".$summary_report_dir_name."/report.txt";
    $self->status_message("Sending the file: $summary_report_path");
    my $mail_cmd = 'mail -s "Summary Report for Build '.$self->build->build_id.'" jeldred@genome.wustl.edu,jpeck@genome.wustl.edu,ssmith@genome.wustl.edu < '.$summary_report_path;
    $self->status_message("E-mail command: $mail_cmd");
    my $mail_rv = system($mail_cmd);
    $self->status_message("E-mail command executed.  Return value: $mail_rv");

   
    ############################################### 
    #PFAM Reports
    #$self->status_message("Starting Pfam report for build id: $build_id");
    #my $p = Genome::Model::ReferenceAlignment::Report::Pfam->create(
    #                                     build_id     => $build_id,
    #                                      name         => 'Pfam',
    #                                    );
    #$p->generate_report_detail(report_detail => "full_report_test.csv");
    #$self->status_message('Completed Pfam report.');
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

sub verify_successful_completion {

    my $self = shift;

    my $return_value = 1;
    my $build = $self->build;

    if ( defined($build) ) {
            my $report_dir = $self->build->resolve_reports_directory;
            $self->status_message('Report dir: '.$report_dir);
            my @report_dirs = glob($report_dir."/*");
            $self->status_message('Contents of report dir: '.join(",",@report_dirs) );
	    my $dir_count = 0;
	    for my $each_dir (@report_dirs) {
		if (-d $each_dir) {
			$dir_count = $dir_count + 1;
 	        }	
	    }

$DB::single = 1;            
 	    unless ( $dir_count == 4 ) {
                $self->error_message("Can't verify successful completeion of RunReports step.  Expecting 4 report directories.  Got: $dir_count");
                return 0;
            }
 
    } else {
        $self->error_message("Can't verify successful completion of RunReports step. Build is undefined.");
        return 0;
    }

    return $return_value;

}

1;

#$HeadURL$
#$Id$
