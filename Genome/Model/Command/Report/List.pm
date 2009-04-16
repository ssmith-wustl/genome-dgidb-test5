package Genome::Model::Command::Report::List;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
require Term::ANSIColor;
require Text::Wrap;

class Genome::Model::Command::Report::List {
    is => 'Command',
    has_optional => [
        model_sub_type => {
            is => 'Text', 
            is_input => 1,
            doc => 'List reports for this model sub type only' 
        },
    ],
};

###################################################

sub help_brief {
    return 'Lists a models reports';
}

sub help_synopsis {
    return <<"EOS"
List all models' retpots
 genome model report list

List reports for reference alignment
 genome model report list --model-sub-type 'reference alignment'

EOS
}

sub help_detail {
    return <<"EOS"
    Lists all models (or, if specified, a particular sub type) reports.
EOS
}

###################################################

sub execute {
    my $self = shift;

    # Get perl dir we are using - then get the model dir
    my $module = _class_to_module(__PACKAGE__);
    my $directory = $INC{$module};
    $directory =~ s/$module//;
    my $model_directory = "$directory/Genome/Model";

    # Get a list of models sub types or use the one indicated
    my @model_sub_classes;
    if ( $self->model_sub_type ) {
        # TODO validate sub type?
        @model_sub_classes = join('', map { ucfirst } split(' ', $self->model_sub_type));
    }
    else {
        @model_sub_classes = glob("$model_directory/*pm");
    }

    # Get reports for models
    my %reports;
    for my $model_sub_class ( @model_sub_classes ) {
        $model_sub_class =~ s#$model_directory/##;
        $model_sub_class =~ s/\.pm//;

        # skip unless isa model
        my $model_class = 'Genome::Model::' . $model_sub_class;
        next unless $model_class->isa('Genome::Model');

        # skip if no reports dir
        my $report_directory = "$model_directory/$model_sub_class/Report";
        next unless -d $report_directory;

        # get model sub type
        my $model_sub_type = _camel_case_to_string($model_sub_class, ' ');
        
        for my $report_module ( glob("$report_directory/*pm") ) {
            $report_module =~ s#$directory/##;
            my $report_class = _module_to_class($report_module);
            #print $report_class,"\n";
            next unless $report_class->isa('Genome::Report::Generator');
            my ($report_subclass) = $report_class =~ m#::([\w\d]+)$#;
            my $report_name = _camel_case_to_string($report_subclass);
            push @{$reports{$model_sub_type}}, $report_name;
        }
    }

    unless ( %reports ) {
        if ( $self->model_sub_type ) { # this is ok
            printf("No reports found for '%s'\n", $self->model_sub_type);
            return 1;
        }
        else { # not ok
            $self->error_message("No reports found for any models!");
            return;
        }
    }
    
    return $self->_print_models_and_reports(\%reports)
}

sub _camel_case_to_string {
    my $camel_case = shift;
    my $join = ( @_ )
    ? $_[0]
    : ' '; 
    my @words = $camel_case =~ /([A-Z](?:[A-Z]*(?=$|[A-Z][a-z])|[a-z]*))/g;
    return join($join, map { lc } @words);
}

sub _class_to_module {
    my $module = shift;
    $module =~ s/::/\//g;
    $module .= '.pm';
    return $module;
}

sub _module_to_class {
    my $module = shift;
    $module =~ s#\.pm##;
    $module =~ s#/#::#g;
    return $module;
}

sub _print_models_and_reports {
    my ($self, $models_reports) = @_;

    my $string;
    for my $model ( sort { $a cmp $b } keys %$models_reports ) {
        $string .= Text::Wrap::wrap(
            '',
            '   ',
            Term::ANSIColor::colored('Reports for', 'bold'),
            Term::ANSIColor::colored($model, 'red'),
            "\n",
            join("\n", @{$models_reports->{$model}}),
        );
    }

    return print "$string\n";
}

1;

#$HeadURL$
#$Id$
