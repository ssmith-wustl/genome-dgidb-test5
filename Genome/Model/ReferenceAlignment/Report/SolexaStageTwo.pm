package Genome::Model::ReferenceAlignment::Report::SolexaStageTwo;

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

class Genome::Model::ReferenceAlignment::Report::SolexaStageTwo {
    is => 'Genome::Model::Report',
};

my %div_hash;
my %job_to_status;

sub _add_to_report_xml {
    # FIXME ajax file needs to go somewhere see detail...
    my $self = shift;

    return {
        html => $self->generate_report_detail,
    };
}

sub name { return 'SolexaStageTwo'; }
sub description 
{
    my $self=shift;
    my $model= $self->model;
    #$self->preload_data();
    #my $output_file = $self->report_brief_output_filename;
    #my $brief = IO::File->new(">$output_file");
    #die unless $brief;

    #my $desc = $self->name . " read sets for " . $model->name . " as of " . UR::Time->now;
    #$brief->print("<div>$desc</div>");

    return '<div>'. $self->name . " read sets for " . $model->name . " as of " . UR::Time->now.'</div>';
}

sub generate_report_detail {    
    my $self=shift;
    my $model= $self->model;
    #my $output_file = $self->report_detail_output_filename;

    my $r = new CGI;

    my $model_name = $model->name;
    my @models = $self->preload_data(
        ($model_name ? (name => $model_name) : ())
    );

    my $title = "Genome Model Pipeline Stage 2 " . UR::Time->now;
    my $time = UR::Time->now;

    # the title doesn't end up in the report: fix me! ? 
    my $report = App::Report->create(title => $title, header => $title );

    for my $model (@models) {
        my $section_title = "<a href=" . $model->latest_build_directory . ">" 
                  . $model->name . " as of " . $time . "</a>"; 

        # the title doesn't end up in the report: fix me! ? 
        my $section = $report->create_section(title => \$section_title);
        
        $section->header(
            'Chromosome',
            'Merge Alignments',
            'Update Genotype',
            'Find Variations',
            'PP Variations',
            'Annotate Variations',
            'Filter Variations',
            'Upload Database',
        );
        my @model_chromosome_details = fetch_data_by_chromosome($model);
      
        for my $detail_arrayref (@model_chromosome_details) {
            $section->add_data(@$detail_arrayref);
        }
    }
    # FIXME put somewhere else
    my $output_file = 'no file';
    my $ajax_output_file= $output_file . "ajax";
    #my $ajax_file= IO::File->new(">$ajax_output_file");
    my $ajax_file= IO::String->new();
    for my $div_id (keys %div_hash) {
        $ajax_file->print($div_hash{$div_id} . "\n");
    }

    my $body = IO::File->new(">$output_file");
    die unless $body;
     
        #my $start_html = $r->start_html;
        #$body->print( $start_html);
        #$body->print( style($ajax_output_file) );
        $body->print( $report->generate(format => 'Html', no_header => 0));
        $body->print( legend() );
        $body->print( style($ajax_output_file) );
        $body->print( $r->end_html );
      
    $body->seek(0, 0);
    return join('', $body->getlines);
}

