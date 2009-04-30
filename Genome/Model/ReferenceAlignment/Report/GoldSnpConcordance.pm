package Genome::Model::ReferenceAlignment::Report::GoldSnpConcordance;

use strict;
use warnings;

use Genome;
use CGI;
use IO::String;

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
    ],
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

sub _generate_data 
{
    my $self = shift;
    return {
        description => $self->generate_report_brief,
        html => $self->generate_report_detail,
    };
}

sub generate_report_brief 
{
    my $self=shift;

    return "<div>Gold Snp coverage for " . $self->model_name . " as of " . UR::Time->now.'</div>';
}

sub generate_report_detail 
{
    my $self = shift;
    my $build = $self->build;
    
    my $gold_snp_path = $self->gold_snp_path;
   
$DB::single = 1;

    my $r = new CGI;
    my $body = IO::String->new();  
    die $! unless $body;
    $body->print( $r->start_html(-title=> 'Gold SNP Concordance Report for Model' . $self->model_id . ', build ' .$build->id) );

    my $style = $self->get_css();
    my $report_start = "<div class=\"container\">\n<div class=\"background\">\n" .
                       "<h1 class=\"report_title\">Gold SNP Concordance Report for Model " .
                       $self->model_id . " (<em>" . $self->model_name . "</em>), build " .
                       $build->id . "</h1>\n";
    my $report_end = "</div>&nbsp;</div>";
    $body->print("<style>$style</style>");
    $body->print("$report_start");

    for my $list (qw/variant_list_files variant_filtered_list_files/) {
        my $snp_file = $self->create_temp_file_path($list);
        my @files = $self->$list;
        system "cat @files > $snp_file";
        
        my $cmd = "gt snp gold-snp-intersection " .
            "--gold-snp-file $gold_snp_path " .
            "--snp-file $snp_file";
        
        $self->status_message("GoldSnp command: ".$cmd);
        
        my $gold_rpt = `$cmd`; 
        #my $output_file = $self->report_detail_output_filename;   
        
        #my $body = IO::File->new(">$output_file");  
       
        my $label;
        if ($list eq 'variant_list_files') {
            $label = 'Gold Concordance for Unfiltered SNVs'
        }
        elsif ($list eq 'variant_filtered_list_files') {
            $label = 'Gold Concordance for SNPFilter SNVs'
        }
        else {
            die "unknown list $list!";
        }
       
        my $formatted_gold_rpt = $self->format_report($gold_rpt, $label);
        $body->print("$formatted_gold_rpt");
        
    }

    $body->print("$report_end");
    $body->print( $r->end_html );
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
        $content=~s/(<td colspan=\"2\" class=\"gold_class\">&nbsp;<\/td><\/tr>\n)/$1<tr><th>&nbsp;<\/th><th>reads<\/th><th>\%<\/th><th>depth<\/th><\/tr>\n/g;
        $content=~s/calls \(could/calls<br \/>(could/g;
        $content = "<h2 class=\"section_title\">$label</h2>\n" .
                   "<table class=\"snp\">\n" .
                   "<tr><td class=\"gold_class\">$content</tr>\n</table>\n";

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

1;
