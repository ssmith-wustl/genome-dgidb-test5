package Genome::Model::ReferenceAlignment::Report::DbSnp;

use strict;
use warnings;

use Genome;

use App::Report;
use CGI;
use IO::String;

class Genome::Model::ReferenceAlignment::Report::DbSnp {
    is => 'Genome::Model::Report',
    has => [
        override_model_snp_file => {
            type => 'Text',
            is_optional => 1,
            doc => "for testing, use this snp file instead of the real file for the model/build",
        },
        override_model_db_snp_file => {
            type => 'Text',
            is_optional => 1,
            doc => "Use this db snp file instead of generating a new one.",
        },
        override_build => {
            type => 'Text',
            is_optional => 1,
            doc => "Use this build instead of looking it up.",
        }
    ],
};

sub _generate_data {
    my $self = shift;

    return {
        description => $self->generate_report_brief,
        html => $self->generate_report_detail,
    };
}

sub generate_report_brief 
{
    my $self=shift;
    my $model = $self->model;
    my $build = $self->build;
    #my $output_file =  $self->report_brief_output_filename;
    
    #my $brief = IO::File->new(">$output_file");
    #die unless $brief;

    #my $desc = "Db Snp coverage for " . $model->name . " (build " . $build->id . ") as of " . UR::Time->now;
    #$brief->print("<div>$desc</div>");
    #$brief->close;

    return "<div>Db Snp coverage for " . $self->model->name . " (build " . $self->build_id . ") as of " . UR::Time->now.'</div>';
}

sub generate_report_detail 
{
    my $self = shift;
    my $model = $self->model;

    my $build = $self->build;
    #my $build;
    #$build = $model->current_running_build;

    #my $output_file = $self->report_detail_output_filename;  
    #print("Will write report to output file: $output_file"); 
   
    my $snp_file;
    my $db_snp_file;
    my $db_snp_path;

    my $cmd;

    my $r = new CGI;
    

    if  (defined $self->override_model_snp_file) {
   	$snp_file =  $self->override_model_snp_file;
    }  else { 
	$snp_file = $self->_generate_combined_snp_file;
    }  

    unless ($snp_file) {
	die "Failed to generate or assign combined snp file!";
    }

    unless (-e $snp_file) {
	die "SNP file $snp_file does not exist!";
    }

    if (defined $self->override_model_db_snp_file) {
        #if (defined $self->override_model_db_snp_file) {
  
        $db_snp_file = $self->override_model_db_snp_file;
	#print("\nUsing provided db snp file: $db_snp_file\n");
	$db_snp_path = $db_snp_file;
        $cmd = "No command executed.  Using provided db snp file: $db_snp_file";

    } else {
        $db_snp_path = $self->build->resolve_reports_directory() . $model->genome_model_id.'snps.dbsnp';  
        #$db_snp_path = $self->resolve_reports_directory() . $model->genome_model_id.'snps.dbsnp';  

   	$cmd = "gt snp create-dbsnp-file-from-snp-file " .
             "--output-file $db_snp_path " .
             "--snp-file $snp_file";
  	my $db_rpt = `$cmd`; 
   }
	 
   my $concordance_cmd = "gt snp db-snp-concordance ".
               "--dbsnp-file $db_snp_path ".
               "--snp-file $snp_file"; 

   #print("Generating concordance report using cmd: $concordance_cmd"); 
   my $concordance_report = `$concordance_cmd`;

   my $concordance_quality_cmd = "gt snp db-snp-concordance ".
             "--report-by-quality ".
             "--dbsnp-file $db_snp_path ".
             "--snp-file $snp_file"; 
   
   #print("Generating concordance quality report using cmd: $concordance_quality_cmd"); 
   my $concordance_quality_report = `$concordance_quality_cmd`;
 
  
   my $build_id;
   if (defined $build) {
	$build_id = $build->build_id; 
   } else {
        $build_id = 'UNKNOWN';
   }
 
   #my $body = IO::File->new(">$output_file");  
   my $body = IO::String->new();  
   die unless $body;
        $body->print( $r->start_html(-title=> 'Db Snp for ' . $model->genome_model_id . ' build(' . $build_id . ')'));
        $body->print("<h3>Concordance Report<h3>");
        $body->print("<p/>");
        $body->print("DbSnp create command:  ".$cmd);
        $body->print("<p/>");
        $body->print("DbSnp concordance command:  ".$concordance_cmd);
        $body->print("<p/>");
        $body->print("DbSnp concordance quality command:  ".$concordance_quality_cmd);
        $body->print("<p/>");
        $body->print("");
        $body->print("<pre>$concordance_report</pre>");
        $body->print("<h3>Concordance by Quality Report</h3>");
        $body->print("<pre>$concordance_quality_report</pre>");
        $body->print( $r->end_html );

        #$body->close;

    $body->seek(0,0);
    return join('', $body->getlines);

}

sub _generate_combined_snp_file
{
    # concatenate variant files from the build
    # this may go in the model/build eventually
    my $self = shift;
    my $build = $self->build;
    my @variant_list_files = $build->_variant_list_files;
    my $file_list = join(' ', (sort @variant_list_files));
    my ($fh,$fname) = File::Temp::tempfile(CLEANUP => 1);
    my $rv = system "cat $file_list > $fname";
    $rv/=256;
    if ($rv) {
        die "Failed to create temp file $fname from snp files: $!";
    }
    return $fname;
}

sub make_fabulous {
    # TODO - not used, but will not work cuz of outfile stuff
    my $self=shift;    
    my $infile = "graph_".$self->report_detail_output_filename;
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
($infile =~ s/.html/_graph.html/);

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