sub preload_data {
    my $self=shift;
    my @models = ($self->model);
    
    my @postprocess_alignments = Genome::Model::Command::Build::ReferenceAlignment::PostprocessAlignments->get(model_id => [map { $_->id } @models]);
    unless(@postprocess_alignments) {
        @postprocess_alignments = Genome::Model::Command::Build::ReferenceAlignment->get(model_id => [map { $_->id } @models]);
    }
    my @model_events = Genome::Model::Event->get(parent_event_id => [ map { $_->id } @postprocess_alignments ]);
    my %model_latest_event = map { $_->id => '' } @models;
    for my $e (@model_events) {
        my $date = $e->date_completed || $e->date_scheduled;
        if ($date gt $model_latest_event{$e->model_id}) {
            $model_latest_event{$e->model_id} = $date;
        }
    }
    @models = 
        sort { 
            ($model_latest_event{$b->id} cmp $model_latest_event{$a->id})
            or
            ($b->id <=> $a->id)
        }
        @models;
    return @models;
}
sub fetch_data_by_chromosome {
    
    #assert - at this point, we have been given a model, and wish 
    #to break down its events by chromosome
    #this will happen for all models
    
    my $model= shift;
    my @chromosome_rows;
    ##THIS IS OBVIOUSLY NOT THE BEST SOLUTION##

    my $tmp_file = '/gsc/var/cache/testsuite/lsf-tmp/bjob_query_result.txt';
    my @bjobs_lines = IO::File->new($tmp_file)->getlines;
    shift(@bjobs_lines);
    for my $bjob_line (@bjobs_lines) {
        my @job = split(/\s+/,$bjob_line);
        $job_to_status{$job[0]} = $job[2];
    }

    my @chromosomes;
    if($model->dna_type eq 'genomic dna') {  
        @chromosomes=$model->get_subreference_names(reference_extension=>'bfa');
        #@chromosomes= ((1..22),'X','Y');
    }
    else {
        @chromosomes='all_sequences';  
    }

    for my $chromosome (@chromosomes) {
        my $chromosome_row=parse_events($chromosome, $model);
        push(@chromosome_rows, $chromosome_row);
    }
    return @chromosome_rows;
}

sub format_time {
    my $event = shift;
    my $diff;
    if ($event->date_completed) {
        $diff = UR::Time->datetime_to_time($event->date_completed) - UR::Time->datetime_to_time($event->date_scheduled)
    }
    else {
        $diff = time - UR::Time->datetime_to_time( $event->date_scheduled)
    }
    my $m = int($diff/60);
    my $s = $diff % 60;
    return "${m}m ${s}s" if $m;
    return "${s}s";
}

sub format_date_time {
    my $event = shift;
    my $s = format_time($event);
    if ($event->event_status eq 'Successful') {
        my $date = $event->date_completed;
        $date =~ s/ .*//g;
        return "$date ($s)";
    }
    elsif ($event->event_status eq 'Scheduled') {
        my $date = $event->date_scheduled;
        return "$date";
    }
    elsif ($event->event_status eq 'Running') {
        my $date = $event->date_scheduled;
        return "$date ($s)";
    }
    else {
        my $date = $event->date_completed;
        $date =~ s/ .*//g;
        return "$date ($s)";
    }
}

