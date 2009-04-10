package Genome::Model::ReferenceAlignment::Report::DbSnpConcordance;

use strict;
use warnings;

use Genome;

use App::Report;
use CGI;
use IO::String;

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
    
    my $body = IO::String->new();
    die unless $body;
    my $r = new CGI;
    
    my $module_path = $INC{"Genome/Model/ReferenceAlignment/Report/DbSnpConcordance.pm"};
    die 'failed to find module path!' unless $module_path;
    
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
    
#    $body->print("<small><a href='../../reports/Summary/report.html'>full report</a></small>");
    $body->print('<div class="container">');
    $body->print('<div class="background">');

    for my $list (qw/variant_list_files variant_filtered_list_files/) {
        
        my $header;
        if ($list eq 'variant_list_files') {
            $header = 'dbSNP Concordance for Unfiltered SNVs';
        }
        elsif ($list eq 'variant_filtered_list_files') {
            $header = 'dbSNP Concordance for SNPfilter SNVs'
        }
        else {
            die "unknown SNV list $list!.  cannot resolve report header!";
        }
        
$DB::single = 1;            
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
            system "cat @files > $snp_file";
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
            
            $self->status_message("Generating dbSNP intersection for concordance checking...");
            
            unless ($self->test and -e $db_snp_path) {
                unless (Genome::Model::Tools::Snp::CreateDbsnpFileFromSnpFile->execute(output_file=>$db_snp_path,snp_file=>$snp_file) ) {
			die "Could not execute create-db-snp-file-from-snp-file.";		
		} 
            }
            
            unless (-e $db_snp_path) {
                die "No dbSNP output file found!";
                return;
            }
        }
        
        #my $concordance_cmd = 
        #    "gt snp db-snp-concordance ".
        #    "--dbsnp-file $db_snp_path ".
        #    "--snp-file $snp_file".
        #    "--output-file $cc_output"; 
        #print("Generating concordance report using cmd: $concordance_cmd");
        
        my $concordance_report;
        
        if ($self->test and -e "./concordance-$list") {
            $concordance_report = `cat ./concordance-$list`;
        }
        else {
            my $cc_output = $self->create_temp_file_path();
            $self->status_message("Output file for DbSnpConcordance: ".$cc_output.",".-s $cc_output);
            $self->status_message("snp_file for DbSnpConcordance: ".$snp_file.",".-s $snp_file);
            $self->status_message("dbsnp_file for DbSnpConcordance: ".$db_snp_path.",".-s $db_snp_path);
            unless (Genome::Model::Tools::Snp::DbSnpConcordance->execute(output_file=>$cc_output,snp_file=>$snp_file,dbsnp_file=>$db_snp_path) ) {
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
        $body->print("<h1 class=\"section_title\">$header</h1>");
		$body->print("<div class='content_padding'>");
        $body->print("<pre>$concordance_report</pre>");
        $body->print("<p/>");
        
        #my $concordance_quality_cmd = 
        #    "gt snp db-snp-concordance ".
        #    "--report-by-quality ".
        #    "--dbsnp-file $db_snp_path ".
        #    "--snp-file $snp_file"; 

        #print("Generating concordance quality report using cmd: $concordance_quality_cmd"); 
        my $concordance_quality_report;
        if ($self->test and -e "./concordance-quality-$list") {
            $concordance_quality_report = `cat ./concordance-quality-$list`;
        }
        else { 
  
            my $cq_output = $self->create_temp_file_path();
            unless (Genome::Model::Tools::Snp::DbSnpConcordance->execute(report_by_quality=>1,output_file=>$cq_output,snp_file=>$snp_file,dbsnp_file=>$db_snp_path) ) {
		die "Could not execute DbSnpConcordance.";		
	    }
            #$concordance_quality_report = `$concordance_quality_cmd`;
            #TODO find a better way than cat...
            $concordance_quality_report = `cat $cq_output`;
            if ($self->test) {
                IO::File->new(">./concordance-quality-$list")->print($concordance_quality_report);
            }
        }
        
        unless ($concordance_quality_report) {
            die "Error generating concordance quality report!";
        }
        
        $body->print("<h3>$header by Quality</h3>");
        
        $DB::single = 1;
        
        my @concordance_quality_report = split(/\n/,$concordance_quality_report);
		pop @concordance_quality_report;
		pop @concordance_quality_report;
        # my $footer = pop @concordance_quality_report;
        # $footer = pop(@concordance_quality_report) . "\n" . $footer;
        
        my $fabulous_concordance_quality_report = $self->make_fabulous(\@concordance_quality_report);

        $body->print($fabulous_concordance_quality_report);
        # $body->print("\n$footer</pre>");
        $body->print("</div>"); #close content_padding div
        next;
        
        # this now appears in the page source, but not in the page itself
        $body->print("<!--\n");
        #$body->print("DbSnp concordance command:  ".$concordance_cmd);
        #$body->print("\n");
        #$body->print("DbSnp concordance quality command:  ".$concordance_quality_cmd);
        $body->print("\n");
        $body->print("\n-->");

		$body->print("</div>"); #close background div
		$body->print("</div>"); #close container div
    }

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

my $n = 0;
sub make_fabulous {
    my $self = shift;
    my $lines = shift;

    $n++;

$DB::single = 1;

    my @x_axis;
    my @dataset1;
    my @dataset2;
    my @current_data;
    my $string_of_data;
    my $line;
    my $header;
    my $footer;

    # Get the body
    while (my $line = shift @$lines) {
        @current_data = split("\t", $line);
        push(@x_axis, $current_data[0]);
        push(@dataset1, $current_data[1]);
        push(@dataset2, $current_data[2]);
    }

    # Reverse the arrays since flot is printing this stuff backwards from what we would expect
    @x_axis = reverse(@x_axis);
    @dataset1 = reverse(@dataset1);
    @dataset2 = reverse(@dataset2);
    
    my $db_snp_data = build_coordinate_string(\@x_axis, \@dataset1);
    my $all_snp_data = build_coordinate_string(\@x_axis, \@dataset2);
    my $concordance_data = build_concordance_string(\@x_axis, \@dataset1, \@dataset2);

    my $db_snp_string = "{ label: \"db snp\", hoverable: true, clickable: true, data: $db_snp_data }";
    my $total_snp_string = "{ label: \"all snps\", hoverable: true, clickable: true, data: $all_snp_data }";
    my $concordance_data_string = "{ label: \"concordance\", yaxis: 2,  hoverable: true, clickable: true, data: $concordance_data }";


    my $graph_data_string = "[ $db_snp_string, $total_snp_string, $concordance_data_string ]";
    
    my $javascript_block=qq|
        <script id="source" language="javascript" type="text/javascript">
        \$(function () {
            var options = {
                legend: { show: true, position: "ne", margin: 20},
                lines: { show: true },
                points: { show: false },
                xaxis: { ticks: 10 },
                yaxis: { tickFormatter: function (v, axis) { return addCommas(v) }},
                y2axis: { ticks: 10, tickFormatter: function (v, axis) { return v + "%"  } },
                grid: { hoverable: true, clickable: true },
            };
        
            \$.plot(\$("#placeholder$n"), $graph_data_string, options);
        });

    function addCommas(number) {
        number = '' + number;
        if (number.length > 3) {
        var mod = number.length % 3;
        var output = (mod > 0 ? (number.substring(0,mod)) : '');
        for (i=0 ; i < Math.floor(number.length / 3); i++) {
                if ((mod == 0) && (i == 0))
                output += number.substring(mod+ 3 * i, mod + 3 * i + 3);
                else
                output+= ',' + number.substring(mod + 3 * i, mod + 3 * i + 3);
        }
        return (output);
        }
        else return number;
    }

    function showTooltip(x, y, contents) {
        \$('<div id="tooltip">' + contents + '</div>').css( {
            position: 'absolute',
            display: 'none',
            top: y + 5,
            left: x + 5,
            border: '1px solid #fdd',
            padding: '2px',
            'background-color': '#fee',
            opacity: 0.80
        }).appendTo("body").fadeIn(200);
    }

    var previousPoint = null;
    \$("#placeholder$n").bind("plothover", function (event, pos, item) {
        \$("#x").text(pos.x.toFixed(2));
        \$("#y").text(pos.y.toFixed(2));

            if (item) {
                if (previousPoint != item.datapoint) {
                    previousPoint = item.datapoint;
                    
                    \$("#tooltip").remove();
                    var x = item.datapoint[0].toFixed(2),
                        y = item.datapoint[1].toFixed(2);
                    
                    showTooltip(item.pageX, item.pageY,
                                item.series.label + " at " + x + " = " + y);
                }
            }
            else {
                \$("#tooltip").remove();
                previousPoint = null;            
            }

    });

        </script> 
    |;
    
    my $output = qq|

<table width="100%" cellpadding="5" cellspacing="0">
  <tr>
   <td valign="middle"><img src="https://gscweb.gsc.wustl.edu/report_resources/db_snp_concordance/images/axis_label_v_SNPs.png" width="19" height="49"/></td>
   <td align="center" valign="middle"><div id="placeholder$n" class="graph_placeholder"/></td>
   <td valign="middle"><img src="https://gscweb.gsc.wustl.edu/report_resources/db_snp_concordance/images/axis_label_v_pct_Concordance.png" width="19" height="151"/></td>
  </tr>
  <tr>
   <td>&nbsp;</td>
   <td align="center"><img src="https://gscweb.gsc.wustl.edu/report_resources/db_snp_concordance/images/axis_label_h_Quality.png" width="67" height="23"/></td>
   <td>&nbsp;</td>
  </tr>
</table>

        $javascript_block
        |;
    return $output;
}

sub build_coordinate_string {
  my $x_axis_ref = shift;
  my $data_set_ref = shift;
  
  my $formatted_return="[ ";
  
  for my $x_point (@{$x_axis_ref}) {
    $formatted_return .= "[ $x_point , " . $data_set_ref->[$x_point] . "],\n ";
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

    $formatted_return .= "[ $x_point , " . sprintf("%.2f", 100 * $v3) . "], /* $v1\t$v2\t$v3 */\n";
  }
  
  
  $formatted_return .= "] ";
  return $formatted_return;
}

1;
