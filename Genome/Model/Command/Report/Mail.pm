
package Genome::Model::Command::Report::Mail;

use strict;
use warnings;
use Mail::Sender;
use Genome;

class Genome::Model::Command::Report::Mail {
    is => 'Genome::Model::Command',
    has => [ 
        report_name => { 
            is => 'Text', 
            doc => "the name of the report to mail",
        },
        build   => { 
            is => 'Genome::Model::Build', 
            id_by => 'build_id',
            doc => "the specific build of a genome model to mail a report for",
        },
        build_id => {
            doc => 'the id for the build on which to report',
        },
        to => {
            is => 'Text', 
            doc => 'the recipient list to mail the report to',
        },

    ],
    has_optional => [
        directory => {
            is => 'Text', 
            doc => 'the path of report directory to mail.  the de',
        }
    ],
};

sub help_brief {
    "mail a report for a given build of a model"
}

sub help_synopsis {
    return <<EOS
genome model report mail --build-id 12345 --report-name "Summary" --to dlarson\@genome.wustl.edu,charris\@genome.wustl.edu

genome model report run -b 12345 -r "DbSnp" --to reseq\@genome.wustl.edu 

genome model report run -b 12345 -r "GoldSnp" --to reseq\@genome.wustl.edu --directory /gscuser/jpeck/reports

EOS
}

sub help_detail {
    return <<EOS
This launcher mails a report for some build of a genome model.

EOS
}

sub sub_command_sort_position { 1 }

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return unless $self;

$DB::single = 1;

    # TODO: move this up
    if (my $build = $self->build) {
        if ($self->model_name and $self->build->model->name ne $self->model_name) {
            $self->error_message("Redundant conflicting parameters.  Specified model name "
                . $self->model_name
                . " does not match the name of build " . $build->id
                . " which is " . $build->model->name
            );
            $self->delete;
            return; 
        }
    }
    elsif ($self->model_name) {
        my @models = Genome::Model->get(name => $self->model_name);
        unless (@models) {
            $self->warning_message("No models have exact name " . $self->model_name);
            @models = Genome::Model->get("name like" => $self->model_name . "%");
            unless (@models) {
                $self->error_message("No models have a name beginning with " . $self->model_name);
                $self->delete;
                return;
            }
            if (@models > 1) {
                $self->error_message("Found multiple models with names like " . $self->model_name . ":\n\t"
                    . join("\n\t", map { $_->name } @models)
                    . "\n"
                );
                $self->delete;
                return;
            }
            $self->status_message("Found model " . $models[0]->id . " (" . $models[0]->name . ")");
            my $build = $models[0]->last_complete_build;
            unless ($build) {
                $self->error_message("No complete build for model!");
                $self->delete;
                return;
            }
            $self->status_message("Found build " . $build->id . " from " . $build->date_completed);
            $self->build($build);
        }
    }
    else {
        $self->error_message("A build must be specified either directly, or indirectly via a model name!");
        $self->delete;
        return;
    }

    return $self;
}

sub execute {
    my $self = shift;
    
$DB::single = 1;
    
    my $build = $self->build;
    my $report_name = $self->report_name;

    my $report_path = $self->directory;
    unless ( defined($report_path) ) {
    	$report_path = $build->resolve_reports_directory;
    }
   
    my $html_file = $report_path."/".$self->report_name."/report.html"; 
    my $txt_file = $report_path."/".$self->report_name."/report.txt"; 

    unless (-e $html_file) {
	die "Could not find the report at: ".$html_file;
    }

    my $txt_option = ""; 
    if (-e $txt_file) {
	$txt_option = " -a $txt_file ";
    } else {
	print("Can't find a .txt file for this report.\n");	
    } 

    my $null_body = "/dev/null";
    my $subject = '"Report: '.$report_name.' from Build: '.$self->build_id.'"'; 
    my $mail_cmd = "mutt -a ".$html_file." ".$txt_option." -s ".$subject." ".$self->to." < ".$null_body;   
    print "Sending mail via: $mail_cmd\n"; 
    #system($mail_cmd);   
    send_mail(); 
    return 1;
}


sub send_mail {

    my $msg_txt = "This is my txt msg.";
    my $msg_html = "<html><body><h1>This is my html message</h1><img src=\"cid:img1\"></body></html>";

eval {
                (new Mail::Sender)->OpenMultipart({
			smtp => 'gscsmtp.wustl.edu',
                        to => 'jpeck@genome.wustl.edu',
                        from => 'jpeck@genome.wustl.edu',
                        subject => 'Alternatives with images',
                        debug => '/gscuser/ssmith/svn/pmr3/Genome/err.log',
                        multipart => 'related',
                })
                        ->Part({ctype => 'multipart/alternative'})
                                ->Part({ ctype => 'text/plain', disposition => 'NONE', msg => $msg_txt })
                                ->Part({ctype => 'text/html', disposition => 'NONE', msg => $msg_html})
                        ->EndPart("multipart/alternative")
                        ->Attach({
                                description => 'gsc logo gif',
                                ctype => 'image/jpeg',
                                encoding => 'base64',
                                disposition => "inline; filename=\"genome_center_logo.gif\";\r\nContent-ID: <img1>",
                                file => '/gscmnt/839/info/medseq/images/genome_center_logo.gif'
                        })
                ->Close();
        } or print "Error sending mail: $Mail::Sender::Error\n";


}


# TODO: move onto the build or report as a method
sub _resolve_valid_report_class_for_build_and_name{
    my $self = shift;
    
    my $build = shift;
    my $report_name = shift;
 
    my $report_class_suffix = 
        join('',
            map { ucfirst($_) } 
            split(" ",$report_name)
        );

    my @model_classes = (
        grep { $_->isa('Genome::Model') and $_ ne 'Genome::Model' } 
        map { $_, $_->inheritance }
        $build->model->get_class_object->class_name
    );

    my $report_class_meta;
    for my $model_class_name (@model_classes) {
        $report_class_meta = UR::Object::Type->get($model_class_name . '::Report::' . $report_class_suffix);
        last if $report_class_meta;
    }

    unless ($report_class_meta) {
        $self->error_message("No reports named '$report_name' are available for models of type "
            . join(", ", @model_classes));
        return;
    }

    return $report_class_meta->class_name;
}



1;

