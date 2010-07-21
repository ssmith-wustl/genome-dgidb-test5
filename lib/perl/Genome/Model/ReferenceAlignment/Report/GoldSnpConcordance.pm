#:boberkfe shouldn't this use the template toolkit to format the report, and not
#:boberkfe html within this module?

package Genome::Model::ReferenceAlignment::Report::GoldSnpConcordance;

use strict;
use warnings;

use Genome;

use App::Report;
use CGI;
use IO::String;
use Data::Dumper;
use Template;
use POSIX;
use XML::Simple;

my $base_template_path = __PACKAGE__->_base_path_for_templates;

class Genome::Model::ReferenceAlignment::Report::GoldSnpConcordance {
    is => 'Genome::Model::Report',
    has => [
        # inputs come from the build
        variant_list_files          => { via => 'build', to => '_snv_file_unfiltered' },
        variant_filtered_list_files => { via => 'build', to => '_snv_file_filtered' },
        gold_snp_path               => { via => 'build' },

        # the name is essentially constant
        name                        => { default_value => 'Gold_SNP_Concordance' },
        description => {
            calculate => q|
            return "<div>Gold Snp coverage for " . $self->model_name . " (build " . $self->build_id . ") as of " . UR::Time->now.'</div>';
            |,
        },
        report_templates => {
            is => 'String',
            is_many => 0,
            default_value => "$base_template_path.html.tt2",
            doc => 'The paths of template(s) to use to format the report.  (In .tt2 format)',
        },
        test => {
            is             => 'Boolean',
            default_value  => 0,
            doc            => "Saves copies of the generated data in the pwd if they do not exist. Re-uses them on the next run(s)."
        }
    ]
};

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

sub _add_to_report_xml
{
    my $self = shift;
#    return {
#        description => $self->generate_report_brief,
#        html => $self->generate_report_detail,
#    };
#  below is part of shift to templating system
    my $template = shift;

    my @templates = $self->report_templates;
    unless (@templates) {
        die "No report templates assigned! Cannot generate any content."
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
#        else {
#            $format = 'text';
#            $key = 'txt';
#        }
        if (exists $data->{$key}) {
            die "Multiple templates return content in $format format. This is not supported, sadly."
                . "  Error processing $template";
        }
        $data->{$key} = $content;
    };
    return $data;
# end of additions
}

sub generate_report_brief
{
    my $self=shift;
#    my $build = $self->build;
    return "<div>Gold Snp coverage for " . $self->model_name . " (build " . $self->build_id . ") as of " . UR::Time->now.'</div>';
}

sub generate_report_detail
{
    my $self = shift;
    my $template = shift;
    unless ($template) {
        die "Please specify which template to use for this report.";
    }

    my $build = $self->build;
    my $model = $build->model;

    my $snv_detector_name = $model->snv_detector_name;
    my $gold_snp_path  = $self->gold_snp_path;

    my $module_path = $INC{"Genome/Model/ReferenceAlignment/Report/GoldSnpConcordance.pm"};
    die 'failed to find module path!' unless $module_path;

$DB::single = 1;

    my $r = new CGI;
    my $style = $self->get_css();
#    my $body = IO::String->new();
#    die $! unless $body;
#    $body->print( $r->start_html(-title=> 'Gold SNP Concordance Report for Model' . $self->model_id . ', build ' .$build->id) );

#    my $report_start = "<div class=\"container\">\n<div class=\"background\">\n" .
#                       "<h1 class=\"report_title\">Gold SNP Concordance Report for Model " .
#                       $self->model_id . " (<em>" . $self->model_name . "</em>), build " .
#                       $build->id . "</h1>\n";
#    my $report_end = "</div>&nbsp;</div>";
#    $body->print("<style>$style</style>");
#    $body->print("$report_start");

    my $content;
    my $report_content;

    my @gold_xml_reports;

    for my $list (qw/variant_list_files variant_filtered_list_files/) {
        my $snp_file = $self->create_temp_file_path($list);
        my $name = $list;
        $name =~ s/_files$//;
        
        my @files = $self->$list;
        system "cat @files > $snp_file";

        #my $report_dir = $build->resolve_reports_directory . $self->name; gold_snp subdir not ready yet.
        my $missed_snp_file = $build->resolve_reports_directory. "$name.missed_gold_snv.dat";
        
        if(-e $missed_snp_file) {
            $self->warning_message('Existing missed snp file found: ' . $missed_snp_file . ' -- moving it out of the way.');
            #This will overwrite any existing ".old" file if someone runs this a third time. Maybe we should just delete it right here anyway?
            unless(rename($missed_snp_file, $missed_snp_file . '.old')) {
                $self->error_message('Failed to move file!');
                die $self->error_message;
            }
        }
        
        my %intersect_params = (
            gold_snp_file   => $gold_snp_path,
            snp_file        => $snp_file,
            missed_snp_file => $missed_snp_file,
        );

        unless ($snv_detector_name eq "maq") {
            $intersect_params{'snp_format'} = 'sam';
        }

        my $cmd = Genome::Model::Tools::Snp::GoldSnpIntersection->create(%intersect_params);

        unless ($cmd) {
            $self->error_message("failed at getting a gold snp intersection command.");
            return;
        }

        unless ($cmd->execute) {
            $self->error_message("gold snp intersection command failed to execute!");
            return;
        }

=cut
        my $cmd = "gmt snp gold-snp-intersection " .
            "--gold-snp-file $gold_snp_path " .
            "--snp-file $snp_file";
        $cmd .= ' --snp-format sam' if $snv_detector_name =~ /samtools/;

        $DB::single = 1;

        $self->status_message("GoldSnp command: ".$cmd);

        my $gold_rpt = `$cmd`;
        #my $output_file = $self->report_detail_output_filename;

        #my $body = IO::File->new(">$output_file");
=cut

        my $gold_rpt = $cmd->_report_txt;
        my $gold_rpt_xml = $cmd->_report_xml;

        my $filter_flavor;
        my $label;
        if ($list eq 'variant_list_files') {
            $label = 'Gold Concordance for Unfiltered SNVs';
            $filter_flavor = "unfiltered";
        }
        elsif ($list eq 'variant_filtered_list_files') {
            $label = 'Gold Concordance for SNPFilter SNVs';
            $filter_flavor = "filtered";
        }
        else {
            die "unknown list $list!";
        }

        push @gold_xml_reports, {filter_flavor=>$filter_flavor, xml=>$gold_rpt_xml};

        my $formatted_gold_rpt = $self->format_report($gold_rpt, $label);
#        $body->print("$formatted_gold_rpt");
        $report_content = $report_content . $formatted_gold_rpt;

    }


#    $body->print("$report_end");
#    $body->print( $r->end_html );
#    $body->seek(0, 0);
#    return join('', $body->getlines);

    my @vars = (
        model_id       => $model->id,
        model_name     => $model->name,
        build_id       => $build->id,
        page_title     => "Gold SNP Concordance Report for Model " . $model->id . " (" . $model->name . "), build " .$build->id,
        style          => $style,
        report_content => $report_content
    );

    my $tt = Template->new({
        ABSOLUTE => 1,
    }) || die "$Template::ERROR\n";

    my $rv = $tt->process($template, { @vars }, \$content) || die $$tt->error(), "\n";
    if ($rv != 1) {
        die "Bad return value from template processing for summary report generation: $rv ";
    }
    unless ($report_content) {
        die "No content returned from template processing!";
    }

    for (@gold_xml_reports) {
        $self->store_report_metrics($_->{xml}, $_->{filter_flavor});
    }

    my $body = IO::String->new();
    die $! unless $body;
    $body->print($content);
    $body->seek(0, 0);
    return join('', $body->getlines);

}

