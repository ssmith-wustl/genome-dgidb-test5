package Genome::Model::ReferenceAlignment::Report::DbSnpConcordance;

use strict;
use warnings;

use Genome;

use App::Report;
use CGI;
use IO::String;
use Data::Dumper;

class Genome::Model::ReferenceAlignment::Report::DbSnpConcordance {
    is => 'Genome::Model::Report',
    has => [
        # inputs come from the build
        variant_list_files          => { via => 'build', to => '_variant_list_files' },
        variant_filtered_list_files => { via => 'build', to => '_variant_filtered_list_files' },
        db_snp_file                 => { via => 'build' },
        
        name                        => { default_value => 'dbSNP Concordance' },
        
        test => {
            is => 'Boolean',
            default_value => 0,
            doc => "Saves copies of the generated data in the pwd if they do not exist.  Re-uses them on the next run(s)."
        },
        override_variant_file => {
            type => 'Text',
            is_optional => 1,
            doc => "for testing, use this snp file instead of the real file for the model/build",
        },
        override_db_snp_file => {
            type => 'Text',
            is_optional => 1,
            doc => "Use this db snp file instead of generating a new one.",
        },
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
    my $build = $self->build;
    return "<div>Db Snp coverage for " . $self->model->name . " (build " . $self->build_id . ") as of " . UR::Time->now.'</div>';
}

sub generate_report_detail 
{
    my $self = shift;

    my $build = $self->build;
    my $build_id = $build->id;
    my $model = $build->model;
    
    my $module_path = $INC{"Genome/Model/ReferenceAlignment/Report/DbSnpConcordance.pm"};
    die 'failed to find module path!' unless $module_path;

    my @cqr_unfiltered;
    my @cqr_filtered;

    my $cqr_unfiltered_summary;
    my $cqr_filtered_summary;
    
	my $concordance_report;

    for my $list (qw/variant_list_files variant_filtered_list_files/) {
        my $snp_file;
        if  (defined $self->override_variant_file) {
            # override SNP list for testing
            # this will be used for both passes through the loop if testing.. 
            $snp_file =  $self->override_variant_file
        }  
        else {
            # get the SNV lists from the build and put them together
            $snp_file = $self->create_temp_file_path($list);
            my @files = $self->$list;
            #my $file_list = join(" ", @files);
            #my $cat_cmd = "cat $file_list > $snp_file";
            #switching this back for the time being... 
            #my $cat_rv = Genome::Utility::FileSystem->shellcmd( cmd=>$cat_cmd, input_files=>\@files, output_files=>[$snp_file] ); 
            #unless ($cat_rv) {
            #	die "Cat'ing snp files failed. Return value: $cat_rv";
            # } 
            Genome::Utility::FileSystem->shellcmd(
                cmd => "cat @files > $snp_file",
            );
            # TODO: verify counts!
        }
        
        unless ($snp_file) {
            die "Failed to generate or assign combined snp file!";
        }
        
        unless (-e $snp_file) {
            die "SNP file $snp_file does not exist!";
        }
        
        # TODO: this should come from the latest build of the dbSNP imported variations model
        my $db_snp_file;
        my $db_snp_path;
        
        if (defined $self->override_db_snp_file) {
            $db_snp_file = $self->override_model_db_snp_file;
            #print("\nUsing provided db snp file: $db_snp_file\n");
            $db_snp_path = $db_snp_file;
        }
        else {
            $db_snp_path = $self->build->resolve_reports_directory() ."/". $model->genome_model_id. "$list.dbsnp";
            
            # TODO: make this called from _inside_ the DbSnpConcordance checker and throw it away afterwards
            if ($self->test and -e $db_snp_path) {
                $self->status_message("Re-using existing dbSNP intersection file because the testing flag is set, and it already exists:  $db_snp_path");
            }
            else {
                if (-e $db_snp_path) {           
                    $self->status_message("Found existing dbSNP intersection file.  Deleting... $db_snp_path");
                    unlink $db_snp_path;
                    if (-e $db_snp_path) {
                        die "Failed to remove previous dbsnp file!: $!";
                    }
                }

                $self->status_message("Generating dbSNP intersection for concordance checking...");
                unless (
                    Genome::Model::Tools::Snp::CreateDbsnpFileFromSnpFile->execute(
                        output_file     => $db_snp_path,
                        snp_file        => $snp_file
                    ) 
                ) {
                    die "Could not execute create-db-snp-file-from-snp-file.";
                }

                unless (-e $db_snp_path) {
                    die "No dbSNP output file found!";
                    return;
                }
            }
        }
        
        if ($self->test and -e "./concordance-$list") {
            $concordance_report = `cat ./concordance-$list`;
        }
        else {
            my $cc_output = $self->create_temp_file_path();
            $self->status_message("Output file for DbSnpConcordance: ".$cc_output.",".-s $cc_output);
            $self->status_message("snp_file for DbSnpConcordance: ".$snp_file.",".-s $snp_file);
            $self->status_message("dbsnp_file for DbSnpConcordance: ".$db_snp_path.",".-s $db_snp_path);
            unless (
                Genome::Model::Tools::Snp::DbSnpConcordance->execute(
                    output_file     =>$cc_output,
                    snp_file        =>$snp_file,
                    dbsnp_file      =>$db_snp_path
                ) 
            ) {
                die "Could not execute db-snp-concordance.";
            }
            $self->status_message("output result: ".-s $cc_output);
            #TODO this cat should be done differently.   
            $concordance_report = `cat $cc_output`; 
            $self->status_message("concordance report: ".$concordance_report);
            # $concordance_report = `$concordance_cmd`;
            if ($self->test) {
                IO::File->new(">./concordance-$list")->print($concordance_report);
            }
        }
        
        unless ($concordance_report) {
            die "Error generating concordance report!"
        }
        
        my $concordance_quality_report;
        if ($self->test and -e "./concordance-quality-$list") {
            $self->status_message("Re-using previous conconcordance quality data for testing...");
            $concordance_quality_report = `cat ./concordance-quality-$list`;
        }
        else { 
            my $cq_output = $self->create_temp_file_path();
            $self->status_message("Generating dbSNP concordance...");
            unless (
                Genome::Model::Tools::Snp::DbSnpConcordance->execute(
                    report_by_quality   =>1,
                    output_file         =>$cq_output,
                    snp_file            =>$snp_file,
                    dbsnp_file          =>$db_snp_path
                ) 
            ) {
                die "Could not execute DbSnpConcordance.";
            }

            #$concordance_quality_report = `$concordance_quality_cmd`;
            #TODO find a better way than cat...
            $concordance_quality_report = `cat $cq_output`;
            if ($self->test) {
                $self->status_message("Saving dbSNP concordance data for subsequent tests...");
                IO::File->new(">./concordance-quality-$list")->print($concordance_quality_report);
            }
        }
        
        unless ($concordance_quality_report) {
            die "Error generating concordance quality report!";
        }
        
        $DB::single = 1;
        
        my @concordance_quality_report = split(/\n/,$concordance_quality_report);
        pop @concordance_quality_report;
        pop @concordance_quality_report;
                
        if ($list eq 'variant_list_files') {
            @cqr_unfiltered = @concordance_quality_report;
            $cqr_unfiltered_summary = $concordance_report;            
        }
        elsif ($list eq 'variant_filtered_list_files') {
            @cqr_filtered = @concordance_quality_report;
            $cqr_filtered_summary = $concordance_report;            
        }
        else {
            die "unknown SNV list $list!.  Cannot properly assign graph data strings!";
        }
    }

    # let's make sure that the reports made it out of the loop:
    $DB::single = 1;

    #
    # BUILD HTML REPORT
    #

    my $body = IO::String->new();
    die unless $body;
    my $r = new CGI;

    # load page resources
    
    my $css_file = "$module_path.html.css";
    my $css_fh = IO::File->new($css_file);
    unless ($css_fh) {
        die "failed to open file $css_file!"; 
    }
    my $css_content = join('',$css_fh->getlines);
    
    my $title =  'Db Snp for model ' . $model->id . ' ("' . $model->name . '")  build ' . $build_id . ')';
    
    $body->print($r->start_html(
        -title  => $title,
        -style  => { -code => $css_content },
        -script => [
            { -type => 'text/javascript', -src => 'https://gscweb.gsc.wustl.edu/report_resources/db_snp_concordance/js/jquery.js'},
            { -type => 'text/javascript', -src => 'https://gscweb.gsc.wustl.edu/report_resources/db_snp_concordance/js/jquery.flot.js'}
        ]
    ));
    
    # $body->print("<small><a href='../../reports/Summary/report.html'>full report</a></small>");
    $body->print('<div class="container">');
    $body->print('<div class="background">');


    my $header = "dbSNP Concordance for SNVs";

    $body->print("<h1 class=\"section_title\">$header</h1>");
    $body->print("<div class='content_padding'>");
    $body->print("<table width='100%' cellpadding='10' cellspacing='0'><tr><td width='50%'><h3>Unfiltered Concordance Summary:</h3><pre>$cqr_unfiltered_summary</pre></td><td width='50%'><h3>Filtered Concordance Summary:</h3><pre>$cqr_filtered_summary</pre></td></tr></table>");    
    $body->print("<p/>");

    $body->print("<h3>$header by Quality</h3>");

    #
    # BUILD GRAPH
    #

    ## TODO: Parse the data and create the graph data strings using a proper function
    ## instead of repeating the same process twice. - jmcmicha

    ## begin filtered graph data assembly
    my $filtered_lines = \@cqr_filtered;

    my @filtered_x_axis;
    my @filtered_dataset1;
    my @filtered_dataset2;
    my @filtered_current_data;

    # Get the body
    while (my $line = shift @$filtered_lines) {
        @filtered_current_data = split("\t", $line);
        push(@filtered_x_axis, $filtered_current_data[0]);
        push(@filtered_dataset1, $filtered_current_data[1]);
        push(@filtered_dataset2, $filtered_current_data[2]);
    }

    # Reverse the arrays since flot is printing this stuff backwards from what we would expect
    @filtered_x_axis = reverse(@filtered_x_axis);
    @filtered_dataset1 = reverse(@filtered_dataset1);
    @filtered_dataset2 = reverse(@filtered_dataset2);
    
    my $filtered_db_snp_data = build_coordinate_string(\@filtered_x_axis, \@filtered_dataset1);
    my $filtered_all_snp_data = build_coordinate_string(\@filtered_x_axis, \@filtered_dataset2);
    my $filtered_concordance_data = build_concordance_string(\@filtered_x_axis, \@filtered_dataset1, \@filtered_dataset2);
    ## end filtered graph data assembly

    ## yeah, this is a horrible kludge.
    
    ## begin unfiltered graph data assembly
    my $unfiltered_lines = \@cqr_unfiltered;

    my @unfiltered_x_axis;
    my @unfiltered_dataset1;
    my @unfiltered_dataset2;
    my @unfiltered_current_data;

    # Get the body
    while (my $line = shift @$unfiltered_lines) {
        @unfiltered_current_data = split("\t", $line);
        push(@unfiltered_x_axis, $unfiltered_current_data[0]);
        push(@unfiltered_dataset1, $unfiltered_current_data[1]);
        push(@unfiltered_dataset2, $unfiltered_current_data[2]);
    }

    # Reverse the arrays since flot is printing this stuff backwards from what we would expect
    @unfiltered_x_axis = reverse(@unfiltered_x_axis);
    @unfiltered_dataset1 = reverse(@unfiltered_dataset1);
    @unfiltered_dataset2 = reverse(@unfiltered_dataset2);
    
    my $unfiltered_db_snp_data = build_coordinate_string(\@unfiltered_x_axis, \@unfiltered_dataset1);
    my $unfiltered_all_snp_data = build_coordinate_string(\@unfiltered_x_axis, \@unfiltered_dataset2);
    my $unfiltered_concordance_data = build_concordance_string(\@unfiltered_x_axis, \@unfiltered_dataset1, \@unfiltered_dataset2);
    ## end unfiltered graph data assembly
    
    my $js_datasets = qq|
    var datasets = {
        "db SNP filtered": {
            label: "db SNP filtered",
            hoverable: true,
            clickable: true,
            shadowSize: 0,
            data: $filtered_db_snp_data
        },

        "all SNPs filtered": {
            label: "all SNPs filtered",
            hoverable: true,
            clickable: true,
            shadowSize: 0,
            data: $filtered_all_snp_data
        },

        "concordance filtered": {
            label: "filtered concordance",
            yaxis: 2,
            hoverable: true,
            clickable: true,
            shadowSize: 0,
            data: $filtered_concordance_data
        },
        "db SNP unfiltered": {
            label: "db SNP unfiltered",
            hoverable: true,
            clickable: true,
            shadowSize: 0,
            data: $unfiltered_db_snp_data
        },

        "all SNPs unfiltered": {
            label: "all SNPs unfiltered",
            hoverable: true,
            clickable: true,
            shadowSize: 0,
            data: $unfiltered_all_snp_data
        },

        "concordance unfiltered": {
            label: "unfiltered concordance",
            yaxis: 2,
            hoverable: true,
            clickable: true,
            shadowSize: 0,
            data: $unfiltered_concordance_data
        }

    };|;

    my $js_file = "$module_path.html.js";
    my $js_fh = IO::File->new($js_file);
    unless ($js_fh) {
        die "failed to open file $js_file!"; 
    }
    my $js_content = join('',$js_fh->getlines);
    
    $body->print("<script type='text/javascript'>//<![CDATA[\n\n");
    $body->print("\$(function() {");
    $body->print($js_datasets);
    $body->print($js_content);
    $body->print("});");
    $body->print("\n\n//]]></script>");
    
    my $flot_graph = qq|

<table width="100%" cellpadding="5" cellspacing="0">
  <tr>
   <td valign="middle"><img src="https://gscweb.gsc.wustl.edu/report_resources/db_snp_concordance/images/axis_label_v_SNPs.png" width="19" height="49"/></td>
   <td align="center" valign="middle"><div id="placeholder" class="graph_placeholder"/></td>
   <td valign="middle"><img src="https://gscweb.gsc.wustl.edu/report_resources/db_snp_concordance/images/axis_label_v_pct_Concordance.png" width="19" height="151"/></td>
  </tr>
  <tr>
   <td>&nbsp;</td>
   <td align="center"><img src="https://gscweb.gsc.wustl.edu/report_resources/db_snp_concordance/images/axis_label_h_Quality.png" width="67" height="23"/></td>
   <td>&nbsp;</td>
  </tr>
  <tr>
   <td colspan="3">
    <div id="plots"><p><strong>Show:</strong</p></div>
   </td>
  </tr>
</table>

        |;
        
    $body->print($flot_graph);
    $body->print("</div>"); #close content_padding div
    $body->print("</div>"); #close background div
    $body->print("</div>"); #close container div	
    $body->print( $r->end_html );
    $body->seek(0,0);
    
    my @lines = $body->getlines;
    my $text = join('',@lines);
    return $text;
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

sub build_coordinate_string {
    my $x_axis_ref = shift;
    my $data_set_ref = shift;
    
    my $formatted_return="[ ";
    
    for my $x_point (@{$x_axis_ref}) {
        my $v1 = $data_set_ref->[$x_point] || 0;
        $formatted_return .= "[ $x_point , " . $v1 . "], ";
    }
    
    $formatted_return .= "] ";
    return $formatted_return;
}
    
sub build_concordance_string {
    my $x_axis_ref = shift;
    my $data_set_ref1 = shift;
    my $data_set_ref2 = shift;
    
    my $formatted_return="[ ";
    
    for my $x_point (@{$x_axis_ref}) {
        my $v1 =  $data_set_ref1->[$x_point];
        my $v2 = $data_set_ref2->[$x_point];
        my $v3;
    
        if (!$v2) {
            $v3 = 0;
        } else {
            $v3 = $v1/$v2;
        }
    
        $formatted_return .= "[ $x_point , " . sprintf("%.2f", 100 * $v3) . "], ";
    }
    
    $formatted_return .= "] ";
    return $formatted_return;
}

1;
