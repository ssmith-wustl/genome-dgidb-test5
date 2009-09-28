
package Genome::Model::Command::Export;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Export {
    is => 'Genome::Model::Command',
    has => [ 
           model => { is => 'Genome::Model', id_by => 'model_id'},
           #generate_report_brief => { is_abstract => 1 },
           #generate_report_detail => { is_abstract => 1},
       ],
};

sub help_brief {
    "export data about a model into an external format"
}

sub sub_command_sort_position { 97 }

sub generate_report_brief {
    die "Implement me in the subclass, owangutang";
}

sub generate_report_detail {
    die "Implement generate_report_detail in the subclass you're writing, or this will 
     continue to fail";
 }



sub resolve_reports_directory {
    my $self = shift;
    my $reports_dir = $self->model->resolve_reports_directory;
    unless(-d $reports_dir) {
        unless(mkdir $reports_dir) {
            $self->error_message("Directory $reports_dir doesn't exist, can't create");
            return;
        }
        chmod 02775, $reports_dir;
    }
   return $reports_dir;
}


##these can be moved down to subclass or subclasses can supply a type argument to support
##files other than HTML...don't freak out, you danglers
sub report_brief_output_filename {
    my $self=shift;
    return $self->resolve_reports_directory . "/brief.html";
}

sub report_detail_output_filename {
    my $self=shift;
    return $self->resolve_reports_directory . "/detail.html";
}


1;

