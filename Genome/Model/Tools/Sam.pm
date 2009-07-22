package Genome::Model::Tools::Sam;

use strict;
use warnings;

use Genome; 
use File::Basename;

my $DEFAULT = 'r320wu1';

class Genome::Model::Tools::Sam {
    is  => 'Command',
    has => [
        use_version => { 
            is  => 'Version', 
            doc => "samtools version to be used, default is $DEFAULT",
            is_optional   => 1, 
            default_value => $DEFAULT,   
        }
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
Everytime when we get a new version of samtools, we need update in this module and create new 
processing_profile/model for pipeline.
EOS
}


my %SAMTOOLS_VERSIONS = (
    r301wu1 => '/gscuser/dlarson/samtools/r301wu1/samtools',
    r320wu1 => '/gscuser/dlarson/samtools/r320wu1/samtools',
    r320wu2 => '/gscuser/dlarson/samtools/r320wu2/samtools',
    r350wu1 => '/gscuser/dlarson/samtools/r350wu1/samtools',
);


sub path_for_samtools_version {
    my ($class, $version) = @_;
    $version ||= $DEFAULT;
    my $path = $SAMTOOLS_VERSIONS{$version};
    return $path if defined $path;
    die 'No path found for samtools version: '.$version;
}


sub default_samtools_version {
    die "default samtools version: $DEFAULT is not valid" unless $SAMTOOLS_VERSIONS{$DEFAULT};
    return $DEFAULT;
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

