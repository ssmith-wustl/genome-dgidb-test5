package Genome::Model::ReferenceAlignment::Report::GoldSnpConcordance;

use strict;
use warnings;

use Genome;
use CGI;
use IO::String;

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
    $body->print( $r->start_html(-title=> 'Gold SNP Concordance Report for ' . $build->id) );
   
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

    $body->print( $r->end_html );
    $body->seek(0, 0);
    return join('', $body->getlines);
}

sub format_report
{
    #assumes plain-text
    #convert newlines to divs, and tabs to padded spans
    my ($self, $content, $label) = @_;
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
        $content = "<h1>$label</h1>\n\n" .
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
