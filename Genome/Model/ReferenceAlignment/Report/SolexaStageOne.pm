package Genome::Model::ReferenceAlignment::Report::SolexaStageOne;

use strict;
use warnings;

use CGI;
use English;
use Memoize;
use IO::File;
use Cwd;
use File::Basename qw/basename/;
use App::Report;




class Genome::Model::ReferenceAlignment::Report::SolexaStageOne {
    is => 'Genome::Model::Report',
};

my %div_hash;
my %job_to_status;

sub _generate_data {
    # FIXME ajax file needs to go somewhere see detail...
    my $self = shift;

    return {
        html => $self->generate_report_detail,
    };
}

sub name { return 'SolexaStageOne'; }
sub description 
{
    my $self=shift;
    my $model= $self->model;
    $self->get_models_and_preload_related_data();
    #my $output_file = $self->report_brief_output_filename;
    my @details = get_instrument_data_for_model($model);
    #my $brief = IO::File->new(">$output_file");
    #die unless $brief;

    #my $desc = @details . " instrument data for " . $model->name . " as of " . UR::Time->now;
    #$brief->print("<div>$desc</div>");

    my $desc = '<div>'.@details . " instrument data for " . $model->name . " as of " . UR::Time->now.'</div>';
}

sub generate_report_detail {
    my $self=shift;
    my $model= $self->model;
    $self->get_models_and_preload_related_data();
    #my $output_file = $self->report_detail_output_filename;
    
    my $r = new CGI;
     
    my $start_time = time;
    my $time = UR::Time->now;
    my $title = "Genome Model Pipeline Stage 1 for " .  $model->name . " as-of " . $time;
    my $report = App::Report->create(title => $title, header => $title );
    
       my $section_title = "<a href=\"https://gscweb.gsc.wustl.edu" . $model->data_directory . "\">" 
                    . $model->name . " (" . $model->id . ") " 
                    . " as of " . $time . "</a>"; 

        # the title doesn't end up in the report: fix me! ? 
        my $section = $report->create_section(title => \$section_title);
        
        $section->header(
            'Library Name',
            'Run Name',
            'Lane',
            'Paired',
            'Read Length',
            'DB ID',
            'GERALD Dir',
            'Assign-Run',
            'Align-Rds',
            'Proc-LQ',
        );
        my @details = get_instrument_data_for_model($model);
      
        for my $detail_arrayref (@details) {
            $section->add_data(@$detail_arrayref);
        }
    # FIXME put somewhere else
    my $output_file = 'no file';
    my $ajax_output_file= $output_file . "ajax";
    #my $ajax_file= IO::File->new(">$ajax_output_file");
    my $ajax_file= IO::String->new();
    for my $div_id (keys %div_hash) {
        $ajax_file->print($div_hash{$div_id} . "\n");
    }
    my $elapsed_time = time - $start_time;
    
    #my $body = IO::File->new(">$output_file");
    my $body = IO::String->new();
    die unless $body;
     
        $body->print( $r->start_html(-title=> 'Solexa Stage One for ' . $model->genome_model_id ,));
        $body->print( $report->generate(format => 'Html', no_header => 0));
        $body->print("<p>(report processed in $elapsed_time seconds)<p>");
        $body->print( $self->legend() );
        $body->print( style($ajax_output_file) );
        $body->print( $r->end_html );

    $body->seek(0, 0);
    return join('', $body->getlines);
}

