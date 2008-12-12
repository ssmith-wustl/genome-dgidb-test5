package Genome::Model::Report::RefSeqMaq;

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


class Genome::Model::Report::RefSeqMaq{
    is => 'Genome::Model::Report',
    has =>
    [
        #if we have a ref seq, just get that, otherwise get 'em all
        ref_seq_name => {is => 'VARCHAR2', len => 64, is_optional => 1, doc => 'Identifies Ref Sequence'},
        bfa_path =>
        {
            type => 'String',
            doc => "Path for .bfa file", #does this need to be a param?
            default => "/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/",
        }, 
        cmd =>
        {
            type => 'String',
            doc => "system command for generating report", #does this need to be a param?
            default => "/gsc/pkg/bio/maq/maq-0.6.8_x86_64-linux/maq mapcheck",
        },
    ],
};

sub resolve_reports_directory {
    my $self = shift;
    my $basedir = $self->SUPER::resolve_reports_directory();
    my $reports_dir= $basedir . "SolexaStageOne";
#    $reports_dir .= '-' . $self->ref_seq_name if $self->ref_seq_name; 
    unless(-d $reports_dir) {
        unless(mkdir $reports_dir) {
            $self->error_message("Directory $reports_dir doesn't exist, can't create");
            return;
        }
        chmod 02775, $reports_dir;
    }

   `touch $reports_dir/generation_class.SolexaStageOne`;
   return $reports_dir;
}


sub report_brief_output_filename {
    my $self=shift;
    return $self->resolve_reports_directory . "/ref_seq_brief.html";
}

sub report_detail_output_filename {
    my $self=shift;
    return $self->resolve_reports_directory . "/ref_seq_detail.html";
}

sub generate_report_brief 
{
    my $self=shift;
   
    #get ref seq's 
    my $i = $self->get_ref_seq_iterator;
    my ($o, @o);
    while ($o = $i->next) 
    {
        push @o, $o;
    }
    
    my $output_file = $self->report_brief_output_filename;
    my $brief = IO::File->new(">$output_file");
    $brief->print("<ul>");
    die unless $brief;

    my %maqs = $self->get_maq_content;
    my ($rpt,$avg);
    foreach my $ref_seq(sort keys %maqs)
    {
        $rpt = $maps{$ref_seq};
        $avg =  $rpt=~m/(.*non-gap regions:\s*)(\d+\.\d+)/ ? $2 : 'Not Available';
        $brief->print("<li>$ref_seq:<a href=\"" .
                      $self->reports_dir . '/' .  $ref_seq_name . '_detail.html'; . 
                      "\">$avg</a></li>");
    }
    $brief->print("<ul>");
    $brief->close;
}

sub generate_report_detail 
{
    my $self = shift;
    $self->get_maq_content;
    return;
}

sub get_maq_content
{
    my $self = shift;
    my $model = $self->model;
    my $i = $self->get_ref_seq_iterator;  #rely on get_ref_seq_iterator to filter on ref_seq_name, if necessary

    my ($o, @o);
    while ($o = $i->next) 
    {
        push @o, $o;
    }

    my ($maq_file, $bfa_file, $cmd, @maq, $fh, $file_name, %output, $rpt);
    my $reports_dir = $self->model->resolve_reports_directory;
    foreach $o(@o)
    {
        $maq_file = $o->resolve_accumulated_alignments_filename;
        $bfa_file = $self->bfa_path . $o->ref_seq_name . ".bfa " . $maq_file;
        $cmd = $self->cmd . " " .$bfa_file; 
        @maq = `$cmd`;
        $rpt = join('',@maq);
        #make detail report
        $file_name = $reports_dir . '/' .  $o->ref_seq_name . '_detail.html';
        $fh = IO::File->new(">$file_name");        
        $fh->print($rpt);
        $fh->close;
        #store for brief report
        $output{$o->ref_seq_name} = $rpt;
    }
    return %output;
}

sub get_ref_seq_iterator
{
    my $self = shift;
    my $i;
    if ($self->ref_seq_name)
    {
        $i = Genome::Model::RefSeq->create_iterator(where => [ model_id=> $self->model_id,
                                                               ref_seq_name => $self->ref_seq_name,
                                                               variation_position_read_depths => 2 ]);
    }
    else
    {
        $i = Genome::Model::RefSeq->create_iterator(where => [ model_id=> $self->model_id,
                                                                  variation_position_read_depths => 2 ]);
    }
    return $i;
} 


1;
