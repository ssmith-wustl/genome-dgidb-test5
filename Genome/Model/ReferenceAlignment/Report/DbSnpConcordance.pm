#:boberkfe the generate report detail method here is way too long, this should
#:boberkfe be broken up to divide out the work between collecting data and making graphs, etc

package Genome::Model::ReferenceAlignment::Report::DbSnpConcordance;

use strict;
use warnings;

use Genome;

use App::Report;
use CGI;
use IO::String;
use Data::Dumper;
use Template;
use POSIX; 


my $base_template_path = __PACKAGE__->_base_path_for_templates;

class Genome::Model::ReferenceAlignment::Report::DbSnpConcordance {
    is => 'Genome::Model::Report',
    has => [
        
        # inputs come from the build
        variant_list_files          => { via => 'build', to => '_snv_file_unfiltered' },
        variant_filtered_list_files => { via => 'build', to => '_snv_file_filtered' },
        db_snp_file                 => { via => 'build' },
        
        name                        => { default_value => 'dbSNP Concordance' },
        description => {
            calculate => q|
            return "<div>Db Snp coverage for " . $self->model->name . " (build " . $self->build_id . ") as of " . UR::Time->now.'</div>';
            |,
        },

        report_templates => {
            is => 'String',
            is_many => 1,
            default_value => [
            "$base_template_path.html.tt2",
            "$base_template_path.txt.tt2"
            ],
            doc => 'The paths of template(s) to use to format the report.  (In .tt2 format)',
        },
        
        test => {
            is             => 'Boolean',
            default_value  => 0,
            doc            => "Saves copies of the generated data in the pwd if they do not exist.  Re-uses them on the next run(s)."
        },
        override_variant_file => {
            type         => 'Text',
            is_optional  => 1,
            doc          => "for testing, use this snp file instead of the real file for the model/build",
        },
        override_db_snp_file => {
            type         => 'Text',
            is_optional  => 1,
            doc          => "Use this db snp file instead of generating a new one.",
        }
    ]
};

# TODO: move up into base class
sub _base_path_for_templates 
{
    my $module = __PACKAGE__;
    $module =~ s/::/\//g;
    $module .= '.pm';
    my $module_path = $INC{$module};
    unless ($module_path) {
        die "Module " . __PACKAGE__ . " failed to find its own path!  Checked for $module in \%INC...";
    }
    return $module_path;
}

# sub _add_to_report_xml {
#     my $self = shift;

#     return {
#         description => $self->generate_report_brief,
#         html => $self->generate_report_detail,
#     };
# }