sub get_models_and_preload_related_data {
    $DB::single=1;
    my $self=shift;
    my @models = ($self->model);
    my %model_latest_event;
    my %model_instrument_data;
    for my $m (@models) {
        for my $e ($m->events) {
            if ($e->instrument_data_id) {
                $model_instrument_data{$e->instrument_data_id}++;
            }
            no warnings;
            my $date = $e->date_completed || $e->date_scheduled;
            if ($date gt $model_latest_event{$e->model_id}) {
                $model_latest_event{$e->model_id} = $date;
            }
        }
    }
    my @instrument_data = Genome::InstrumentData->get([keys %model_instrument_data]);
    my @lanes = GSC::RunLaneSolexa->get([keys %model_instrument_data]);
    @models =
    sort {
        ($model_latest_event{$b->id} cmp $model_latest_event{$a->id})
            or
        ($b->id <=> $a->id)
    }
    @models;

    # Record the latest status of LSF jobs.
    # THIS IS OBVIOUSLY NOT THE BEST SOLUTION
    my $tmp_file = '/gsc/var/cache/testsuite/lsf-tmp/bjob_query_result.txt';
    my @bjobs_lines = IO::File->new($tmp_file)->getlines;
    shift(@bjobs_lines);
    for my $bjob_line (@bjobs_lines) {
        my @job = split(/\s+/,$bjob_line);
        $job_to_status{$job[0]} = $job[2];
    }

    return @models;
}



sub get_instrument_data_for_model {
    #assert - at this point, we have been given a model, and wish 
    #to break down its events by chromosome
    #this will happen for all models
    my $model= shift;
    my @assigned_instrument_data = $model->instrument_data;
    my @steps = Genome::ProcessingProfile::ReferenceAlignment::Solexa->alignment_job_classes;
    my @rows;
    for my $r (@assigned_instrument_data) {
        my $rls= GSC::RunLaneSolexa->get($r->id);
        my @row = (
            library_name($r->library_name),
            run_name($r->run_name),
            $r->subset_name,
            (eval { $r->is_paired_end } || $@),
            $r->read_length,
            $r->id,
            gerald_directory($r->full_path),
            map { data_for_step($rls, $_, $model) } @steps
        );
        push @rows, \@row;
    }
    
    return @rows;
}

sub library_name {
    my ($library_name) = @_;
    return '' if ! $library_name;
    return \qq|<a href='http://intweb/cgi-bin/solexa/solexa_summary.cgi?action=search&by=dna_name&search_param=$library_name'>$library_name</a>|;
}


sub run_name {
    my ($run_name) = @_;
    return '' if ! $run_name;
    my $flow_cell_id = $run_name;
    $flow_cell_id =~ s/^.*_//;
    return \qq|<a href='http://intweb/cgi-bin/solexa/solexa_summary.cgi?action=search&by=flow_cell_id&search_param=$flow_cell_id'>$run_name</a>|;
}

sub gerald_directory {
    my $gerald_directory = $_[0];
    return '' if ! $gerald_directory;
    if (defined($gerald_directory) and -d $gerald_directory) {
        return \qq|<a href='$gerald_directory/Summary.htm'>ok</a>|;
    }
    else {
        return \qq|<a href='$gerald_directory/Summary.html' class='broken'>MISSING</a>|;
    }
}

