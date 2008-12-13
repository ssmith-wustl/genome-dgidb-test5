package Genome::Model::Report::DbSnp;

use strict;
use warnings;

use Genome;
use CGI;
use English;
use Memoize;
use IO::File;
use Cwd;
use File::Basename qw/basename/;
use App::Report;


class Genome::Model::Report::DbSnp{
    is => 'Genome::Model::Report',
    has =>
    [
        snp_file => {
                        type => 'String',
                        doc => 'snp file to run',
                     }
    ],
};

sub resolve_reports_directory {
    my $self = shift;
    my $basedir = $self->SUPER::resolve_reports_directory();
    my $reports_dir= $basedir . "DbSnp/";
    unless(-d $reports_dir) {
        unless(mkdir $reports_dir) {
            $self->error_message("Directory $reports_dir doesn't exist, can't create");
            return;
        }
        chmod 02775, $reports_dir;
    }

   `touch $reports_dir/generation_class.DbSnp`;
   return $reports_dir;
}

sub report_brief_output_filename {
    my $self=shift;
    return $self->resolve_reports_directory . "/brief.html";
}

sub report_detail_output_filename {
    my $self=shift;
    return $self->resolve_reports_directory . "/detail.html";
}
sub generate_report_brief 
{
    my $self=shift;
    my $model = $self->model;
    my $output_file =  $self->report_brief_output_filename;
    
    my $brief = IO::File->new(">$output_file");
    die unless $brief;

    my $desc = "Db Snp coverage for " . $model->name . " as of " . UR::Time->now;
    $brief->print("<div>$desc</div>");
    $brief->close;
}

sub generate_report_detail 
{
   my $self = shift;
   my $model = $self->model;
   my $db_snp_path = $self->SUPER::resolve_reports_directory() . $model->genome_model_id.'snps.dbsnp';
   my $snp_file = $self->snp_file;
   #my $snp_file  = "/gscmnt/sata146/info/medseq/dlarson/GBM_Genome_Model/tumor/2733662090.snps";

   my $r = new CGI;
   my $cmd = "gt snp create-dbsnp-file-from-snp-file " .
             "--output-file $db_snp_path " .
             "--snp-file $snp_file";
   my $db_rpt = `$cmd`; 

   my $concordance_cmd = "gt snp db-snp-concordance ".
               "--dbsnp-file $db_snp_path ".
               "--snp-file $snp_file"; 
 
   my $concordance_report = `$concordance_cmd`;

   my $concordance_quality_cmd = "gt snp db-snp-concordance ".
             "--report-by-quality ".
             "--dbsnp-file $db_snp_path ".
             "--snp-file $snp_file"; 
   
   my $concordance_quality_report = `$concordance_quality_cmd`;
 
   my $output_file = $self->report_detail_output_filename;   
   
   my $body = IO::File->new(">$output_file");  
   die unless $body;
        $body->print( $r->start_html(-title=> 'Db Snp for ' . $model->genome_model_id ,));
        $body->print("<h3>Concordance Report</pre>");
        $body->print("<pre>$concordance_report</pre>");
        $body->print("<h3>Concordance by Quality Report</h3>");
        $body->print("<pre>$concordance_quality_report</pre>");
        $body->print( $r->end_html );

    $body->close;
}

sub get_snp_file
{
   #concatenate variant files 
    my $self = shift;
    my $model = $self->model;
    my $last_complete_build = $model->last_complete_build;
    my @variant_list_files = $last_complete_build->_variant_list_files;
    my $file_list = join(' ', (sort @variant_list_files));
    my $cat = `cat $file_list`;
    return $cat;
}

1;
