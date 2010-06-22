package Genome::Model::Tools::Picard;

use strict;
use warnings;

use Genome; 
use File::Basename;

my $PICARD_DEFAULT = '1.17';
my $DEFAULT_MEMORY = 2;
my $DEFAULT_VALIDATION_STRINGENCY = 'SILENT';

class Genome::Model::Tools::Picard {
    is  => 'Command',
    has_input => [
        use_version => { 
            is  => 'Version', 
            doc => 'Picard version to be used.  default_value='. $PICARD_DEFAULT,
            is_optional   => 1, 
            default_value => $PICARD_DEFAULT,
        },
        maximum_memory => {
            is => 'Integer',
            doc => 'the maximum memory (Gb) to use when running Java VM. default_value='. $DEFAULT_MEMORY,
            is_optional => 1,
            default_value => $DEFAULT_MEMORY,
        },
        temp_directory => {
            is => 'String',
            doc => 'A temp directory to use when sorting or merging BAMs results in writing partial files to disk.  The default temp directory is resolved for you if not set.',
            is_optional => 1,
        },
        validation_stringency => {
            is => 'String',
            doc => 'Controls how strictly to validate a SAM file being read. default_value='. $DEFAULT_VALIDATION_STRINGENCY,
            is_optional => 1,
            default_value => $DEFAULT_VALIDATION_STRINGENCY,
            valid_values => ['SILENT','STRICT','LENIENT'],
        },
    ],
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "Tools to run the Java toolkit Picard and work with SAM/BAM format files.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt picard ...    
EOS
}

sub help_detail {                           
    return <<EOS 
More information about the Picard suite of tools can be found at http://picard.sourceforge.net/.
EOS
}

my %PICARD_VERSIONS = (
    '1.23' => '/gsc/scripts/lib/java/samtools/picard-tools-1.23',
    'r436' => '/gsc/scripts/lib/java/samtools/picard-tools-r436', #contains a fix for when a whole library is unmapped
    '1.22' => '/gsc/scripts/lib/java/samtools/picard-tools-1.22',
    '1.21' => '/gsc/scripts/lib/java/samtools/picard-tools-1.21',
    '1.17' => '/gsc/scripts/lib/java/samtools/picard-tools-1.17',
    # old processing profiles used a different standard
    # this was supposed to be ONLY for things where we work directly from svn instead of released versions, like samtools :(
    'r116' => '/gsc/scripts/lib/java/samtools/picard-tools-1.16',
    'r107' => '/gsc/scripts/lib/java/samtools/picard-tools-1.07/',
    'r104' => '/gsc/scripts/lib/java/samtools/picard-tools-1.04/',
    'r103wu0' => '/gsc/scripts/lib/java/samtools/picard-tools-1.03/',
);

sub path_for_picard_version {
    my ($class, $version) = @_;
    $version ||= $PICARD_DEFAULT;
    my $path = $PICARD_VERSIONS{$version};
    return $path if defined $path;
    die 'No path found for picard version: '.$version;
}

sub default_picard_version {
    die "default picard version: $PICARD_DEFAULT is not valid" unless $PICARD_VERSIONS{$PICARD_DEFAULT};
    return $PICARD_DEFAULT;
}

sub picard_path {
    my $self = shift;
    return $self->path_for_picard_version($self->use_version);
}

sub run_java_vm {
    my $self = shift;
    my %params = @_;
    my $cmd = delete($params{'cmd'});
    unless ($cmd) {
        die('Must pass cmd to run_java_vm');
    }
    my $java_vm_cmd = 'java -Xmx'. $self->maximum_memory .'g -cp '. $cmd;
    $java_vm_cmd .= ' VALIDATION_STRINGENCY='. $self->validation_stringency;
    $java_vm_cmd .= ' TMP_DIR='. $self->temp_directory;
    $params{'cmd'} = $java_vm_cmd;
    Genome::Utility::FileSystem->shellcmd(%params);
    return 1;
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    unless ($self->temp_directory) {
        my $base_temp_directory = Genome::Utility::FileSystem->base_temp_directory;
        my $temp_dir = File::Temp::tempdir($base_temp_directory .'/Picard-XXXX', CLEANUP => 1);
        Genome::Utility::FileSystem->create_directory($temp_dir);
        $self->temp_directory($temp_dir);
    }
    return $self;
}

1;