sub _add_to_report_xml 
{
    my $self = shift;
    my $template = shift;

    my @templates = $self->report_templates;
    unless (@templates) {
        die "No report templates assigned!  Cannot generate any content."
    }

    #my $data = { description => $self->generate_report_brief };
    my $data = {}; 
    
    for my $template (@templates) {
        my $content = $self->generate_report_detail($template);
        my ($format,$key);
        if ($content =~ /\<\s*HTML/i) {
            $format = 'HTML';
            $key = 'html';
        }
        else {
            $format = 'text';
            $key = 'txt'; 
        }
        if (exists $data->{$key}) {
            die "Multiple templates return content in $format format.  This is not supported, sadly."
                . "  Error processing $template";
        }
        $data->{$key} = $content;
    };
    return $data;
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
    my $template = shift;
    unless ($template) {
        die "Please specify which template to use for this report!";
    }
    
    my $build = $self->build;
    my $build_id = $build->id;
    my $model = $build->model;

    my $content;
    
    $self->status_message("Running dbSNP Concordance Report for build ".$build->id.".");
    
    my $module_path = $INC{"Genome/Model/ReferenceAlignment/Report/DbSnpConcordance.pm"};
    die 'failed to find module path!' unless $module_path;

    my @cqr_unfiltered;
    my @cqr_filtered;

    my $cqr_unfiltered_summary;
    my $cqr_filtered_summary;

    my $total_unfiltered_snps;
    my $total_filtered_snps;
    my $dbsnp_unfiltered_positions;
    my $dbsnp_filtered_positions;
    my $unfiltered_concordance;
    my $filtered_concordance;
    
	my $concordance_report;

    
    for my $list (qw/variant_list_files variant_filtered_list_files/) {
        my $snp_file;
        if  (defined $self->override_variant_file) {
            # override SNP list for testing
            # this will be used for both passes through the loop if testing.. 
            $snp_file =  $self->override_variant_file
        }  
        else {
            my @extra;
            ($snp_file,@extra) = $self->$list;           
            if (@extra) {
                die "Expected only one file of SNPs!"
                    . join("\n",@extra);
            } 
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
                    Genome::Model::Tools::Annotate::LookupVariants->execute(
                        output_file     => $db_snp_path,
                        variant_file    => $snp_file,
                        report_mode     => 'known-only',
                    ) 
                ) {
                    die "Could not execute LookupVariants.";
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
            $self->status_message("Output file for DbSnpConcordance: ".$cc_output);
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
        
        my @concordance_quality_report = split(/\n/,$concordance_quality_report);
        pop @concordance_quality_report;
        pop @concordance_quality_report;
        
        if ($list eq 'variant_list_files') {
            @cqr_unfiltered = @concordance_quality_report;
            $cqr_unfiltered_summary = $concordance_report;

            ## extract snp positions, dbsnp positions, and concordance data so we can display them in a nice table
            ## TODO: create a sub for this so we're not doing it twice in a row
            if($cqr_unfiltered_summary eq 'There were 0 in the snp file.  No output was generated.'){
                $total_unfiltered_snps = $dbsnp_unfiltered_positions = $unfiltered_concordance = 0;
                print("No snps to generate concordance, setting metrics to 0");
            } elsif ($cqr_unfiltered_summary =~ m/(\d+) .* (\d+) .* (\d+\.\d+\%)/s) {
                $total_unfiltered_snps = $1;
                $dbsnp_unfiltered_positions = $2;
                $unfiltered_concordance = $3;
                print("total_unfiltered_snps: $total_unfiltered_snps\n dbsnp_unfiltered_positions: $dbsnp_unfiltered_positions\n unfiltered_concordance: $unfiltered_concordance\n\n");
                
            } else {
                $self->status_message("Could not extract unfiltered summary report data from dbSNP concordance report!");
            }

        }
        elsif ($list eq 'variant_filtered_list_files') {
            @cqr_filtered = @concordance_quality_report;
            $cqr_filtered_summary = $concordance_report;

            ## extract snp positions, dbsnp positions, and concordance data so we can display them in a nice table            
            if($cqr_unfiltered_summary eq 'There were 0 in the snp file.  No output was generated.'){
                $total_unfiltered_snps = $dbsnp_unfiltered_positions = $unfiltered_concordance = 0;
                print("No snps to generate concordance, setting metrics to 0");
            }elsif ($cqr_filtered_summary =~ m/(\d+) .* (\d+) .* (\d+\.\d+\%)/s) {
                $total_filtered_snps = $1;
                $dbsnp_filtered_positions = $2;
                $filtered_concordance = $3;
                print("total_filtered_snps: $total_filtered_snps\n dbsnp_filtered_positions: $dbsnp_filtered_positions\n filtered_concordance: $filtered_concordance\n\n");
            } else {
                $self->status_message("Could not extract filtered summary report data from dbSNP concordance report!");
            }

        }
        else {
            die "unknown SNV list $list!.  Cannot properly assign graph data strings!";
        }
    }

    # let's make sure that the reports made it out of the loop:

    #
    # BUILD GRAPH
    #

    ## TODO: Parse the data and create the graph data strings using a proper function
    ## instead of repeating the same process twice.

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

    ## get CSS resources
    my $css_file = "$module_path.html.css";
    my $css_fh = IO::File->new($css_file);
    unless ($css_fh) {
        die "failed to open file $css_file!"; 
    }
    my $page_css = join('',$css_fh->getlines);
    
    ## get javascript resources
    my $graph_script_file = "$module_path.html.js";
    my $graph_script_fh = IO::File->new($graph_script_file);
    unless ($graph_script_fh) {
        die "failed to open file $graph_script_file"; 
    }
    my $graph_script = join('',$graph_script_fh->getlines);

    ########## RENDER TEMPLATE #############

    my @vars = (
        model_id                       => $model->id,
        model_name                     => $model->name,
        page_title                     => "Db Snp for model " . $model->id . ' (&quot;' . $model->name . "&quot;) build $build_id",
        
        unfiltered_concordance_summary => $cqr_unfiltered_summary,
        filtered_concordance_summary   => $cqr_filtered_summary,

        total_unfiltered_snps          => commify($total_unfiltered_snps),
        total_filtered_snps            => commify($total_filtered_snps),
        dbsnp_unfiltered_positions     => commify($dbsnp_unfiltered_positions),
        dbsnp_filtered_positions       => commify($dbsnp_filtered_positions),
        unfiltered_concordance         => $unfiltered_concordance,
        filtered_concordance           => $filtered_concordance,
        
        filtered_db_snp_data           => $filtered_db_snp_data, 
        filtered_all_snp_data          => $filtered_all_snp_data,
        filtered_concordance_data      => $filtered_concordance_data,
        unfiltered_db_snp_data         => $unfiltered_db_snp_data,
        unfiltered_all_snp_data        => $unfiltered_all_snp_data,
        unfiltered_concordance_data    => $unfiltered_concordance_data,

        graph_script                   => $graph_script,
        page_css                       => $page_css
    );

    ## $self->status_message("Summary Report values: ".Dumper(\@vars) );
    
    ##################################
      
    my $tt = Template->new({
         ABSOLUTE => 1,
        #INCLUDE_PATH => '/gscuser/jpeck/svn/pm2/Genome/Model/ReferenceAlignment/Report',
        #INTERPOLATE  => 1,
    }) || die "$Template::ERROR\n";

    $self->status_message("processing template $template");

    my $rv = $tt->process($template, { @vars }, \$content) || die $tt->error(), "\n";
    if ($rv != 1) {
   	    die "Bad return value from template processing for summary report generation: $rv ";
    }
    unless ($content) {
        die "No content returned from template processing!";
    }
    
    my $body = IO::String->new();  
    die $! unless $body;
    $body->print($content);
    $body->seek(0, 0);
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

sub commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;
}

sub build_coordinate_string {
    my $x_axis_ref = shift;
    my $data_set_ref = shift;
    
    my $formatted_return="[ ";
    
    for my $x_point (@{$x_axis_ref}) {
        my $v1 = $data_set_ref->[$x_point] || 0;
        $formatted_return .= "[ $x_point, " . $v1 . "], ";
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
    
        $formatted_return .= "[ $x_point, " . sprintf("%.2f", 100 * $v3) . "], ";
    }
    
    $formatted_return .= "] ";
    return $formatted_return;
}

1;
