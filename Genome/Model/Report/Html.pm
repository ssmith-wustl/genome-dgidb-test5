package Genome::Model::Report::Html;

use strict;
use warnings;

use Genome::RunChunk;
use CGI;
use English;
use Memoize;
use IO::File;
use Cwd;
use File::Basename qw/basename/;
use App::Report;




class Genome::Model::Report::Html {
    is => 'Genome::Model::Report',
};

my %div_hash;
my %job_to_status;

sub _resolve_subclass_name {
    return;
}

sub get_brief_output
{
    my $self=shift;
    my $model= $self->model;

    my $desc = $self->name . ' for ' . $model->name . ' as of ' . UR::Time->now;
    return "<div>$desc</div>";
}

sub generate_report_brief 
{
    my $self=shift;
    my $model= $self->model;
    my $output_file = $self->report_brief_output_filename;
    my $brief = IO::File->new(">$output_file");
    die unless $brief;

    my $desc = $self->name . ' for ' . $model->name . ' as of ' . UR::Time->now;
    $brief->print("<div>$desc</div>");
}

sub generate_report_detail {
    my $self=shift;
    my $model= $self->model;
    my $name = $self->name;

    my $output_file = $self->report_detail_output_filename;
    
    my $r = new CGI;
     
    my $start_time = time;
    my $time = UR::Time->now;
    my $title = "$name Report for " .  $model->name . " as-of " . $time;
    my $report = App::Report->create(title => $title, header => $title );
    
       my $section_title = "<a href=\"https://gscweb.gsc.wustl.edu" . $model->data_directory . "\">" 
                    . $model->name . " (" . $model->id . ") " 
                    . " as of " . $time . "</a>"; 

        # the title doesn't end up in the report: fix me! ? 
        my $section = $report->create_section(title => \$section_title);
        
    my $elapsed_time = time - $start_time;
    
    my $body = IO::File->new(">$output_file");
    die unless $body;
     
        $body->print( $r->start_html(-title=> "$name for " . $model->genome_model_id ,));
        $body->print( $report->generate(format => 'Html', no_header => 0));
        $body->print("<p>(report processed in $elapsed_time seconds)<p>");
        $body->print( $self->legend() );
        $body->print( $r->end_html );
}

sub report_detail_output_filename
{
    my $self = shift;
    my $model = $self->model;
    my $name = $self->name;
    my $file;
    ($file) =  glob($model->resolve_reports_directory."$name/*.html");
    return $file or die("don't have file");
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

