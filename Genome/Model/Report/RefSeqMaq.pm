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
    my $reports_dir= $basedir . "RefSeqMaq";
    #$reports_dir .= '-' . $self->ref_seq_name if $self->ref_seq_name; 
    unless(-d $reports_dir) {
        unless(mkdir $reports_dir) {
            $self->error_message("Directory $reports_dir doesn't exist, can't create");
            return;
        }
        chmod 02775, $reports_dir;
    }

   `touch $reports_dir/generation_class.RefSeqMaq`;
    print $reports_dir;
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
        $rpt = $maqs{$ref_seq};
        $avg =  $rpt=~m/(.*non-gap regions:\s*)(\d+\.\d+)/ ? $2 : 'Not Available';
        $brief->print("<li>$ref_seq:<a href=\"" . $self->get_coverage_filename . "\">$avg</a></li>");
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

    my ($maq_file, $bfa_file, $cmd, @maq, $fh, $file_name, %output, $rpt,$maplist);
    
    my $reports_dir = $self->model->resolve_reports_directory;
    $file_name = $self->get_coverage_filename;#$reports_dir . '/' .  $model->genome_model_id . '_coverage_detail.html';
    $self->status_message("Will write final report file to: ".$file_name);
    
    my @all_map_lists;
    my @map_list;
    my $c;
    my @chromosomes = (1..22,'X','Y');
    #my @chromosomes = (22);
    foreach $c(@chromosomes) {
        my $a_ref_seq = Genome::Model::RefSeq->get(model_id=>$model->genome_model_id,ref_seq_name=>$c);
        @map_list = $a_ref_seq->combine_maplists;
        #print "There are ".scalar(@map_list). " map lists.  They are:\n";
        push (@all_map_lists, @map_list); 
    }
   
    my $result_file = '/tmp/mapmerge_'.$model->genome_model_id;

    $self->warning_message("Performing a complete mapmerge for $result_file \n"); 
    ($fh,$maplist) = File::Temp::tempfile;
    $fh->print(join("\n",@all_map_lists),"\n");
    $fh->close;
    $self->status_message("gt maq vmerge --maplist $maplist --pipe $result_file &");
    system "gt maq vmerge --maplist $maplist --pipe $result_file &";
    my $start_time = time;
    until (-p "$result_file" or ( (time - $start_time) > 100) )  {
            $self->status_message("Waiting for pipe...");
            sleep(5);
    }
    unless (-p "$result_file") {
            die "Failed to make pipe? $!";
    }
    $self->status_message("Streaming into file $result_file.");
       
    $self->warning_message("mapmerge complete.  output filename is $result_file");
    chmod 00664, $result_file;

    #$bfa_file = $self->bfa_path . "22" . ".bfa " . $result_file;
    $bfa_file = $self->bfa_path . "all_sequences.bfa " . $result_file;
    $cmd = $self->cmd . " " .$bfa_file; 
    @maq = `$cmd`;
    $rpt = join('',@maq);
    print $rpt;
    
    #make detail report
    #$file_name = $reports_dir . '/' .  $model->genome_model_id . '_coverage_detail.html';
    $self->warning_message("Writing final report to: ".$file_name);
    $fh = IO::File->new(">$file_name");        
    $fh->print($rpt);
    $fh->close;
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

sub get_coverage_filename
{
    my $self = shift;
    my $reports_dir = $self->model->resolve_reports_directory;
    my $model = $self->model;
    return $reports_dir . '/' .  $model->genome_model_id . '_coverage_detail.html';
}

1;