sub data_for_step {
    my ($lane,$step_class,$model,$events_override) = @_;
    my @results;
    $DB::single=1;
    my $event_state;
    my $event_text;


    my @rc = Genome::InstrumentData->is_loaded(
        instrument_data_id => $lane->id,
        sample_name => $lane->sample_name, # this gets around dups in this temp table from testing
    );

    if (@rc == 0) {
        $event_state = '';
    }
    elsif (@rc > 1) {
        die "multiple RC for " . $lane->seq_id . " " . $lane->sample_name;
    }
    else {
        my @events = 
        sort { $a->date_scheduled cmp $b->date_scheduled } 
        $step_class->is_loaded(
            model_id => $model->id,
            #event_type => { operator => "like", value => "%" . $step . "%" },
            instrument_data_id => $rc[0]->id
        );
        if (@events) {
            $event_state = 'Unknown';

            for my $event (@events) {
                push @results, [
                $event->id,
                $event->event_status,
                $event->retry_count,
                $event->date_scheduled,
                $event->date_completed,
                $event->lsf_job_id,
                format_time($event),
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
                elsif ($event->event_status =~ /Failed|Crashed|Abandoned/) {
                    $event_state = $event->event_status;
                    $event_text = $event->date_scheduled;
                    last;
                }
                elsif ($event->event_status =~ /Scheduled/) {
                    if ($event->lsf_job_id && !$job_to_status{$event->lsf_job_id}) {
                        $event_state = 'NotScheduled';
                        $event_text = $event->date_scheduled;
                    } else {
                        $event_state = $event->event_status;
                        $event_text = $event->date_scheduled;
                    }
                }
                elsif ($event->event_status =~ /Running/) {
                    if ($event->lsf_job_id && !$job_to_status{$event->lsf_job_id}) {
                        $event_state = 'NotRunning';
                        $event_text = $event->date_scheduled;
                    } else {
                        $event_state = $event->event_status;
                        $event_text = $event->date_scheduled;
                    }
                }
            }

            $event_text .= " (" . scalar(@events) . ")" if scalar(@events) > 1;
            if (@lsf_statuses) {
                $event_text .= "\n" . join("\n",@lsf_statuses);
            }
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
    $DB::single=1;
    my $gm_run = Genome::InstrumentData->is_loaded(instrument_data_id => $lane->id, sample_name => $lane->sample_name);
    my $detail = format_div_data(\@merged, $gm_run, $model);
    my $detail_n++;
    my $title=join(" ",$merged[0]);
    my $id=$step_class . "-" . $title;
    $id=~ s/\s+//g;
    $id=~ tr/,:()=/\-\-\-\-\-/;
    my $chopped_text=chop_time($event_text) if $event_text;
    if ($event_state) {
        $div_hash{$id}=qq| $id $detail |;        
        return \qq|<div class='$event_state'><span onclick="ajax_query(this)" title="$id">$chopped_text</span></div>|;
    }
    else {
        return $event_text;
    }
}

sub format_date_time {
    my $event = shift;
    my $s = format_time($event);
    if ($event->event_status eq 'Successful') {
        my $date = $event->date_completed;
        $date ||= '';
        $date =~ s/ .*//g;
        return "$date ($s)";
    }
    elsif ($event->event_status eq 'Scheduled') {
        my $date = $event->date_scheduled;
        $date ||= '';
        return "$date";
    }
    elsif ($event->event_status eq 'Running') {
        my $date = $event->date_scheduled;
        $date ||= '';
        return "$date ($s)";
    }
    else {
        my $date = $event->date_completed;
        $date ||= '';
        $date =~ s/ .*//g;
        return "$date ($s)";
    }
}





sub format_div_data {
    my $merged = shift;
    my $instrument_data= shift;
    my $model = shift;
        my $log_directory= $model->latest_build_directory . "/logs/solexa/" . $instrument_data->run_name . "/";
    my $formatted_string;

    no warnings; # tolerate undef = ''
    $formatted_string .= "<b>ID:</b> ".  @$merged[0] . "<br /> ";
    $formatted_string .= "<b>Status:</b> ".  @$merged[1] . "<br /> ";
    $formatted_string .= "<b>Retries:</b> ".  @$merged[2] . "<br /> ";
    $formatted_string .= "<b>Date:</b> ".  @$merged[3] . "<br /> ";
    $formatted_string .= "<b>LSF Job:</b> ".  @$merged[4] . "<br /> ";
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




sub style {
    my $ajax_output_file=shift;
    return "
    <script src='http://code.jquery.com/jquery-1.2.4a.js' type='text/javascript' ></script>
    <script src='http://linus215:3000/static/js/jquery.growl.js' type='text/javascript' > </script>
    <script type='text/javascript'>
   // \$(document).ready(function(\$) {
        \ function ajax_query(obj) {
            obj.parentNode.style.border='2px #F06 solid';
            id= obj.getAttribute('title');
            ajax='/cgi-bin/solexa/all_runs_ajax.cgi?ajaxfile=$ajax_output_file&searchstring=' + id;
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
    .Abandoned
    {
        background-color: #000;
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

