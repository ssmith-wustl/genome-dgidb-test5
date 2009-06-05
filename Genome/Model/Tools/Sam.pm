package Genome::Model::Tools::Sam;

use strict;
use warnings;

use Genome;                         # >above< ensures YOUR copy is used during development

use File::Basename;

class Genome::Model::Tools::Sam {
    is => 'Command',
    has => [
        use_version => { is => 'Version', is_optional => 1, default_value => 'r301wu1', doc => 'Version of Sam to use' }
    ],
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "Tools to run Sam or work with its output files.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools Sam ...    
EOS
}

sub help_detail {                           
    return <<EOS 
More information about the Sam suite of tools can be found at http://Samtools.sourceforege.net.
EOS
}


my %SAMTOOLS_VERSIONS = (
    r301wu1 => '/gscuser/dlarson/samtools/r301wu1/samtools',
);


sub path_for_samtools_version {
    my ($class, $version) = @_;
    my $path = $SAMTOOLS_VERSIONS{$version};
    return $path if defined $path;
    die 'No path found for samtools version: '.$version;
}

sub samtools_path {
    my $self = shift;
    return $self->path_for_samtools_version($self->use_version);
}

sub c_linkage_class {
    my $self = shift;

$DB::single = $DB::stopper;
    my $version = $self->use_version;
    $version =~ s/\./_/g;

    my $class_to_use = __PACKAGE__ . "::CLinkage$version";
  
    #eval "use above '$class_to_use';";
    eval "use $class_to_use;";
    if ($@) {
        $self->error_message("Failed to use $class_to_use: $@");
        return undef;
    }

    return $class_to_use;
}

1;