sub parse_events {
    my $chromosome =shift;
    my $model = shift;
   
    my @finished_row_of_data = ($chromosome);
    
    my @steps = (
        'merge-alignments',
        'update-genotype',
        'find-variations',
        'postprocess-variations',
        'annotate-variations',
        'filter-variations',
        'upload-database',
    );
    
    if($chromosome eq '22') {
        $DB::single=1;
    } 

    $DB::single=1;    
    for my $step (@steps) {
        my @events=
            sort { $a->id cmp $b->id } 
            Genome::Model::Event->is_loaded(
                model_id => $model->id,
                event_type => { operator => "like", value => "%" . $step . "%" },
                ref_seq_id => $chromosome,
            );
            unless(@events) {
                @events=
                sort { $a->id cmp $b->id } 
                Genome::Model::Event->is_loaded(
                    model_id => $model->id,
                    event_type => { operator => "like", value => "%" . $step . "%" },
                    ref_seq_id => 'chr' . $chromosome,
                );
           }
        my $event_text;
        my $event_state;
        my @results;
        if (@events) {
            $event_state = 'Unknown';

            for my $event (reverse @events) {
                push @results, [
                    $event->id,
                    $event->event_status,
                    $event->retry_count,
                    $event->date_scheduled,
                    $event->date_completed,
                    $event->lsf_job_id,
                    format_time($event)
                ];
            }               

            my @lsf_ids = grep { $_ } map { $_->lsf_job_id } @events;

            my @lsf_statuses = 
                map { $_ . ': ' . $job_to_status{$_}  } 
                grep { $job_to_status{$_} }
                @lsf_ids;

            for my $event (reverse @events) {
                $event_text = format_date_time($event);
                if ($event->event_status =~ /Succeeded/) {
                    $event_state = $event->event_status;
                    last;
                }
                elsif ($event->event_status =~ /Failed|Crashed/) {
                    $event_state = $event->event_status;
                    last;
                }
                elsif ($event->event_status =~ /Scheduled/) {
                    if ($event->lsf_job_id && !$job_to_status{$event->lsf_job_id}) {
                        $event_state = 'NotScheduled';
                        last;
                    } else {
                        $event_state = $event->event_status;
                        last;
                    }
                }
                elsif ($event->event_status =~ /Running/) {
                    if ($event->lsf_job_id && !$job_to_status{$event->lsf_job_id}) {
                        $event_state = 'NotRunning';
                        last;
                    } else {
                        $event_state = $event->event_status;
                        last; 
                    }
                }
            }

            $event_text .= " (" . scalar(@events) . ")" if scalar(@events) > 1;
            if (@lsf_statuses) {
                $event_text .= "\n" . join("\n",@lsf_statuses);
            }
        }   

        my @merged;
        no warnings;
        for my $result (@results) {
            for (my $n=0; $n<@$result; $n++) {
                $merged[$n] .= ", " unless $result eq $results[0];
                $merged[$n] .= $result->[$n];
            }
        }
        my $detail = format_div_data(\@merged, $chromosome, $model);
        my $detail_n++;
        my $title=join(" ",$merged[0]);
        my $id=$step . "-" . $title;
        $id=~ s/\s+//g;
        $id=~ tr/,:()=/\-\-\-\-\-/;
        my $chopped_text=chop_time($event_text) if $event_text;
        if ($event_state) {
            $div_hash{$id}=qq| $id $detail  |;        
            push(@finished_row_of_data, \qq|<div class='$event_state'><span onclick="ajax_query(this)" title="$id">$chopped_text</span></div>|);
        }
        else {
            push(@finished_row_of_data, "Not Found");
        }
    }
    return \@finished_row_of_data;
}

sub format_div_data {
    my $merged = shift;
    my $chromosome= shift;
    my $model = shift;
    my $log_directory= $model->latest_build_directory .  "/logs/$chromosome/";
    my $formatted_string;

    no warnings; # tolerate undef = ''
    $formatted_string .= "<b>ID:</b> ".  @$merged[0] . "<br /> ";
    $formatted_string .= "<b>Status:</b> ".  @$merged[1] . "<br /> ";
    $formatted_string .= "<b>Retries:</b> ".  @$merged[2] . "<br /> ";
    $formatted_string .= "<b>Date Scheduled:</b> ".  @$merged[3] . "<br /> ";
    $formatted_string .= "<b>Date Completed:</b> ".  @$merged[4] . "<br /> ";
    $formatted_string .= "<b>Elapsed Time:</b> ".  @$merged[6] . "<br /> ";
    $formatted_string .= "<b>LSF Job:</b> ".  @$merged[5] . "<br /> ";

    my @ids = split(/,\s*/,@$merged[0]);
    use warnings;

    for my $id (@ids) {
        my $outputfile = $log_directory . $id . ".out";
        my $errfile = $log_directory . $id . ".err";
            $formatted_string .= "<a target='_blank' href='". $outputfile . "'>" . $id . " output</a><br />";
            $formatted_string .= "<a target='_blank' href='". $errfile . "'>" . $id  . " error</a><br />";
    }

    return $formatted_string;
}



sub chop_time {
    my $time=shift;
    $time=~ s/2008-//g;
    return $time;
}

