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

sub make_fabulous {
    my $self=shift;    
    my $infile = $self->report_detail_output_filename;
    my $fh = IO::File->new($infile);
    my $begin_data_string = "</h3><pre>";

    my @x_axis;
    my @dataset1;
    my @dataset2;
    my @current_data;
    my $string_of_data;
    my $line;
    my $header;
    my $footer;

# Get the header
while ($line = $fh->getline) {
    if ($line =~ /$begin_data_string/) {
        my $end_of_header;
        ($end_of_header) = ($line =~ /(.*$begin_data_string)/);
        $header .= $end_of_header; 
        last;
    } else {
        $header .= $line;
    }
}

($string_of_data) = ($line =~ /$begin_data_string(.*$)/);

@current_data = split("\t", $string_of_data);
push(@x_axis, $current_data[0]);
push(@dataset1, $current_data[1]);
push(@dataset2, $current_data[2]);

# Get the body
while (my $line = $fh->getline) {
    if ($line =~ /^There/i) {
        $footer .= $line;
        last;
    }

    @current_data = split("\t", $line);
    push(@x_axis, $current_data[0]);
    push(@dataset1, $current_data[1]);
    push(@dataset2, $current_data[2]);
}

# Reverse the arrays since flot is printing this stuff backwards from what we would expect
@x_axis = reverse(@x_axis);
@dataset1 = reverse(@dataset1);
@dataset2 = reverse(@dataset2);

# Get the footer
while (my $line = $fh->getline) {
    $footer .= $line;
}

my $db_snp_data = build_coordinate_string(\@x_axis, \@dataset1);
my $all_snp_data = build_coordinate_string(\@x_axis, \@dataset2);

my $db_snp_string = "{ label: \"db snp\", data: $db_snp_data }";
my $total_snp_string = "{ label: \"all snps\", data: $all_snp_data }";

my $graph_data_string = "[ $db_snp_string, $total_snp_string ]";

my $javascript_block=qq|
<script language="javascript" type="text/javascript" src="http://people.iola.dk/olau/flot/jquery.js"></script>
<script language="javascript" type="text/javascript" src="http://people.iola.dk/olau/flot/jquery.flot.js"></script>
<script id="source" language="javascript" type="text/javascript">
\$(function () {
    var options = {
        legend: { show: true, position: "nw"},
        lines: { show: true },
        points: { show: true },
        xaxis: { ticks: 10 },
    };

    \$.plot(\$("#placeholder"), $graph_data_string, options);
});
</script> 
|;

$header .= '<div id="placeholder" style="width:900px;height:450px;"></div>';
my $output = $header. $javascript_block . $footer;
$fh->close;
($infile =~ s/.html/_fabulous.html/);

my $new_report_fh = IO::File->new(">$infile");

print $new_report_fh $output;
$new_report_fh->close;
}

sub build_coordinate_string {
    my $x_axis_ref = shift;
    my $data_set_ref = shift;

    my $formatted_return="[ ";
    
    for my $x_point (@{$x_axis_ref}) {
        $formatted_return .= "[ $x_point , " . $data_set_ref->[$x_point] . "], ";
    }

    $formatted_return .= "] ";
    return $formatted_return;
}



1;
