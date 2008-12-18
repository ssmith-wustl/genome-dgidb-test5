package Genome::Model::Report::GoldSnp;

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


class Genome::Model::Report::GoldSnp{
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
    my $reports_dir= $basedir . "GoldSnp/";
    unless(-d $reports_dir) {
        unless(mkdir $reports_dir) {
            $self->error_message("Directory $reports_dir doesn't exist, can't create");
            return;
        }
        chmod 02775, $reports_dir;
    }

   `touch $reports_dir/generation_class.GoldSnp`;
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

    my $desc = "Gold Snp coverage for " . $model->name . " as of " . UR::Time->now;
    $brief->print("<div>$desc</div>");
    $brief->close;
}

sub generate_report_detail 
{
   my $self = shift;
   my $model = $self->model;
   my $gold_snp_path = $model->gold_snp_path;
   my $snp_file = $self->snp_file;  
   #my $snp_file  = "/gscmnt/sata146/info/medseq/dlarson/GBM_Genome_Model/tumor/2733662090.snps";

   my $r = new CGI;
   my $cmd = "gt snp gold-snp-intersection " .
             "--gold-snp-file $gold_snp_path " .
             "--snp-file $snp_file";
   my $gold_rpt = `$cmd`; 
   my $output_file = $self->report_detail_output_filename;   
    
    my $body = IO::File->new(">$output_file");  
    die unless $body;
        $body->print( $r->start_html(-title=> 'Gold Snp for ' . $model->genome_model_id ,));
        $gold_rpt = $self->format_report($gold_rpt);
        $body->print("$gold_rpt");
        $body->print( $r->end_html );
    $body->close;
}

sub format_report
{
    #assumes plain-text
    #convert newlines to divs, and tabs to padded spans
    my ($self, $content) = @_;
    my $model = $self->model;
    my $result = "\n<!--\n$content\n-->\n";    
    if ($content=~m/(\s*)(.*)(\s*)/sm)
    {
        $content = $2;
        my $span = "<span style=\"padding-left:10px;\">";

        $content=~s/\n/<\/div>\n<div>/g;
        $content=~s/(<div>)(\t)(.*)(<\/div>)/$1\n$span$3<\/span>\n$4/g;
        $content=~s/\t/<\/span>$span/g;
        $content=~s/(.*<\/div>\s*)(<div>\s*There were .+)/$1<\/p>\n<hr align=\"left\">\n<p>$2/g;
        $content = "<h1>Gold Concordance for " . $model->genome_model_id . "</h1>\n\n" .
                   "<p><div>$content</div><p>" .
                   $self->get_css;
        return $content;
    }
}

sub get_css
{
    return 
"<style>
    p {font-size:16px;background-color:tan;}
    span {font-size:.9em}
    hr {width:30%;} 
</style>";

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
