package Genome::Model::Command::Report::AmpliconAssembly;

use strict;
use warnings;

use Genome;

use File::Path;
use Data::Dumper 'Dumper';

class Genome::Model::Command::Report::AmpliconAssembly {
    is => 'Command',
    is_abstract => 1,
    has_optional => [
    model => {
        is => 'Genome::Model',
        is_input => 1,
        id_by => 'model_id',
        doc => 'Genome model id.  Will use most recent completed build.',
    },
    model_id => {
        is => 'Integer',
        doc => 'Genome model id.  Will use most recent completed build.',
    },
    #build_id => { is => 'Integer', is_input => 1, doc => 'Build id to generate report.' },
    ],
};

###################################################

#< Auto generate the subclasses >#
our @SUB_COMMAND_CLASSES;
my $module = __PACKAGE__;
$module =~ s/::/\//g;
$module .= '.pm';
my $path = $INC{$module};
$path =~ s/$module//;
$path .= 'Genome/Model/AmpliconAssembly/Report';
for my $target ( glob("$path/*pm") ) {
    $target =~ s#$path/##;
    $target =~ s/\.pm//;
    my $target_class = 'Genome::Model::AmpliconAssembly::Report::' . $target;
    my $target_meta = $target_class->get_class_object;
    unless ( $target_meta ) {
        eval("use $target_class;");
        die "$@\n" if $@;
        $target_meta = $target_class->get_class_object;
    }
    next if $target_class->get_class_object->is_abstract;
    my $subclass = __PACKAGE__.'::'. $target;
    #print Dumper({mod=>$module, path=>$path, target=>$target, target_class=>$target_class,subclass=>$subclass});

    no strict 'refs';
    class {$subclass} {
        is => __PACKAGE__,
        sub_classification_method_name => 'class',
    };
    push @SUB_COMMAND_CLASSES, $subclass;
}

###################################################

sub sub_command_dirs {
    my $class = ref($_[0]) || $_[0];
    return ( $class eq __PACKAGE__ ? 1 : 0 );
}

sub sub_command_classes {
    my $class = ref($_[0]) || $_[0];
    return ( $class eq __PACKAGE__ ? @SUB_COMMAND_CLASSES : 0 );
}

sub help_brief {
    my ($model_type, $report_type) = _model_and_report_types(@_);
    return sprintf(
        'Operate on %sreports for %s models',
        ( $report_type ? "$report_type "  : '' ),
        $model_type,
    );
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
EOS
}

###################################################

sub _get_class {
    return ref($_[0]) || $_[0];
}

sub _get_subclass {
    my $class = _get_class(@_);

    return if $class eq __PACKAGE__;
    
    my ($subclass) = $class =~ /::(.+)$/;

    return $subclass;
}

sub _target_class {
    my ($model_token, $report_token) = _model_and_report_tokens(@_)
        or return;
    
    return 'Genome::Model::'.$model_token.'::Report::'.$report_token;
}

sub _model_and_report_tokens {
    my $class = _get_class(@_);
    $class =~ s/Genome::Model::Command::Report:://;
    return split('::', $class);
}

sub _model_and_report_types {
    return map { _camel_split($_) } _model_and_report_tokens(@_);
}

sub _camel_split {
    my $string = shift;
    my @words = $string =~ /([A-Z](?:[A-Z]*(?=$|[A-Z][a-z])|[a-z]*))/g;
    return join(' ', map { lc } @words);
}

###################################################

sub execute {
    my $self = shift;

    # Make sure there aren't any bare args
    my $ref = $self->bare_args;
    if ( $ref && (my @args = @$ref) ) {
        $self->error_message("extra arguments: @args");
        $self->usage_message($self->help_usage_complete_text);
        return;
    }

    my $report_class = $self->_target_class;
    my $report = $report_class->create();
    for my $amplicon ( @{$self->model->get_amplicons} ) {
        $report->add_amplicon($amplicon);
    }
    $report->output_csv;

    return 1;
    
    my $build;
    if ( $self->model_id ) {
        my $model = Genome::Model->get( $self->model_id );
        unless ( $model ) {
            $self->error_message( sprintf('Can\'t get build for id (%s)', $self->build_id) );
            return;
        }
        $build = $self->model->last_complete_build;
        unless ( $build ) {
            $self->error_message( 
                sprintf( 'Can\'t get recent build for model (%s <ID> %s)', $model->name, $model->id,)
            );
            return;
        }
    }
    elsif ( $self->build_id ) {
        $build = Genome::Model::Build->get( $self->build_id );
        unless ( $build ) {
            $self->error_message( sprintf('Can\'t get build for id (%s)', $self->build_id) );
            return;
        }
    }
    else {
        $self->error_message("Need model id or build id to get build to generate report");
        return;
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