sub format_report
{
    #assumes plain-text
    #convert newlines to table rows, and tabs to table cells
    my ($self, $content, $label) = @_;
    my $model = $self->model;
    my $result = "\n<!--\n$content\n-->\n";
    if ($content=~m/(\s*)(.*)(\s*)/sm)
    {
        $content = $2;
        my $span = "<span style=\"padding-left:10px;\">";

        $content=~s/\n\t\t/<\/td><\/tr>\n<tr><td class=\"maq_class\">/g;
        $content=~s/\n\t/<\/td><\/tr>\n<tr><td class=\"match_class\" colspan=\"4\">/g;
        $content=~s/\t/<\/td><td>/g;
        $content=~s/(\n)(There were .+)/<\/td><\/tr>\n<tr><td class=\"gold_class\">$2/g;
        $content=~s/(There were )(\d+)(\s)(.+)(<\/td><\/tr>)/$4<\/td><td class=\"gold_class\">$2<\/td><td colspan=\"2\" class=\"gold_class\">&nbsp;$5/g;
        $content=~s/(<td colspan=\"2\" class=\"gold_class\">&nbsp;<\/td><\/tr>\n)/$1<tr><th>&nbsp;<\/th><th>SNVs<\/th><th>\%<\/th><th>depth<\/th><\/tr>\n/g;
        $content=~s/calls \(could/calls<br \/>(could/g;
        $content = "<div class=\"section_content\">\n<h2 class=\"section_title\">$label</h2>\n" .
                   "<table class=\"snp\">\n" .
                   "<tr><td class=\"gold_class\">$content</tr>\n</table>\n</div>";

        return $content;
    }
}

sub get_css
{
    my $module_path = $INC{"Genome/Model/ReferenceAlignment/Report/GoldSnpConcordance.pm"};
    die 'failed to find module path!' unless $module_path;

    ## get CSS resources
    my $css_file = "$module_path.html.css";
    my $css_fh = IO::File->new($css_file);
    unless ($css_fh) {
        die "failed to open file $css_file!";
    }
    my $page_css = join('',$css_fh->getlines);

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

sub store_report_metrics {
    my $self = shift;
    my $report_xml = shift;
    my $filter_flavor = shift;

    my $xml_struct = XMLin($report_xml);

    my @report_keys = keys %{$xml_struct};

    for my $block (@report_keys) {
        my $this_block = $xml_struct->{$block};

        my @block_keys = keys %{$this_block};

        for my $match_type ( grep { $_ =~ m/match/ } @block_keys ) {
            my $variant_set = $this_block->{$match_type}->{'variant'};
            my @variants;
            if ( ref($variant_set) eq 'HASH' ) {
                @variants = ($variant_set);
            }
            else {
                @variants = @{$variant_set};
            }

            for (@variants) {
                my $t = $_->{type};
                $t =~ s/\s\-\s/-/g;
                $t =~ s/\s/\-/g;

                my $metric_name = "$block $match_type $t $filter_flavor";
                my $metric_value = $_->{intersection};

                $self->build->set_metric($metric_name, $metric_value);
            }
        }
    }
}

1;