sub style {
    my $ajax_output_file=shift;
    return "
    <script src='http://code.jquery.com/jquery-1.2.4a.js' type='text/javascript' ></script>
    <script src='/jquery.growl.js' type='text/javascript' > </script>
    <script type='text/javascript'>
   // \$(document).ready(function(\$) {
        \ function ajax_query(obj) {
            obj.parentNode.style.border='2px #F06 solid';
            id= obj.getAttribute('title');
            ajax='all_runs_ajax.cgi?ajaxfile=$ajax_output_file&searchstring=' + id;
            \$('#helper').load(ajax, function() {
            msgtext=\$('#helper').html();
            \$.growl(id, msgtext, obj);
        });
    }
 //   });
    </script>          
    <style>
    
    .growl a {
        color: #FFF;
    } 
    .broken 
    {
        background-color: #FF0000;
        color: #000000;
        font-weight: bold;
    }

    .Scheduled
    {
        background-color: #FFFF00;
        color: #000000;
    }

    .NotScheduled
    {
        background-color: #FF9900;
        color: #000000;
    }

    .Running
    {
        background-color: #3333FF;
        color: #000000;
    }

    .NotRunning
    {
        background-color: #FF00FF;
        color: #000000;
    }

    .Succeeded
    {
        background-color: #00FF00;
        color: #000000;
    }

    .NotSucceeded
    {
        background-color: #009900;
        color: #000000;
        font-weight: bold;
    }

    .Failed
    {
        background-color: #FF0000;
        color: #000000;
        font-weight: bold;
    }

    .Crashed
    {
        background-color: #660000;
        color: #000000;
        font-weight: bold;
    }

    .Unknown
    {
        background-color: #0000DD;
        color: #000000;
        font-weight: bold;
    }

    th
    { border-bottom: 2px solid #6699CC;
    border-left: 1px solid #6699CC;
    background-color: #BEC8D1;
    text-align: center;
    font-family: Verdana;
    font-weight: bold;
    font-size: 14px;
    color: #404040; }

 td
    { border-bottom: 1px solid #000;
    border-top: 0px;
    border-left: 1px solid #000;
    border-right: 0px;
    font-family: Verdana, sans-serif, Arial;
    font-weight: normal;
    font-size: 12px;
    padding: 0 0 0 0;
    
    background-color: #fafafa;
    border-spacing: 0px;
    margin-top: 0px;
}

table
{
    text-align: center;
    font-family: Verdana;
    font-weight: normal;
    font-size: 12px;
    color: #404040;
    background-color: #fafafa;
    border: 1px #000 solid;
    border-collapse: collapse;
    border-spacing: 0px;
}

tr td{
    background-color: #fafafa;
}

tr.row0 td{
    background-color: #fafafa;
}

tr.row1 td{
    background-color: #eeeeee;
}
a img {
    border: medium none;
    border-collapse: collapse;
}
.drag_it {
}
</style>"

}

sub legend
{
    my $text = <<'EOT';
                        <div id="legend">
                        <table>
                        <tr><th colspan=2 >Legend</th></tr>
                        <tr><th width=150px>Scheduled<td width=150px><div class="Scheduled">&nbsp;</div></td>
                        <tr><th width=150px>NotScheduled<td width=150px><div class="NotScheduled">&nbsp;</div></td>
                        <tr><th width=150px>Running<td width=150px><div class="Running">&nbsp;</div></td>
                        <tr><th width=150px>NotRunning<td width=150px><div class="NotRunning">&nbsp;</div></td>
                        <tr><th width=150px>Succeeded<td width=150px><div class="Succeeded">&nbsp;</div></td>
                        <tr><th width=150px>NotSucceeded<td width=150px><div class="NotSucceeded">&nbsp;</div></td>
                        <tr><th width=150px>Failed<td width=150px><div class="Failed">&nbsp;</div></td>
                        <tr><th width=150px>Crashed<td width=150px><div class="Crashed">&nbsp;</div></td>
                        <tr><th width=150px>Unknown<td width=150px><div class="Unknown">&nbsp;</div></td>
                        </table>
                        </div>
                        <div id="helper" style="display:none;"></div>
EOT
    return $text;
}

1;

