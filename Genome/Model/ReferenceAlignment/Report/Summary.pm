package Genome::Model::ReferenceAlignment::Report::Summary;

use strict;
use warnings;

use Genome;

use App::Report;
use CGI;
use IO::String;
use Template;
use Data::Dumper;

class Genome::Model::ReferenceAlignment::Report::Summary {
    is => 'Genome::Model::Report',
    has => [
        report_templates => {
            is => 'String',
            is_many => 1,
            default_value => [
                'build_report_template_html.tt2',
                'build_report_template_txt.tt2'
            ],
            doc => 'The paths of template(s) to use to format the report.  (In .tt2 format)',
        },
        name => {
            default_value => 'Build Summary',
        },
    ],
};

sub _generate_data 
{
    my $self = shift;
    my $template = shift;

    my @templates = $self->report_templates;
    unless (@templates) {
        die "No report templates assigned!  Cannot generate any content."
    }

    my $data = { description => $self->generate_report_brief };
    
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
    return "Link to summary report will go here";
}

sub generate_report_detail 
{
    my $self = shift;
    my $template = shift;
    unless ($template) {
        die "please specify which template to use for this report!";
    }

    my $model = $self->model;
    my $build = $self->build;
   
   $self->status_message("Running report summary for build ".$build->id.".");
   my $body = IO::String->new();  
   die $! unless $body;
   my $summary = $self->get_summary_information($template);
   $body->print($summary);
   $body->seek(0, 0);
   return join('', $body->getlines);
}

sub get_summary_information 
{
    my $self = shift;
    my $template = shift;
    unless ($template) {
        die "please specify which template to use for this report!";
    }

$DB::single = 1;   

    my $model = $self->model;
    my $build = $self->build;
    
    my $content;
 
    ################################# 
    my $na = "Not Available";
    my $haploid_coverage=$na;
    my $diploid_coverage_percent=$na;
    my $diploid_coverage_actual_number=$na;
    my $dbsnp_concordance=$na;

    my $report_dir = $build->resolve_reports_directory;

    my $mapcheck_report_file = $report_dir."/RefSeqMaq/report.html";
    my $goldsnp_report_file = $report_dir."/GoldSnp/report.html";
    my $dbsnp_report_file = $report_dir."/DbSnp/report.html";

    ##match mapcheck report
    my $fh = new IO::File($mapcheck_report_file, "r");
    if ($fh) {
            my $mapcheck_contents = get_contents($fh);
            if ($mapcheck_contents =~ m/Average depth across all non-gap regions: (\S+)/ ) {
                    $haploid_coverage=$1 if defined($1);
            }
    $fh->close();
    }

    ##match goldsnp report
    $fh = new IO::File($goldsnp_report_file, "r");
    if ($fh) {
        my $goldsnp_contents = get_contents($fh);
        if ($goldsnp_contents =~ m|heterozygous - 1 allele variant</span><span style=\"padding-left:10px;\">(\S+)</span><span style=\"padding-left:10px;\">(\S+)</span><span style=\"padding-left:10px;\">(\S+)</span>|) {
                #print ("Found match. >$1, $2, $3<\n");
                $diploid_coverage_actual_number=$1; 
                $diploid_coverage_percent=$2; 
        }
        $fh->close();
    }

    ##match dbsnp report
    $fh = new IO::File($dbsnp_report_file, "r");
    if ($fh) {
        my $dbsnp_contents = get_contents($fh);
        if ( $dbsnp_contents =~ m|There were (\S+) positions in dbSNP for a concordance of (\S+)%| ) {
            $dbsnp_concordance=$2;
        } 
        $fh->close();
    }

    ##the number of instrument data assignments is:
    my @inst_data_ass = $build->instrument_data_assignments;

    my $vars = {
	model_id=>$model->id,
	model_name=>$model->name,
	model_owner=>$model->user_name,
	model_subject_name=>$model->subject_name,
	model_creation_date=>$model->creation_date,
	model_data_directory=>$model->data_directory,

	build_id=>$build->id,
	build_status=>$build->build_status,
	build_scheduled=>$build->date_scheduled,
	build_completed=>$build->date_completed,
	number_of_instrument_data_assignments=>scalar(@inst_data_ass) ,

	haploid_coverage=>$haploid_coverage,
	diploid_coverage_actual_number=>$diploid_coverage_actual_number,
	diploid_coverage_percent=>$diploid_coverage_percent,
	dbsnp_concordance=>$dbsnp_concordance
    };

    #$self->status_message("Summary Report values: ".Dumper($vars) );

    ##################################
      
    my $tt = Template->new({
        INCLUDE_PATH => '/gscuser/jpeck/svn/pm2/Genome/Model/ReferenceAlignment/Report',
        #INTERPOLATE  => 1,
    }) || die "$Template::ERROR\n";

    my $varstest = {
        name     => 'Mickey',
        debt     => '3 riffs and a solo',
        deadline => 'the next chorus',
    };

    $self->status_message("processing template $template");

    my $rv = $tt->process($template, $vars, \$content) || die $tt->error(), "\n";
    if ($rv != 1) {
   	die "Bad return value from template processing for summary report generation: $rv ";
    }
    unless ($content) {
        die "No content returned from template processing!";
    }

    return $content;
}

sub get_contents {
   my $in = shift;
   my $ret = "";
   while (<$in>) {
      $ret.= $_;
   }
   return $ret;
}

1;
