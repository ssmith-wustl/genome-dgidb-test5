package Genome::Model::Tools::Sam;

use strict;
use warnings;

use Genome; 
use File::Basename;

my $DEFAULT = 'r544';
my $PICARD_DEFAULT = '1.22';
#3Gb
my $DEFAULT_MEMORY = 402653184;

class Genome::Model::Tools::Sam {
    is  => 'Command',
    has => [
        use_version => { 
            is  => 'Version', 
            doc => "samtools version to be used, default is $DEFAULT. ", 
            is_optional   => 1, 
            default_value => $DEFAULT,   
        },
        use_picard_version => { 
            is  => 'Version', 
            doc => "picard version to be used, default is $PICARD_DEFAULT",
            is_optional   => 1, 
            default_value => $PICARD_DEFAULT,   
        },
        maximum_memory => {
            is => 'Integer',
            doc => "the maximum memory available, default is $DEFAULT_MEMORY",
            is_optional => 1,
            default_value => $DEFAULT_MEMORY,
        },
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
    r544    => '/gsc/pkg/bio/samtools/samtools-0.1.7ar544/samtools',
    r510    => '/gsc/pkg/bio/samtools/samtools-0.1.7a/samtools',
    r453    => '/gsc/pkg/bio/samtools/samtools-0.1.6/samtools',
    r449    => '/gsc/pkg/bio/samtools/samtools-0.1.5-32/samtools',
    r301wu1 => '/gscuser/dlarson/samtools/r301wu1/samtools',
    r320wu1 => '/gscuser/dlarson/samtools/r320wu1/samtools',
    r320wu2 => '/gscuser/dlarson/samtools/r320wu2/samtools',
    r350wu1 => '/gscuser/dlarson/samtools/r350wu1/samtools',
);

my %PICARD_VERSIONS = (
    '1.22'  => '/gsc/scripts/lib/java/samtools/picard-tools-1.22',
    '1.21'  => '/gsc/scripts/lib/java/samtools/picard-tools-1.21',
    '1.17'  => '/gsc/scripts/lib/java/samtools/picard-tools-1.17',
    r116    => '/gsc/scripts/lib/java/samtools/picard-tools-1.16',
    r107    => '/gsc/scripts/lib/java/samtools/picard-tools-1.07/',
    r104    => '/gsc/scripts/lib/java/samtools/picard-tools-1.04/',
    r103wu0 => '/gsc/scripts/lib/java/samtools/picard-tools-1.03/',
);


sub path_for_samtools_version {
    my ($class, $version) = @_;
    $version ||= $DEFAULT;
    my $path = $SAMTOOLS_VERSIONS{$version};
    return $path if defined $path;
    die 'No path found for samtools version: '.$version;
}

sub path_for_picard_version {
    my ($class, $version) = @_;
    $version ||= $PICARD_DEFAULT;
    my $path = $PICARD_VERSIONS{$version};
    return $path if defined $path;
    die 'No path found for samtools version: '.$version;
}

sub default_samtools_version {
    die "default samtools version: $DEFAULT is not valid" unless $SAMTOOLS_VERSIONS{$DEFAULT};
    return $DEFAULT;
}
 
sub default_picard_version {
    die "default picard version: $PICARD_DEFAULT is not valid" unless $PICARD_VERSIONS{$PICARD_DEFAULT};
    return $PICARD_DEFAULT;
}
        
    
sub samtools_path {
    my $self = shift;
    return $self->path_for_samtools_version($self->use_version);
}

sub picard_path {
    my $self = shift;
    return $self->path_for_picard_version($self->use_picard_version);
}


sub samtools_pl_path {
    my $self = shift;
    my $dir  = dirname $self->samtools_path;
    my $path = "$dir/misc/samtools.pl";
    
    unless (-x $path) {
        $self->error_message("samtools.pl: $path is not executable");
        return;
    }
    return $path;
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

