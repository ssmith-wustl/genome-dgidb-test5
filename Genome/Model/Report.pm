
package Genome::Model::Report;

use strict;
use warnings;

use Genome;

class Genome::Model::Report {
    sub_classification_method_name => '_resolve_subclass_name',
    has => [
           build => {is => 'Genome::Model::Command::Build', id_by => 'build_id'},
           build_id => {is => 'Integer', doc=>'identifies the build this report directory belongs to'},

           model => {is => 'Genome::Model', via => 'build'},
           model_id        => { is => 'Integer', doc => 'identifies the genome model by id' },
           model_name      => { is => 'String', via => 'model', to => 'name' },

           name            => { is => 'String'},
    ],
    has_optional => [
           type            => { is => 'String'},
    ],
};

sub help_brief {
    "generate reports for a given model"
}

sub sub_command_sort_position { 12 }

sub generate_report_brief {
    die "Implement me in the subclass, owangutang";
}

sub generate_report_detail {
     die "Implement generate_report_detail in the subclass you're writing, or this will 
     continue to fail";
}

sub _resolve_subclass_name {
    my $class = shift;

    if ($class ne __PACKAGE__ and $class->isa(__PACKAGE__)) {
        # already subclassed!
        return $class;
    }

    $DB::single = $DB::stopper;
 
    if (ref($_[0]) and $_[0]->isa(__PACKAGE__)) 
    {
        my $name = $_[0]->name;
        my $build_id = $_[0]->build_id;
        return $class->_resolve_subclass_name_for_name($build_id,$name);
    }
    elsif (my $name = $class->get_rule_for_params(@_)->specified_value_for_property_name('name')) 
    {
        my $build_id = $class->get_rule_for_params(@_)->specified_value_for_property_name('build_id');
        return $class->_resolve_subclass_name_for_model_and_name($build_id,$name);
    }
    else 
    {
        return;
    }
}

sub _resolve_subclass_name_for_model_and_name {
    my $class = shift;
    my $build_id = shift;
    my $name = shift;

    $DB::single = $DB::stopper;
    my $build = Genome::Model::Build->get(id => $build_id);
    my $report_dir = $build->resolve_reports_directory;
    unless (-d $report_dir) {
        $class->error_message("No $name report directory for ".$report_dir);
        return;
    }

    my ($file)=glob("$report_dir/generation_class.*");
    if($file) {
        $DB::single=1;
        #so, we found a generating class notation..this is a regular report
        my ($class) = ($file =~ /generation_class.(.*)/);
        return "Genome::Model::Report::$class";
    }

    ($file) = glob("$report_dir/*.html");
    if($file) {
        $DB::single=1;
        return "Genome::Model::Report::Html";
    }

    ($file) = glob("$report_dir/*.[ct]sv");
    if($file) {

        $DB::single=1;
        return "Genome::Model::Report::Table";
    }
    return;
}

# This is called by both of the above.
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

sub get_brief_output
{
    my $self=shift;
    my $fh = new FileHandle;
    my $bod;
    #ensure file exists (do check)
    #(-e $self->report_brief_output_filename) or die("no have it");#$self->generate_report_brief();
    (-e $self->report_brief_output_filename or 
        $self->generate_report_brief() and 
        return "File not found. Generating now...");

    if ($fh->open("< " . $self->report_brief_output_filename )) 
    {
        while (!$fh->eof())
        {
            $bod .= $fh->getline;
        }
        $fh->close;
    }
    return $bod;
}

sub get_detail_output
{
    my $self=shift;
    my $fh = new FileHandle;
    my $bod;

    #ensure file exists (do check)

    #(-e $self->report_detail_output_filename ) or die("no have it");#$self->generate_report_detail();
    (-e $self->report_detail_output_filename or 
        $self->generate_report_detail() and 
        return "File not found.  Generating now...");
    if ($fh->open("< " . $self->report_detail_output_filename )) 
    {
        while (!$fh->eof())
        {
            $bod .= $fh->getline;
        }
        $fh->close;
    }
    return $bod;
}

sub create {
    #needs to return a file path, not a string 
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return unless $self;
    unless ($class->get_class_object->get_property_meta_by_name("model")->is_optional or $self->model) {
        if ($self->bare_args) {
            my $pattern = $self->bare_args->[0];
            if ($pattern) {
                my @models = Genome::Model->get(name => { operator => "like", value => '%' . $pattern . '%' });
                if (@models >1) {
                    $self->error_message(
                        "No model specified, and multiple models match pattern \%${pattern}\%!\n"
                        . join("\n", map { $_->name } @models)
                        . "\n"
                    );
                    $self->delete;
                    return;
                }
                elsif (@models == 1) {
                    $self->model($models[0]);
                }
            } else {
                # continue, the developer may set this value later...
            }
        } else {
            $self->error_message("No model or bare_args exists");
            $self->delete;
            return;
        }
    }
    return $self;
}
1;

